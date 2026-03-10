# Bug Report: Server Not Processing Uploaded Health Data
**Date:** 2026-02-26
**Reporter:** iOS Client Testing
**Severity:** Critical
**Component:** Server - `/api/upload` endpoint

---

## Summary
The `/api/upload` endpoint is accepting POST requests and returning HTTP 200 with `{"inserted":0,"skipped":0,"errors":[]}`, but is **not actually inserting any records into the database**. The server receives the data correctly but fails to process it.

## Expected Behavior
When the iOS app uploads health data to `/api/upload`, the server should:
1. Parse the JSON request body
2. Insert new records into the database
3. Return counts of inserted/skipped records
4. Return `{"inserted": N, "skipped": M, "errors": []}` where N > 0 for new data

## Actual Behavior
The server:
1. Accepts the POST request
2. Returns HTTP 200 OK
3. Returns `{"inserted":0,"skipped":0,"errors":[]}`
4. Does NOT insert any records into the database

## Reproduction Steps
1. Pair an iOS device with the server using a valid pairing code
2. Initiate a sync from the iOS app (either full export or incremental)
3. Observe the server response in the iOS app logs
4. Check the database - no records are inserted

## Technical Details

### iOS Client Request Format
The iOS app sends data in the following format:

```json
{
 "data": {
 "records": [
 "type": "HKQuantityTypeIdentifierHeartRate",
 "sourceName": "Apple Watch",
 "sourceVersion": null,
 "device": null,
 "unit": "count/min",
 "value": 99.0,
 "startDate": "2026-02-26 14:49:09 -1000",
 "endDate": "2026-02-26 14:49:09 -1000",
 "creationDate": null
 }
 ],
 "workouts": [
 "workoutType": "HKWorkoutActivityTypeRunning",
 "duration": 30.5,
 "durationUnit": "min",
 "totalDistance": 2.5,
 "totalDistanceUnit": "mi",
 "totalEnergy": 250.0,
 "totalEnergyUnit": "kcal",
 "startDate": "2026-02-26 14:30:00 -1000",
 "endDate": "2026-02-26 15:00:30 -1000",
 ]
```

### Request Headers
POST /api/upload HTTP/1.1
Authorization: Bearer {api_key}
Content-Type: application/json

### Server Response
"inserted": 0,
 "skipped": 0,
 "errors": []

### Sample iOS Client Logs
 Uploading data in 1 chunk(s) (10000 items per chunk)
 Records: 53 in 1 chunk(s)
 Workouts: 0 in 0 chunk(s)
 Uploading chunk 1/1: 53 records + 0 workouts
 Encoding upload data...
 Uploading 53 records + 0 workouts (total: 53)
 Payload size: 0.01 MB
 Sending to: http://192.168.1.32:8765/api/upload
 Sample record: type=HKQuantityTypeIdentifierHeartRate, value=99.0, startDate=2026-02-26 14:49:09 -1000
⏳ Waiting for server response...
 Network request attempt 1/3...
 Request completed in 0.8s
 Server responded with status: 200
 Raw server response: {"inserted":0,"skipped":0,"errors":[]}
 Upload successful: 0 inserted, 0 skipped, 0 errors
️ WARNING: Server accepted data but reported 0 insertions and 0 skips
 This suggests the server may not be processing the data correctly

## Possible Root Causes
1. **Request Body Parsing Issue**
 - Server may not be correctly parsing the JSON body
 - Check if the request body is being read before processing

2. **Data Structure Mismatch**
 - Server may be looking for different field names
 - Verify the server expects `data.records` and `data.workouts`
 - Check if date format is being parsed correctly: `"yyyy-MM-dd HH:mm:ss Z"`

3. **Database Insertion Logic**
 - Database insert/upsert functions may not be called
 - Transaction may be rolled back silently
 - Check for missing `commit()` or `flush()` calls

4. **Silent Error Handling**
 - Exceptions may be caught and ignored
 - Database errors may not be bubbling up
 - Check error logging in the upload handler

5. **Authentication/Authorization**
 - Request may be passing auth but failing authorization checks
 - User/device association may be broken

## Debugging Checklist
- [ ] Add logging to confirm request body is received
- [ ] Log the parsed JSON structure
- [ ] Add logging before/after database insert operations
- [ ] Check database transaction handling (commit/rollback)
- [ ] Verify error handling doesn't silently swallow exceptions
- [ ] Check database constraints (unique keys, foreign keys)
- [ ] Verify the API key maps to a valid user/device
- [ ] Test with a minimal payload (1-2 records)
- [ ] Check database logs for any constraint violations

## Workaround
None available. The iOS app is correctly formatting and sending data. This is a server-side issue that must be fixed on the backend.

## Impact
- **Critical** - No health data can be synced from iOS devices
- Affects all users attempting to sync
- Data is lost if users continue syncing (lastSyncDate advances but no data is stored)

## Additional Notes
The iOS client has been thoroughly tested and verified to:
- Correctly format JSON payloads
- Send proper authentication headers
- Use correct date formats
- Handle chunked uploads for large datasets
- Parse server responses correctly

The issue is definitively on the server side and requires immediate attention.