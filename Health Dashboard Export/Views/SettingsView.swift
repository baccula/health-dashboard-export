//
//  SettingsView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var exporter: HealthExporter
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearDataAlert = false
    @State private var showingAPISettings = false
    @State private var showingRepairAlert = false
    
    private let apiClient = APIClient.shared

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
                } header: {
                    Text("Sync Status")
                }
                
                Section {
                    Button(action: {
                        showingAPISettings = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Server")
                                    .foregroundColor(.primary)
                                Text(apiClient.baseURL)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("Device Paired")
                        Spacer()
                        if apiClient.isPaired {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if apiClient.isPaired {
                        Button(action: {
                            showingRepairAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Re-pair Device")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Configure the API server endpoint for syncing your health data.")
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
                        Text("1.1.0")
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
            .sheet(isPresented: $showingAPISettings) {
                APISettingsView()
            }
            .alert("Re-pair Device?", isPresented: $showingRepairAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Re-pair", role: .destructive) {
                    apiClient.unpairDevice()
                }
            } message: {
                Text("This will unpair your device. You'll need to enter a new pairing code.")
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

#Preview {
    SettingsView(exporter: HealthExporter())
}
