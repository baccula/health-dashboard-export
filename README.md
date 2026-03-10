# Health Dashboard Export
Health Dashboard Export is a SwiftUI iOS app that uploads Apple HealthKit data to a configured dashboard API. It supports pairing, manual syncs, and scheduled background syncs.

## Highlights
- HealthKit read access for selected quantity, category, and workout types
- Incremental and full exports
- Device pairing with API key stored in Keychain
- Scheduled syncs via BGTaskScheduler
- Configurable API server endpoint

## Getting Started
- Setup: `SETUP.md`, Quick start: `QUICK_START.md`, Scheduling: `SCHEDULING_GUIDE.md`, Project overview: `PROJECT_SUMMARY.md`

## Requirements
- iOS device or simulator with HealthKit support
- HealthKit capability enabled
- Background App Refresh enabled for scheduled syncs

## Notes
- Background sync timing is controlled by iOS
- HealthKit data is inaccessible while the device is locked