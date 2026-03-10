# Scheduling Guide
Automate health data uploads with scheduled syncs that run in the background.

## Overview
Schedules let you:
- Run incremental or full syncs
- Set daily, weekly, bi-weekly, or monthly frequencies
- Enable/disable schedules without deleting them

## Create a Schedule
1. Settings → Scheduled Syncs
2. Tap "+"
3. Configure name, type, frequency, time
4. Save

## Sync Types

### Incremental Sync
- Uploads only new data since the last sync
- Best for daily or frequent schedules

### Full Export
- Uploads all historical data
- Best for occasional backfills

## Background Sync Requirements
Background tasks are controlled by iOS and may not run exactly on time.

**To improve reliability:**
- Enable Background App Refresh
- Keep the device charged
- Avoid Low Power Mode
- Do not force quit the app

**Protected Health Data**
- HealthKit data is not accessible while the device is locked
- The device must be unlocked at least once after reboot
- If you see "Protected health data is inaccessible", unlock the device and try again

## Troubleshooting
**Schedule didn't run**
- Background App Refresh is off
- Low Power Mode is on
- iOS postponed the task

**Schedule ran but failed**
- HealthKit permissions revoked
- Device locked (protected data unavailable)
- Network unavailable

## Tips
- Use incremental for daily schedules
- Test schedules with "Run Now" after creating them
- Schedule during times you normally charge the device