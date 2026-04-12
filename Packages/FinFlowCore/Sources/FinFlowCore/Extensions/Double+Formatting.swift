import Foundation

public extension Double {
    /// Format a quantity (stock count, unit count) as a grouped decimal integer without fraction digits.
    /// Example: 12345.0 → "12.345"
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? String(Int(self))
    }
}
