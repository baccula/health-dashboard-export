# File Access Guide

How to access your exported health data files.

## Quick Setup: Enable Files App Access

To see exported files in the Files app on your iPhone:

### In Xcode (Required - One Time Setup)

1. **Open your project in Xcode**
2. **Select the "Health Dashboard Export" target**
3. **Go to the "Info" tab**
4. **Add these keys under "Custom iOS Target Properties":**

   **Key 1**: `UIFileSharingEnabled`
   - **Type**: Boolean
   - **Value**: YES
   
   **Key 2**: `LSSupportsOpeningDocumentsInPlace`
   - **Type**: Boolean  
   - **Value**: YES

5. **Build and run the app again**

After this, you'll see the app in **Files app → On My iPhone → Health Dashboard Export**

---

## Method 1: Files App (After Setup Above)

### On iPhone
```
Files app → Browse → On My iPhone → Health Dashboard Export
```

You'll see a `Documents` folder containing `HealthExport` with all your JSON files.

From here you can:
- Tap to view
- Share via AirDrop
- Copy to iCloud Drive
- Upload to cloud storage
- Email
- Use in Shortcuts

---

## Method 2: Finder (Mac)

### Connect iPhone to Mac

1. **Connect iPhone** to Mac via cable
2. **Open Finder**
3. **Select your iPhone** in the sidebar
4. **Click "Files" tab**
5. **Find "Health Dashboard Export"**
6. **Drag files to your Mac**

This works even without the Info.plist keys above.

---

## Method 3: Xcode Devices Window

### Download App Container

1. **Connect iPhone** to Mac
2. **Open Xcode**
3. **Window → Devices and Simulators** (⇧⌘2)
4. **Select your iPhone**
5. **Select "Health Dashboard Export" app**
6. **Click gear icon** (⚙️) → **Download Container**
7. **Save to Mac**
8. **Right-click saved file** → **Show Package Contents**
9. **Navigate to**: `AppData/Documents/HealthExport/`

All your export files are there!

---

## Method 4: Shortcuts (For Automation)

Even without Files app visibility, Shortcuts can access the files:

```
Get File
- Location: Documents/HealthExport/
- Filter: Name ends with ".json"
- Sort: Last Modified
- Limit: 1
```

This works immediately, no configuration needed!

---

## Method 5: In-App Location Display

### Get File Path

1. **Open app**
2. **Settings → Show Export Location**
3. **Path is copied to clipboard**
4. **Check console** for access instructions

---

## Current File Structure

```
Documents/
└── HealthExport/
    ├── health-export-full-2026-02-11.json
    ├── health-export-delta-2026-02-11.json
    ├── health-export-full-2026-02-12.json
    └── health-export-delta-2026-02-12.json
```

Files are named:
- **Full exports**: `health-export-full-YYYY-MM-DD.json`
- **Incremental**: `health-export-delta-YYYY-MM-DD.json`

---

## Troubleshooting

### "No Documents folder in Files app"

**Cause**: `UIFileSharingEnabled` not set in Info.plist

**Solution**: 
1. Follow setup instructions above
2. Add the two keys to Info.plist
3. Rebuild and reinstall app

### "Files folder is empty"

**Cause**: No exports have been created yet

**Solution**:
1. Open app
2. Tap "Full Export" or "Sync Now"
3. Wait for completion
4. Check Files app again

### "Can't find app in Finder Files tab"

**Cause**: iPhone not trusted or Files sharing not enabled

**Solution**:
1. Trust the Mac on iPhone if prompted
2. Add `UIFileSharingEnabled` to Info.plist
3. Rebuild app

### "Xcode can't download container"

**Cause**: App not installed or device not connected

**Solution**:
1. Ensure app is installed and running
2. Reconnect iPhone
3. Try again

---

## Recommended Setup for Easy Access

### Best User Experience:

1. **Enable file sharing** (Info.plist keys above)
2. **Access via Files app** on iPhone
3. **Create Shortcuts** to automatically:
   - Sync data
   - Upload to cloud/server
   - Clean up old files

### For Automation:

```
Shortcut: "Upload Health Data"
1. Sync Health Data (app intent)
2. Get File (Documents/HealthExport/, newest .json)
3. Upload to Dropbox/SSH/HTTP
4. Notify success
```

Set to run daily at 11:30 PM → fully automated!

---

## Alternative: iCloud Drive

If you want files in iCloud Drive instead of local storage:

### Enable iCloud (Optional)

1. **Xcode → Target → Signing & Capabilities**
2. **+ Capability → iCloud**
3. **Enable iCloud Documents**
4. **Sign in with Apple ID** on device

Files will then appear in:
```
Files app → iCloud Drive → Health Dashboard Export
```

**Note**: Works with free Apple ID, no paid developer account needed for personal use.

---

## Quick Reference

| Method | Setup Required | Best For |
|--------|---------------|----------|
| Files App | Info.plist keys | iOS access, sharing |
| Finder | None | Quick Mac transfer |
| Xcode Devices | None | Deep inspection |
| Shortcuts | None | Automation |
| iCloud Drive | iCloud capability | Cloud sync |

---

## Next Steps

1. **Add Info.plist keys** (see setup above)
2. **Run an export** in the app
3. **Check Files app** → On My iPhone → Health Dashboard Export
4. **Create upload Shortcut** for automation

Your health data will be accessible and ready for automation!
