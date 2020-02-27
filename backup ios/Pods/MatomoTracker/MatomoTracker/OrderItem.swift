import Foundation

/// Order item as described in: https://matomo.org/docs/ecommerce-analytics/#tracking-ecommerce-orders-items-purchased-required
public struct OrderItem: Codable {
    
    /// The SKU of the order item
    let sku: String
    
    /// The name of the order item
    let name: String
    
    /// The category of the order item
    let category: String
    
    /// The price of the order item
    let price: Float
    
    /// The quantity of the order item
    let quantity: Int
    
    /// Creates a new OrderItem
    ///
    /// - Parameters:
    ///   - sku: The SKU of the item
    ///   - name: The name of the item. Empty string per default.
    ///   - category: The category of the item. Empty string per default.
    ///   - price: The price of the item. 0 per default.
    ///   - quantity: The quantity of the item. 1 per default.
    public init(sku: String, name: String = "", category: String = "", price: Float = 0.0, quantity: Int = 1) {
        self.sku = sku
        self.name = name
        self.category = category
        self.price = price
        self.quantity = quantity
    }
}
