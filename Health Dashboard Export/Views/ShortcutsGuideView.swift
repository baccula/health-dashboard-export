//
//  ShortcutsGuideView.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI

struct ShortcutsGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Shortcuts & Automation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Automate your health data exports with Siri and the Shortcuts app")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Available Actions
                GroupBox(label: Label("Available Actions", systemImage: "list.bullet")) {
                    VStack(alignment: .leading, spacing: 16) {
                        ActionRow(
                            icon: "arrow.clockwise.circle.fill",
                            title: "Sync Health Data",
                            description: "Export only new data since last sync. Fast and efficient for daily use."
                        )
                        
                        Divider()
                        
                        ActionRow(
                            icon: "square.and.arrow.down.fill",
                            title: "Full Health Export",
                            description: "Export all historical health data. Use for initial setup or complete backups."
                        )
                        
                        Divider()
                        
                        ActionRow(
                            icon: "info.circle.fill",
                            title: "Get Export Status",
                            description: "Check last sync date, total records, and last export file."
                        )
                    }
                    .padding(.vertical, 8)
                }
                
                // Voice Commands
                GroupBox(label: Label("Voice Commands", systemImage: "waveform")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Say to Siri:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VoiceCommandRow(text: "Sync my health data")
                        VoiceCommandRow(text: "Export all health data")
                        VoiceCommandRow(text: "Get my health export status")
                        
                        Text("Tip: Add custom phrases using the 'Add to Siri' buttons in Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // Quick Setup
                GroupBox(label: Label("Quick Setup", systemImage: "1.circle.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        SetupStep(number: 1, text: "Open the Shortcuts app")
                        SetupStep(number: 2, text: "Tap '+' to create a new shortcut")
                        SetupStep(number: 3, text: "Search for 'Health Dashboard Export'")
                        SetupStep(number: 4, text: "Choose an action (Sync/Full Export/Status)")
                        SetupStep(number: 5, text: "Optionally add a notification to see results")
                        SetupStep(number: 6, text: "Name your shortcut and tap Done")
                    }
                    .padding(.vertical, 8)
                }
                
                // Automation Example
                GroupBox(label: Label("Daily Auto-Sync", systemImage: "clock.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set up automatic daily syncs:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            AutomationStep(icon: "gear", text: "Open Settings → Shortcuts → Automation")
                            AutomationStep(icon: "plus.circle", text: "Tap '+' → Time of Day")
                            AutomationStep(icon: "clock", text: "Choose 11:00 PM daily")
                            AutomationStep(icon: "checkmark.circle", text: "Enable 'Run Immediately'")
                            AutomationStep(icon: "arrow.clockwise", text: "Select 'Sync Health Data' action")
                        }
                        
                        Text("Your health data will now sync automatically every night!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // Advanced Examples
                GroupBox(label: Label("Advanced Examples", systemImage: "star.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        AdvancedExample(
                            title: "Sync & AirDrop to Mac",
                            steps: [
                                "1. Sync Health Data",
                                "2. Get latest export file",
                                "3. AirDrop to your Mac"
                            ]
                        )
                        
                        Divider()
                        
                        AdvancedExample(
                            title: "After Workout Sync",
                            steps: [
                                "Automation: When Health app closes",
                                "Action: Sync Health Data",
                                "Notification: Show sync result"
                            ]
                        )
                        
                        Divider()
                        
                        AdvancedExample(
                            title: "Weekly Backup",
                            steps: [
                                "Automation: Every Sunday 10 PM",
                                "Action: Full Health Export",
                                "Action: Upload to Dropbox/iCloud"
                            ]
                        )
                    }
                    .padding(.vertical, 8)
                }
                
                // Tips
                GroupBox(label: Label("Tips & Best Practices", systemImage: "lightbulb.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TipRow(text: "Use incremental sync for daily automation")
                        TipRow(text: "Schedule full exports weekly or monthly")
                        TipRow(text: "Add notifications to verify sync success")
                        TipRow(text: "Chain actions to automatically upload/share files")
                        TipRow(text: "Test shortcuts manually before automating")
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Shortcuts Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Views

struct ActionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct VoiceCommandRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .italic()
            Image(systemName: "quote.closing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SetupStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct AutomationStep: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
}

struct AdvancedExample: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(steps, id: \.self) { step in
                    Text("• \(step)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationView {
        ShortcutsGuideView()
    }
}
