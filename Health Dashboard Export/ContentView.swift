//
//  ContentView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var exporter = HealthExporter()
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var showingError = false
    @State private var showingAuthorizationPrompt = false
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @State private var showingScheduleEditor = false
    @State private var scheduleToEdit: SyncSchedule?
    
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("HealthExport")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Status Section
                VStack(alignment: .leading, spacing: 16) {
                    StatusRow(
                        label: "Last Sync",
                        value: exporter.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
                    )
                    
                    StatusRow(
                        label: "Records Uploaded",
                        value: formatNumber(exporter.totalRecords)
                    )
                    
                    if exporter.isExporting {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exporter.exportProgressText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: exporter.exportProgress)
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Scheduled Sync Section
                VStack(spacing: 16) {
                    if scheduleManager.schedules.isEmpty {
                        // No schedules - show create button
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No Scheduled Sync")
                                .font(.headline)
                            
                            Text("Create a schedule to automatically sync your health data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingScheduleEditor = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Schedule")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .font(.headline)
                            }
                            .disabled(!exporter.isAuthorized)
                        }
                        .padding()
                    } else {
                        // Show active schedules
                        VStack(spacing: 12) {
                            ForEach(scheduleManager.schedules.prefix(3)) { schedule in
                                ScheduleCardView(schedule: schedule, scheduleManager: scheduleManager)
                                    .onTapGesture {
                                        scheduleToEdit = schedule
                                    }
                            }
                            
                            if scheduleManager.schedules.count > 3 {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Text("View All Schedules")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if !exporter.isAuthorized {
                        Button(action: {
                            Task {
                                await requestAuthorization()
                            }
                        }) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                Text("Grant HealthKit Access")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.headline)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                exporter.errorMessage = nil
            }
        } message: {
            Text(exporter.errorMessage ?? "An unknown error occurred")
        }
        .task {
            checkPairingStatus()
            // Only request auth if already paired (returning user)
            if apiClient.isPaired {
                await requestAuthorization()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceUnpaired)) { _ in
            checkPairingStatus()
        }
        .onChange(of: exporter.errorMessage) { oldValue, newValue in
            showingError = newValue != nil
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(exporter: exporter)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isOnboardingComplete: $showingOnboarding)
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorView(scheduleManager: scheduleManager, exporter: exporter)
        }
        .sheet(item: $scheduleToEdit) { schedule in
            ScheduleEditorView(scheduleManager: scheduleManager, exporter: exporter, scheduleToEdit: schedule)
        }
    }
    
    // MARK: - Pairing
    
    private func checkPairingStatus() {
        showingOnboarding = !apiClient.isPaired
    }
    
    // MARK: - Actions
    
    private func requestAuthorization() async {
        do {
            try await exporter.requestAuthorization()
        } catch {
            print("Authorization error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct ScheduleCardView: View {
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
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(nextRun, style: .relative)
                        }
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .environmentObject(ScheduleManager())
}
