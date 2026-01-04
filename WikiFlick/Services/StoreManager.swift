import Foundation
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let productIDs = ["wiki_w", "wiki_life"]
    private var updateListenerTask: Task<Void, Never>? = nil
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    Logger.error("Transaction failed verification", category: .payment)
                }
            }
        }
    }
    
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwraped value.
            return safe
        }
    }
    
    func loadProducts() async {
        defer { isLoading = false }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    func purchase(_ product: Product) async {
        defer { isLoading = false }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updatePurchasedProducts()
                case .unverified(let transaction, let verificationError):
                    // Log security issue but don't grant entitlement
                    Logger.fault("SECURITY: Unverified transaction detected - \(verificationError)", category: .payment)
                    await transaction.finish() // Finish to remove from queue but don't grant access
                    errorMessage = "Purchase verification failed. Please contact support if this issue persists."
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending"
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    func restorePurchases() async {
        defer { isLoading = false }
        
        isLoading = true
        errorMessage = ""
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            case .unverified:
                break
            }
        }
        
        purchasedProducts = purchased
    }
    
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProducts.contains(productID)
    }
    
    func getProduct(for id: String) -> Product? {
        return products.first { $0.id == id }
    }
}

public enum StoreError: Error {
    case failedVerification
}