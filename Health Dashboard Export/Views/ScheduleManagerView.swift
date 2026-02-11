//
//  ScheduleManagerView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI

struct ScheduleManagerView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @ObservedObject var exporter: HealthExporter
    @State private var showingAddSchedule = false
    @State private var scheduleToEdit: SyncSchedule?
    
    var body: some View {
        List {
            if scheduleManager.schedules.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Scheduled Syncs")
                            .font(.headline)
                        
                        Text("Create a schedule to automatically export your health data at regular intervals")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingAddSchedule = true
                        }) {
                            Label("Create Schedule", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(scheduleManager.schedules) { schedule in
                        ScheduleRow(schedule: schedule, scheduleManager: scheduleManager)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    scheduleManager.deleteSchedule(schedule)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    scheduleToEdit = schedule
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    Task {
                                        try? await scheduleManager.executeScheduleNow(schedule)
                                    }
                                } label: {
                                    Label("Run Now", systemImage: "play.circle")
                                }
                                
                                Button {
                                    scheduleToEdit = schedule
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    scheduleManager.deleteSchedule(schedule)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Active Schedules")
                } footer: {
                    Text("Swipe left on a schedule to edit or delete. Long press for more options.")
                }
            }
            
            Section {
                InfoRow(label: "Background Refresh", value: "Enabled")
                InfoRow(label: "Total Schedules", value: "\(scheduleManager.schedules.count)")
                
                if let nextSchedule = scheduleManager.schedules.filter({ $0.isEnabled }).min(by: { ($0.nextRun ?? Date.distantFuture) < ($1.nextRun ?? Date.distantFuture) }) {
                    if let nextRun = nextSchedule.nextRun {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Sync")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(nextSchedule.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(nextRun, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("Info")
            }
        }
        .navigationTitle("Scheduled Syncs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddSchedule = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSchedule) {
            ScheduleEditorView(scheduleManager: scheduleManager, exporter: exporter)
        }
        .sheet(item: $scheduleToEdit) { schedule in
            ScheduleEditorView(scheduleManager: scheduleManager, exporter: exporter, scheduleToEdit: schedule)
        }
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: SyncSchedule
    @ObservedObject var scheduleManager: ScheduleManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: schedule.syncType.icon)
                .font(.title2)
                .foregroundColor(schedule.isEnabled ? .blue : .gray)
                .frame(width: 30)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.name)
                    .font(.headline)
                    .foregroundColor(schedule.isEnabled ? .primary : .secondary)
                
                HStack(spacing: 12) {
                    Label(schedule.frequency.rawValue, systemImage: schedule.frequency.icon)
                    
                    if let nextRun = schedule.nextRun {
                        Label(nextRun.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in scheduleManager.toggleSchedule(schedule) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        ScheduleManagerView(exporter: HealthExporter())
            .environmentObject(ScheduleManager())
    }
}
