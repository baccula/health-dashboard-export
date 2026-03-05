//
//  OnboardingView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/25/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var pairingCode: String = ""
    @State private var isPairing = false
    @State private var isPaired = false
    @State private var errorMessage: String?
    @State private var showingAPISettings = false
    @State private var customAPIURL: String
    
    private let apiClient = APIClient.shared
    private let exporter = HealthExporter()
    
    init(isOnboardingComplete: Binding<Bool>) {
        _isOnboardingComplete = isOnboardingComplete
        _customAPIURL = State(initialValue: APIClient.shared.baseURL)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 40)
                    
                    // Logo/Icon
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)
                    
                    // Welcome text
                    VStack(spacing: 12) {
                        Text(isPaired ? "Almost Done!" : "Welcome to Health Dashboard Export")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                        
                        Text(isPaired ? "Grant access to your health data to complete setup" : "Automatically sync your Apple Health data to your personal dashboard")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                
                if isPaired {
                    // Success message and HealthKit access button
                    VStack(spacing: 20) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Device paired successfully!")
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button(action: {
                            Task {
                                await requestHealthKitAccess()
                            }
                        }) {
                            Text("Grant HealthKit Access")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // Pairing instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pair Your Device")
                            .font(.headline)
                        
                        InstructionRow(
                            number: "1",
                            text: "Open \(customAPIURL) in your browser"
                        )
                        
                        InstructionRow(
                            number: "2",
                            text: "Click 'Pair Device' and get your 6-digit code"
                        )
                        
                        InstructionRow(
                            number: "3",
                            text: "Enter the code below"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Code input
                    VStack(spacing: 12) {
                        TextField("Enter 6-digit code", text: $pairingCode)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title2)
                            .disabled(isPairing)
                            .onChange(of: pairingCode) { _, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    pairingCode = String(newValue.prefix(6))
                                }
                                // Clear error when typing
                                errorMessage = nil
                                
                                // Auto-submit when 6 digits entered
                                if pairingCode.count == 6 && !isPairing {
                                    Task {
                                        await pairDevice()
                                    }
                                }
                            }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Pairing status indicator (replaces button)
                    if isPairing {
                        HStack {
                            ProgressView()
                            Text("Pairing...")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isPaired {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAPISettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAPISettings) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("API Server URL", text: $customAPIURL)
                                .textContentType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        } header: {
                            Text("Server Configuration")
                        } footer: {
                            Text("Enter the full URL of your health dashboard API server")
                        }
                        
                        Section {
                            Button(action: {
                                customAPIURL = "https://health.neuwirth.cc"
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Use Default Server")
                                }
                            }
                        } footer: {
                            Text("Default: https://health.neuwirth.cc")
                        }
                    }
                    .navigationTitle("API Server")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                // Validate and save URL
                                let trimmedURL = customAPIURL.trimmingCharacters(in: .whitespaces)
                                if let url = URL(string: trimmedURL), 
                                   (url.scheme == "http" || url.scheme == "https") {
                                    apiClient.baseURL = trimmedURL
                                    customAPIURL = trimmedURL
                                    showingAPISettings = false
                                } else {
                                    // Reset to current valid URL if invalid
                                    customAPIURL = apiClient.baseURL
                                    showingAPISettings = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func pairDevice() async {
        print("🔑 Starting pairing with code: \(pairingCode)")
        isPairing = true
        errorMessage = nil
        
        do {
            print("📡 Calling confirmPairingCode...")
            let response = try await apiClient.confirmPairingCode(pairingCode)
            print("✓ Paired as: \(response.deviceName)")
            
            // Verify pairing was successful by checking if API key was saved
            guard apiClient.isPaired else {
                print("❌ API key verification failed")
                throw APIError.pairingFailed("Pairing succeeded but API key was not saved")
            }
            
            print("✅ Pairing verified, API key saved")
            
            // Pairing successful, show HealthKit access button
            await MainActor.run {
                isPaired = true
                isPairing = false
            }
        } catch {
            print("❌ Pairing error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isPairing = false
                pairingCode = "" // Clear code on error
            }
        }
    }
    
    private func requestHealthKitAccess() async {
        do {
            print("🔐 Requesting HealthKit authorization...")
            try await exporter.requestAuthorization()
            print("✓ HealthKit authorization completed")
            
            // Small delay to ensure authorization sheet has dismissed
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Complete onboarding
            await MainActor.run {
                print("✅ Onboarding complete")
                isOnboardingComplete = true
            }
        } catch {
            print("❌ HealthKit authorization error: \(error)")
            await MainActor.run {
                errorMessage = "HealthKit access error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
                .fixedSize()
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
