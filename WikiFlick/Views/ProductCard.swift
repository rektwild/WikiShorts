
import SwiftUI
import StoreKit

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    @ObservedObject var languageManager: AppLanguageManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(languageManager.localizedString(key: "wikishorts_pro"))
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
                
                if product.id == "wiki_w" {
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
            return "/week"
        }
        return ""
    }
}
