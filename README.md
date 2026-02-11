# Health Dashboard Export

A native iOS app for exporting Apple HealthKit data to JSON format with automated syncing, scheduling, and Shortcuts integration.

## Overview

Health Dashboard Export replaces the manual Health app export workflow with an automated solution that exports your health data to JSON files that can be saved anywhere in the Files app, synced to cloud storage, or integrated into automation workflows.

## Features

### Core Functionality
- **HealthKit Integration**: Export 17+ health data types including:
  - Heart rate, resting heart rate, HRV
  - Workouts with detailed metrics
  - Sleep analysis
  - Steps, distance, flights climbed
  - Active and basal energy
  - Body measurements (weight, height, BMI, body fat %)
  - Blood pressure, oxygen saturation
  - And more...

### Smart Syncing
- **Incremental Sync**: Export only new data since last sync (delta export)
- **Full Export**: Complete data dump when needed
- **Progress Tracking**: Live record counts during export
- **Sync History**: Track last sync date and total records exported

### Flexible Storage
- **Save Anywhere**: Choose any folder in the Files app
- **Cloud Integration**: Works with iCloud Drive, Dropbox, Google Drive, etc.
- **Local Storage**: Save to device with fallback support
- **File Sharing**: Access exports via Files app, Finder, or Shortcuts

### Automation
- **Scheduled Syncs**: Set up recurring exports (daily, weekly, monthly)
- **Background Tasks**: Automatic syncs run even when app is closed
- **iOS Shortcuts**: Integrate with Shortcuts app for advanced automation
- **Siri Support**: Voice-activated exports via App Intents

## Installation

### Requirements
- iOS 17.0 or later
- Xcode 15.0 or later (for building from source)
- Apple device with HealthKit support

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/baccula/health-dashboard-export.git
cd health-dashboard-export
```

2. Open the project in Xcode:
```bash
open "Health Dashboard Export.xcodeproj"
```

3. Select your development team in Xcode:
   - Select the project in the navigator
   - Go to "Signing & Capabilities"
   - Choose your team under "Signing"

4. Build and run on your device (HealthKit requires a physical device, not simulator)

**Note**: You do NOT need a paid Apple Developer subscription for personal use. A free Apple ID works fine for sideloading to your own devices.

## Quick Start

1. **First Launch**: Grant HealthKit permissions when prompted
2. **Choose Location**: Tap "Sync Now" and select where to save exports
3. **Export Data**:
   - "Sync Now" for incremental export (new data only)
   - "Full Export" for complete data dump
4. **Access Files**: Find your exports in the Files app at your chosen location

See [QUICK_START.md](QUICK_START.md) for detailed instructions.

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed setup and configuration instructions
- **[QUICK_START.md](QUICK_START.md)** - Getting started guide
- **[SHORTCUTS_GUIDE.md](SHORTCUTS_GUIDE.md)** - iOS Shortcuts integration and automation recipes
- **[SCHEDULING_GUIDE.md](SCHEDULING_GUIDE.md)** - Setting up scheduled syncs
- **[FILE_ACCESS_GUIDE.md](FILE_ACCESS_GUIDE.md)** - File management and cloud storage
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical architecture overview

## Usage Examples

### Manual Export
1. Open the app
2. Tap "Sync Now" for incremental sync or "Full Export" for all data
3. Choose save location when prompted
4. Wait for export to complete

### Scheduled Syncs
1. Open Settings (gear icon)
2. Tap "Scheduled Syncs"
3. Create a new schedule with preferred frequency
4. Enable the schedule

### Shortcuts Automation
1. Open iOS Shortcuts app
2. Create new automation
3. Add "Sync Health Data" action
4. Configure trigger (time of day, location, etc.)

See [SHORTCUTS_GUIDE.md](SHORTCUTS_GUIDE.md) for detailed automation examples.

## JSON Export Format

Exports are saved as timestamped JSON files with the following structure:

```json
{
  "export_date": "2026-02-11T12:00:00Z",
  "export_type": "incremental",
  "records": [
    {
      "type": "HeartRate",
      "start_date": "2026-02-11T10:30:00Z",
      "end_date": "2026-02-11T10:30:00Z",
      "value": 72.0,
      "unit": "count/min",
      "source": "Apple Watch"
    }
  ],
  "workouts": [
    {
      "workout_type": "Running",
      "start_date": "2026-02-11T08:00:00Z",
      "end_date": "2026-02-11T08:45:00Z",
      "duration": 2700.0,
      "total_distance": 5000.0,
      "total_energy": 350.0,
      "source": "Apple Watch"
    }
  ]
}
```

## Privacy & Security

- **Local Processing**: All data processing happens on your device
- **No Cloud Service**: No data is sent to external servers
- **Your Control**: You choose where files are saved
- **HealthKit Permissions**: Only requested data types are accessed
- **Read-Only**: App never writes or modifies your health data

## Technical Details

- **Language**: Swift 5.9+
- **Framework**: SwiftUI with Combine
- **Architecture**: MVVM pattern
- **Storage**: UserDefaults for sync state, security-scoped bookmarks for file access
- **Background Tasks**: BGTaskScheduler for scheduled syncs
- **Date Format**: ISO 8601 for all timestamps

## Troubleshooting

### Files not appearing in Files app
- Ensure UIFileSharingEnabled is set in Info.plist
- Check that you selected a valid folder location
- Try restarting the Files app

### Background syncs not running
- Enable Background App Refresh in Settings
- Ensure device is connected to power for some sync types
- Check that scheduled sync is enabled

### HealthKit permission issues
- Go to Settings > Privacy > Health > Health Dashboard Export
- Ensure all needed data types are enabled

See [SETUP.md](SETUP.md) for more troubleshooting tips.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is available for personal use. Please see the repository for license details.

## Acknowledgments

Built with Claude Code and the Swift community's excellent documentation and tools.

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation in the repo

---

**Note**: This app is for personal health data management. Always maintain backups of important health data.
