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
    @State private var showingError = false
    @State private var showingAuthorizationPrompt = false
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    
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
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await performSync()
                        }
                    }) {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                Text("Sync Now")
                            }
                            .font(.headline)
                            
                            Text(exporter.lastSyncDate != nil ? "Export new data only" : "First sync - will export all")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(exporter.isExporting || !exporter.isAuthorized)
                    
                    Button(action: {
                        Task {
                            await performFullExport()
                        }
                    }) {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Full Export")
                            }
                            .font(.headline)
                            
                            Text("Export all historical data")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(exporter.isExporting || !exporter.isAuthorized)
                    
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
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .task {
            checkPairingStatus()
            await requestAuthorization()
        }
        .onChange(of: exporter.errorMessage) { oldValue, newValue in
            showingError = newValue != nil
        }
        .onChange(of: showingOnboarding) { oldValue, newValue in
            // When onboarding closes, request HealthKit auth
            if oldValue && !newValue {
                Task {
                    await requestAuthorization()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(exporter: exporter)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isOnboardingComplete: $showingOnboarding)
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
    
    private func performSync() async {
        do {
            let recordsBefore = exporter.totalRecords
            try await exporter.performIncrementalSync()
            let newRecords = exporter.totalRecords - recordsBefore

            if newRecords > 0 {
                successMessage = "Sync completed! \(formatNumber(newRecords)) new records uploaded to dashboard."
            } else {
                successMessage = "Sync completed! No new data since last sync."
            }
            showingSuccess = true
        } catch {
            print("Sync error: \(error)")
        }
    }

    private func performFullExport() async {
        do {
            try await exporter.performFullExport()
            successMessage = "Full export completed! \(formatNumber(exporter.totalRecords)) total records uploaded to dashboard."
            showingSuccess = true
        } catch {
            print("Export error: \(error)")
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

#Preview {
    ContentView()
}
