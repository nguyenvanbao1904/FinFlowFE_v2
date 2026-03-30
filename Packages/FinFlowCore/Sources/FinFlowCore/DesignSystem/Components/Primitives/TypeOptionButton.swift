import SwiftUI

/// Two-option type button (used for Income/Expense, Buy/Sell, Deposit/Withdraw...)
/// Matches the same visual behavior as `AddTransactionView.typeButton`.
public struct TypeOptionButton: View {
    private let title: String
    private let isSelected: Bool
    private let color: Color
    private let action: () -> Void

    public init(
        title: String,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background {
                    if isSelected {
                        color.opacity(OpacityLevel.light)
                    } else {
                        Rectangle().fill(AppColors.cardBackground)
                    }
                }
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isSelected
                                ? color.opacity(OpacityLevel.strong)
                                : AppColors.disabled.opacity(OpacityLevel.medium),
                            lineWidth: BorderWidth.thin
                        )
                )
        }
        .buttonStyle(.borderless)
    }
}

