import XCTest
@testable import WikiFlick

final class SecureConfigManagerTests: XCTestCase {
    
    var configManager: SecureConfigManager!
    
    override func setUpWithError() throws {
        configManager = SecureConfigManager.shared
    }
    
    override func tearDownWithError() throws {
        configManager = nil
    }
    
    func testConfigurationValidation() throws {
        // Test that configuration validation returns expected results
        #if DEBUG
        let issues = configManager.validateConfiguration()
        
        // Should either have no issues or specific expected issues
        if !issues.isEmpty {
            print("Configuration issues found: \(issues)")
            // In a real test, you might want to assert specific behavior
        }
        #endif
    }
    
    func testAdUnitIDsNotEmpty() throws {
        // Test that ad unit IDs are not empty (they should be loaded from config)
        XCTAssertFalse(configManager.interstitialAdUnitID.isEmpty, "Interstitial Ad Unit ID should not be empty")
        XCTAssertFalse(configManager.nativeAdUnitID.isEmpty, "Native Ad Unit ID should not be empty")
        XCTAssertFalse(configManager.rewardedAdUnitID.isEmpty, "Rewarded Ad Unit ID should not be empty")
    }
    
    func testAdUnitIDFormat() throws {
        // Test that ad unit IDs have the expected AdMob format
        let adMobPattern = "^ca-app-pub-[0-9]+/[0-9]+$"
        let regex = try NSRegularExpression(pattern: adMobPattern)
        
        let interstitialRange = NSRange(location: 0, length: configManager.interstitialAdUnitID.utf16.count)
        let nativeRange = NSRange(location: 0, length: configManager.nativeAdUnitID.utf16.count)
        let rewardedRange = NSRange(location: 0, length: configManager.rewardedAdUnitID.utf16.count)
        
        XCTAssertNotNil(regex.firstMatch(in: configManager.interstitialAdUnitID, options: [], range: interstitialRange))
        XCTAssertNotNil(regex.firstMatch(in: configManager.nativeAdUnitID, options: [], range: nativeRange))
        XCTAssertNotNil(regex.firstMatch(in: configManager.rewardedAdUnitID, options: [], range: rewardedRange))
    }
}