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
        // Schedule next background task
        scheduleBackgroundTask()
        
        // Create task expiration handler
        task.expirationHandler = {
            print("⚠️ Background task expired")
        }
        
        // Find schedules that need to run
        let now = Date()
        let schedulesToRun = schedules.filter { schedule in
            guard schedule.isEnabled else { return false }
            guard let nextRun = schedule.nextRun else { return false }
            return nextRun <= now
        }
        
        guard !schedulesToRun.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }
        
        // Execute syncs
        let exporter = HealthExporter()
        var success = true
        
        for schedule in schedulesToRun {
            do {
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
                print("✗ Failed to execute scheduled sync: \(error)")
                success = false
            }
        }
        
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
}
