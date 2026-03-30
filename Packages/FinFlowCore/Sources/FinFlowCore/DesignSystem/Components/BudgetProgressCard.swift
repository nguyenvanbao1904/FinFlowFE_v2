//
//  BudgetProgressCard.swift
//  FinFlowCore
//
//  Budget card showing category, progress bar, and spending status
//  Apple Native Design: Solid card with clear information hierarchy
//

import SwiftUI

/// Budget progress card component
/// Shows category icon, name, progress bar, spent/limit amounts, and warning
public struct BudgetProgressCard: View {
    public let budget: BudgetResponse
    public let spentAmount: Double
    public let onTap: () -> Void

    private var progress: Double {
        guard budget.targetAmount > 0 else { return 0 }
        return spentAmount / budget.targetAmount
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return AppColors.google  // Exceeded - red
        } else if progress >= 0.9 {
            return AppColors.google  // Warning - red
        } else if progress >= 0.75 {
            return AppColors.accent  // High - blue
        } else {
            return AppColors.success  // Safe - green
        }
    }

    private var isWarning: Bool {
        progress >= 0.9 && progress < 1.0
    }

    private var isExceeded: Bool {
        progress >= 1.0
    }

    private var categoryColor: Color {
        Color(hex: budget.categoryColor)
    }

    public init(
        budget: BudgetResponse,
        spentAmount: Double,
        onTap: @escaping () -> Void = {}
    ) {
        self.budget = budget
        self.spentAmount = spentAmount
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.md) {
                // Header: Icon + Category Name + Recurring Badge
                HStack(spacing: Spacing.sm) {
                    // Category Icon
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)

                        Image(systemName: budget.categoryIcon)
                            .font(AppTypography.iconMedium)
                            .foregroundStyle(categoryColor)
                    }

                    // Category Name
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text(budget.categoryName)
                            .font(AppTypography.headline)
                            .foregroundStyle(.primary)

                        if budget.isRecurring {
                            HStack(spacing: Spacing.xs / 2) {
                                Image(systemName: "repeat")
                                    .font(AppTypography.caption)
                                Text("Hàng tháng")
                                    .font(AppTypography.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Warning/Exceeded Icon
                    if isExceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.iconMedium)
                            .foregroundStyle(AppColors.google)
                    } else if isWarning {
                        Image(systemName: "exclamationmark.triangle")
                            .font(AppTypography.iconMedium)
                            .foregroundStyle(AppColors.google)
                    }
                }

                // Progress Bar
                ProgressBar(
                    current: spentAmount,
                    total: budget.targetAmount,
                    color: progressColor,
                    height: Spacing.xs
                )

                // Footer: Spent / Limit amounts + Percentage
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Đã chi")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(spentAmount))
                            .font(AppTypography.subheadline)
                            .foregroundStyle(progressColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xs / 2) {
                        Text("Giới hạn")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(budget.targetAmount))
                            .font(AppTypography.subheadline)
                            .foregroundStyle(.primary)
                    }
                }

                // Progress percentage
                Text("\(Int(progress * 100))% đã sử dụng")
                    .font(AppTypography.caption)
                    .foregroundStyle(progressColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Spacing.md)
            .background(AppColors.cardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        isExceeded ? AppColors.google.opacity(OpacityLevel.medium) : Color.clear,
                        lineWidth: BorderWidth.thick
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
