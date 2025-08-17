import Foundation
import GoogleMobileAds
import UIKit
import AppTrackingTransparency

class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    // Interstitial Ads
    private var interstitialAd: GADInterstitialAd?
    private let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    
    // Native Ads
    private var nativeAd: GADNativeAd?
    private let testNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    
    // Rewarded Ads
    private var rewardedAd: GADRewardedAd?
    private let testRewardedAdUnitID = "ca-app-pub-3940256099942544/5224354917"
    
    @Published var isAdLoaded = false
    @Published var isNativeAdLoaded = false
    @Published var currentNativeAd: GADNativeAd?
    @Published var isRewardedAdLoaded = false
    
    private var articleCount = 0
    private let interstitialAdFrequency = 8
    private let nativeAdFrequency = 5
    
    override init() {
        super.init()
        setupAdMob()
        loadInterstitialAd()
        loadNativeAd()
        loadRewardedAd()
    }
    
    private func setupAdMob() {
        requestTrackingPermission { [weak self] in
            GADMobileAds.sharedInstance().start { [weak self] status in
                self?.loadInterstitialAd()
                self?.loadNativeAd()
                self?.loadRewardedAd()
            }
        }
    }
    
    private func requestTrackingPermission(completion: @escaping () -> Void) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        break
                    case .denied:
                        break
                    case .restricted:
                        break
                    case .notDetermined:
                        break
                    @unknown default:
                        break
                    }
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
    func loadInterstitialAd() {
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: testInterstitialAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
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
        let adLoader = GADAdLoader(adUnitID: testNativeAdUnitID, rootViewController: nil, adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(GADRequest())
    }
    
    func shouldShowInterstitialAd() -> Bool {
        articleCount += 1
        
        if articleCount % interstitialAdFrequency == 0 && isAdLoaded {
            return true
        }
        return false
    }
    
    func shouldShowNativeAd(forArticleIndex index: Int) -> Bool {
        let articleNumber = index + 1
        return articleNumber % nativeAdFrequency == 0 && isNativeAdLoaded
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
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: testRewardedAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
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
        guard let rewardedAd = rewardedAd else {
            return
        }
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }
            
            rewardedAd.present(fromRootViewController: rootViewController) {
                // Ödül verildi - 10 dakika reklamsız kullanım
                // Bu kısmı daha sonra implement edebiliriz
            }
        }
    }
    
    func resetArticleCount() {
        articleCount = 0
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