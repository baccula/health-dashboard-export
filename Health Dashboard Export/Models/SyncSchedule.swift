//
//  SyncSchedule.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import Foundation

// MARK: - Sync Schedule Model

struct SyncSchedule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var syncType: SyncType
    var frequency: ScheduleFrequency
    var time: Date  // Time of day to run
    var lastRun: Date?
    var nextRun: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        syncType: SyncType,
        frequency: ScheduleFrequency,
        time: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.syncType = syncType
        self.frequency = frequency
        self.time = time
        self.lastRun = nil
        self.nextRun = frequency.calculateNextRun(from: Date(), at: time)
    }
}

// MARK: - Sync Type

enum SyncType: String, Codable, CaseIterable {
    case incremental = "Incremental Sync"
    case full = "Full Export"
    
    var icon: String {
        switch self {
        case .incremental:
            return "arrow.clockwise.circle.fill"
        case .full:
            return "square.and.arrow.down.fill"
        }
    }
    
    var description: String {
        switch self {
        case .incremental:
            return "Export only new data since last sync"
        case .full:
            return "Export all historical health data"
        }
    }
}

// MARK: - Schedule Frequency

enum ScheduleFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
    
    var icon: String {
        switch self {
        case .daily:
            return "calendar"
        case .weekly:
            return "calendar.badge.clock"
        case .biweekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar.badge.clock"
        }
    }
    
    var description: String {
        switch self {
        case .daily:
            return "Runs every day at the specified time"
        case .weekly:
            return "Runs once per week at the specified time"
        case .biweekly:
            return "Runs every two weeks at the specified time"
        case .monthly:
            return "Runs once per month at the specified time"
        }
    }
    
    func calculateNextRun(from date: Date, at time: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        // Build today's occurrence at the scheduled time.
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        todayComponents.hour = timeComponents.hour
        todayComponents.minute = timeComponents.minute
        todayComponents.second = 0
        
        guard let todayOccurrence = calendar.date(from: todayComponents) else {
            return date
        }
        
        // If today's scheduled time is still in the future, run today.
        if todayOccurrence > date {
            return todayOccurrence
        }
        
        // Otherwise, today's scheduled time has passed, so advance by frequency.
        let nextRun: Date
        switch self {
        case .daily:
            nextRun = calendar.date(byAdding: .day, value: 1, to: todayOccurrence) ?? todayOccurrence
        case .weekly:
            nextRun = calendar.date(byAdding: .weekOfYear, value: 1, to: todayOccurrence) ?? todayOccurrence
        case .biweekly:
            nextRun = calendar.date(byAdding: .weekOfYear, value: 2, to: todayOccurrence) ?? todayOccurrence
        case .monthly:
            nextRun = calendar.date(byAdding: .month, value: 1, to: todayOccurrence) ?? todayOccurrence
        }

        return nextRun
    }
    
    func calculateNextRunAfter(date: Date, at time: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        // Start from the date that just ran, then add the interval
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0

        guard let baseDate = calendar.date(from: components) else {
            return date
        }

        // Add the appropriate interval from the base date
        let nextRun: Date
        switch self {
        case .daily:
            nextRun = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        case .weekly:
            nextRun = calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate) ?? baseDate
        case .biweekly:
            nextRun = calendar.date(byAdding: .weekOfYear, value: 2, to: baseDate) ?? baseDate
        case .monthly:
            nextRun = calendar.date(byAdding: .month, value: 1, to: baseDate) ?? baseDate
        }

        print("📅 Calculated next run: \(nextRun) (from \(date), frequency: \(self.rawValue))")
        return nextRun
    }
}
