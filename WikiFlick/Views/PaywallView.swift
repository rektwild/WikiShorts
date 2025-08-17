import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @StateObject private var storeManager = StoreManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                closeButton
                
                Spacer()
                
                VStack(spacing: 20) {
                    headerSection
                    featuresSection
                    pricingSection
                    subscribeButton
                    restoreButton
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                footerSection
            }
            .padding(.vertical, 20)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: storeManager.errorMessage) { _, errorMessage in
            if !errorMessage.isEmpty {
                alertMessage = errorMessage
                showingAlert = true
            }
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
    }
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .padding(.trailing, 20)
            .padding(.top, 10)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("WikiShorts-pre")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
            
            Text("WikiShorts PRO")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRow(icon: "nosign", title: "Ad-Free Experience", description: "Enjoy uninterrupted reading without any ads")
            FeatureRow(icon: "calendar", title: "2-Week Free Trial", description: "Try all premium features completely free")
            FeatureRow(icon: "bolt.fill", title: "Faster Loading", description: "Premium servers for lightning-fast article loading")
        }
    }
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if let product = storeManager.getProduct(for: "wiki_m") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WikiShorts Pro")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("1 Month")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Cancel anytime")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text(product.displayPrice + "/month")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WikiShorts Pro")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("1 Month")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Cancel anytime")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Loading...")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var subscribeButton: some View {
        Button(action: {
            guard let product = storeManager.getProduct(for: "wiki_m") else { return }
            Task {
                await storeManager.purchase(product)
                if storeManager.isPurchased("wiki_m") {
                    isPresented = false
                }
            }
        }) {
            HStack {
                if storeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                }
                
                Text(storeManager.isPurchased("wiki_m") ? "Already Subscribed" : "Start Free Trial")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(storeManager.isPurchased("wiki_m") ? Color.gray : Color.white)
            )
        }
        .disabled(storeManager.isLoading || storeManager.isPurchased("wiki_m"))
        .padding(.top, 8)
    }
    
    private var restoreButton: some View {
        Button(action: {
            Task {
                await storeManager.restorePurchases()
            }
        }) {
            HStack {
                if storeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                }
                
                Text("Restore Purchases")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .disabled(storeManager.isLoading)
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://www.freeprivacypolicy.com/live/affd7171-b413-4bef-bbad-b4ec83a5fa1d") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            }
            
            Text("2-week free trial, then $4.99/month")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.yellow)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    PaywallView(isPresented: .constant(true))
}