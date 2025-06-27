import Foundation

// Configuration for the BetTracker app
// This file manages environment-specific settings and API credentials
struct Config {
    // MARK: - Supabase Configuration
    
    // Get Supabase URL from environment variable or use default
    static var supabaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return envURL
        }
        
        // Default URL - should be replaced with your actual Supabase URL
        // For production, always use environment variables
        return "https://anxncoikpbipuplrkqrd.supabase.co"
    }
    
    // Get Supabase anonymous key from environment variable or use default
    static var supabaseAnonKey: String {
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            return envKey
        }
        
        // Default key - should be replaced with your actual Supabase anon key
        // For production, always use environment variables˜
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFueG5jb2lrcGJpcHVwbHJrcXJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3ODY1OTMsImV4cCI6MjA2NTM2MjU5M30.gMAaJ1h7ZmiSbaInhNgYNCsJhLj8SljiawkDyWlYrGQ"
    }
    
    // MARK: - Environment Detection
    
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Configuration Validation
    
    static func validateConfiguration() -> Bool {
        // Check if we're using environment variables (preferred)
        let hasEnvURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] != nil
        let hasEnvKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] != nil
        
        if !hasEnvURL || !hasEnvKey {
            print("⚠️ Warning: Using hardcoded Supabase credentials. Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables for production.")
        }
        
        // Validate URL format
        guard let url = URL(string: supabaseURL),
              url.scheme == "https",
              url.host != nil else {
            print("❌ Error: Invalid Supabase URL format")
            return false
        }
        
        // Basic JWT validation for anon key
        let keyParts = supabaseAnonKey.split(separator: ".")
        guard keyParts.count == 3 else {
            print("❌ Error: Invalid Supabase anon key format")
            return false
        }
        
        return true
    }
}

// MARK: - Environment Variable Setup Instructions

/*
 To set up environment variables for BetTracker:
 
 1. In Xcode:
    - Select your scheme and click "Edit Scheme..."
    - Go to the "Run" tab, then "Arguments"
    - In "Environment Variables", add:
      - SUPABASE_URL: Your Supabase project URL
      - SUPABASE_ANON_KEY: Your Supabase anonymous key
 
 2. For production builds:
    - Use a build configuration file or CI/CD environment variables
    - Never commit actual credentials to version control
 
 3. For local development:
    - Create a .env file (add to .gitignore)
    - Use a script to load environment variables before building
 
 Example .env file:
 ```
 SUPABASE_URL=https://your-project.supabase.co
 SUPABASE_ANON_KEY=your-anon-key-here
 ```
 */
