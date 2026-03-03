//
//  APISettingsView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customURL: String
    @State private var showingResetAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let apiClient = APIClient.shared
    
    init() {
        _customURL = State(initialValue: APIClient.shared.baseURL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Server URL", text: $customURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Server Configuration")
                } footer: {
                    Text("Enter the full URL of your health dashboard API server (e.g., https://health.neuwirth.cc)")
                }
                
                Section {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                    }
                } footer: {
                    Text("This will reset the API endpoint to https://health.neuwirth.cc")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important")
                                .fontWeight(.semibold)
                        }
                        
                        Text("Changing the API endpoint will unpair your device. You'll need to pair again with the new server to continue syncing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("API Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(customURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Reset to Default?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetToDefault()
                }
            } message: {
                Text("This will reset the API endpoint to the default server and unpair your device.")
            }
            .alert("Invalid URL", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveSettings() {
        let trimmedURL = customURL.trimmingCharacters(in: .whitespaces)
        
        // Validate URL format
        guard let url = URL(string: trimmedURL) else {
            errorMessage = "Please enter a valid URL"
            showingError = true
            return
        }
        
        guard url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "URL must start with http:// or https://"
            showingError = true
            return
        }
        
        // If URL changed, unpair device
        if trimmedURL != apiClient.baseURL {
            apiClient.unpairDevice()
        }
        
        // Save new URL
        apiClient.baseURL = trimmedURL
        dismiss()
    }
    
    private func resetToDefault() {
        apiClient.unpairDevice()
        apiClient.resetToDefaultURL()
        customURL = apiClient.baseURL
        dismiss()
    }
}

#Preview {
    APISettingsView()
}
