//
//  Health_Dashboard_ExportApp.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI
import CoreData

@main
struct Health_Dashboard_ExportApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var scheduleManager = ScheduleManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(scheduleManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        scheduleManager.normalizeSchedules()
                    }
                }
        }
    }
}
