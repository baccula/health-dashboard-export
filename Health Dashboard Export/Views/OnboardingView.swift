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
    @State private var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo/Icon
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                // Welcome text
                VStack(spacing: 12) {
                    Text("Welcome to Health Dashboard Export")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Automatically sync your Apple Health data to your personal dashboard")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Pairing instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pair Your Device")
                        .font(.headline)
                    
                    InstructionRow(
                        number: "1",
                        text: "Open https://health.neuwirth.cc in your browser"
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
                        .onChange(of: pairingCode) { newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                pairingCode = String(newValue.prefix(6))
                            }
                            // Clear error when typing
                            errorMessage = nil
                        }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                // Pair button
                Button(action: {
                    Task {
                        await pairDevice()
                    }
                }) {
                    HStack {
                        if isPairing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isPairing ? "Pairing..." : "Pair Device")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pairingCode.count == 6 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(pairingCode.count != 6 || isPairing)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func pairDevice() async {
        isPairing = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.confirmPairingCode(pairingCode)
            print("✓ Paired as: \(response.deviceName)")
            
            // Pairing successful, close onboarding
            isOnboardingComplete = true
        } catch {
            errorMessage = error.localizedDescription
            isPairing = false
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
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
