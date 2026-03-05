# Client Change List: Sync Latest Endpoint

## Models
- Add response model for sync latest endpoint:
  - `SyncLatestResponse` with fields:
    - `deviceId: String`
    - `generatedAt: String`
    - `records: [String: String]?`
    - `workouts: String?`
    - `globalMax: String?`

## APIClient
- Add a method:
  - `func fetchSyncLatest() async throws -> SyncLatestResponse`
- Implement `GET /api/sync/latest` with Bearer auth.
- Decode JSON into `SyncLatestResponse`.

## HealthExporter
- On sync start (incremental and full flows):
  - Call `fetchSyncLatest()`.
  - For each type in `HealthDataType`, choose a `since` date:
    - Use per-type timestamp if present.
    - Else use `globalMax` if present.
    - Else fall back to `lastSyncDate` if present.
  - Export and upload only records newer than that cutoff.
- For workouts:
  - Use `workouts` timestamp, else `globalMax`, else `lastSyncDate`.

## HealthKit Queries
- Continue to use `HKSampleQuery` with `predicateForSamples(withStart: since, end: nil, options: .strictStartDate)`.
- Optionally add a small buffer window before `since` to mitigate late-arriving samples (server de-duplication will absorb duplicates).

## Error Handling
- If sync-latest call fails:
  - Log and fall back to current `lastSyncDate` behavior.

## UI/Settings (optional)
- Add diagnostic display: “Server latest sync timestamps fetched at …”.
- Add a “Force full re-sync” action that bypasses server timestamps.

## Testing
- Unit-test parsing of `SyncLatestResponse`.
- Mock `fetchSyncLatest()` to validate per-type cutoff selection.
- Verify fallbacks when records map omits types or endpoint fails.
