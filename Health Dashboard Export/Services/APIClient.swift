//
//  APIClient.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/25/26.
//

import Foundation

@MainActor
class APIClient {
    static let shared = APIClient()
    
    let baseURL = "https://health.neuwirth.cc"
    private let keychain = KeychainHelper.shared
    private let apiKeyName = "healthDashboardAPIKey"
    
    private init() {}
    
    // MARK: - Authentication
    
    /// Get the stored API key from Keychain
    /// - Returns: API key if stored, nil otherwise
    func getAPIKey() -> String? {
        return try? keychain.load(key: apiKeyName)
    }
    
    /// Check if device is paired (has valid API key)
    var isPaired: Bool {
        keychain.exists(key: apiKeyName)
    }
    
    /// Clear the stored API key (for re-pairing)
    func clearAPIKey() throws {
        try keychain.delete(key: apiKeyName)
    }
    
    // MARK: - Pairing
    
    /// Confirm a pairing code and receive an API key
    /// - Parameter code: 6-digit pairing code from dashboard
    /// - Returns: PairResponse with API key
    /// - Throws: APIError on failure
    func confirmPairingCode(_ code: String) async throws -> PairResponse {
        let url = URL(string: "\(baseURL)/api/pair/confirm")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body = PairConfirmRequest(code: code)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = errorResponse?.message ?? "Pairing failed with status \(httpResponse.statusCode)"
            throw APIError.pairingFailed(message)
        }
        
        let pairResponse = try JSONDecoder().decode(PairResponse.self, from: data)
        
        // Save API key to Keychain
        try keychain.save(key: apiKeyName, value: pairResponse.apiKey)
        print("✓ Device paired successfully: \(pairResponse.deviceName)")
        
        return pairResponse
    }
    
    // MARK: - Upload
    
    /// Upload health records and workouts to the dashboard
    /// - Parameters:
    ///   - records: Array of health records in API format
    ///   - workouts: Array of workout records in API format
    /// - Returns: UploadResponse with import stats
    /// - Throws: APIError on failure
    func uploadHealthData(records: [APIHealthRecord], workouts: [APIWorkoutRecord]) async throws -> UploadResponse {
        guard let apiKey = getAPIKey() else {
            throw APIError.notPaired
        }
        
        let url = URL(string: "\(baseURL)/api/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Upload can take longer
        
        let uploadData = UploadData(records: records, workouts: workouts)
        let body = UploadRequest(data: uploadData)
        request.httpBody = try JSONEncoder().encode(body)
        
        let totalSize = records.count + workouts.count
        print("📤 Uploading \(records.count) records + \(workouts.count) workouts (total: \(totalSize))")
        
        let (data, response) = try await performRequestWithRetry(request: request)
        let httpResponse = response as! HTTPURLResponse
        
        switch httpResponse.statusCode {
        case 200:
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            print("✓ Upload successful: \(uploadResponse.records.imported) records, \(uploadResponse.workouts.imported) workouts imported")
            return uploadResponse
            
        case 401, 403:
            // Auth expired, clear key and require re-pairing
            try? clearAPIKey()
            throw APIError.authExpired
            
        case 413:
            throw APIError.payloadTooLarge
            
        case 500:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = errorResponse?.message ?? "Server error"
            throw APIError.serverError(message)
            
        default:
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = errorResponse?.message ?? "Upload failed with status \(httpResponse.statusCode)"
            throw APIError.uploadFailed(message)
        }
    }
    
    // MARK: - Status
    
    /// Get upload status and server stats
    /// - Returns: UploadStatusResponse with last upload time and record counts
    /// - Throws: APIError on failure
    func getUploadStatus() async throws -> UploadStatusResponse {
        guard let apiKey = getAPIKey() else {
            throw APIError.notPaired
        }
        
        let url = URL(string: "\(baseURL)/api/upload/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                try? clearAPIKey()
                throw APIError.authExpired
            }
            throw APIError.requestFailed("Status check failed with status \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(UploadStatusResponse.self, from: data)
    }
    
    // MARK: - Device Management
    
    /// List all paired devices
    /// - Returns: Array of DeviceInfo
    /// - Throws: APIError on failure
    func listDevices() async throws -> [DeviceInfo] {
        guard let apiKey = getAPIKey() else {
            throw APIError.notPaired
        }
        
        let url = URL(string: "\(baseURL)/api/pair/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                try? clearAPIKey()
                throw APIError.authExpired
            }
            throw APIError.requestFailed("List devices failed with status \(httpResponse.statusCode)")
        }
        
        let devicesResponse = try JSONDecoder().decode(DevicesResponse.self, from: data)
        return devicesResponse.devices
    }
    
    /// Revoke a paired device
    /// - Parameter deviceId: Device ID to revoke
    /// - Throws: APIError on failure
    func revokeDevice(_ deviceId: String) async throws {
        guard let apiKey = getAPIKey() else {
            throw APIError.notPaired
        }
        
        let url = URL(string: "\(baseURL)/api/pair/devices/\(deviceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                try? clearAPIKey()
                throw APIError.authExpired
            }
            throw APIError.requestFailed("Revoke device failed with status \(httpResponse.statusCode)")
        }
        
        print("✓ Device \(deviceId) revoked")
    }
    
    // MARK: - Retry Logic
    
    /// Perform a request with exponential backoff retry (max 3 attempts)
    /// - Parameter request: URLRequest to execute
    /// - Returns: Tuple of (Data, URLResponse)
    /// - Throws: Error from last attempt
    private func performRequestWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        let maxAttempts = 3
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await URLSession.shared.data(for: request)
            } catch {
                lastError = error
                
                // Don't retry on last attempt
                if attempt == maxAttempts {
                    break
                }
                
                // Exponential backoff: 1s, 2s, 4s
                let delay = Double(1 << (attempt - 1))
                print("⚠️ Request failed (attempt \(attempt)/\(maxAttempts)), retrying in \(delay)s...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? APIError.networkError
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case notPaired
    case pairingFailed(String)
    case authExpired
    case payloadTooLarge
    case serverError(String)
    case uploadFailed(String)
    case requestFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notPaired:
            return "Device not paired. Please enter a pairing code."
        case .pairingFailed(let message):
            return message
        case .authExpired:
            return "API key expired. Please pair your device again."
        case .payloadTooLarge:
            return "Upload too large. Please try incremental sync instead of full export."
        case .serverError(let message):
            return "Server error: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .requestFailed(let message):
            return message
        case .networkError:
            return "Network error. Please check your connection to health.neuwirth.cc"
        }
    }
}
