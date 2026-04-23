//
//  CurrencyFormatter.swift
//  FinFlowCore
//
//  Centralized currency formatting utility
//

import Foundation

public enum CurrencyFormatter {

    // MARK: - Shared Formatter

    private nonisolated(unsafe) static let sharedFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // MARK: - Public API

    /// Format amount as plain currency (e.g., "150.000 ₫")
    public static func format(_ amount: Double) -> String {
        if let formatted = sharedFormatter.string(from: NSNumber(value: amount)) {
            return "\(formatted) ₫"
        }
        return "\(Int(amount)) ₫"
    }

    /// Format amount with explicit sign (e.g., "+ 150.000 ₫" or "- 50.000 ₫")
    public static func formatWithSign(_ amount: Double, isIncome: Bool) -> String {
        let absoluteValue = abs(amount)
        let formatted =
            sharedFormatter.string(from: NSNumber(value: absoluteValue)) ?? "\(Int(absoluteValue))"
        let sign = isIncome ? "+" : "-"
        return "\(sign) \(formatted) ₫"
    }

    /// Format balance with auto sign detection (e.g., "+ 150.000 ₫", "- 50.000 ₫", or "0 ₫")
    public static func formatBalance(_ value: Double) -> String {
        let absoluteValue = abs(value)
        let formatted =
            sharedFormatter.string(from: NSNumber(value: absoluteValue)) ?? "\(Int(absoluteValue))"

        if value < 0 {
            return "- \(formatted) ₫"
        } else if value > 0 {
            return "+ \(formatted) ₫"
        } else {
            return "\(formatted) ₫"
        }
    }

    /// Format numeric input for text field (e.g., "150000" → "150.000").
    /// When `allowNegative` is true, a single leading "-" is preserved (e.g. "-150000" → "-150.000").
    public static func formatInput(_ input: String, allowNegative: Bool = false) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let hasLeadingMinus = allowNegative && trimmed.hasPrefix("-")
        let withoutMinus = hasLeadingMinus ? String(trimmed.dropFirst()) : trimmed
        let numericOnly = String(withoutMinus.filter { "0123456789".contains($0) })

        if numericOnly.isEmpty {
            return hasLeadingMinus ? "-" : ""
        }

        guard let number = Double(numericOnly) else { return input }
        let formatted = sharedFormatter.string(from: NSNumber(value: number)) ?? numericOnly
        return hasLeadingMinus ? "-" + formatted : formatted
    }

    /// Parse formatted currency text to numeric value (e.g., "1.500.000" -> 1500000).
    public static func parseCurrencyInput(_ input: String) -> Double? {
        let normalized = input
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    /// Parse integer-only input to numeric value; returns nil for decimal values.
    public static func parseIntegerInput(_ input: String) -> Double? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if normalized.contains(".") || normalized.contains(",") { return nil }
        guard let intValue = Int(normalized.filter { "0123456789-".contains($0) }) else { return nil }
        return Double(intValue)
    }

    /// Parse percent input, supporting comma and dot decimal separators.
    public static func parsePercentInput(_ input: String) -> Double? {
        let normalized = input
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    /// Format axis large numbers (e.g., 1500000 → "1.5M")
    public static func formatAxisValue(_ value: Int) -> String {
        let doubleVal = Double(value)
        if doubleVal >= 1_000_000 {
            return String(format: "%gM", doubleVal / 1_000_000)
        } else if doubleVal >= 1_000 {
            return String(format: "%gK", doubleVal / 1_000)
        } else {
            return "\(value)"
        }
    }

    /// Format a quantity (stock count, unit count) as a grouped decimal integer without fraction digits.
    /// Example: 12345.0 → "12.345"
    public static func formatQuantity(_ value: Double) -> String {
        sharedFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}
