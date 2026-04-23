//
//  AccountSelectionSheet.swift
//  Transaction
//
//  Account selection for transactions (transaction-eligible accounts only).
//  Follows Apple HIG: single clear action, recognizable list.
//

import FinFlowCore
import SwiftUI

/// Account selection sheet with balance display; use with transaction-eligible accounts only.
public struct AccountSelectionSheet: View {
    @Binding public var isPresented: Bool
    @Binding public var selectedAccount: WealthAccountResponse?
    public let accounts: [WealthAccountResponse]

    public init(
        isPresented: Binding<Bool>,
        selectedAccount: Binding<WealthAccountResponse?>,
        accounts: [WealthAccountResponse]
    ) {
        self._isPresented = isPresented
        self._selectedAccount = selectedAccount
        self.accounts = accounts
    }

    public var body: some View {
        SelectionSheet(
            isPresented: $isPresented,
            selectedItem: $selectedAccount,
            items: accounts,
            title: "Chọn tài khoản"
        ) { account, isSelected in
            AccountRow(account: account, isSelected: isSelected)
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: WealthAccountResponse
    let isSelected: Bool

    private var typeColor: Color {
        Color(hex: account.accountType.color)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(OpacityLevel.ultraLight))
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                Image(systemName: account.accountType.icon)
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(typeColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                Text(account.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: Spacing.xs) {
                    Text(account.accountType.displayName)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    if account.isSynced {
                        Image(systemName: "checkmark.seal.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.success)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs / 2) {
                BalanceLabel(balance: account.balance, style: .signed)
                    .font(AppTypography.headline)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
