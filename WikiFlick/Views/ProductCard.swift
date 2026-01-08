
import SwiftUI
import StoreKit

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    @ObservedObject var languageManager: AppLanguageManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(getTitleText())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(getPeriodText())
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(getSubtitleText())
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice + getPriceSuffix())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if let trialText = getTrialText() {
                    Text(trialText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                } else if product.id == "wiki_w" {
                     Text(languageManager.localizedString(key: "free_trial"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.yellow : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private func getPeriodText() -> String {
        if product.id == "wiki_life" {
            return languageManager.localizedString(key: "lifetime")
        }
        return languageManager.localizedString(key: "one_week")
    }
    
    private func getSubtitleText() -> String {
        if product.id == "wiki_life" {
            return languageManager.localizedString(key: "one_time_payment")
        }
        return languageManager.localizedString(key: "cancel_anytime")
    }
    
    private func getPriceSuffix() -> String {
        if product.id == "wiki_w" {
            return languageManager.localizedString(key: "per_week")
        }
        return ""
    }
    
    private func getTitleText() -> String {
        if product.id == "wiki_life" {
            return languageManager.localizedString(key: "lifetime")
        }
        return languageManager.localizedString(key: "weekly")
    }
    
    private func getTrialText() -> String? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer,
              offer.type == .introductory else {
            return nil
        }
        
        let count = offer.period.value
        let unit = offer.period.unit
        
        let unitKey: String
        switch unit {
        case .day: unitKey = count == 1 ? "day" : "days"
        case .week: unitKey = count == 1 ? "week" : "weeks"
        case .month: unitKey = count == 1 ? "month" : "months"
        case .year: unitKey = count == 1 ? "year" : "years"
        @unknown default: return nil
        }
        
        let unitString = languageManager.localizedString(key: unitKey)
        let freeString = languageManager.localizedString(key: "free_lower")
        
        return "\(count) \(unitString) \(freeString)"
    }
}
