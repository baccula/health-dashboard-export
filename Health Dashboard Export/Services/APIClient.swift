//
//  APIClient.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/25/26.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    private let defaultBaseURL = "https://health.neuwirth.cc"
    private let userDefaults: UserDefaults
    private let baseURLKey = "apiBaseURL"
    private let keychain: KeychainStoring
    private let apiKeyName = "healthDashboardAPIKey"
    private let deviceIdName = "healthDashboardDeviceId"
    private let session: URLSession
    
    var baseURL: String {
        get {
            userDefaults.string(forKey: baseURLKey) ?? defaultBaseURL
        }
        set {
            userDefaults.set(newValue, forKey: baseURLKey)
        }
    }
    
    func resetToDefaultURL() {
        userDefaults.removeObject(forKey: baseURLKey)
    }
    
    // MARK: - Error Handling
    
    /// Extract error message from API response (handles both FastAPI {detail} and custom {message} formats)
    private func extractErrorMessage(from data: Data, statusCode: Int) -> String {
        // Try FastAPI format first: {detail: "..."}
        if let fastAPIError = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: data) {
            return fastAPIError.detail
        }
        // Try custom format: {status, message}
        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return apiError.message
        }
        // Fallback
        return "Request failed with status \(statusCode)"
    }
    
    init(
        session: URLSession = .shared,
        keychain: KeychainStoring = KeychainHelper.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.keychain = keychain
        self.userDefaults = userDefaults
    }
    
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

    /// Returns a stable device identifier persisted in Keychain.
    /// This survives app reinstalls and is tied to this app's keychain access.
    func getOrCreateDeviceId() throws -> String {
        if let existing = try keychain.load(key: deviceIdName), !existing.isEmpty {
            return existing
        }

        let deviceId = UUID().uuidString.lowercased()
        try keychain.save(key: deviceIdName, value: deviceId)
        return deviceId
    }
    
    /// Unpair the device (clears API key)
    func unpairDevice() {
        try? clearAPIKey()
        print("🔓 Device unpaired")
        
        // Notify observers that pairing status changed
        NotificationCenter.default.post(name: .deviceUnpaired, object: nil)
    }
    
    // MARK: - Pairing
    
    /// Confirm a pairing code and receive an API key
    /// - Parameter code: 6-digit pairing code from dashboard
    /// - Returns: PairResponse with API key
    /// - Throws: APIError on failure
    func confirmPairingCode(_ code: String) async throws -> PairResponse {
        let url = URL(string: "\(baseURL)/api/pair/confirm")!
        print("🌐 Pairing URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body = PairConfirmRequest(code: code)
        request.httpBody = try JSONEncoder().encode(body)
        print("📤 Sending pairing request with code: \(code)")
        
        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            print("📥 Pairing response status: \(httpResponse.statusCode)")
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Raw pairing response: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                let message = extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                print("❌ Pairing failed: \(message)")
                throw APIError.pairingFailed(message)
            }
            
            let pairResponse = try JSONDecoder().decode(PairResponse.self, from: data)
            print("✓ Decoded pairing response: deviceName=\(pairResponse.deviceName)")
            
            // Save API key to Keychain
            try keychain.save(key: apiKeyName, value: pairResponse.apiKey)
            print("✓ Device paired successfully: \(pairResponse.deviceName)")
            
            return pairResponse
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Network/decoding error during pairing: \(error)")
            throw APIError.pairingFailed("Connection error: \(error.localizedDescription)")
        }
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
        let deviceId = try getOrCreateDeviceId()
        
        let url = URL(string: "\(baseURL)/api/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.timeoutInterval = 300 // 5 minutes for large uploads
        
        let uploadData = UploadData(records: records, workouts: workouts)
        let body = UploadRequest(data: uploadData)
        
        print("📦 Encoding upload data...")
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let totalSize = records.count + workouts.count
        let bodySize = request.httpBody?.count ?? 0
        let bodySizeMB = Double(bodySize) / 1_024_000
        print("📤 Uploading \(records.count) records + \(workouts.count) workouts (total: \(totalSize))")
        print("📊 Payload size: \(String(format: "%.2f", bodySizeMB)) MB")
        print("🌐 Sending to: \(baseURL)/api/upload")
        
        // Debug: Show sample of first record
        if let firstRecord = records.first {
            print("📋 Sample record: type=\(firstRecord.type), value=\(firstRecord.value ?? 0), startDate=\(firstRecord.startDate)")
        }
        
        print("⏳ Waiting for server response...")
        let (data, response) = try await performRequestWithRetry(request: request)
        let httpResponse = response as! HTTPURLResponse
        
        print("✅ Server responded with status: \(httpResponse.statusCode)")
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Raw server response: \(responseString)")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            print("✓ Upload successful: \(uploadResponse.inserted) inserted, \(uploadResponse.skipped) skipped, \(uploadResponse.errors.count) errors")
            if uploadResponse.inserted == 0 && uploadResponse.skipped == 0 && records.count > 0 {
                print("⚠️ WARNING: Server accepted data but reported 0 insertions and 0 skips")
                print("   This suggests the server may not be processing the data correctly")
            }
            return uploadResponse
            
        case 401, 403:
            // Auth expired, clear key and require re-pairing
            try? clearAPIKey()
            throw APIError.authExpired
            
        case 413:
            throw APIError.payloadTooLarge
            
        case 500:
            let message = extractErrorMessage(from: data, statusCode: 500)
            throw APIError.serverError(message)
            
        default:
            let message = extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIError.uploadFailed(message)
        }
    }
    
    // MARK: - Status

    /// Fetch latest sync timestamps from server, keyed by HealthKit type identifier.
    /// - Parameter deviceId: Stable device ID used to identify this device on server.
    /// - Returns: Dictionary of `HealthKitType -> Date` timestamps.
    func getLatestSyncDates(deviceId: String) async throws -> [String: Date] {
        guard let apiKey = getAPIKey() else {
            throw APIError.notPaired
        }

        var components = URLComponents(string: "\(baseURL)/api/sync/latest")!
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceId)
        ]
        guard let url = components.url else {
            throw APIError.requestFailed("Invalid sync latest URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        switch httpResponse.statusCode {
        case 200:
            return try parseSyncLatestDates(from: data)
        case 401, 403:
            try? clearAPIKey()
            throw APIError.authExpired
        default:
            let message = extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIError.requestFailed(message)
        }
    }
    
    // MARK: - Device Management
    
    /// List all paired devices
    /// - Returns: Array of DeviceInfo
    /// - Throws: APIError on failure
    func listDevices() async throws -> [DeviceInfo] {
        // Note: API endpoint is intentionally open (no auth required)
        let url = URL(string: "\(baseURL)/api/pair/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.requestFailed("List devices failed with status \(httpResponse.statusCode)")
        }
        
        let devicesResponse = try JSONDecoder().decode(DevicesResponse.self, from: data)
        return devicesResponse.devices
    }
    
    // MARK: - Retry Logic

    private func parseSyncLatestDates(from data: Data) throws -> [String: Date] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.requestFailed("Invalid sync latest response format")
        }

        var parsed: [String: Date] = [:]
        extractSyncDates(from: json, into: &parsed, depth: 0)
        return parsed
    }

    private func extractSyncDates(from map: [String: Any], into parsed: inout [String: Date], depth: Int) {
        guard depth <= 4 else { return }

        for (key, value) in map {
            if let normalizedKey = normalizedHealthTypeKey(key) {
                if let dateString = value as? String, let date = APIDateCodec.parse(dateString) {
                    parsed[normalizedKey] = date
                    continue
                }
                if let nested = value as? [String: Any],
                   let date = parseTimestamp(from: nested) {
                    parsed[normalizedKey] = date
                    continue
                }
            }

            if let nested = value as? [String: Any] {
                extractSyncDates(from: nested, into: &parsed, depth: depth + 1)
            }
        }
    }

    private func normalizedHealthTypeKey(_ key: String) -> String? {
        if key.hasPrefix("HK") {
            return key
        }
        if key.caseInsensitiveCompare("workout") == .orderedSame {
            return HealthDataType.workout.name
        }
        return nil
    }

    private func parseTimestamp(from map: [String: Any]) -> Date? {
        let timestampKeys = ["timestamp", "latest", "lastSync", "date"]
        for key in timestampKeys {
            if let rawValue = map[key] as? String, let date = APIDateCodec.parse(rawValue) {
                return date
            }
        }
        return nil
    }
    
    /// Perform a request with exponential backoff retry (max 3 attempts)
    /// - Parameter request: URLRequest to execute
    /// - Returns: Tuple of (Data, URLResponse)
    /// - Throws: Error from last attempt
    private func performRequestWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        let maxAttempts = 3
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                print("🔄 Network request attempt \(attempt)/\(maxAttempts)...")
                let startTime = Date()
                let result = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startTime)
                print("✓ Request completed in \(String(format: "%.1f", elapsed))s")
                return result
            } catch {
                lastError = error
                print("❌ Request failed: \(error.localizedDescription)")
                
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
        
        print("💥 All retry attempts exhausted")
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

// MARK: - Notifications

extension Notification.Name {
    static let deviceUnpaired = Notification.Name("deviceUnpaired")
}
