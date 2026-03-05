//
//  Health_Dashboard_ExportTests.swift
//  Health Dashboard ExportTests
//
//  Created by Mike Neuwirth on 2/11/26.
//

import HealthKit
import XCTest
@testable import Health_Dashboard_Export

final class ScheduleFrequencyTests: XCTestCase {
    func testDailyScheduleCreatedBeforeScheduledTime_RunsToday() {
        let createdAt = makeLocalDate(year: 2026, month: 3, day: 4, hour: 9, minute: 0)
        let scheduledTime = makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30)

        let nextRun = ScheduleFrequency.daily.calculateNextRun(from: createdAt, at: scheduledTime)

        XCTAssertEqual(calendar.component(.day, from: nextRun), 4)
        XCTAssertEqual(calendar.component(.hour, from: nextRun), 15)
        XCTAssertEqual(calendar.component(.minute, from: nextRun), 30)
    }

    func testDailyScheduleCreatedAfterScheduledTime_RunsTomorrow() {
        let createdAt = makeLocalDate(year: 2026, month: 3, day: 4, hour: 20, minute: 0)
        let scheduledTime = makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30)

        let nextRun = ScheduleFrequency.daily.calculateNextRun(from: createdAt, at: scheduledTime)

        XCTAssertEqual(calendar.component(.day, from: nextRun), 5)
        XCTAssertEqual(calendar.component(.hour, from: nextRun), 15)
        XCTAssertEqual(calendar.component(.minute, from: nextRun), 30)
    }

    func testWeeklyScheduleCalculatesCorrectNextRun() {
        let createdAt = makeLocalDate(year: 2026, month: 3, day: 4, hour: 20, minute: 0)
        let scheduledTime = makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30)

        let nextRun = ScheduleFrequency.weekly.calculateNextRun(from: createdAt, at: scheduledTime)
        let expected = calendar.date(byAdding: .weekOfYear, value: 1, to: makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30))!

        XCTAssertEqual(nextRun, expected)
    }

    func testBiweeklyScheduleCalculatesCorrectNextRun() {
        let createdAt = makeLocalDate(year: 2026, month: 3, day: 4, hour: 20, minute: 0)
        let scheduledTime = makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30)

        let nextRun = ScheduleFrequency.biweekly.calculateNextRun(from: createdAt, at: scheduledTime)
        let expected = calendar.date(byAdding: .weekOfYear, value: 2, to: makeLocalDate(year: 2026, month: 3, day: 4, hour: 15, minute: 30))!

        XCTAssertEqual(nextRun, expected)
    }

    func testMonthlyScheduleCalculatesCorrectNextRun() {
        let createdAt = makeLocalDate(year: 2026, month: 3, day: 31, hour: 22, minute: 0)
        let scheduledTime = makeLocalDate(year: 2026, month: 3, day: 31, hour: 15, minute: 30)

        let nextRun = ScheduleFrequency.monthly.calculateNextRun(from: createdAt, at: scheduledTime)
        let expected = calendar.date(byAdding: .month, value: 1, to: makeLocalDate(year: 2026, month: 3, day: 31, hour: 15, minute: 30))!

        XCTAssertEqual(nextRun, expected)
    }

    @MainActor
    func testOverdueSchedulesAreAdvancedProperlyWhenAppReopens() throws {
        let suiteName = "ScheduleManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = makeLocalDate(year: 2026, month: 3, day: 4, hour: 12, minute: 0)
        let timeOfDay = makeLocalDate(year: 2026, month: 3, day: 1, hour: 9, minute: 0)
        let overdueDate = makeLocalDate(year: 2026, month: 3, day: 1, hour: 9, minute: 0)

        var schedule = SyncSchedule(
            name: "Daily",
            syncType: .incremental,
            frequency: .daily,
            time: timeOfDay
        )
        schedule.nextRun = overdueDate

        let data = try JSONEncoder().encode([schedule])
        defaults.set(data, forKey: "syncSchedules")

        let manager = ScheduleManager(
            userDefaults: defaults,
            shouldManageBackgroundTasks: false,
            nowProvider: { now }
        )

        guard let advancedDate = manager.schedules.first?.nextRun else {
            XCTFail("Expected a next run date")
            return
        }

        XCTAssertGreaterThan(advancedDate, now)
        XCTAssertEqual(calendar.component(.hour, from: advancedDate), 9)
        XCTAssertEqual(calendar.component(.minute, from: advancedDate), 0)
    }
}

final class HealthExporterTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "HealthExporterTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testFullExportExportsAllDataTypes() async throws {
        let provider = MockHealthDataProvider()
        provider.recordsForFullExport = [
            HealthRecord(type: "HKQuantityTypeIdentifierStepCount", startDate: makeUTCDate(2026, 3, 1, 8, 0), endDate: makeUTCDate(2026, 3, 1, 8, 1), value: 1000, unit: "count", source: "Watch"),
            HealthRecord(type: "HKCategoryTypeIdentifierSleepAnalysis", startDate: makeUTCDate(2026, 3, 1, 0, 0), endDate: makeUTCDate(2026, 3, 1, 7, 0), value: 1, unit: "category", source: "Phone")
        ]
        provider.workoutsForFullExport = [
            WorkoutRecord(type: "HKWorkoutActivityTypeRunning", startDate: makeUTCDate(2026, 3, 2, 7, 0), endDate: makeUTCDate(2026, 3, 2, 7, 30), durationMinutes: 30, distanceMiles: 3, calories: 200, source: "Watch")
        ]

        let uploadClient = MockUploadClient()
        uploadClient.responses = [UploadResponse(inserted: 2, skipped: 0, errors: [])]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults,
            nowProvider: { makeUTCDate(2026, 3, 4, 12, 0) }
        )

        try await exporter.performFullExport()

        XCTAssertEqual(uploadClient.uploadCalls.count, 1)
        XCTAssertEqual(uploadClient.uploadCalls[0].records.count, 2)
        XCTAssertEqual(uploadClient.uploadCalls[0].workouts.count, 1)
        XCTAssertEqual(Set(uploadClient.uploadCalls[0].records.map(\.type)), Set(["HKQuantityTypeIdentifierStepCount", "HKCategoryTypeIdentifierSleepAnalysis"]))
        XCTAssertEqual(uploadClient.uploadCalls[0].workouts.first?.workoutType, "HKWorkoutActivityTypeRunning")
    }

    @MainActor
    func testIncrementalExportOnlyExportsNewDataSinceLastSync() async throws {
        let lastSync = makeUTCDate(2026, 3, 3, 12, 0)
        userDefaults.set(lastSync, forKey: "lastSyncDate")
        userDefaults.set(10, forKey: "totalRecords")

        let provider = MockHealthDataProvider()
        provider.recordsForIncrementalExport = [
            HealthRecord(type: "HKQuantityTypeIdentifierHeartRate", startDate: makeUTCDate(2026, 3, 4, 10, 0), endDate: makeUTCDate(2026, 3, 4, 10, 1), value: 72, unit: "count/min", source: "Watch")
        ]
        provider.workoutsForIncrementalExport = [
            WorkoutRecord(type: "HKWorkoutActivityTypeWalking", startDate: makeUTCDate(2026, 3, 4, 9, 0), endDate: makeUTCDate(2026, 3, 4, 9, 20), durationMinutes: 20, distanceMiles: 1, calories: 100, source: "Phone")
        ]

        let uploadClient = MockUploadClient()
        uploadClient.responses = [UploadResponse(inserted: 1, skipped: 0, errors: [])]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults,
            nowProvider: { makeUTCDate(2026, 3, 4, 13, 0) }
        )

        try await exporter.performIncrementalSync()

        XCTAssertEqual(provider.recordsSinceDates, [lastSync])
        XCTAssertEqual(provider.recordsPerTypeSince, [[:]])
        XCTAssertEqual(provider.workoutsSinceDates, [lastSync])
        XCTAssertEqual(uploadClient.uploadCalls.count, 1)
        XCTAssertEqual(uploadClient.uploadCalls[0].records.count, 1)
        XCTAssertEqual(uploadClient.uploadCalls[0].workouts.count, 1)
    }

    @MainActor
    func testIncrementalSyncUsesServerPerTypeTimestampsWhenAvailable() async throws {
        let localLastSync = makeUTCDate(2026, 3, 3, 12, 0)
        let serverHeartRateSince = makeUTCDate(2026, 3, 4, 8, 0)
        let serverWorkoutSince = makeUTCDate(2026, 3, 4, 9, 0)
        userDefaults.set(localLastSync, forKey: "lastSyncDate")

        let provider = MockHealthDataProvider()
        provider.recordsForIncrementalExport = [
            HealthRecord(type: "HKQuantityTypeIdentifierHeartRate", startDate: makeUTCDate(2026, 3, 4, 10, 0), endDate: makeUTCDate(2026, 3, 4, 10, 1), value: 75, unit: "count/min", source: "Watch")
        ]
        provider.workoutsForIncrementalExport = [
            WorkoutRecord(type: "HKWorkoutActivityTypeRunning", startDate: makeUTCDate(2026, 3, 4, 10, 0), endDate: makeUTCDate(2026, 3, 4, 10, 30), durationMinutes: 30, distanceMiles: 3, calories: 250, source: "Watch")
        ]

        let uploadClient = MockUploadClient()
        uploadClient.latestSyncDates = [
            "HKQuantityTypeIdentifierHeartRate": serverHeartRateSince,
            "HKWorkout": serverWorkoutSince
        ]
        uploadClient.responses = [UploadResponse(inserted: 2, skipped: 0, errors: [])]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults
        )

        try await exporter.performIncrementalSync()

        XCTAssertEqual(uploadClient.requestedLatestSyncDeviceIds, ["test-device-id"])
        XCTAssertEqual(provider.recordsSinceDates, [localLastSync])
        XCTAssertEqual(provider.recordsPerTypeSince.count, 1)
        XCTAssertEqual(provider.recordsPerTypeSince[0]["HKQuantityTypeIdentifierHeartRate"], serverHeartRateSince)
        XCTAssertEqual(provider.workoutsSinceDates, [serverWorkoutSince])
    }

    @MainActor
    func testIncrementalSyncFallsBackToLocalLastSyncWhenLatestEndpointUnavailable() async throws {
        let localLastSync = makeUTCDate(2026, 3, 3, 12, 0)
        userDefaults.set(localLastSync, forKey: "lastSyncDate")

        let provider = MockHealthDataProvider()
        provider.recordsForIncrementalExport = [
            HealthRecord(type: "HKQuantityTypeIdentifierStepCount", startDate: makeUTCDate(2026, 3, 4, 11, 0), endDate: makeUTCDate(2026, 3, 4, 11, 1), value: 500, unit: "count", source: "Watch")
        ]
        provider.workoutsForIncrementalExport = [
            WorkoutRecord(type: "HKWorkoutActivityTypeWalking", startDate: makeUTCDate(2026, 3, 4, 11, 0), endDate: makeUTCDate(2026, 3, 4, 11, 20), durationMinutes: 20, distanceMiles: 1, calories: 120, source: "Phone")
        ]

        let uploadClient = MockUploadClient()
        uploadClient.latestSyncDatesError = APIError.networkError
        uploadClient.responses = [UploadResponse(inserted: 2, skipped: 0, errors: [])]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults
        )

        try await exporter.performIncrementalSync()

        XCTAssertEqual(provider.recordsSinceDates, [localLastSync])
        XCTAssertEqual(provider.recordsPerTypeSince, [[:]])
        XCTAssertEqual(provider.workoutsSinceDates, [localLastSync])
    }

    @MainActor
    func testIncrementalSyncUsesServerStateWhenLocalSyncMissing() async throws {
        let serverHeartRateSince = makeUTCDate(2026, 3, 4, 8, 0)
        let serverWorkoutSince = makeUTCDate(2026, 3, 4, 9, 0)

        let provider = MockHealthDataProvider()
        provider.recordsForIncrementalExport = [
            HealthRecord(type: "HKQuantityTypeIdentifierHeartRate", startDate: makeUTCDate(2026, 3, 4, 10, 0), endDate: makeUTCDate(2026, 3, 4, 10, 1), value: 75, unit: "count/min", source: "Watch")
        ]
        provider.workoutsForIncrementalExport = [
            WorkoutRecord(type: "HKWorkoutActivityTypeRunning", startDate: makeUTCDate(2026, 3, 4, 10, 0), endDate: makeUTCDate(2026, 3, 4, 10, 30), durationMinutes: 30, distanceMiles: 3, calories: 250, source: "Watch")
        ]

        let uploadClient = MockUploadClient()
        uploadClient.latestSyncDates = [
            "HKQuantityTypeIdentifierHeartRate": serverHeartRateSince,
            "HKWorkout": serverWorkoutSince
        ]
        uploadClient.responses = [UploadResponse(inserted: 2, skipped: 0, errors: [])]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults
        )

        try await exporter.performIncrementalSync()

        XCTAssertEqual(provider.recordsSinceDates, [nil])
        XCTAssertEqual(provider.recordsPerTypeSince.count, 1)
        XCTAssertEqual(provider.recordsPerTypeSince[0]["HKQuantityTypeIdentifierHeartRate"], serverHeartRateSince)
        XCTAssertEqual(provider.workoutsSinceDates, [serverWorkoutSince])
        XCTAssertEqual(uploadClient.uploadCalls.count, 1)
    }

    @MainActor
    func testChunkedUploadProcessesAllChunks() async throws {
        let provider = MockHealthDataProvider()
        provider.recordsForFullExport = makeHealthRecords(count: 25_050)
        provider.workoutsForFullExport = makeWorkoutRecords(count: 15_050)

        let uploadClient = MockUploadClient()
        uploadClient.responses = [
            UploadResponse(inserted: 10_000, skipped: 0, errors: []),
            UploadResponse(inserted: 10_000, skipped: 0, errors: []),
            UploadResponse(inserted: 5_050, skipped: 0, errors: [])
        ]

        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults,
            nowProvider: { makeUTCDate(2026, 3, 4, 14, 0) }
        )

        try await exporter.performFullExport()

        XCTAssertEqual(uploadClient.uploadCalls.count, 3)
        XCTAssertEqual(uploadClient.uploadCalls[0].records.count, 10_000)
        XCTAssertEqual(uploadClient.uploadCalls[1].records.count, 10_000)
        XCTAssertEqual(uploadClient.uploadCalls[2].records.count, 5_050)
        XCTAssertEqual(uploadClient.uploadCalls[0].workouts.count, 10_000)
        XCTAssertEqual(uploadClient.uploadCalls[1].workouts.count, 5_050)
        XCTAssertEqual(uploadClient.uploadCalls[2].workouts.count, 0)

        let uploadedRecordTotal = uploadClient.uploadCalls.reduce(0) { $0 + $1.records.count }
        let uploadedWorkoutTotal = uploadClient.uploadCalls.reduce(0) { $0 + $1.workouts.count }
        XCTAssertEqual(uploadedRecordTotal, 25_050)
        XCTAssertEqual(uploadedWorkoutTotal, 15_050)
    }

    @MainActor
    func testSyncStatePersistsCorrectly() async throws {
        let provider = MockHealthDataProvider()
        provider.recordsForFullExport = makeHealthRecords(count: 3)

        let uploadClient = MockUploadClient()
        uploadClient.responses = [UploadResponse(inserted: 3, skipped: 0, errors: [])]

        let now = makeUTCDate(2026, 3, 4, 15, 0)
        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults,
            nowProvider: { now }
        )
        try await exporter.performFullExport()

        let reloadedExporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults,
            nowProvider: { now }
        )

        XCTAssertEqual(reloadedExporter.lastSyncDate, now)
        XCTAssertEqual(reloadedExporter.totalRecords, 3)
    }

    @MainActor
    func testClearAllDataRemovesAllStateAndUnpairsDevice() {
        userDefaults.set(makeUTCDate(2026, 3, 4, 16, 0), forKey: "lastSyncDate")
        userDefaults.set(42, forKey: "totalRecords")

        let provider = MockHealthDataProvider()
        let uploadClient = MockUploadClient()
        let exporter = HealthExporter(
            apiClient: uploadClient,
            dataProvider: provider,
            userDefaults: userDefaults
        )

        exporter.clearAllData()

        XCTAssertNil(exporter.lastSyncDate)
        XCTAssertEqual(exporter.totalRecords, 0)
        XCTAssertEqual(exporter.exportProgress, 0)
        XCTAssertEqual(exporter.exportProgressText, "")
        XCTAssertNil(userDefaults.object(forKey: "lastSyncDate"))
        XCTAssertNil(userDefaults.object(forKey: "totalRecords"))
        XCTAssertTrue(uploadClient.unpairCalled)
    }
}

final class APIClientTests: XCTestCase {
    private var keychain: InMemoryKeychain!
    private var userDefaults: UserDefaults!
    private var session: URLSession!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        keychain = InMemoryKeychain()
        suiteName = "APIClientTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session.invalidateAndCancel()
        userDefaults.removePersistentDomain(forName: suiteName)
        session = nil
        userDefaults = nil
        suiteName = nil
        keychain = nil
        super.tearDown()
    }

    @MainActor
    func testPairingWithValidCodeSucceeds() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/pair/confirm")
            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PairConfirmRequest.self, from: body)
            XCTAssertEqual(payload.code, "123456")

            let response = PairResponse(apiKey: "api-test-key", deviceName: "Mike iPhone", createdAt: "2026-03-04T19:11:00Z")
            let data = try JSONEncoder().encode(response)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)
        let response = try await client.confirmPairingCode("123456")

        XCTAssertEqual(response.apiKey, "api-test-key")
        XCTAssertEqual(response.deviceName, "Mike iPhone")
        XCTAssertTrue(client.isPaired)
    }

    @MainActor
    func testPairingWithInvalidCodeFailsWithProperError() async {
        MockURLProtocol.requestHandler = { request in
            let error = APIErrorResponse(status: "error", message: "Invalid pairing code")
            let data = try JSONEncoder().encode(error)
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)

        do {
            _ = try await client.confirmPairingCode("000000")
            XCTFail("Expected pairing to fail")
        } catch let error as APIError {
            if case .pairingFailed(let message) = error {
                XCTAssertEqual(message, "Invalid pairing code")
            } else {
                XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testUploadWithValidAPIKeySucceeds() async throws {
        try keychain.save(key: "healthDashboardAPIKey", value: "valid-key")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid-key")
            let response = UploadResponse(inserted: 2, skipped: 0, errors: [])
            let data = try JSONEncoder().encode(response)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)
        let result = try await client.uploadHealthData(records: [makeAPIRecord()], workouts: [makeAPIWorkout()])

        XCTAssertEqual(result.inserted, 2)
    }

    @MainActor
    func testUploadWithoutAPIKeyThrowsNotPairedError() async {
        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)

        do {
            _ = try await client.uploadHealthData(records: [makeAPIRecord()], workouts: [])
            XCTFail("Expected notPaired error")
        } catch let error as APIError {
            guard case .notPaired = error else {
                XCTFail("Expected notPaired but got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testAuthExpiryTriggersRePairingFlow() async throws {
        try keychain.save(key: "healthDashboardAPIKey", value: "expired-key")
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)

        do {
            _ = try await client.uploadHealthData(records: [makeAPIRecord()], workouts: [])
            XCTFail("Expected authExpired error")
        } catch let error as APIError {
            guard case .authExpired = error else {
                XCTFail("Expected authExpired but got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(client.isPaired)
    }

    func testGetOrCreateDeviceIdReturnsStableValue() throws {
        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)

        let first = try client.getOrCreateDeviceId()
        let second = try client.getOrCreateDeviceId()

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
    }

    @MainActor
    func testGetLatestSyncDatesIncludesDeviceIdAndParsesResponse() async throws {
        try keychain.save(key: "healthDashboardAPIKey", value: "valid-key")

        let expectedDeviceId = "test-device-id-123"
        let heartRateTimestamp = "2026-03-04T19:11:00Z"
        let workoutTimestamp = "2026-03-04T18:00:00Z"

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/sync/latest")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "deviceId" })?.value, expectedDeviceId)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-ID"), expectedDeviceId)

            let payload: [String: Any] = [
                "latest": [
                    "HKQuantityTypeIdentifierHeartRate": heartRateTimestamp,
                    "HKWorkout": ["timestamp": workoutTimestamp]
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = APIClient(session: session, keychain: keychain, userDefaults: userDefaults)
        let timestamps = try await client.getLatestSyncDates(deviceId: expectedDeviceId)

        XCTAssertEqual(timestamps["HKQuantityTypeIdentifierHeartRate"], makeUTCDate(2026, 3, 4, 19, 11))
        XCTAssertEqual(timestamps["HKWorkout"], makeUTCDate(2026, 3, 4, 18, 0))
    }
}

final class KeychainHelperTests: XCTestCase {
    private var keysToDelete: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        try ensureKeychainAvailable()
    }

    override func tearDown() {
        for key in keysToDelete {
            try? KeychainHelper.shared.delete(key: key)
        }
        keysToDelete = []
        super.tearDown()
    }

    func testSaveAndLoadOperationsWorkCorrectly() throws {
        let key = "test-key-\(UUID().uuidString)"
        let value = "secret-value"
        keysToDelete.append(key)

        try KeychainHelper.shared.save(key: key, value: value)
        let loaded = try KeychainHelper.shared.load(key: key)

        XCTAssertEqual(loaded, value)
    }

    func testDeleteRemovesTheKey() throws {
        let key = "test-key-\(UUID().uuidString)"
        keysToDelete.append(key)

        try KeychainHelper.shared.save(key: key, value: "value")
        try KeychainHelper.shared.delete(key: key)

        XCTAssertFalse(KeychainHelper.shared.exists(key: key))
    }

    func testExistsReturnsCorrectStatus() throws {
        let key = "test-key-\(UUID().uuidString)"
        keysToDelete.append(key)

        XCTAssertFalse(KeychainHelper.shared.exists(key: key))
        try KeychainHelper.shared.save(key: key, value: "value")
        XCTAssertTrue(KeychainHelper.shared.exists(key: key))
    }

    private func ensureKeychainAvailable() throws {
        let probeKey = "keychain-probe-\(UUID().uuidString)"
        do {
            try KeychainHelper.shared.save(key: probeKey, value: "probe")
            _ = try KeychainHelper.shared.load(key: probeKey)
            try KeychainHelper.shared.delete(key: probeKey)
        } catch {
            throw XCTSkip("Keychain unavailable for tests: \(error)")
        }
    }
}

final class DateHandlingTests: XCTestCase {
    func testDatesFormatRoundTripsForAPI() {
        let date = makeUTCDate(2026, 3, 4, 19, 11)

        let formatted = APIDateCodec.format(date)
        let parsed = APIDateCodec.parse(formatted)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, date)
    }

    func testDateParsingHandlesISO8601Format() {
        let isoString = "2026-03-04T19:11:00Z"

        let parsed = APIDateCodec.parse(isoString)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, makeUTCDate(2026, 3, 4, 19, 11))
    }
}

@MainActor
private final class MockHealthDataProvider: HealthDataProviding {
    var recordsForFullExport: [HealthRecord] = []
    var workoutsForFullExport: [WorkoutRecord] = []
    var recordsForIncrementalExport: [HealthRecord] = []
    var workoutsForIncrementalExport: [WorkoutRecord] = []
    var authorizationRequestStatus: HKAuthorizationRequestStatus = .shouldRequest

    var recordsSinceDates: [Date?] = []
    var recordsPerTypeSince: [[String: Date]] = []
    var workoutsSinceDates: [Date?] = []

    func requestAuthorization() async throws {}

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        authorizationRequestStatus
    }

    func exportAllRecords(since: Date?, perTypeSince: [String: Date]) async throws -> [HealthRecord] {
        recordsSinceDates.append(since)
        recordsPerTypeSince.append(perTypeSince)
        return (since == nil && perTypeSince.isEmpty) ? recordsForFullExport : recordsForIncrementalExport
    }

    func exportAllWorkouts(since: Date?) async throws -> [WorkoutRecord] {
        workoutsSinceDates.append(since)
        return since == nil ? workoutsForFullExport : workoutsForIncrementalExport
    }
}

@MainActor
private final class MockUploadClient: HealthUploadClient {
    var responses: [UploadResponse] = []
    var uploadCalls: [(records: [APIHealthRecord], workouts: [APIWorkoutRecord])] = []
    var latestSyncDates: [String: Date] = [:]
    var latestSyncDatesError: Error?
    var requestedLatestSyncDeviceIds: [String] = []
    var deviceId = "test-device-id"
    var unpairCalled = false

    func uploadHealthData(records: [APIHealthRecord], workouts: [APIWorkoutRecord]) async throws -> UploadResponse {
        uploadCalls.append((records, workouts))
        if responses.isEmpty {
            return UploadResponse(inserted: records.count, skipped: 0, errors: [])
        }
        return responses.removeFirst()
    }

    func getOrCreateDeviceId() throws -> String {
        deviceId
    }

    func getLatestSyncDates(deviceId: String) async throws -> [String: Date] {
        requestedLatestSyncDeviceIds.append(deviceId)
        if let latestSyncDatesError {
            throw latestSyncDatesError
        }
        return latestSyncDates
    }

    func unpairDevice() {
        unpairCalled = true
    }
}

private final class InMemoryKeychain: KeychainStoring {
    private var values: [String: String] = [:]

    func save(key: String, value: String) throws {
        values[key] = value
    }

    func load(key: String) throws -> String? {
        values[key]
    }

    func delete(key: String) throws {
        values.removeValue(forKey: key)
    }

    func exists(key: String) -> Bool {
        values[key] != nil
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private let calendar = Calendar.current

private func makeLocalDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0
    return components.date!
}

private func makeUTCDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

    var components = DateComponents()
    components.calendar = utcCalendar
    components.timeZone = utcCalendar.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0
    return components.date!
}

private func makeHealthRecords(count: Int) -> [HealthRecord] {
    (0..<count).map { index in
        let start = makeUTCDate(2026, 3, 1, 0, 0).addingTimeInterval(Double(index) * 60)
        let end = start.addingTimeInterval(60)
        return HealthRecord(
            type: "HKQuantityTypeIdentifierStepCount",
            startDate: start,
            endDate: end,
            value: Double(index),
            unit: "count",
            source: "Mock"
        )
    }
}

private func makeWorkoutRecords(count: Int) -> [WorkoutRecord] {
    (0..<count).map { index in
        let start = makeUTCDate(2026, 3, 1, 0, 0).addingTimeInterval(Double(index) * 300)
        let end = start.addingTimeInterval(300)
        return WorkoutRecord(
            type: "HKWorkoutActivityTypeWalking",
            startDate: start,
            endDate: end,
            durationMinutes: 5,
            distanceMiles: 0.2,
            calories: 20,
            source: "Mock"
        )
    }
}

private func makeAPIRecord() -> APIHealthRecord {
    APIHealthRecord(
        type: "HKQuantityTypeIdentifierStepCount",
        sourceName: "Watch",
        sourceVersion: nil,
        device: nil,
        unit: "count",
        value: 100,
        startDate: "2026-03-04 10:00:00 +0000",
        endDate: "2026-03-04 10:05:00 +0000",
        creationDate: nil
    )
}

private func makeAPIWorkout() -> APIWorkoutRecord {
    APIWorkoutRecord(
        workoutType: "HKWorkoutActivityTypeRunning",
        sourceName: "Watch",
        sourceVersion: nil,
        device: nil,
        duration: 30,
        durationUnit: "min",
        totalDistance: 3,
        totalDistanceUnit: "mi",
        totalEnergy: 250,
        totalEnergyUnit: "kcal",
        startDate: "2026-03-04 09:00:00 +0000",
        endDate: "2026-03-04 09:30:00 +0000",
        creationDate: nil
    )
}
