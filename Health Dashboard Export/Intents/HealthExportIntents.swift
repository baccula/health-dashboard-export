//
//  HealthExportIntents.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import AppIntents
import Foundation

// MARK: - App Shortcuts Provider

struct HealthExportShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncNowIntent(),
            phrases: [
                "Sync my health data in \(.applicationName)",
                "Export new health data in \(.applicationName)",
                "Sync health to \(.applicationName)"
            ],
            shortTitle: "Sync Health Data",
            systemImageName: "arrow.clockwise.circle.fill"
        )
        
        AppShortcut(
            intent: FullExportIntent(),
            phrases: [
                "Export all health data in \(.applicationName)",
                "Full health export in \(.applicationName)"
            ],
            shortTitle: "Full Health Export",
            systemImageName: "square.and.arrow.down.fill"
        )
    }
}

// MARK: - Sync Now Intent (Incremental)

struct SyncNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Health Data"
    static var description = IntentDescription("Export new health data since last sync")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let exporter = HealthExporter()
        
        // Ensure authorization
        if !exporter.isAuthorized {
            try await exporter.requestAuthorization()
            guard exporter.isAuthorized else {
                throw IntentError.authorizationRequired
            }
        }
        
        let recordsBefore = exporter.totalRecords
        
        do {
            try await exporter.performIncrementalSync()
            let newRecords = exporter.totalRecords - recordsBefore
            
            let message: String
            if newRecords > 0 {
                message = "✓ Synced \(newRecords) new health records"
            } else {
                message = "✓ No new health data since last sync"
            }
            
            return .result(value: message)
        } catch {
            throw IntentError.exportFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Full Export Intent

struct FullExportIntent: AppIntent {
    static var title: LocalizedStringResource = "Full Health Export"
    static var description = IntentDescription("Export all historical health data")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let exporter = HealthExporter()
        
        // Ensure authorization
        if !exporter.isAuthorized {
            try await exporter.requestAuthorization()
            guard exporter.isAuthorized else {
                throw IntentError.authorizationRequired
            }
        }
        
        do {
            try await exporter.performFullExport()
            let message = "✓ Exported \(exporter.totalRecords) total health records"
            return .result(value: message)
        } catch {
            throw IntentError.exportFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Get Export Status Intent

struct GetExportStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Export Status"
    static var description = IntentDescription("Get information about the last health data export")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let exporter = HealthExporter()
        
        var status = "Health Export Status\n"
        status += "─────────────────────\n"
        
        if let lastSync = exporter.lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            status += "Last Sync: \(formatter.string(from: lastSync))\n"
        } else {
            status += "Last Sync: Never\n"
        }
        
        status += "Total Records: \(exporter.totalRecords)\n"
        
        if let fileURL = exporter.lastExportedFileURL {
            status += "Last File: \(fileURL.lastPathComponent)"
        }
        
        return .result(value: status)
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case exportFailed(reason: String)
    case authorizationRequired
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .authorizationRequired:
            return "HealthKit authorization required. Please open the app to grant access."
        }
    }
}
