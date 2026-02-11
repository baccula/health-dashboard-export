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
    
    @Published var isAuthorized = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportProgressText: String = ""
    @Published var lastSyncDate: Date?
    @Published var totalRecords: Int = 0
    @Published var errorMessage: String?
    @Published var lastExportedFileURL: URL?
    @Published var saveLocationURL: URL?
    
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastSyncDate"
    private let totalRecordsKey = "totalRecords"
    private let saveLocationKey = "saveLocationBookmark"
    
    init() {
        loadSyncState()
    }
    
    // MARK: - Sync State Management
    
    private func loadSyncState() {
        if let lastSync = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = lastSync
        }
        totalRecords = userDefaults.integer(forKey: totalRecordsKey)
        
        // Load saved location bookmark
        if let bookmarkData = userDefaults.data(forKey: saveLocationKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) {
                if !isStale {
                    saveLocationURL = url
                }
            }
        }
    }
    
    private func saveSyncState() {
        if let lastSync = lastSyncDate {
            userDefaults.set(lastSync, forKey: lastSyncKey)
        }
        userDefaults.set(totalRecords, forKey: totalRecordsKey)
        
        // Save location bookmark
        if let url = saveLocationURL {
            if let bookmarkData = try? url.bookmarkData(options: .minimalBookmark) {
                userDefaults.set(bookmarkData, forKey: saveLocationKey)
            }
        }
    }
    
    func setSaveLocation(_ url: URL) {
        saveLocationURL = url
        saveSyncState()
    }
    
    func clearAllData() {
        lastSyncDate = nil
        totalRecords = 0
        lastExportedFileURL = nil
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
            let records = try await exportAllRecords()
            let workouts = try await exportAllWorkouts()
            
            // Create export data structure
            let exportData = HealthExportData(
                exportDate: Date(),
                device: await UIDevice.current.name,
                records: records,
                workouts: workouts
            )
            
            // Write to local storage
            let fileURL = try await writeToiCloud(exportData: exportData, isFullExport: true)
            
            // Update sync state
            lastSyncDate = Date()
            totalRecords = records.count + workouts.count
            lastExportedFileURL = fileURL
            saveSyncState()
            
            print("✓ Full export completed: \(fileURL.path)")
            print("✓ Exported \(records.count) records and \(workouts.count) workouts")
            print("✓ File location: \(fileURL.absoluteString)")
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
            let records = try await exportAllRecords(since: sinceDate)
            let workouts = try await exportAllWorkouts(since: sinceDate)
            
            // Create export data structure
            let exportData = HealthExportData(
                exportDate: Date(),
                device: await UIDevice.current.name,
                records: records,
                workouts: workouts
            )
            
            // Write to local storage
            let fileURL = try await writeToiCloud(exportData: exportData, isFullExport: false)
            
            // Update sync state
            lastSyncDate = Date()
            totalRecords += records.count + workouts.count
            lastExportedFileURL = fileURL
            saveSyncState()
            
            print("✓ Incremental sync completed: \(fileURL.path)")
            print("✓ Exported \(records.count) new records and \(workouts.count) new workouts since \(sinceDate)")
            print("✓ File location: \(fileURL.absoluteString)")
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
    
    // MARK: - Storage Export
    
    func prepareExportData(isFullExport: Bool) async throws -> (Data, String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Export data
        let records = try await exportAllRecords(since: isFullExport ? nil : lastSyncDate)
        let workouts = try await exportAllWorkouts(since: isFullExport ? nil : lastSyncDate)
        
        let exportData = HealthExportData(
            exportDate: Date(),
            device: await UIDevice.current.name,
            records: records,
            workouts: workouts
        )
        
        let jsonData = try encoder.encode(exportData)
        
        // Create filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = isFullExport
            ? "health-export-full-\(dateString).json"
            : "health-export-delta-\(dateString).json"
        
        return (jsonData, filename)
    }
    
    private func writeToiCloud(exportData: HealthExportData, isFullExport: Bool) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        
        // Use custom save location if set, otherwise use default
        let exportURL: URL
        if let customLocation = saveLocationURL {
            exportURL = customLocation
            print("✓ Using custom save location: \(customLocation.path)")
        } else if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("HealthExport") {
            exportURL = iCloudURL
            print("✓ Using iCloud Drive storage")
        } else {
            // Fallback to local Documents directory
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw HealthExportError.storageNotAvailable
            }
            exportURL = documentsURL.appendingPathComponent("HealthExport")
            print("⚠️ Using local storage")
        }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        
        // Create filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = isFullExport
            ? "health-export-full-\(dateString).json"
            : "health-export-delta-\(dateString).json"
        
        let fileURL = exportURL.appendingPathComponent(filename)
        
        // Write file
        try jsonData.write(to: fileURL)
        
        return fileURL
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
