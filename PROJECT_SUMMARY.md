# Health Dashboard Export - Project Summary

## Overview
A native iOS app that uploads Apple HealthKit data to a configured dashboard API. Built with SwiftUI, with pairing, scheduled syncs, and manual export options.

## Features Implemented

### Core
- HealthKit read access (selected quantity, category, and workout types)
- Incremental sync (uploads only new data since last sync)
- Full export (uploads all historical data)
- Pairing flow with API key stored in Keychain
- Configurable API server endpoint
- Scheduled background syncs via BGTaskScheduler
- Sync state persisted in UserDefaults

### UI/UX
- Onboarding with pairing instructions
- Settings for API server and sync status
- Schedule manager (create, edit, enable/disable)
- Progress and error feedback

## Data Types Exported

### Quantity Types
- Heart Rate, Resting Heart Rate
- Heart Rate Variability (SDNN)
- VO2 Max
- Body Mass, Body Fat %, Lean Body Mass
- Active Energy Burned, Basal Energy Burned
- Step Count, Distance Walking/Running, Flights Climbed
- Blood Pressure (Systolic, Diastolic)
- Blood Glucose, Oxygen Saturation, Respiratory Rate

### Category Types
- Sleep Analysis
- Stand Hours

### Workouts
- All workouts with duration, distance, calories, source

## Architecture

### SwiftUI + Async/Await
- `HealthExporter`: fetches HealthKit data and uploads via API
- `APIClient`: pairing, API key management, uploads
- `ScheduleManager`: schedule storage and background tasks
- `KeychainHelper`: secure API key storage

### Storage
- UserDefaults: sync state and schedules
- Keychain: API key

### Capabilities
- HealthKit
- Background Modes (fetch, processing)

## Files & Structure
```
Health Dashboard Export/
├── Models/
│ ├── APIModels.swift
│ ├── HealthRecord.swift
│ └── SyncSchedule.swift
├── Services/
│ ├── APIClient.swift
│ ├── HealthExporter.swift
│ ├── KeychainHelper.swift
│ └── ScheduleManager.swift
├── Views/
│ ├── ContentView.swift
│ ├── SettingsView.swift
│ ├── OnboardingView.swift
│ ├── ScheduleManagerView.swift
│ └── ScheduleEditorView.swift
└── Documentation/
 ├── SETUP.md
 ├── QUICK_START.md
 └── SCHEDULING_GUIDE.md

## Known Limitations
- Background sync timing is controlled by iOS
- HealthKit data is inaccessible while the device is locked
- Requires network access for uploads

## Status
- App compiles and runs
- Pairing and sync flows implemented
- Background syncs require device testing