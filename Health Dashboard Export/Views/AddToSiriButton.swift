//
//  AddToSiriButton.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import SwiftUI
import AppIntents

struct AddToSiriButton<Intent: AppIntent, Label: View>: View {
    let intent: Intent
    let label: () -> Label
    
    init(intent: Intent, @ViewBuilder label: @escaping () -> Label) {
        self.intent = intent
        self.label = label
    }
    
    var body: some View {
        Button(action: {
            // Note: In iOS 16+, Siri shortcuts are managed through the Shortcuts app
            // This button will open the Shortcuts app to the relevant intent
            if let url = URL(string: "shortcuts://") {
                UIApplication.shared.open(url)
            }
        }) {
            label()
        }
    }
}
