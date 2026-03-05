# Quick Start Guide

## Running the App

1. Open `Health Dashboard Export.xcodeproj` in Xcode
2. Select a target device or simulator
3. Press ⌘R (or click the Play button)
4. Pair your device (first run only)
5. Grant HealthKit permissions when prompted
6. Choose a sync mode:
   - "Sync Now" (incremental)
   - "Full Export" (all historical data)

## Pairing (First Run)

1. Open the API server URL shown in the app
2. Click "Pair Device" and get a 6-digit code
3. Enter the code in the app
4. Once paired, grant HealthKit access

## Sync Modes

### Sync Now (Incremental)
- Uploads only new data since the last sync
- Fast for regular updates
- If no previous sync exists, it performs a full export first

### Full Export
- Uploads all historical data
- Use for initial setup or complete backfills
- Can take longer for large datasets

## Scheduled Syncs

1. Open Settings → Scheduled Syncs
2. Create a schedule with frequency and time
3. Leave the app installed and Background App Refresh enabled

## Troubleshooting

**Not paired / API errors**
- Check Settings → API Server
- Re-pair the device if you changed the server

**HealthKit access denied**
- Settings → Privacy & Security → Health → Health Dashboard Export
- Enable permissions and re-open the app

**"Protected health data is inaccessible"**
- Unlock the device once after reboot
- HealthKit data is unavailable while the device is locked

**Scheduled syncs not running**
- Settings → General → Background App Refresh → ON
- Low Power Mode can prevent background syncs
- iOS may delay or skip tasks based on system conditions
