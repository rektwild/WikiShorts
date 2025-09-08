import Foundation

/// Secure configuration manager to handle sensitive app configuration
/// This should be excluded from version control for production apps
final class SecureConfigManager {
    static let shared = SecureConfigManager()
    
    private let configBundle: Bundle
    
    private init() {
        // In production, consider using encrypted configuration or Keychain
        guard let path = Bundle.main.path(forResource: "AdMobConfig", ofType: "plist"),
              let bundle = Bundle(path: path) else {
            self.configBundle = Bundle.main
            print("⚠️ Warning: AdMobConfig.plist not found, using main bundle")
            return
        }
        self.configBundle = bundle
    }
    
    // MARK: - AdMob Configuration
    
    var interstitialAdUnitID: String {
        return getConfigValue(for: "InterstitialAdUnitID") ?? ""
    }
    
    var nativeAdUnitID: String {
        return getConfigValue(for: "NativeAdUnitID") ?? ""
    }
    
    var rewardedAdUnitID: String {
        return getConfigValue(for: "RewardedAdUnitID") ?? ""
    }
    
    // MARK: - Private Helpers
    
    private func getConfigValue(for key: String) -> String? {
        // First check main bundle Info.plist (for CI/CD environment variables)
        if let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty {
            return value
        }
        
        // Then check config plist
        if let path = Bundle.main.path(forResource: "AdMobConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let value = config[key] as? String {
            return value
        }
        
        print("⚠️ Warning: Configuration value for '\(key)' not found")
        return nil
    }
    
    // MARK: - Development Helpers
    
    #if DEBUG
    func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        let requiredKeys = ["InterstitialAdUnitID", "NativeAdUnitID", "RewardedAdUnitID"]
        
        for key in requiredKeys {
            if let value = getConfigValue(for: key) {
                if value.isEmpty {
                    issues.append("\(key) is empty")
                } else if value.contains("test") || value.contains("debug") {
                    print("ℹ️ Using test/debug configuration for \(key)")
                }
            } else {
                issues.append("\(key) is missing")
            }
        }
        
        return issues
    }
    #endif
}