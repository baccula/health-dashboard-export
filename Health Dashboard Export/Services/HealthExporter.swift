//
//  HealthExporter.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
protocol HealthUploadClient {
    func uploadHealthData(records: [APIHealthRecord], workouts: [APIWorkoutRecord]) async throws -> UploadResponse
    func unpairDevice()
}

extension APIClient: HealthUploadClient {}

@MainActor
protocol HealthDataProviding {
    func requestAuthorization() async throws
    func exportAllRecords(since: Date?) async throws -> [HealthRecord]
    func exportAllWorkouts(since: Date?) async throws -> [WorkoutRecord]
}

@MainActor
final class HealthKitDataProvider: HealthDataProviding {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthExportError.healthKitNotAvailable
        }

        let typesToRead = Set(HealthDataType.allTypes.compactMap { type -> HKSampleType? in
            switch type {
            case .quantity(let identifier):
                return HKQuantityType(identifier)
            case .category(let identifier):
                return HKCategoryType(identifier)
            case .workout:
                return HKWorkoutType.workoutType()
            }
        })

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    func exportAllRecords(since: Date? = nil) async throws -> [HealthRecord] {
        var allRecords: [HealthRecord] = []
        let types = HealthDataType.quantityTypes

        for type in types {
            guard case .quantity(let identifier) = type else { continue }
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

            let records = try await queryQuantitySamples(for: quantityType, since: since)
            allRecords.append(contentsOf: records)
        }

        let categoryTypes = HealthDataType.categoryTypes
        for type in categoryTypes {
            guard case .category(let identifier) = type else { continue }
            guard let categoryType = HKCategoryType.categoryType(forIdentifier: identifier) else { continue }

            let records = try await queryCategorySamples(for: categoryType, since: since)
            allRecords.append(contentsOf: records)
        }

        return allRecords
    }

    func exportAllWorkouts(since: Date? = nil) async throws -> [WorkoutRecord] {
        return try await queryWorkouts(since: since)
    }

    private func queryQuantitySamples(for type: HKQuantityType, since: Date?) async throws -> [HealthRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let since = since {
                predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
            }

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = quantitySamples.map { sample in
                    let unit = self.preferredUnit(for: type)
                    let value = sample.quantity.doubleValue(for: unit)

                    return HealthRecord(
                        type: type.identifier,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        value: value,
                        unit: unit.unitString,
                        source: sample.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    private func queryCategorySamples(for type: HKCategoryType, since: Date?) async throws -> [HealthRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let since = since {
                predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
            }

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = categorySamples.map { sample in
                    HealthRecord(
                        type: type.identifier,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        value: Double(sample.value),
                        unit: "category",
                        source: sample.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    private func queryWorkouts(since: Date?) async throws -> [WorkoutRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let since = since {
                predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
            }

            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let records = workouts.map { workout in
                    let durationMinutes = workout.duration / 60.0

                    var distanceMiles: Double?
                    if let distance = workout.totalDistance {
                        distanceMiles = distance.doubleValue(for: .mile())
                    }

                    var calories: Double?
                    if let energy = workout.totalEnergyBurned {
                        calories = energy.doubleValue(for: .kilocalorie())
                    }

                    return WorkoutRecord(
                        type: workout.workoutActivityType.name,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        durationMinutes: durationMinutes,
                        distanceMiles: distanceMiles,
                        calories: calories,
                        source: workout.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: records)
            }

            healthStore.execute(query)
        }
    }

    private func preferredUnit(for type: HKQuantityType) -> HKUnit {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())

        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return .secondUnit(with: .milli)

        case HKQuantityTypeIdentifier.vo2Max.rawValue:
            return HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute())

        case HKQuantityTypeIdentifier.bodyMass.rawValue,
             HKQuantityTypeIdentifier.leanBodyMass.rawValue:
            return .pound()

        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            return .percent()

        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .kilocalorie()

        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()

        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            return .mile()

        case HKQuantityTypeIdentifier.flightsClimbed.rawValue:
            return .count()

        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .millimeterOfMercury()

        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .percent()

        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())

        default:
            return .count()
        }
    }
}

@MainActor
class HealthExporter: ObservableObject {
    @Published var isAuthorized = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportProgressText: String = ""
    @Published var lastSyncDate: Date?
    @Published var totalRecords: Int = 0
    @Published var errorMessage: String?

    private let apiClient: HealthUploadClient
    private let dataProvider: HealthDataProviding
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let nowProvider: () -> Date

    private let lastSyncKey = "lastSyncDate"
    private let totalRecordsKey = "totalRecords"

    static let syncStateDidChangeNotification = Notification.Name("HealthExporterSyncStateDidChange")

    init(
        apiClient: HealthUploadClient = APIClient.shared,
        dataProvider: HealthDataProviding? = nil,
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.apiClient = apiClient
        self.dataProvider = dataProvider ?? HealthKitDataProvider()
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.nowProvider = nowProvider

        loadSyncState()

        notificationCenter.addObserver(
            self,
            selector: #selector(handleSyncStateChange),
            name: HealthExporter.syncStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleSyncStateChange() {
        loadSyncState()
    }

    // MARK: - Sync State Management

    private func loadSyncState() {
        lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
        totalRecords = userDefaults.object(forKey: totalRecordsKey) as? Int ?? 0
    }

    private func saveSyncState() {
        if let lastSync = lastSyncDate {
            userDefaults.set(lastSync, forKey: lastSyncKey)
        } else {
            userDefaults.removeObject(forKey: lastSyncKey)
        }
        userDefaults.set(totalRecords, forKey: totalRecordsKey)

        notificationCenter.post(
            name: HealthExporter.syncStateDidChangeNotification,
            object: nil
        )
    }

    func clearAllData() {
        lastSyncDate = nil
        totalRecords = 0
        exportProgress = 0.0
        exportProgressText = ""

        userDefaults.removeObject(forKey: lastSyncKey)
        userDefaults.removeObject(forKey: totalRecordsKey)

        apiClient.unpairDevice()

        print("✓ All sync data cleared and device unpaired")
    }

    // MARK: - HealthKit Authorization

    func requestAuthorization() async throws {
        try await dataProvider.requestAuthorization()
        isAuthorized = true
    }

    // MARK: - Full Export

    func performFullExport() async throws {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil

        defer {
            isExporting = false
        }

        do {
            exportProgressText = "Exporting records..."
            let hkRecords = try await dataProvider.exportAllRecords(since: nil)

            exportProgress = 0.9
            exportProgressText = "Exporting workouts..."
            let hkWorkouts = try await dataProvider.exportAllWorkouts(since: nil)

            let apiRecords = transformRecordsToAPIFormat(hkRecords)
            let apiWorkouts = transformWorkoutsToAPIFormat(hkWorkouts)

            let uploadedCounts = try await uploadInChunks(
                records: apiRecords,
                workouts: apiWorkouts
            )

            lastSyncDate = nowProvider()
            totalRecords = uploadedCounts.recordsImported + uploadedCounts.workoutsImported
            saveSyncState()

            print("✓ Full export completed via API")
            print("✓ Uploaded \(apiRecords.count) records + \(apiWorkouts.count) workouts")
            print("✓ Imported \(uploadedCounts.recordsImported) records (combined)")
            if uploadedCounts.recordsSkipped > 0 {
                print("  ℹ️ Skipped \(uploadedCounts.recordsSkipped) duplicates (combined)")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("✗ Export failed: \(error)")
            throw error
        }
    }

    // MARK: - Incremental Sync

    func performIncrementalSync() async throws {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil

        defer {
            isExporting = false
        }

        do {
            guard let sinceDate = lastSyncDate else {
                print("⚠️ No previous sync found, performing full export...")
                try await performFullExport()
                return
            }

            exportProgressText = "Exporting records..."
            let hkRecords = try await dataProvider.exportAllRecords(since: sinceDate)

            exportProgress = 0.9
            exportProgressText = "Exporting workouts..."
            let hkWorkouts = try await dataProvider.exportAllWorkouts(since: sinceDate)

            let apiRecords = transformRecordsToAPIFormat(hkRecords)
            let apiWorkouts = transformWorkoutsToAPIFormat(hkWorkouts)

            let uploadedCounts = try await uploadInChunks(
                records: apiRecords,
                workouts: apiWorkouts
            )

            lastSyncDate = nowProvider()
            totalRecords += uploadedCounts.recordsImported + uploadedCounts.workoutsImported
            saveSyncState()

            print("✓ Incremental sync completed via API")
            print("✓ Uploaded \(apiRecords.count) new records + \(apiWorkouts.count) new workouts since \(sinceDate)")
            print("✓ Imported \(uploadedCounts.recordsImported) records (combined)")
            if uploadedCounts.recordsSkipped > 0 {
                print("  ℹ️ Skipped \(uploadedCounts.recordsSkipped) duplicates (combined)")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("✗ Sync failed: \(error)")
            throw error
        }
    }

    // MARK: - Chunked Upload

    private struct UploadCounts {
        var recordsImported: Int = 0
        var recordsSkipped: Int = 0
        var workoutsImported: Int = 0
        var workoutsSkipped: Int = 0
    }

    private func uploadInChunks(
        records: [APIHealthRecord],
        workouts: [APIWorkoutRecord]
    ) async throws -> UploadCounts {
        let chunkSize = 10_000
        var counts = UploadCounts()

        let totalRecords = records.count
        let totalWorkouts = workouts.count
        let recordChunks = stride(from: 0, to: totalRecords, by: chunkSize).map {
            Array(records[$0..<min($0 + chunkSize, totalRecords)])
        }
        let workoutChunks = stride(from: 0, to: totalWorkouts, by: chunkSize).map {
            Array(workouts[$0..<min($0 + chunkSize, totalWorkouts)])
        }

        let totalChunks = max(recordChunks.count, workoutChunks.count)

        print("📦 Uploading data in \(totalChunks) chunk(s) (\(chunkSize) items per chunk)")
        print("   Records: \(totalRecords) in \(recordChunks.count) chunk(s)")
        print("   Workouts: \(totalWorkouts) in \(workoutChunks.count) chunk(s)")

        for chunkIndex in 0..<totalChunks {
            let recordChunk = chunkIndex < recordChunks.count ? recordChunks[chunkIndex] : []
            let workoutChunk = chunkIndex < workoutChunks.count ? workoutChunks[chunkIndex] : []

            exportProgressText = "Uploading chunk \(chunkIndex + 1) of \(totalChunks)..."
            exportProgress = 0.9 + (0.1 * Double(chunkIndex) / Double(totalChunks))

            print("📤 Uploading chunk \(chunkIndex + 1)/\(totalChunks): \(recordChunk.count) records + \(workoutChunk.count) workouts")

            let response = try await apiClient.uploadHealthData(
                records: recordChunk,
                workouts: workoutChunk
            )

            counts.recordsImported += response.total.imported
            counts.recordsSkipped += response.total.skipped_duplicate
            counts.workoutsImported += 0
            counts.workoutsSkipped += 0

            print("   ✓ Chunk \(chunkIndex + 1) imported: \(response.total.imported) records (combined)")
        }

        exportProgressText = "Upload complete"
        exportProgress = 1.0

        return counts
    }

    // MARK: - API Data Transformation

    private func transformRecordsToAPIFormat(_ records: [HealthRecord]) -> [APIHealthRecord] {
        return records.map { record in
            APIHealthRecord(
                type: record.type,
                sourceName: record.source,
                sourceVersion: nil,
                device: nil,
                unit: record.unit,
                value: record.value,
                startDate: APIDateCodec.format(record.startDate),
                endDate: APIDateCodec.format(record.endDate),
                creationDate: nil
            )
        }
    }

    private func transformWorkoutsToAPIFormat(_ workouts: [WorkoutRecord]) -> [APIWorkoutRecord] {
        return workouts.map { workout in
            APIWorkoutRecord(
                workoutType: workout.type,
                sourceName: workout.source,
                sourceVersion: nil,
                device: nil,
                duration: workout.durationMinutes,
                durationUnit: "min",
                totalDistance: workout.distanceMiles,
                totalDistanceUnit: "mi",
                totalEnergy: workout.calories,
                totalEnergyUnit: "kcal",
                startDate: APIDateCodec.format(workout.startDate),
                endDate: APIDateCodec.format(workout.endDate),
                creationDate: nil
            )
        }
    }
}

// MARK: - Errors

enum HealthExportError: LocalizedError {
    case healthKitNotAvailable
    case storageNotAvailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .storageNotAvailable:
            return "Local storage is not available."
        case .authorizationDenied:
            return "HealthKit authorization was denied. Please enable in Settings."
        }
    }
}

enum APIDateCodec {
    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601FractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func format(_ date: Date) -> String {
        apiFormatter.string(from: date)
    }

    static func parse(_ string: String) -> Date? {
        if let date = iso8601FractionalSecondsFormatter.date(from: string) {
            return date
        }
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        return apiFormatter.date(from: string)
    }
}

// MARK: - Extensions

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "HKWorkoutActivityTypeRunning"
        case .cycling: return "HKWorkoutActivityTypeCycling"
        case .walking: return "HKWorkoutActivityTypeWalking"
        case .swimming: return "HKWorkoutActivityTypeSwimming"
        case .yoga: return "HKWorkoutActivityTypeYoga"
        case .functionalStrengthTraining: return "HKWorkoutActivityTypeFunctionalStrengthTraining"
        case .traditionalStrengthTraining: return "HKWorkoutActivityTypeTraditionalStrengthTraining"
        case .elliptical: return "HKWorkoutActivityTypeElliptical"
        case .rowing: return "HKWorkoutActivityTypeRowing"
        case .hiking: return "HKWorkoutActivityTypeHiking"
        default: return "HKWorkoutActivityTypeOther"
        }
    }
}
