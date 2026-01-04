import Foundation
import GoogleMobileAds
import UIKit
import AppTrackingTransparency
import Combine

final class GlobalAdConfig {
    static let shared = GlobalAdConfig()
    var nonPersonalizedExtras: Extras?
    
    private init() {}
}

@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    // MARK: - Constants
    private enum Constants {
        static let premiumProductID = "wiki_m"
        static let interstitialAdFrequency = 10
        static let nativeAdFrequency = 5
        static let feedAdFrequency = 5
        static let feedAdStartsFromIndex = 4
        static let adFreeDuration: TimeInterval = 10 * 60
    }
    
    private let storeManager: StoreManager
    private var cancellables = Set<AnyCancellable>()
    
    // Interstitial Ads
    private var interstitialAd: InterstitialAd?
    private let interstitialAdUnitID: String
    
    // Native Ads
    private var nativeAd: NativeAd?
    private let nativeAdUnitID: String
    
    // Rewarded Ads
    private var rewardedAd: RewardedAd?
    private let rewardedAdUnitID: String
    
    // Banner Ads
    let bannerAdUnitID: String
    
    @Published var isAdLoaded = false
    @Published var isNativeAdLoaded = false
    @Published var currentNativeAd: NativeAd?
    @Published var isRewardedAdLoaded = false
    
    // UI refresh trigger for premium status changes
    @Published var premiumStatusChanged = false
    @Published var isPremiumUser = false
    
    private var pageViewCount = 0
    private var hasATTPermission = false
    private var isAdMobInitialized = false
    
    // Ad-free period tracking
    private var adFreeStartTime: Date?
    
    override init() {
        self.storeManager = StoreManager()
        
        // Initialize secure configuration
        let config = SecureConfigManager.shared
        self.interstitialAdUnitID = config.interstitialAdUnitID
        self.nativeAdUnitID = config.nativeAdUnitID
        self.rewardedAdUnitID = config.rewardedAdUnitID
        self.bannerAdUnitID = config.bannerAdUnitID
        
        super.init()
        
        // Set initial premium status
        self.isPremiumUser = storeManager.isPurchased(Constants.premiumProductID)
        
        #if DEBUG
        validateAdConfiguration()
        #endif
        
        setupSubscriptionMonitoring()
        setupATTNotificationListener()
    }
    
    private func setupSubscriptionMonitoring() {
        storeManager.$purchasedProducts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] purchasedProducts in
                self?.handleSubscriptionChange(purchasedProducts: purchasedProducts)
            }
            .store(in: &cancellables)
    }
    
    private func handleSubscriptionChange(purchasedProducts: Set<String>) {
        let wasPremium = isPremiumUser
        let isPremiumNow = purchasedProducts.contains(Constants.premiumProductID)
        
        // Update published properties
        self.isPremiumUser = isPremiumNow
        
        if wasPremium != isPremiumNow {
            // Trigger UI refresh
            self.premiumStatusChanged.toggle()
            
            if isPremiumNow {
                print("🏆 User became premium - stopping all ads and refreshing UI")
                stopAllAds()
                
                // Force UI refresh with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.premiumStatusChanged.toggle()
                    
                    // Send notification for immediate page refresh
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PremiumStatusChanged"),
                        object: nil,
                        userInfo: ["isPremium": true]
                    )
                }
            } else {
                print("📱 Premium expired - reloading ads and refreshing UI")
                if isAdMobInitialized {
                    loadAllAds()
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("PremiumStatusChanged"),
                    object: nil,
                    userInfo: ["isPremium": false]
                )
            }
        }
    }
    
    private func stopAllAds() {
        interstitialAd = nil
        nativeAd = nil
        currentNativeAd = nil
        rewardedAd = nil
        
        isAdLoaded = false
        isNativeAdLoaded = false
        isRewardedAdLoaded = false
        
        print("🏆 All ads stopped for premium user")
    }
    
    private func setupATTNotificationListener() {
        // Listen for ATT permission updates using Combine
        NotificationCenter.default.publisher(for: NSNotification.Name("ATTPermissionUpdated"))
            .compactMap { $0.userInfo?["status"] as? ATTStatus }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("🔐 ATT Permission updated: \(status)")
                self?.hasATTPermission = true
                self?.configureAdSettings(for: status)
                self?.initializeAdMob()
            }
            .store(in: &cancellables)
        
        // Check if ATT has already been determined
        let currentStatus = ATTManager.shared.getCurrentStatus()
        if currentStatus != .notDetermined {
            print("🔐 ATT already determined: \(currentStatus)")
            hasATTPermission = true
            configureAdSettings(for: currentStatus)
            initializeAdMob()
        }
    }
    
    private func initializeAdMob() {
        guard hasATTPermission else {
            print("❌ Cannot initialize AdMob - no ATT permission yet")
            return
        }
        
        MobileAds.shared.start { [weak self] (initializationStatus: InitializationStatus) in
            Task { @MainActor [weak self] in
                print("✅ AdMob initialized successfully")
                self?.isAdMobInitialized = true
                self?.loadAllAds()
            }
        }
    }

    private func loadAllAds() {
        guard isAdMobInitialized else { return }
        loadInterstitialAd()
        loadNativeAd()
        loadRewardedAd()
    }
    
    // MARK: - Premium Subscription Control
    
    private func isPremiumActive() -> Bool {
        return storeManager.isPurchased(Constants.premiumProductID)
    }
    
    private func configureAdSettings(for attStatus: ATTStatus) {
        if attStatus != .authorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            GlobalAdConfig.shared.nonPersonalizedExtras = extras
        } else {
            GlobalAdConfig.shared.nonPersonalizedExtras = nil
        }
    }
    
    func makeAdRequest() -> Request {
        let request = Request()
        if let extras = GlobalAdConfig.shared.nonPersonalizedExtras {
            request.register(extras)
        }
        return request
    }
    
    func loadInterstitialAd() {
        guard hasATTPermission && isAdMobInitialized else { return }
        
        guard !isPremiumActive() else {
            isAdLoaded = false
            return
        }
        
        let request = makeAdRequest()
        
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                    self?.isAdLoaded = false
                    return
                }
                
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                self?.isAdLoaded = true
            }
        }
    }
    
    func loadNativeAd() {
        guard hasATTPermission && isAdMobInitialized else { return }
        
        guard !isPremiumActive() else {
            isNativeAdLoaded = false
            currentNativeAd = nil
            return
        }
        
        let adLoader = AdLoader(adUnitID: nativeAdUnitID, rootViewController: nil, adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(makeAdRequest())
    }

    func incrementPageViewAndCheckAd() -> Bool {
        if isPremiumActive() || isInAdFreePeriod() { return false }

        pageViewCount += 1
        print("📄 Page view: \(pageViewCount)")

        if pageViewCount % Constants.interstitialAdFrequency == 0 && isAdLoaded {
            print("🎯 Showing ad after \(pageViewCount) page views")
            return true
        }
        return false
    }
    
    func shouldShowNativeAd(forArticleIndex index: Int) -> Bool {
        if isPremiumActive() || isInAdFreePeriod() { return false }
        
        let articleNumber = index + 1
        return articleNumber % Constants.nativeAdFrequency == 0 && isNativeAdLoaded
    }
    
    func shouldShowFeedAd(forArticleIndex index: Int) -> Bool {
        if isPremiumActive() || isInAdFreePeriod() { return false }
        
        if index < Constants.feedAdStartsFromIndex { return false }
        
        let articleNumber = index + 1
        return articleNumber % Constants.feedAdFrequency == 0 && isNativeAdLoaded
    }
    
    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
    }
    
    private var rootViewController: UIViewController? {
        activeWindowScene?.windows.first { $0.isKeyWindow }?.rootViewController
            ?? activeWindowScene?.windows.first?.rootViewController
    }
    
    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd,
              let rootViewController = rootViewController else {
            return
        }
         
        interstitialAd.present(from: rootViewController)
    }
    
    func loadRewardedAd() {
        guard hasATTPermission && isAdMobInitialized else { return }
        
        guard !isPremiumActive() else {
            isRewardedAdLoaded = false
            return
        }
        
        let request = makeAdRequest()
        
        RewardedAd.load(with: rewardedAdUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("❌ Failed to load rewarded ad: \(error.localizedDescription)")
                    self?.isRewardedAdLoaded = false
                    return
                }
                
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                self?.isRewardedAdLoaded = true
            }
        }
    }
    
    func showRewardedAd() {
        guard !isPremiumActive(),
              let rewardedAd = rewardedAd,
              let rootViewController = rootViewController else {
            return
        }
        
        rewardedAd.present(from: rootViewController, userDidEarnRewardHandler: { [weak self] in
            self?.startAdFreePeriod()
        })
    }
    
    func resetPageViewCount() {
        pageViewCount = 0
    }
    
    // MARK: - Ad-free period methods
    
    private func startAdFreePeriod() {
        adFreeStartTime = Date()
    }
    
    private func isInAdFreePeriod() -> Bool {
        guard let startTime = adFreeStartTime else { return false }
        return Date().timeIntervalSince(startTime) < Constants.adFreeDuration
    }
    
    func getRemainingAdFreeTime() -> TimeInterval? {
        guard let startTime = adFreeStartTime else { return nil }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = Constants.adFreeDuration - elapsedTime
        return remainingTime > 0 ? remainingTime : nil
    }
    
    // MARK: - Feed Ad Configuration
    
    func getFeedAdFrequency() -> Int {
        return Constants.feedAdFrequency
    }
    
    func getFeedAdStartIndex() -> Int {
        return Constants.feedAdStartsFromIndex
    }
    
    func isCurrentNativeAdValid() -> Bool {
        return currentNativeAd != nil && isNativeAdLoaded
    }
    
    // MARK: - Development Helpers
    
    #if DEBUG
    private func validateAdConfiguration() {
        let issues = SecureConfigManager.shared.validateConfiguration()
        if !issues.isEmpty {
            print("⚠️ Ad Configuration Issues:")
            issues.forEach { print("  - \($0)") }
        }
        
        if interstitialAdUnitID.isEmpty { print("🚨 CRITICAL: Interstitial Ad Unit ID is empty!") }
        if nativeAdUnitID.isEmpty { print("🚨 CRITICAL: Native Ad Unit ID is empty!") }
        if rewardedAdUnitID.isEmpty { print("🚨 CRITICAL: Rewarded Ad Unit ID is empty!") }
        if bannerAdUnitID.isEmpty { print("🚨 CRITICAL: Banner Ad Unit ID is empty!") }
    }
    #endif
}

extension AdMobManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            if ad is InterstitialAd {
                loadInterstitialAd()
            } else if ad is RewardedAd {
                loadRewardedAd()
            }
        }
    }
    
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            if ad is InterstitialAd {
                loadInterstitialAd()
            } else if ad is RewardedAd {
                loadRewardedAd()
            }
        }
    }
}

extension AdMobManager: AdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            isNativeAdLoaded = false
        }
    }
}

extension AdMobManager: NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.nativeAd = nativeAd
            self.currentNativeAd = nativeAd
            self.isNativeAdLoaded = true
        }
    }
}