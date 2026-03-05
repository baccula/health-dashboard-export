# Proposal: Server “Latest Record” Sync Endpoint

## Goal
Avoid re-uploading already-ingested HealthKit samples after local data clears by letting the client ask the server for the latest ingested timestamps, then exporting only newer samples.

## API
### Endpoint
`GET /api/sync/latest`

### Auth
Bearer API key (same as upload endpoint).

### Response (per-type recommended)
```json
{
    "deviceId": "abc123",
    "generatedAt": "2026-03-05T18:30:00Z",
    "records": {
        "HKQuantityTypeIdentifierHeartRate": "2026-03-04T23:59:59Z",
        "HKCategoryTypeIdentifierSleepAnalysis": "2026-03-02T08:10:00Z"
    },
    "workouts": "2026-03-03T17:22:00Z",
    "globalMax": "2026-03-04T23:59:59Z"
}
```

Notes:
- `records` is a per-type map (preferred).
- `workouts` is a single timestamp for workouts.
- `globalMax` is optional and can be used as a fallback.
- Types with no data can be omitted or set to null.

## Server Behavior
- Maintain “latest ingested timestamp” per type (plus workouts), keyed by API key or device id.
- Update on ingest, or compute from the database on demand.
- Return timestamps in ISO-8601 UTC.

## Client Behavior (high-level)
1. Call `GET /api/sync/latest` at sync start.
2. For each HealthKit type, export data since that type’s timestamp (strictStartDate).
3. For workouts, export since workouts timestamp.
4. If the endpoint is unavailable, fall back to existing local `lastSyncDate` behavior.

## Edge Cases
- Late-arriving older samples: optionally subtract a small buffer (e.g., 6–12 hours) and rely on server de-duplication.
- Identical timestamps: use strictStartDate; duplicates with same timestamp are handled by server de-dupe.
- Re-pairing: server can treat a new API key as a new device unless state is migrated.

## Security & Ops
- Same auth as upload.
- Minimal payload and compute; can be cached or rate-limited.

## Optional Enhancements
- Add `sync cursor` for stronger incremental sync.
- Add “missing ranges” response to further reduce upload size.
