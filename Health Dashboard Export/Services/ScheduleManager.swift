//
//  ScheduleManager.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import Foundation
import BackgroundTasks
import Combine
import UserNotifications

@MainActor
class ScheduleManager: ObservableObject {
    @Published var schedules: [SyncSchedule] = []
    
    private let userDefaults: UserDefaults
    private let nowProvider: () -> Date
    private let shouldManageBackgroundTasks: Bool
    private let schedulesKey = "syncSchedules"
    private let backgroundTaskIdentifier = "com.healthexport.sync"
    private let notificationsPermissionRequestedKey = "notificationsPermissionRequested"
    
    init(
        userDefaults: UserDefaults = .standard,
        shouldManageBackgroundTasks: Bool = true,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.shouldManageBackgroundTasks = shouldManageBackgroundTasks
        self.nowProvider = nowProvider
        loadSchedules()
        registerBackgroundTasks()
        normalizeSchedules()
        if shouldManageBackgroundTasks, !schedules.isEmpty {
            scheduleBackgroundTask()
        }
    }
    
    // MARK: - Schedule Management
    
    func addSchedule(_ schedule: SyncSchedule) {
        let isFirstSchedule = schedules.isEmpty
        schedules.append(schedule)
        saveSchedules()
        if isFirstSchedule {
            Task {
                await requestNotificationPermission()
            }
        }
        scheduleBackgroundTask()
    }
    
    func updateSchedule(_ schedule: SyncSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
            scheduleBackgroundTask()
        }
    }
    
    func deleteSchedule(_ schedule: SyncSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
        scheduleBackgroundTask()
    }
    
    func toggleSchedule(_ schedule: SyncSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            scheduleBackgroundTask()
        }
    }
    
    // MARK: - Persistence

    private func loadSchedules() {
        guard let data = userDefaults.data(forKey: schedulesKey),
              let decoded = try? JSONDecoder().decode([SyncSchedule].self, from: data) else {
            schedules = []
            return
        }
        schedules = decoded
    }

    private func saveSchedules() {
        guard let encoded = try? JSONEncoder().encode(schedules) else { return }
        userDefaults.set(encoded, forKey: schedulesKey)
    }

    /// Triggers a refresh so next-run calculations reflect the current time.
    func normalizeSchedules(now: Date? = nil) {
        _ = now ?? nowProvider()
        objectWillChange.send()
    }

    func nextRun(for schedule: SyncSchedule, now: Date? = nil) -> Date? {
        let now = now ?? nowProvider()

        guard schedule.isEnabled else {
            return nil
        }

        let currentNextRun: Date
        if let lastRun = schedule.lastRun {
            currentNextRun = schedule.frequency.calculateNextRunAfter(date: lastRun, at: schedule.time)
        } else {
            currentNextRun = schedule.frequency.calculateNextRun(from: now, at: schedule.time)
        }
        if currentNextRun > now {
            return currentNextRun
        }

        var updatedNextRun = currentNextRun
        while updatedNextRun <= now {
            updatedNextRun = schedule.frequency.calculateNextRunAfter(
                date: updatedNextRun,
                at: schedule.time
            )
        }

        return updatedNextRun
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        guard shouldManageBackgroundTasks else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
    }
    
    private func scheduleBackgroundTask() {
        guard shouldManageBackgroundTasks else { return }

        normalizeSchedules()

        // Cancel existing tasks
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        
        // Find next scheduled task
        guard let nextSchedule = getNextSchedule() else {
            print("No active schedules")
            return
        }
        
        guard let nextRun = nextRun(for: nextSchedule) else {
            print("No next run time calculated")
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = nextRun
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✓ Background task scheduled for \(nextRun)")
        } catch {
            print("✗ Could not schedule background task: \(error)")
        }
    }
    
    private func getNextSchedule() -> SyncSchedule? {
        let activeSchedules = schedules.filter { $0.isEnabled }
        let now = nowProvider()
        return activeSchedules.min(by: {
            (nextRun(for: $0, now: now) ?? Date.distantFuture) < (nextRun(for: $1, now: now) ?? Date.distantFuture)
        })
    }
    
    // MARK: - Background Task Execution
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        print("🔔 Background task triggered at \(Date())")

        normalizeSchedules()

        // Schedule next background task
        scheduleBackgroundTask()

        // Create task expiration handler
        task.expirationHandler = {
            print("⚠️ Background task expired before completion")
        }

        // Find schedules that need to run
        let now = Date()
        print("📋 Checking \(schedules.count) schedules at \(now)")

        let schedulesToRun = schedules.filter { schedule in
            guard schedule.isEnabled else {
                print("⏭️ Skipping disabled schedule: \(schedule.name)")
                return false
            }
            guard let nextRun = nextRun(for: schedule, now: now) else {
                print("⏭️ Skipping schedule with no next run: \(schedule.name)")
                return false
            }
            let shouldRun = nextRun <= now
            print("🔍 Schedule '\(schedule.name)': nextRun=\(nextRun), shouldRun=\(shouldRun)")
            return shouldRun
        }

        guard !schedulesToRun.isEmpty else {
            print("✅ No schedules ready to run")
            task.setTaskCompleted(success: true)
            return
        }

        print("🚀 Executing \(schedulesToRun.count) scheduled sync(s)")

        // Execute syncs
        let exporter = HealthExporter()
        var success = true

        for schedule in schedulesToRun {
            do {
                print("▶️ Starting sync: \(schedule.name) (\(schedule.syncType.rawValue))")
                switch schedule.syncType {
                case .incremental:
                    try await exporter.performIncrementalSync()
                case .full:
                    try await exporter.performFullExport()
                }

                // Update schedule
                updateScheduleAfterRun(schedule)
                print("✓ Executed scheduled sync: \(schedule.name)")
            } catch {
                let errorDescription = error.localizedDescription
                print("✗ Failed to execute scheduled sync '\(schedule.name)': \(error)")
                success = false
                await sendFailureNotification(scheduleName: schedule.name, error: errorDescription)
            }
        }

        print("🏁 Background task completed: success=\(success)")
        task.setTaskCompleted(success: success)
    }
    
    private func updateScheduleAfterRun(_ schedule: SyncSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].lastRun = Date()
            saveSchedules()
        }
    }

    func requestNotificationPermission() async {
        if userDefaults.bool(forKey: notificationsPermissionRequestedKey) {
            return
        }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            userDefaults.set(true, forKey: notificationsPermissionRequestedKey)
            if !granted {
                print("⚠️ Notification permission not granted")
            }
        } catch {
            print("Could not request notification permission: \(error)")
        }
    }

    private func sendFailureNotification(scheduleName: String, error: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Sync Failed"
        content.body = "Scheduled sync '\(scheduleName)' failed: \(error)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📣 Sent failure notification for schedule '\(scheduleName)'")
        } catch {
            print("Could not send failure notification: \(error)")
        }
    }
    
    // MARK: - Manual Execution

    func executeScheduleNow(_ schedule: SyncSchedule) async throws {
        let exporter = HealthExporter()

        switch schedule.syncType {
        case .incremental:
            try await exporter.performIncrementalSync()
        case .full:
            try await exporter.performFullExport()
        }

        updateScheduleAfterRun(schedule)
    }

    // MARK: - Testing/Debugging

    /// Simulates what would happen if the background task fired right now
    /// Useful for testing scheduled sync logic without waiting for iOS
    func simulateBackgroundTaskExecution() async {
        print("🧪 SIMULATED background task execution")
        let now = Date()
        print("📋 Current time: \(now)")
        print("📋 Active schedules: \(schedules.count)")

        for schedule in schedules {
            if let nextRun = nextRun(for: schedule, now: now) {
                let timeUntil = nextRun.timeIntervalSince(now)
                print("   - '\(schedule.name)': nextRun in \(timeUntil/60) minutes, enabled=\(schedule.isEnabled)")
            } else {
                print("   - '\(schedule.name)': NO NEXT RUN SET")
            }
        }

        let schedulesToRun = schedules.filter { schedule in
            guard schedule.isEnabled else { return false }
            guard let nextRun = nextRun(for: schedule, now: now) else { return false }
            return nextRun <= now
        }

        if schedulesToRun.isEmpty {
            print("✅ No schedules ready to execute now")
            return
        }

        print("🚀 Would execute \(schedulesToRun.count) schedule(s)")

        let exporter = HealthExporter()
        for schedule in schedulesToRun {
            do {
                print("▶️ Executing: \(schedule.name)")
                switch schedule.syncType {
                case .incremental:
                    try await exporter.performIncrementalSync()
                case .full:
                    try await exporter.performFullExport()
                }
                updateScheduleAfterRun(schedule)
                print("✓ Completed: \(schedule.name)")
            } catch {
                print("✗ Failed: \(schedule.name) - \(error)")
            }
        }
    }
}
