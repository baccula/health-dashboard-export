# Shortcuts Integration Guide

The Health Dashboard Export app includes full Shortcuts support, allowing you to automate health data exports.

## Available Actions

### 1. Sync Health Data (Incremental)
**What it does**: Exports only new health data since the last sync

**Use for**:
- Daily automated syncs
- Quick updates after workouts
- Regular scheduled exports

**Voice commands**:
- "Sync my health data in Health Dashboard Export"
- "Export new health data in Health Dashboard Export"
- "Sync health to Health Dashboard Export"

**Returns**: Message indicating how many new records were exported

---

### 2. Full Health Export
**What it does**: Exports all historical health data

**Use for**:
- Initial setup
- Creating complete backups
- Rebuilding your health dashboard

**Voice commands**:
- "Export all health data in Health Dashboard Export"
- "Full health export in Health Dashboard Export"

**Returns**: Message indicating total records exported

---

### 3. Get Export Status
**What it does**: Returns information about your last export

**Use for**:
- Checking sync status
- Verifying last export time
- Monitoring export counts

**Returns**: Status report with last sync date, total records, and last file name

---

## Setting Up Shortcuts

### Quick Sync Shortcut

1. **Open Shortcuts app**
2. **Tap "+" to create new shortcut**
3. **Add action**: Search for "Health Dashboard Export"
4. **Choose**: "Sync Health Data"
5. **Optional**: Add notification with the result
6. **Name it**: "Sync Health"

Example shortcut:
```
1. Sync Health Data (Health Dashboard Export)
2. Show Notification
   - Title: "Health Sync"
   - Body: [Result from step 1]
```

### Daily Automated Sync

1. **Create shortcut** as above
2. **Add automation**:
   - Settings → Shortcuts → Automation → "+"
   - Choose "Time of Day"
   - Set time (e.g., 11:00 PM)
   - Choose "Run Immediately" (no confirmation)
   - Select your "Sync Health" shortcut

This will automatically sync your health data every day at the specified time!

### After Workout Sync

1. **Create shortcut** as above
2. **Add automation**:
   - Settings → Shortcuts → Automation → "+"
   - Choose "App" → "Health"
   - Set "When App is Closed"
   - Select your "Sync Health" shortcut

This syncs your data whenever you close the Health app (great after logging workouts).

---

## Advanced Shortcuts Examples

### Sync & Share to Mac

```
1. Sync Health Data
2. Get File (Documents/HealthExport/)
   - Filter: Name ends with ".json"
   - Sort by: Last Modified Date
   - Limit: 1
3. AirDrop to [Your Mac]
```

### Sync & Upload to Cloud

```
1. Sync Health Data
2. Get File (Documents/HealthExport/)
   - Filter: Name ends with ".json"
   - Sort by: Last Modified Date
   - Limit: 1
3. Save File to Dropbox/iCloud Drive/etc.
```

### Weekly Full Export with Notification

```
1. Full Health Export
2. Get File (Documents/HealthExport/)
   - Filter: Name contains "full"
   - Sort by: Last Modified Date
   - Limit: 1
3. Show Notification
   - Title: "Weekly Backup Complete"
   - Body: [Result from step 1]
```

Automation:
- Every Sunday at 10:00 PM
- Run immediately

---

## Siri Integration

Once you've created shortcuts, you can trigger them with Siri:

**Example phrases**:
- "Hey Siri, Sync Health"
- "Hey Siri, run my health sync shortcut"
- "Hey Siri, export my health data"

---

## Important Notes

### HealthKit Permissions
- The first time a shortcut runs, you may need to grant HealthKit permissions
- If authorization fails, the shortcut will return an error
- Open the app manually to grant permissions, then try again

### Background Execution
- Shortcuts run in the background (app doesn't open)
- `openAppWhenRun` is set to `false` for seamless operation
- Progress won't be visible, but you'll get a result message

### File Access
- Exported files are in the app's Documents directory
- Use "Get File" action in Shortcuts to access them
- Filter by "health-export-delta" or "health-export-full"

### Performance
- Incremental syncs are fast (seconds)
- Full exports may take longer (minutes for large datasets)
- Shortcuts have a ~30 second timeout - full exports might time out
- For full exports, prefer running from the app or use automation at night

---

## Troubleshooting

### "Authorization Required" Error
**Solution**: Open the app and grant HealthKit permissions manually

### Shortcut Times Out
**Solution**: 
- Use "Sync Health Data" instead of "Full Health Export"
- Or schedule full exports when you're not using your phone

### No New Data Exported
**Normal**: If you haven't generated health data since last sync
**Check**: Open app and verify Last Sync date

### Cannot Find Export File
**Solution**: Run an export first from the app or shortcut
**Check**: Use "Get Export Status" action to verify last export

---

## Tips & Best Practices

1. **Daily Syncs**: Use incremental sync automation (much faster)
2. **Weekly Backups**: Use full export automation on weekends
3. **After Workouts**: Trigger sync when closing Health or Fitness apps
4. **Verify Success**: Add notification actions to see results
5. **Chain Actions**: Combine with file operations to upload/share data

Enjoy automated health data exports! 🎯
