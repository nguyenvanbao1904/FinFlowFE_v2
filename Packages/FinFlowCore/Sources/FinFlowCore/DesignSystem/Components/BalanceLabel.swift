//
//  BalanceLabel.swift
//  FinFlowCore
//
//  Single place for balance formatting and sign-based color (no scattered if/else).
//

import SwiftUI

/// Displays a balance with consistent formatting and color (negative = red, positive = green or primary).
public struct BalanceLabel: View {
    public let balance: Double
    public var style: Style = .plain

    public enum Style {
        /// No sign prefix; negative = red, positive = primary.
        case plain
        /// With +/− prefix; negative = red, positive = green.
        case signed
    }

    public init(balance: Double, style: Style = .plain) {
        self.balance = balance
        self.style = style
    }

    private var formattedText: String {
        switch style {
        case .plain: return CurrencyFormatter.format(balance)
        case .signed: return CurrencyFormatter.formatBalance(balance)
        }
    }

    private var balanceColor: Color {
        if balance < 0 { return AppColors.expense }
        switch style {
        case .plain: return .primary
        case .signed: return AppColors.success
        }
    }

    public var body: some View {
        Text(formattedText)
            .foregroundStyle(balanceColor)
    }
}
