//
//  APIModels.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/25/26.
//

import Foundation

// MARK: - Pairing Models

struct PairConfirmRequest: Codable {
    let code: String
}

struct PairResponse: Codable {
    let apiKey: String
    let deviceName: String
    let createdAt: String
}

struct DeviceInfo: Codable, Identifiable {
    let id: String
    let deviceName: String
    let createdAt: String
    let lastUsed: String?
}

struct DevicesResponse: Codable {
    let devices: [DeviceInfo]
}

// MARK: - Upload Models

struct UploadRequest: Codable {
    let data: UploadData
}

struct UploadData: Codable {
    let records: [APIHealthRecord]
    let workouts: [APIWorkoutRecord]
}

struct APIHealthRecord: Codable {
    let type: String
    let sourceName: String?
    let sourceVersion: String?
    let device: String?
    let unit: String?
    let value: Double?
    let startDate: String
    let endDate: String
    let creationDate: String?
}

struct APIWorkoutRecord: Codable {
    let workoutType: String
    let sourceName: String?
    let sourceVersion: String?
    let device: String?
    let duration: Double?
    let durationUnit: String?
    let totalDistance: Double?
    let totalDistanceUnit: String?
    let totalEnergy: Double?
    let totalEnergyUnit: String?
    let startDate: String
    let endDate: String
    let creationDate: String?
}

struct UploadResponse: Codable {
    let inserted: Int
    let skipped: Int
    let errors: [String]  // Combined count for records and workouts
    
    // Aggregate stats for display (API returns combined counts)
    var total: UploadStats {
        UploadStats(received: inserted + skipped, imported: inserted, skipped_duplicate: skipped, errors: errors.count)
    }
}

struct UploadStats: Codable {
    let received: Int
    let imported: Int
    let skipped_duplicate: Int
    let errors: Int
}

// MARK: - Error Models

struct APIErrorResponse: Codable {
    let status: String
    let message: String
}
