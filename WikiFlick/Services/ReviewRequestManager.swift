import Foundation
import StoreKit
import UIKit

class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    private let minimumArticlesReadForReview = 10
    private let minimumDaysBeforeReview = 3
    private let daysBetweenReviews = 120 // 4 months

    private init() {}

    // Keys for UserDefaults
    private let lastReviewRequestDateKey = "lastReviewRequestDate"
    private let hasRequestedReviewKey = "hasRequestedReview"
    private let articlesReadCountKey = "articlesReadCount"
    private let firstLaunchDateKey = "firstLaunchDate"

    /// Request a review if conditions are met
    func requestReviewIfAppropriate() {
        // Don't request if already requested recently
        guard shouldRequestReview() else {
            print("📱 Review request conditions not met")
            return
        }

        // Get the window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("⚠️ Could not find window scene for review request")
            return
        }

        // Request the review
        SKStoreReviewController.requestReview(in: windowScene)

        // Update tracking
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
        UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)

        print("✅ Review requested successfully")
    }

    /// Request review immediately (for settings button)
    func requestReviewImmediately() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("⚠️ Could not find window scene for review request")
            return
        }

        SKStoreReviewController.requestReview(in: windowScene)

        // Track the request
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
        UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)
    }

    /// Increment article read count
    func incrementArticleReadCount() {
        let currentCount = UserDefaults.standard.integer(forKey: articlesReadCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: articlesReadCountKey)

        // Check if we should request a review after this article
        if currentCount + 1 == minimumArticlesReadForReview {
            requestReviewIfAppropriate()
        }
    }

    /// Check if we should request a review
    private func shouldRequestReview() -> Bool {
        // Check if first launch date is set, if not set it
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }

        // Check minimum days since first launch
        guard let firstLaunchDate = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date else {
            return false
        }

        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
        guard daysSinceFirstLaunch >= minimumDaysBeforeReview else {
            print("📱 Not enough days since first launch: \(daysSinceFirstLaunch)/\(minimumDaysBeforeReview)")
            return false
        }

        // Check minimum articles read
        let articlesRead = UserDefaults.standard.integer(forKey: articlesReadCountKey)
        guard articlesRead >= minimumArticlesReadForReview else {
            print("📱 Not enough articles read: \(articlesRead)/\(minimumArticlesReadForReview)")
            return false
        }

        // Check if we've requested a review before and if enough time has passed
        if let lastReviewDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date {
            let daysSinceLastReview = Calendar.current.dateComponents([.day], from: lastReviewDate, to: Date()).day ?? 0
            guard daysSinceLastReview >= daysBetweenReviews else {
                print("📱 Not enough days since last review: \(daysSinceLastReview)/\(daysBetweenReviews)")
                return false
            }
        }

        return true
    }

    /// Reset review tracking (useful for testing)
    func resetReviewTracking() {
        UserDefaults.standard.removeObject(forKey: lastReviewRequestDateKey)
        UserDefaults.standard.removeObject(forKey: hasRequestedReviewKey)
        UserDefaults.standard.removeObject(forKey: articlesReadCountKey)
        UserDefaults.standard.removeObject(forKey: firstLaunchDateKey)
    }
}