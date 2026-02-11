//
//  ScheduleEditorView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI

struct ScheduleEditorView: View {
    @ObservedObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleToEdit: SyncSchedule?
    
    @State private var name: String
    @State private var syncType: SyncType
    @State private var frequency: ScheduleFrequency
    @State private var time: Date
    @State private var isEnabled: Bool
    
    init(scheduleManager: ScheduleManager, scheduleToEdit: SyncSchedule? = nil) {
        self.scheduleManager = scheduleManager
        self.scheduleToEdit = scheduleToEdit
        
        _name = State(initialValue: scheduleToEdit?.name ?? "")
        _syncType = State(initialValue: scheduleToEdit?.syncType ?? .incremental)
        _frequency = State(initialValue: scheduleToEdit?.frequency ?? .daily)
        _time = State(initialValue: scheduleToEdit?.time ?? Date())
        _isEnabled = State(initialValue: scheduleToEdit?.isEnabled ?? true)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Schedule Name", text: $name)
                        .autocorrectionDisabled()
                    
                    Toggle("Enabled", isOn: $isEnabled)
                } header: {
                    Text("Basic Info")
                }
                
                Section {
                    Picker("Sync Type", selection: $syncType) {
                        ForEach(SyncType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Text(syncType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Export Type")
                }
                
                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    Text(frequency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Frequency")
                }
                
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    
                    let nextRun = frequency.calculateNextRun(from: Date(), at: time)
                    
                    HStack {
                        Text("Next Run")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(nextRun, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("On")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(nextRun.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    }
                } header: {
                    Text("Schedule Time")
                } footer: {
                    Text("The sync will run at this time according to the selected frequency.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Background Sync Requirements")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        RequirementRow(text: "Device must be plugged in and charging")
                        RequirementRow(text: "Device should be connected to WiFi")
                        RequirementRow(text: "Background App Refresh must be enabled")
                        RequirementRow(text: "Syncs may be delayed based on system conditions")
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Open Settings")
                                    .font(.caption)
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Important")
                }
            }
            .navigationTitle(scheduleToEdit == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveSchedule() {
        if let existingSchedule = scheduleToEdit {
            // Update existing schedule
            let updated = SyncSchedule(
                id: existingSchedule.id,
                name: name,
                isEnabled: isEnabled,
                syncType: syncType,
                frequency: frequency,
                time: time
            )
            scheduleManager.updateSchedule(updated)
        } else {
            // Create new schedule
            let newSchedule = SyncSchedule(
                name: name,
                isEnabled: isEnabled,
                syncType: syncType,
                frequency: frequency,
                time: time
            )
            scheduleManager.addSchedule(newSchedule)
        }
        
        dismiss()
    }
}

// MARK: - Requirement Row

struct RequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ScheduleEditorView(scheduleManager: ScheduleManager())
}
