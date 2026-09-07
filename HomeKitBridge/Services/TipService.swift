import Foundation
import StoreKit

/// A one-off thank-you. There is nothing to unlock: the app is the same before
/// and after, which is the point.
protocol TipService: AnyObject {
    func product() async -> TipProduct?
    /// True when the tip went through, false when the person backed out.
    func tip() async throws -> Bool
}

struct TipProduct: Equatable {
    static let identifier = "com.hasync.tip"

    let displayName: String
    let displayPrice: String
}

@MainActor
final class StoreKitTipService: TipService {
    func product() async -> TipProduct? {
        guard let product = try? await Product.products(for: [TipProduct.identifier]).first else {
            return nil
        }
        return TipProduct(displayName: product.displayName, displayPrice: product.displayPrice)
    }

    func tip() async throws -> Bool {
        guard let product = try await Product.products(for: [TipProduct.identifier]).first else {
            return false
        }

        switch try await product.purchase() {
        case .success(let verification):
            // A tip is consumable: finish it and leave nothing behind.
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }
}
