//
//  ScheduleManager.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import Foundation
import BackgroundTasks
import Combine

@MainActor
class ScheduleManager: ObservableObject {
    @Published var schedules: [SyncSchedule] = []
    
    private let userDefaults = UserDefaults.standard
    private let schedulesKey = "syncSchedules"
    private let backgroundTaskIdentifier = "com.healthexport.sync"
    
    init() {
        loadSchedules()
        registerBackgroundTasks()
        updateOverdueSchedules()
        if !schedules.isEmpty {
            scheduleBackgroundTask()
        }
    }
    
    // MARK: - Schedule Management
    
    func addSchedule(_ schedule: SyncSchedule) {
        schedules.append(schedule)
        saveSchedules()
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

    /// Updates schedules whose nextRun time has passed without executing
    /// This prevents the timer from counting up when app is reopened after scheduled time
    private func updateOverdueSchedules() {
        let now = Date()
        var needsSave = false

        for i in 0..<schedules.count {
            guard schedules[i].isEnabled else { continue }
            guard let nextRun = schedules[i].nextRun else { continue }

            // If nextRun is in the past, advance it to the next occurrence
            if nextRun < now {
                print("⏩ Advancing overdue schedule '\(schedules[i].name)' from \(nextRun)")

                // Keep advancing until we find a future time
                var updatedNextRun = nextRun
                while updatedNextRun < now {
                    updatedNextRun = schedules[i].frequency.calculateNextRunAfter(
                        date: updatedNextRun,
                        at: schedules[i].time
                    )
                }

                schedules[i].nextRun = updatedNextRun
                needsSave = true
                print("   ➡️ New nextRun: \(updatedNextRun)")
            }
        }

        if needsSave {
            saveSchedules()
        }
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
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
        // Cancel existing tasks
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        
        // Find next scheduled task
        guard let nextSchedule = getNextSchedule() else {
            print("No active schedules")
            return
        }
        
        guard let nextRun = nextSchedule.nextRun else {
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
        return activeSchedules.min(by: { ($0.nextRun ?? Date.distantFuture) < ($1.nextRun ?? Date.distantFuture) })
    }
    
    // MARK: - Background Task Execution
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        print("🔔 Background task triggered at \(Date())")

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
            guard let nextRun = schedule.nextRun else {
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
                print("✗ Failed to execute scheduled sync '\(schedule.name)': \(error)")
                success = false
            }
        }

        print("🏁 Background task completed: success=\(success)")
        task.setTaskCompleted(success: success)
    }
    
    private func updateScheduleAfterRun(_ schedule: SyncSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].lastRun = Date()
            schedules[index].nextRun = schedule.frequency.calculateNextRunAfter(
                date: Date(),
                at: schedule.time
            )
            saveSchedules()
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
            if let nextRun = schedule.nextRun {
                let timeUntil = nextRun.timeIntervalSince(now)
                print("   - '\(schedule.name)': nextRun in \(timeUntil/60) minutes, enabled=\(schedule.isEnabled)")
            } else {
                print("   - '\(schedule.name)': NO NEXT RUN SET")
            }
        }

        let schedulesToRun = schedules.filter { schedule in
            guard schedule.isEnabled else { return false }
            guard let nextRun = schedule.nextRun else { return false }
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
