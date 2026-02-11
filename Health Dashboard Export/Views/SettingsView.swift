//
//  SettingsView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI
import AppIntents
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var exporter: HealthExporter
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearDataAlert = false
    @State private var showingShortcutsGuide = false
    @State private var showingLocationPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(exporter.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Total Records")
                        Spacer()
                        Text(formatNumber(exporter.totalRecords))
                            .foregroundColor(.secondary)
                    }

                    if let fileURL = exporter.lastExportedFileURL {
                        HStack {
                            Text("Last Export File")
                            Spacer()
                            Text(fileURL.lastPathComponent)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }

                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Save Location")
                                    .foregroundColor(.primary)
                                Text(getSaveLocationDescription())
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Export Status")
                }

                Section {
                    NavigationLink(destination: ScheduleManagerView()) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Scheduled Syncs")
                        }
                    }

                    NavigationLink(destination: ShortcutsGuideView()) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                            Text("Shortcuts Guide")
                        }
                    }

                    AddToSiriButton(intent: SyncNowIntent()) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                            Text("Add Sync to Siri")
                        }
                    }

                    AddToSiriButton(intent: FullExportIntent()) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                            Text("Add Full Export to Siri")
                        }
                    }
                } header: {
                    Text("Shortcuts & Automation")
                } footer: {
                    Text("Add shortcuts to Siri for voice control, or use with the Shortcuts app for automation.")
                }

                Section {
                    Button(role: .destructive, action: {
                        showingClearDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This will reset all sync history and remove cached export information. Your health data will not be affected.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    exporter.clearAllData()
                    dismiss()
                }
            } message: {
                Text("This will reset your sync history and remove all cached export information. This cannot be undone.")
            }
            .sheet(isPresented: $showingLocationPicker) {
                DocumentPicker(onSelect: { url in
                    exporter.setSaveLocation(url)
                })
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func getSaveLocationDescription() -> String {
        if let saveURL = exporter.saveLocationURL {
            let components = saveURL.pathComponents
            // Try to find a meaningful parent directory name
            if components.count >= 2 {
                let parent = components[components.count - 2]
                let folder = saveURL.lastPathComponent
                return "\(parent)/\(folder)"
            }
            return saveURL.lastPathComponent
        } else {
            // Fallback location description
            if FileManager.default.ubiquityIdentityToken != nil {
                return "iCloud Drive/Health Export/"
            } else {
                return "On My iPhone/Documents/Health Export/"
            }
        }
    }
}

#Preview {
    SettingsView(exporter: HealthExporter())
}
