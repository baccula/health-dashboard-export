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
class HealthExporter: ObservableObject {
    private let healthStore = HKHealthStore()
    private let apiClient = APIClient.shared

    @Published var isAuthorized = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportProgressText: String = ""
    @Published var lastSyncDate: Date?
    @Published var totalRecords: Int = 0
    @Published var errorMessage: String?

    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastSyncDate"
    private let totalRecordsKey = "totalRecords"

    static let syncStateDidChangeNotification = Notification.Name("HealthExporterSyncStateDidChange")
    
    // Date formatter for API spec format: "yyyy-MM-dd HH:mm:ss Z"
    private lazy var apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    init() {
        loadSyncState()

        // Listen for sync state changes from other instances
        NotificationCenter.default.addObserver(
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
        if let lastSync = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = lastSync
        }
        totalRecords = userDefaults.integer(forKey: totalRecordsKey)
    }
    
    private func saveSyncState() {
        if let lastSync = lastSyncDate {
            userDefaults.set(lastSync, forKey: lastSyncKey)
        }
        userDefaults.set(totalRecords, forKey: totalRecordsKey)

        // Notify other instances that sync state has changed
        NotificationCenter.default.post(
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
        
        print("✓ All sync data cleared")
    }
    
    // MARK: - HealthKit Authorization
    
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
            // Export all data from the beginning of time
            let hkRecords = try await exportAllRecords()
            let hkWorkouts = try await exportAllWorkouts()
            
            // Transform to API format
            let apiRecords = transformRecordsToAPIFormat(hkRecords)
            let apiWorkouts = transformWorkoutsToAPIFormat(hkWorkouts)
            
            // Upload to API
            exportProgressText = "Uploading to dashboard..."
            exportProgress = 0.95
            
            let response = try await apiClient.uploadHealthData(
                records: apiRecords,
                workouts: apiWorkouts
            )
            
            // Update sync state
            lastSyncDate = Date()
            totalRecords = response.records.imported + response.workouts.imported
            saveSyncState()
            
            print("✓ Full export completed via API")
            print("✓ Uploaded \(apiRecords.count) records + \(apiWorkouts.count) workouts")
            print("✓ Imported \(response.records.imported) records + \(response.workouts.imported) workouts")
            if response.records.skipped_duplicate > 0 || response.workouts.skipped_duplicate > 0 {
                print("  ℹ️ Skipped \(response.records.skipped_duplicate) duplicate records + \(response.workouts.skipped_duplicate) duplicate workouts")
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
            // If no previous sync, perform full export instead
            guard let sinceDate = lastSyncDate else {
                print("⚠️ No previous sync found, performing full export...")
                try await performFullExport()
                return
            }
            
            // Export only new data since last sync
            let hkRecords = try await exportAllRecords(since: sinceDate)
            let hkWorkouts = try await exportAllWorkouts(since: sinceDate)
            
            // Transform to API format
            let apiRecords = transformRecordsToAPIFormat(hkRecords)
            let apiWorkouts = transformWorkoutsToAPIFormat(hkWorkouts)
            
            // Upload to API
            exportProgressText = "Uploading to dashboard..."
            exportProgress = 0.95
            
            let response = try await apiClient.uploadHealthData(
                records: apiRecords,
                workouts: apiWorkouts
            )
            
            // Update sync state
            lastSyncDate = Date()
            totalRecords += response.records.imported + response.workouts.imported
            saveSyncState()
            
            print("✓ Incremental sync completed via API")
            print("✓ Uploaded \(apiRecords.count) new records + \(apiWorkouts.count) new workouts since \(sinceDate)")
            print("✓ Imported \(response.records.imported) records + \(response.workouts.imported) workouts")
            if response.records.skipped_duplicate > 0 || response.workouts.skipped_duplicate > 0 {
                print("  ℹ️ Skipped \(response.records.skipped_duplicate) duplicate records + \(response.workouts.skipped_duplicate) duplicate workouts")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("✗ Sync failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Export
    
    private func exportAllRecords(since: Date? = nil) async throws -> [HealthRecord] {
        var allRecords: [HealthRecord] = []
        let types = HealthDataType.quantityTypes
        
        for (index, type) in types.enumerated() {
            exportProgress = Double(index) / Double(types.count) * 0.8 // 80% of progress for quantity types
            exportProgressText = "Exporting \(allRecords.count) records..."
            
            guard case .quantity(let identifier) = type else { continue }
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            
            let records = try await queryQuantitySamples(for: quantityType, since: since)
            allRecords.append(contentsOf: records)
        }
        
        exportProgress = 0.8
        exportProgressText = "Exporting \(allRecords.count) records..."
        
        // Export category types
        let categoryTypes = HealthDataType.categoryTypes
        for type in categoryTypes {
            guard case .category(let identifier) = type else { continue }
            guard let categoryType = HKCategoryType.categoryType(forIdentifier: identifier) else { continue }
            
            let records = try await queryCategorySamples(for: categoryType, since: since)
            allRecords.append(contentsOf: records)
        }
        
        exportProgress = 0.9
        exportProgressText = "Exporting \(allRecords.count) records..."
        
        return allRecords
    }
    
    private func exportAllWorkouts(since: Date? = nil) async throws -> [WorkoutRecord] {
        exportProgress = 0.9
        exportProgressText = "Exporting workouts..."
        let workouts = try await queryWorkouts(since: since)
        exportProgress = 1.0
        exportProgressText = "Export complete"
        return workouts
    }
    
    // MARK: - HealthKit Queries
    
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
    
    // MARK: - Unit Helpers
    
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
    
    // MARK: - API Data Transformation
    
    /// Transform HealthKit records to API format
    private func transformRecordsToAPIFormat(_ records: [HealthRecord]) -> [APIHealthRecord] {
        return records.map { record in
            APIHealthRecord(
                type: record.type,
                sourceName: record.source,
                sourceVersion: nil, // Not available in HealthRecord model
                device: nil, // Not available in HealthRecord model
                unit: record.unit,
                value: record.value,
                startDate: apiDateFormatter.string(from: record.startDate),
                endDate: apiDateFormatter.string(from: record.endDate),
                creationDate: nil // Not tracked in current model
            )
        }
    }
    
    /// Transform HealthKit workouts to API format
    private func transformWorkoutsToAPIFormat(_ workouts: [WorkoutRecord]) -> [APIWorkoutRecord] {
        return workouts.map { workout in
            APIWorkoutRecord(
                workoutType: workout.type,
                sourceName: workout.source,
                sourceVersion: nil, // Not available in WorkoutRecord model
                device: nil, // Not available in WorkoutRecord model
                duration: workout.durationMinutes,
                durationUnit: "min",
                totalDistance: workout.distanceMiles,
                totalDistanceUnit: "mi",
                totalEnergy: workout.calories,
                totalEnergyUnit: "kcal",
                startDate: apiDateFormatter.string(from: workout.startDate),
                endDate: apiDateFormatter.string(from: workout.endDate),
                creationDate: nil // Not tracked in current model
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
