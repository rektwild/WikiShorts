//
//  WikiTrailingHeaderView.swift
//  WikiFlick
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

struct WikiTrailingHeaderView: View {
    @Binding var showingSettings: Bool
    @Binding var showingRewardAlert: Bool
    @Binding var showingNoAdAlert: Bool
    
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Gift Button (Rewarded Ad) - Hide if purchased
            if !storeManager.hasPremiumAccess {
                Button(action: {
                    if AdMobManager.shared.isRewardedAdLoaded {
                        showingRewardAlert = true
                    } else {
                        showingNoAdAlert = true
                    }
                }) {
                    Image(systemName: "gift")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // Settings Button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}
