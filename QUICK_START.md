# Quick Start Guide

## Running the App

1. **Open** `Health Dashboard Export.xcodeproj` in Xcode
2. **Select** your target device or simulator
3. **Press** ⌘R (or click the Play button)
4. **Grant** HealthKit permissions when prompted
5. **Choose your export mode**:
   - **"Sync Now"** - Export only new data since last sync (incremental)
   - **"Full Export"** - Export all historical data
6. **Wait** for export to complete (progress bar shows status)

## Export Modes

### Sync Now (Incremental)
- Exports **only new data** since last sync
- Much faster for regular updates
- Creates delta files: `health-export-delta-YYYY-MM-DD.json`
- **First sync?** Automatically does a full export

### Full Export
- Exports **all historical data** from the beginning
- Use for initial setup or if you need a complete backup
- Creates full files: `health-export-full-YYYY-MM-DD.json`
- May take several minutes for large datasets

## Finding Your Exported Data

### On Simulator (Easiest for Testing)

After export completes, check the Xcode console for a line like:
```
✓ Export completed: /Users/.../Documents/HealthExport/health-export-full-2026-02-11.json
```

Copy that path and open it in your editor, or:
```bash
# The path will be printed to console - use it directly
open /path/from/console/health-export-full-2026-02-11.json
```

### On Physical Device

**Option 1: Xcode Devices Window**
1. Connect device to Mac
2. Xcode → Window → Devices and Simulators
3. Select your device → Select "Health Dashboard Export" app
4. Click gear icon → "Download Container"
5. Find files in: `AppData/Documents/HealthExport/`

**Option 2: Enable File Sharing**
1. Add `UIFileSharingEnabled = YES` to Info.plist
2. Connect device → Open Finder
3. Select device → Files tab
4. Find "Health Dashboard Export" → Download files

## Understanding the Export

The JSON file contains:
```json
{
  "export_date": "2026-02-11T12:00:00Z",
  "device": "iPhone 15 Pro",
  "records": [
    {
      "type": "HKQuantityTypeIdentifierHeartRate",
      "start_date": "2026-02-11T08:30:00-07:00",
      "end_date": "2026-02-11T08:30:00-07:00",
      "value": 72,
      "unit": "count/min",
      "source": "Apple Watch"
    }
    // ... more records
  ],
  "workouts": [
    {
      "type": "HKWorkoutActivityTypeRunning",
      "start_date": "2026-02-11T06:00:00-07:00",
      "end_date": "2026-02-11T06:45:00-07:00",
      "duration_minutes": 45,
      "distance_miles": 5.2,
      "calories": 520,
      "source": "Apple Watch"
    }
    // ... more workouts
  ]
}
```

## Next Steps

Once you have the JSON file:
1. Copy it to your health dashboard import directory
2. Run your existing import script
3. Your dashboard will be populated with all your health data!

## Troubleshooting

**No health data exported?**
- Add sample data in Health app first
- Make sure HealthKit permissions were granted
- Check Settings → Privacy → Health → Health Dashboard Export

**Can't find the file?**
- Check Xcode console for the exact path
- Make sure export completed (progress bar at 100%)
- Look for green checkmark message in console

**Export takes forever?**
- This is normal for large datasets (1M+ records)
- Progress bar shows current status
- First export exports ALL historical data
- Future incremental syncs will be much faster
