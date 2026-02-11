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
    @State private var showingShareSheet = false
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var showingSettings = false
    @State private var showingLocationPicker = false
    @State private var pendingExportType: ExportType?
    
    enum ExportType {
        case incremental
        case full
    }
    
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
                        label: "Records",
                        value: formatNumber(exporter.totalRecords)
                    )
                    
                    if let fileURL = exporter.lastExportedFileURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Export")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text(fileURL.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
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
            await requestAuthorization()
        }
        .onChange(of: exporter.errorMessage) { oldValue, newValue in
            showingError = newValue != nil
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exporter.lastExportedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(exporter: exporter)
        }
        .sheet(isPresented: $showingLocationPicker) {
            DocumentPicker(onSelect: { url in
                Task {
                    await executeExport(at: url)
                }
            })
        }
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
        // Only prompt for location if one hasn't been set
        if exporter.saveLocationURL == nil {
            pendingExportType = .incremental
            showingLocationPicker = true
        } else {
            // Location already set, proceed directly
            do {
                let recordsBefore = exporter.totalRecords
                try await exporter.performIncrementalSync()
                let newRecords = exporter.totalRecords - recordsBefore

                if newRecords > 0 {
                    successMessage = "Sync completed! \(formatNumber(newRecords)) new records exported."
                } else {
                    successMessage = "Sync completed! No new data since last sync."
                }
                showingSuccess = true
            } catch {
                print("Export error: \(error)")
            }
        }
    }

    private func performFullExport() async {
        // Only prompt for location if one hasn't been set
        if exporter.saveLocationURL == nil {
            pendingExportType = .full
            showingLocationPicker = true
        } else {
            // Location already set, proceed directly
            do {
                try await exporter.performFullExport()
                successMessage = "Full export completed! \(formatNumber(exporter.totalRecords)) total records exported."
                showingSuccess = true
            } catch {
                print("Export error: \(error)")
            }
        }
    }

    private func executeExport(at url: URL) async {
        // Save the selected location
        exporter.setSaveLocation(url)

        do {
            switch pendingExportType {
            case .incremental:
                let recordsBefore = exporter.totalRecords
                try await exporter.performIncrementalSync()
                let newRecords = exporter.totalRecords - recordsBefore

                if newRecords > 0 {
                    successMessage = "Sync completed! \(formatNumber(newRecords)) new records exported."
                } else {
                    successMessage = "Sync completed! No new data since last sync."
                }
                showingSuccess = true

            case .full:
                try await exporter.performFullExport()
                successMessage = "Full export completed! \(formatNumber(exporter.totalRecords)) total records exported."
                showingSuccess = true

            case .none:
                break
            }
        } catch {
            print("Export error: \(error)")
        }

        pendingExportType = nil
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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
