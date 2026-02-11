# Scheduling Guide

Automate your health data exports with scheduled syncs that run automatically in the background.

## Overview

The Health Dashboard Export app includes a powerful scheduling system that allows you to:
- Schedule automatic incremental or full exports
- Set daily, weekly, bi-weekly, or monthly frequencies
- Choose specific times for syncs to run
- View and manage all your schedules in one place
- Enable/disable schedules without deleting them

## Getting Started

### Access Schedule Manager

```
Settings → Scheduled Syncs
```

### Create Your First Schedule

1. **Tap the "+" button** in the top-right
2. **Configure the schedule**:
   - **Name**: Give it a descriptive name (e.g., "Daily Night Sync")
   - **Enabled**: Toggle on to activate
   - **Sync Type**: Choose Incremental or Full Export
   - **Frequency**: Daily, Weekly, Bi-weekly, or Monthly
   - **Time**: When the sync should run

3. **Review the next run time**
4. **Tap "Save"**

Your schedule is now active!

## Sync Types

### Incremental Sync (Recommended for Regular Use)
- **What it does**: Exports only new data since the last sync
- **Speed**: Fast (seconds to minutes)
- **Use for**: Daily or frequent schedules
- **Best for**: Keeping your dashboard current

### Full Export
- **What it does**: Exports all historical health data
- **Speed**: Slower (minutes for large datasets)
- **Use for**: Weekly or monthly backups
- **Best for**: Complete data archives

## Frequency Options

### Daily
- Runs every day at the specified time
- **Example**: 11:00 PM every night
- **Best for**: Incremental syncs to keep data current

### Weekly
- Runs once per week at the specified time
- **Example**: Every Sunday at 10:00 PM
- **Best for**: Regular full backups

### Bi-weekly
- Runs every two weeks at the specified time
- **Example**: Every other Sunday at 10:00 PM
- **Best for**: Less frequent full exports

### Monthly
- Runs once per month at the specified time
- **Example**: 1st of every month at 10:00 PM
- **Best for**: Monthly archives

## Managing Schedules

### View All Schedules
The Schedule Manager shows:
- Schedule name and type icon
- Frequency and next run time
- Enable/disable toggle
- Total schedules count
- Next upcoming sync

### Edit a Schedule
**Option 1**: Swipe left → Tap "Edit"
**Option 2**: Long press → Select "Edit"

### Run a Schedule Immediately
Long press on a schedule → Tap "Run Now"

This executes the schedule immediately without waiting for the next scheduled time.

### Enable/Disable Schedules
Toggle the switch on the right side of each schedule.

Disabled schedules:
- Remain in your list
- Don't run automatically
- Can be re-enabled anytime

### Delete a Schedule
Swipe left → Tap "Delete"

## Background Sync Requirements

For scheduled syncs to work reliably:

### Device Requirements
✅ **Device must be charging** - iOS requires this for background tasks
✅ **Connected to WiFi** - Recommended for large exports
✅ **Background App Refresh enabled** - Check Settings → General → Background App Refresh

### iOS Behavior
⚠️ **Syncs may be delayed** - iOS controls when background tasks actually run
⚠️ **Not guaranteed to run exactly on time** - System manages battery and performance
⚠️ **May not run if battery is low** - iOS prioritizes battery life

### Maximizing Reliability
To ensure your schedules run:
1. **Plug in your device** at night when syncs are scheduled
2. **Keep WiFi on** for better success rate
3. **Schedule during charging times** (e.g., overnight)
4. **Don't force quit the app** - Let it run in background
5. **Enable Background App Refresh** in Settings

## Example Schedules

### Setup 1: Daily Incremental + Weekly Full
```
Schedule 1: "Daily Sync"
- Type: Incremental
- Frequency: Daily
- Time: 11:00 PM

Schedule 2: "Weekly Backup"
- Type: Full Export
- Frequency: Weekly
- Time: 10:00 PM (Sundays)
```

**Why this works**: Daily syncs keep data current, weekly full export creates complete backups.

### Setup 2: Bi-weekly Full Exports Only
```
Schedule: "Bi-weekly Export"
- Type: Full Export
- Frequency: Bi-weekly
- Time: 10:00 PM
```

**Why this works**: Simple, low-maintenance schedule for complete backups every two weeks.

### Setup 3: After-Hours Sync
```
Schedule: "Night Sync"
- Type: Incremental
- Frequency: Daily
- Time: 2:00 AM
```

**Why this works**: Runs in the middle of the night when device is definitely charging and you're asleep.

## Troubleshooting

### Schedule didn't run at the expected time

**Possible causes**:
- Device wasn't charging
- Background App Refresh disabled
- Low battery mode enabled
- iOS postponed the task

**Solutions**:
1. Check Settings → General → Background App Refresh
2. Ensure device is plugged in during scheduled time
3. Check battery level (should be >20%)
4. Run manually using "Run Now" if urgent

### "Next Run" shows unexpected time

**This is normal**: After a schedule runs, it calculates the next occurrence based on frequency.

**Example**: Daily at 11 PM
- First run: Tonight at 11 PM
- After running: Tomorrow at 11 PM
- And so on...

### Background refresh not working

**Check these settings**:
1. Settings → General → Background App Refresh → ON
2. Settings → General → Background App Refresh → Health Dashboard Export → ON
3. Settings → Battery → Low Power Mode → OFF (when syncing)

### Schedule runs but export fails

**Possible causes**:
- HealthKit permissions revoked
- Storage full
- App crashed

**Solutions**:
1. Open app to verify HealthKit permissions
2. Check device storage
3. Try running schedule manually using "Run Now"
4. Check Settings → Last Sync date

## Best Practices

### 1. Use Incremental for Frequency
- Daily/frequent schedules should use incremental sync
- Much faster and more efficient
- Full exports only needed occasionally

### 2. Schedule During Charging Times
- Set schedules when device is normally charging
- Overnight (11 PM - 6 AM) works best for most people
- Ensures iOS allows the background task

### 3. Don't Over-Schedule
- One daily incremental + one weekly full is usually enough
- Too many schedules compete for background resources
- Keep it simple

### 4. Test Your Schedule
- After creating, use "Run Now" to test it works
- Verify the export file was created
- Check Settings → Export Status

### 5. Monitor Success
- Periodically check Settings → Last Sync
- Ensure scheduled syncs are running
- Adjust schedule time if needed

## Advanced Tips

### Combining with Shortcuts
You can supplement scheduled syncs with Shortcuts:
- Schedule runs automatically in background
- Shortcuts run on-demand or with custom automations
- Use both for maximum flexibility

### Optimal Schedule Times
Based on iOS behavior:
- **11:00 PM - 2:00 AM**: Best for daily syncs
- **Weekend mornings**: Good for weekly full exports
- **Avoid 6 AM - 11 PM**: Device likely in use

### Battery Considerations
Background tasks use battery. To minimize impact:
- Schedule when charging
- Use incremental sync (less data = less battery)
- Limit number of active schedules

## FAQ

**Q: Can I have multiple schedules active?**
A: Yes! You can have as many as you want, all running independently.

**Q: What happens if I have two schedules at the same time?**
A: Both will attempt to run. iOS may run them sequentially or postpone one.

**Q: Can schedules run when the app is closed?**
A: Yes, as long as you don't force quit the app. Background refresh works when app is in background.

**Q: How accurate are the scheduled times?**
A: iOS controls exact timing. Expect ±15 minutes variance. For precise timing, use Shortcuts automations.

**Q: Do schedules work on airplane mode?**
A: Yes, but exports only save locally. WiFi recommended for larger datasets.

**Q: Can I export the schedule configuration?**
A: Not currently. Schedules are stored locally on device.

**Q: What happens to schedules if I delete the app?**
A: They're deleted. Reinstalling requires recreating schedules.

---

**Tip**: Start with a simple daily incremental sync. You can always add more schedules later!
