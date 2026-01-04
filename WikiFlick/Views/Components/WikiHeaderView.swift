//  WikiHeaderView.swift
//  WikiFlick
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

struct WikiHeaderView: View {
    @Binding var showingPaywall: Bool
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var languageManager: AppLanguageManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Profile/Logo Button
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
            }) {
                Image("WikiShorts-pre")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
            
            // Remove Ads Button (only if not purchased)
            if !storeManager.isPurchased("wiki_m") {
                Button(action: {
                    showingPaywall = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "nosign")
                            .font(.system(size: 12, weight: .medium))
                        Text(languageManager.localizedString(key: "remove_ads"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
