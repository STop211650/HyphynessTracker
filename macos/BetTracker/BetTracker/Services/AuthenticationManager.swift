import Foundation
import Security

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUserEmail: String?
    
    private let keychainService = "com.bettracker.auth"
    private let keychainAccount = "supabase-auth-token"
    private var supabaseURL: String { Config.supabaseURL }
    private var supabaseAnonKey: String { Config.supabaseAnonKey }
    
    private init() {
        // Check for existing auth token on launch
        if let token = getStoredAuthToken() {
            // Validate token expiration
            if isTokenValid(token) {
                isAuthenticated = true
            } else {
                // Token expired, clean up
                signOut()
            }
        }
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String) async throws -> String {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Store auth token in Keychain
            try storeAuthToken(authResponse.access_token)
            
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUserEmail = email
            }
            
            return authResponse.access_token
        } else {
            let errorData = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.authenticationFailed(errorData?.msg ?? "Authentication failed")
        }
    }
    
    // Sign out
    func signOut() {
        deleteAuthToken()
        isAuthenticated = false
        currentUserEmail = nil
    }
    
    // Get stored auth token
    func getStoredAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        return nil
    }
    
    // Store auth token in Keychain
    private func storeAuthToken(_ token: String) throws {
        let data = token.data(using: .utf8)!
        
        // First, try to update existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            status = SecItemAdd(newItem as CFDictionary, nil)
        }
        
        if status != errSecSuccess {
            throw AuthError.keychainError
        }
    }
    
    // Delete auth token from Keychain
    private func deleteAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // Validate JWT token expiration
    func isTokenValid(_ token: String) -> Bool {
        // Split JWT into parts
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return false }
        
        // Decode the payload (second part)
        let payload = String(parts[1])
        
        // Add padding if needed
        let remainder = payload.count % 4
        let paddedPayload = payload + String(repeating: "=", count: remainder == 0 ? 0 : 4 - remainder)
        
        guard let payloadData = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return false
        }
        
        // Check if token is expired
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate > Date()
    }
    
    // Validate current stored token
    func validateStoredToken() -> Bool {
        guard let token = getStoredAuthToken() else {
            return false
        }
        
        if isTokenValid(token) {
            return true
        } else {
            // Token expired, sign out
            signOut()
            return false
        }
    }
}

// Auth response models
struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String
    let user: AuthUser
}

struct AuthUser: Codable {
    let id: String
    let email: String
    let role: String?
}

struct AuthErrorResponse: Codable {
    let msg: String
}

// Auth errors
enum AuthError: LocalizedError {
    case networkError
    case authenticationFailed(String)
    case keychainError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error. Please check your connection."
        case .authenticationFailed(let message):
            return message
        case .keychainError:
            return "Failed to store credentials securely."
        }
    }
}