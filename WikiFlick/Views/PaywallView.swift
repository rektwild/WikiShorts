import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @StateObject private var storeManager = StoreManager()
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedProduct: Product?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                closeButton
                    .padding(.bottom, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        featuresSection
                        pricingSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                
                VStack(spacing: 16) {
                    subscribeButton
                        .padding(.horizontal, 24)
                    
                    footerSection
                }
                .padding(.vertical, 20)
                .background(Color.black)
            }
        }
        .alert(languageManager.localizedString(key: "error"), isPresented: $showingAlert) {
            Button(languageManager.localizedString(key: "ok")) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: storeManager.errorMessage) { errorMessage in
            if !errorMessage.isEmpty {
                alertMessage = errorMessage
                showingAlert = true
            }
        }
        .onChange(of: storeManager.products) { products in
            if selectedProduct == nil, let weekly = products.first(where: { $0.id == "wiki_w" }) {
                selectedProduct = weekly
            } else if selectedProduct == nil, let first = products.first {
                selectedProduct = first
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
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
        VStack(spacing: 12) {
            Image("WikiShorts-pre")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
            
            Text(languageManager.localizedString(key: "wikishorts_pro"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRow(icon: "nosign", title: languageManager.localizedString(key: "ad_free_experience"), description: languageManager.localizedString(key: "ad_free_experience_desc"))
            FeatureRow(icon: "calendar", title: languageManager.localizedString(key: "free_trial"), description: languageManager.localizedString(key: "free_trial_desc"))
            FeatureRow(icon: "bolt.fill", title: languageManager.localizedString(key: "faster_loading"), description: languageManager.localizedString(key: "faster_loading_desc"))
        }
        .padding(.vertical, 8)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if storeManager.isLoading && storeManager.products.isEmpty {
                loadingProductView
            } else {
                ForEach(storeManager.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        languageManager: languageManager
                    )
                    .contentShape(Rectangle()) // Improves tap area
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    private var loadingProductView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(languageManager.localizedString(key: "wikishorts_pro"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(languageManager.localizedString(key: "loading"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text("...")
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
    
    private var subscribeButton: some View {
        Button(action: {
            guard let product = selectedProduct else { return }
            Task {
                await storeManager.purchase(product)
                if storeManager.isPurchased(product.id) {
                    isPresented = false
                }
            }
        }) {
            HStack {
                if storeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
                
                if let product = selectedProduct, storeManager.isPurchased(product.id) {
                    Text(languageManager.localizedString(key: "already_subscribed"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Text(selectedProduct?.id == "wiki_life" ? languageManager.localizedString(key: "go_premium") : languageManager.localizedString(key: "start_free_trial"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((selectedProduct != nil && storeManager.isPurchased(selectedProduct!.id)) ? Color.gray : Color.white)
            )
        }
        .disabled(storeManager.isLoading || selectedProduct == nil || (selectedProduct != nil && storeManager.isPurchased(selectedProduct!.id)))
    }
    
    private var footerSection: some View {
        HStack(spacing: 24) {
            Button(languageManager.localizedString(key: "terms_of_service")) {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            
            Button(languageManager.localizedString(key: "privacy_policy")) {
                if let url = URL(string: "https://www.freeprivacypolicy.com/live/affd7171-b413-4bef-bbad-b4ec83a5fa1d") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.5))

            Button(action: {
                Task {
                    await storeManager.restorePurchases()
                }
            }) {
                Text(languageManager.localizedString(key: "restore_purchases"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .disabled(storeManager.isLoading)
        }
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