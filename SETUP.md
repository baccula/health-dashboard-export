# Health Dashboard Export - Setup Instructions

## Required Xcode Configuration

### 1. HealthKit Capability
Ensure the HealthKit capability is enabled for the app target.

### 2. Privacy Descriptions
Add these keys in the target Info tab if missing:
- `NSHealthUpdateUsageDescription`

### 3. Background Modes (Scheduled Syncs)
To support scheduled syncs:
1. Target → Signing & Capabilities → + Capability → Background Modes
2. Enable:
 - Background fetch
 - Background processing

Also ensure `BGTaskSchedulerPermittedIdentifiers` includes:
- `com.healthexport.sync`

### 4. API Server Configuration
The app uploads data to a server endpoint:
- Default: `https://health.neuwirth.cc`
- Change it in Settings → API Server
- Changing the server requires re-pairing the device

## Device Setup
1. Run the app on device or simulator
2. Pair the device with the server
3. Grant HealthKit permissions
4. (Optional) Enable Background App Refresh for scheduled syncs

## Troubleshooting
**"HealthKit is not available"**
- HealthKit only works on iOS devices and simulators

**"Authorization denied"**
- Settings → Privacy & Security → Health → Health Dashboard Export
- Enable permissions and re-open the app

**Background syncs not running**
- Background App Refresh must be enabled
- Low Power Mode can prevent background tasks
- iOS controls exact scheduling