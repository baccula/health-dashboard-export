# Health Dashboard Export - Setup Instructions

## Required Xcode Configuration

### 1. Add HealthKit Capability

✅ Already configured in the project!

The project already has:
- HealthKit capability enabled
- Background Delivery enabled
- Required entitlements set

### 2. Privacy Descriptions

✅ Already configured in the project!

The following privacy descriptions are already set:
- `NSHealthShareUsageDescription` - For reading health data
- `NSHealthUpdateUsageDescription` - For HealthKit framework requirement

### 3. Storage Location

The app uses **local device storage** instead of iCloud:
- Exports are saved to: `Documents/HealthExport/`
- Files are accessible through iTunes File Sharing or Finder
- You can enable "Supports iTunes File Sharing" to access files easily

### 4. Enable Background Modes (For Scheduled Syncs)

To use scheduled automatic syncs:

1. Select the "Health Dashboard Export" target
2. Go to the "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "Background Modes"
5. Enable:
   - ☑️ Background fetch
   - ☑️ Background processing

**Also add to Info.plist:**

1. Go to the "Info" tab
2. Under "Custom iOS Target Properties", add:
   - **Key**: `BGTaskSchedulerPermittedIdentifiers`
   - **Type**: Array
   - Add item (String): `com.healthexport.sync`

This allows the app to run scheduled syncs in the background.

### 5. Enable iTunes File Sharing (Optional but Recommended)

To easily access exported files via Finder:

1. Select the "Health Dashboard Export" target
2. Go to the "Info" tab
3. Under "Custom iOS Target Properties", add:
   - **Key**: `UIFileSharingEnabled` (or "Application supports iTunes file sharing")
   - **Type**: Boolean
   - **Value**: YES

4. Optionally add:
   - **Key**: `LSSupportsOpeningDocumentsInPlace`
   - **Type**: Boolean
   - **Value**: YES

This allows you to access exported files via:
- **On Mac**: Finder → Devices → iPhone → Files → Health Dashboard Export
- **On Windows**: iTunes → Device → File Sharing → Health Dashboard Export

## Testing the App

### On Simulator
- ✅ HealthKit works in the simulator
- ✅ You can add sample health data using the Health app in the simulator
- ✅ Local file storage works perfectly in the simulator

### On Device
1. Run the app on your device
2. Grant HealthKit permissions when prompted
3. Tap "Full Export" to export all health data
4. Files are saved to the app's Documents directory

## Accessing Exported Files

### Method 1: Xcode Devices Window
1. Connect device to Mac
2. Open Xcode → Window → Devices and Simulators
3. Select your device
4. Select "Health Dashboard Export" app
5. Click the gear icon → "Download Container"
6. Browse to `AppData/Documents/HealthExport/`

### Method 2: Finder (if iTunes File Sharing enabled)
1. Connect device to Mac
2. Open Finder
3. Select your device in sidebar
4. Click "Files" tab
5. Find "Health Dashboard Export"
6. Drag files to your Mac

### Method 3: Simulator
1. Run in simulator
2. Files are at: `~/Library/Developer/CoreSimulator/Devices/[DEVICE-ID]/data/Containers/Data/Application/[APP-ID]/Documents/HealthExport/`
3. Or print the path in console and open in Finder

## File Export Format

File naming:
- Full export: `health-export-full-YYYY-MM-DD.json`
- Incremental: `health-export-delta-YYYY-MM-DD.json` (Phase 2)

Location: `Documents/HealthExport/`

## Troubleshooting

### "HealthKit is not available"
- Make sure you're running on iOS device or simulator (not Mac)
- HealthKit capability should already be enabled

### "Authorization Denied"
- Go to Settings → Privacy & Security → Health
- Find "Health Dashboard Export"
- Enable the required permissions
- Restart the app

### Can't find exported files
- Check console output for the exact file path
- Use Xcode Devices window to download app container
- Enable iTunes File Sharing for easier access
- In simulator, check `~/Library/Developer/CoreSimulator/Devices/`

### Export seems stuck
- Check console for errors
- Large datasets may take several minutes
- Progress bar shows current status
- Force quit and restart app if truly frozen

## Next Steps

You're ready to run the app!

1. **Build and run** the app on device or simulator
2. **Grant HealthKit permissions** when prompted
3. **Tap "Full Export"** to export all health data
4. **Monitor progress** in the app (progress bar shows status)
5. **Access the exported JSON file** using one of the methods above

The app will print the file path to the console when export completes.

## What Gets Exported

The app exports:
- **17 quantity types**: Heart rate, steps, workouts, body metrics, etc.
- **2 category types**: Sleep analysis, stand hours
- **All workouts**: With duration, distance, calories

Data is exported as JSON with ISO 8601 timestamps, ready for import to your health dashboard.

## Phase 2 Features (Not Yet Implemented)

Future enhancements:
- Incremental sync (only export new data)
- Background refresh (automatic daily sync)
- Direct API upload to dashboard
- More granular data type selection
