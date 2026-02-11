//
//  HealthRecord.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/11/26.
//

import Foundation
import HealthKit

// MARK: - Health Record Models

struct HealthRecord: Codable {
    let type: String
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case startDate = "start_date"
        case endDate = "end_date"
        case value
        case unit
        case source
    }
}

struct WorkoutRecord: Codable {
    let type: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Double
    let distanceMiles: Double?
    let calories: Double?
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case startDate = "start_date"
        case endDate = "end_date"
        case durationMinutes = "duration_minutes"
        case distanceMiles = "distance_miles"
        case calories
        case source
    }
}

struct HealthExportData: Codable {
    let exportDate: Date
    let device: String
    let records: [HealthRecord]
    let workouts: [WorkoutRecord]
    
    enum CodingKeys: String, CodingKey {
        case exportDate = "export_date"
        case device
        case records
        case workouts
    }
}

// MARK: - Health Data Type Definitions

enum HealthDataType {
    case quantity(HKQuantityTypeIdentifier)
    case category(HKCategoryTypeIdentifier)
    case workout
    
    var name: String {
        switch self {
        case .quantity(let identifier):
            return identifier.rawValue
        case .category(let identifier):
            return identifier.rawValue
        case .workout:
            return "HKWorkout"
        }
    }
    
    static var allTypes: [HealthDataType] {
        return quantityTypes + categoryTypes + [.workout]
    }
    
    static var quantityTypes: [HealthDataType] {
        return [
            .quantity(.heartRate),
            .quantity(.restingHeartRate),
            .quantity(.heartRateVariabilitySDNN),
            .quantity(.vo2Max),
            .quantity(.bodyMass),
            .quantity(.bodyFatPercentage),
            .quantity(.leanBodyMass),
            .quantity(.activeEnergyBurned),
            .quantity(.basalEnergyBurned),
            .quantity(.stepCount),
            .quantity(.distanceWalkingRunning),
            .quantity(.flightsClimbed),
            .quantity(.bloodPressureSystolic),
            .quantity(.bloodPressureDiastolic),
            .quantity(.bloodGlucose),
            .quantity(.oxygenSaturation),
            .quantity(.respiratoryRate)
        ]
    }
    
    static var categoryTypes: [HealthDataType] {
        return [
            .category(.sleepAnalysis),
            .category(.appleStandHour)
        ]
    }
}
