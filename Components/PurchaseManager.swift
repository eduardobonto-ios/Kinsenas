import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    
    @Published var isPurchased: Bool = false
    
    private let productID = "kinsenas.pro.lifetime"
    
    func loadPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                isPurchased = true
                return
            }
        }
    }
    
    func buy() async {
        do {
            let products = try await Product.products(for: [productID])
            
            guard let product = products.first else { return }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPurchased = true
                    await transaction.finish()
                }
                
            case .userCancelled:
                break
                
            default:
                break
            }
        } catch {
            print("Purchase error:", error)
        }
    }
    
    func restore() async {
        await loadPurchaseStatus()
    }
}
