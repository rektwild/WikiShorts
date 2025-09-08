import Foundation
import GoogleMobileAds
import UIKit
import AppTrackingTransparency
import Combine

final class GlobalAdConfig {
    static let shared = GlobalAdConfig()
    var nonPersonalizedExtras: GADExtras?
    
    private init() {}
}

@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    private let storeManager: StoreManager
    
    // Interstitial Ads
    private var interstitialAd: GADInterstitialAd?
    private let interstitialAdUnitID = "ca-app-pub-7984188512879505/1948301985"
    
    // Native Ads
    private var nativeAd: GADNativeAd?
    private let nativeAdUnitID = "ca-app-pub-7984188512879505/2754504239"
    
    // Rewarded Ads
    private var rewardedAd: GADRewardedAd?
    private let rewardedAdUnitID = "ca-app-pub-7984188512879505/1080112876"
    
    @Published var isAdLoaded = false
    @Published var isNativeAdLoaded = false
    @Published var currentNativeAd: GADNativeAd?
    @Published var isRewardedAdLoaded = false
    
    // UI refresh trigger for premium status changes
    @Published var premiumStatusChanged = false
    @Published var isPremiumUser = false
    
    private var articleCount = 0
    private let interstitialAdFrequency = 5
    private let nativeAdFrequency = 5
    private let feedAdFrequency = 5
    
    private var hasATTPermission = false
    private var isAdMobInitialized = false
    
    // Subscription monitoring
    private var subscriptionCancellable: AnyCancellable?
    
    // Ad-free period tracking
    private var adFreeStartTime: Date?
    private let adFreeDurationMinutes: TimeInterval = 10 * 60 // 10 minutes in seconds
    
    override init() {
        self.storeManager = StoreManager()
        super.init()
        
        // Set initial premium status
        self.isPremiumUser = storeManager.isPurchased("wiki_m")
        
        setupSubscriptionMonitoring()
        setupATTNotificationListener()
    }
    
    private func setupSubscriptionMonitoring() {
        subscriptionCancellable = storeManager.$purchasedProducts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] purchasedProducts in
                self?.handleSubscriptionChange(purchasedProducts: purchasedProducts)
            }
    }
    
    private func handleSubscriptionChange(purchasedProducts: Set<String>) {
        let wasPremium = isPremiumUser
        let isPremiumNow = purchasedProducts.contains("wiki_m")
        
        // Update published properties
        self.isPremiumUser = isPremiumNow
        
        if wasPremium != isPremiumNow {
            // Trigger UI refresh
            self.premiumStatusChanged.toggle()
            
            if isPremiumNow {
                print("🏆 User became premium - stopping all ads and refreshing UI")
                stopAllAds()
                
                // Force UI refresh with a slight delay to ensure state propagation
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
                
                // Send notification for immediate page refresh
                NotificationCenter.default.post(
                    name: NSNotification.Name("PremiumStatusChanged"),
                    object: nil,
                    userInfo: ["isPremium": false]
                )
            }
        }
    }
    
    private func stopAllAds() {
        // Clear all loaded ads
        interstitialAd = nil
        nativeAd = nil
        currentNativeAd = nil
        rewardedAd = nil
        
        // Update published properties
        isAdLoaded = false
        isNativeAdLoaded = false
        isRewardedAdLoaded = false
        
        print("🏆 All ads stopped for premium user")
    }
    
    deinit {
        subscriptionCancellable?.cancel()
    }
    
    private func setupATTNotificationListener() {
        // Listen for ATT permission updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ATTPermissionUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let status = notification.userInfo?["status"] as? ATTStatus {
                print("🔐 ATT Permission updated: \(status)")
                self?.hasATTPermission = true
                self?.configureAdSettings(for: status)
                self?.initializeAdMob()
            }
        }
        
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
        
        GADMobileAds.sharedInstance().start { [weak self] _ in
            print("✅ AdMob initialized successfully")
            self?.isAdMobInitialized = true
            self?.loadAllAds()
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
        return storeManager.isPurchased("wiki_m")
    }
    
    private func shouldSkipAdsForPremium() -> Bool {
        let isPremium = isPremiumActive()
        if isPremium {
            print("🏆 Premium user - skipping ads")
        }
        return isPremium
    }
    
    private func configureAdSettings(for attStatus: ATTStatus) {
        if attStatus != .authorized {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            GlobalAdConfig.shared.nonPersonalizedExtras = extras
        } else {
            GlobalAdConfig.shared.nonPersonalizedExtras = nil
        }
    }
    
    private func makeAdRequest() -> GADRequest {
        let request = GADRequest()
        if let extras = GlobalAdConfig.shared.nonPersonalizedExtras {
            request.register(extras)
        }
        return request
    }
    
    func loadInterstitialAd() {
        guard hasATTPermission && isAdMobInitialized else {
            print("⏳ Cannot load interstitial ad - waiting for ATT permission or AdMob initialization")
            return
        }
        
        guard !shouldSkipAdsForPremium() else {
            print("🏆 Premium user - skipping interstitial ad loading")
            isAdLoaded = false
            return
        }
        
        let request = makeAdRequest()
        
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
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
        guard hasATTPermission && isAdMobInitialized else {
            print("⏳ Cannot load native ad - waiting for ATT permission or AdMob initialization")
            return
        }
        
        guard !shouldSkipAdsForPremium() else {
            print("🏆 Premium user - skipping native ad loading")
            isNativeAdLoaded = false
            currentNativeAd = nil
            return
        }
        
        let adLoader = GADAdLoader(adUnitID: nativeAdUnitID, rootViewController: nil, adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(makeAdRequest())
    }
    
    func shouldShowInterstitialAd() -> Bool {
        // Premium users never see ads
        if shouldSkipAdsForPremium() {
            return false
        }
        
        // Don't show ads during ad-free period
        if isInAdFreePeriod() {
            return false
        }
        
        articleCount += 1
        
        if articleCount % interstitialAdFrequency == 0 && isAdLoaded {
            return true
        }
        return false
    }
    
    func shouldShowNativeAd(forArticleIndex index: Int) -> Bool {
        // Premium users never see ads
        if shouldSkipAdsForPremium() {
            return false
        }
        
        // Don't show ads during ad-free period
        if isInAdFreePeriod() {
            return false
        }
        
        let articleNumber = index + 1
        return articleNumber % nativeAdFrequency == 0 && isNativeAdLoaded
    }
    
    func shouldShowFeedAd(forArticleIndex index: Int) -> Bool {
        // Premium users never see ads
        if shouldSkipAdsForPremium() {
            return false
        }
        
        // Don't show ads during ad-free period
        if isInAdFreePeriod() {
            return false
        }
        
        let articleNumber = index + 1
        return articleNumber % feedAdFrequency == 0 && isNativeAdLoaded
    }
    
    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd else {
            return
        }
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            interstitialAd.present(fromRootViewController: rootViewController)
        }
    }
    
    func loadRewardedAd() {
        guard hasATTPermission && isAdMobInitialized else {
            print("⏳ Cannot load rewarded ad - waiting for ATT permission or AdMob initialization")
            return
        }
        
        guard !shouldSkipAdsForPremium() else {
            print("🏆 Premium user - skipping rewarded ad loading")
            isRewardedAdLoaded = false
            return
        }
        
        let request = makeAdRequest()
        
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
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
        // Premium users don't need rewarded ads (they already have ad-free experience)
        guard !shouldSkipAdsForPremium() else {
            print("🏆 Premium user - rewarded ad not needed")
            return
        }
        
        guard let rewardedAd = rewardedAd else {
            return
        }
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            rewardedAd.present(fromRootViewController: rootViewController) { [weak self] in
                // Start 10-minute ad-free period
                self?.startAdFreePeriod()
            }
        }
    }
    
    func resetArticleCount() {
        articleCount = 0
    }
    
    // MARK: - Ad-free period methods
    
    private func startAdFreePeriod() {
        adFreeStartTime = Date()
    }
    
    private func isInAdFreePeriod() -> Bool {
        guard let startTime = adFreeStartTime else { return false }
        let elapsedTime = Date().timeIntervalSince(startTime)
        return elapsedTime < adFreeDurationMinutes
    }
    
    func getRemainingAdFreeTime() -> TimeInterval? {
        guard let startTime = adFreeStartTime else { return nil }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = adFreeDurationMinutes - elapsedTime
        return remainingTime > 0 ? remainingTime : nil
    }
}

extension AdMobManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            loadRewardedAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd {
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            loadRewardedAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    }
}

extension AdMobManager: GADAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        isNativeAdLoaded = false
    }
}

extension AdMobManager: GADNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        self.nativeAd = nativeAd
        self.currentNativeAd = nativeAd
        self.isNativeAdLoaded = true
    }
}