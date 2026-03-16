//
//  FinancialHeroCard.swift
//  FinFlowCore
//
//  Hero card component for financial overview sections
//  Used in Budget (total overview) and Transaction (balance summary) screens
//  Features dark background with high contrast for visual hierarchy
//

import SwiftUI

/// Hero card displaying prominent financial information with dark background
/// Designed to be the focal point at top of Budget and Transaction screens
public struct FinancialHeroCard<Content: View>: View {
    private let title: String
    private let mainAmount: String
    private let subtitle: String?
    private let content: Content

    /// Create a hero card with custom content
    /// - Parameters:
    ///   - title: Small label above main amount (e.g., "Tổng số dư", "Tổng quan")
    ///   - mainAmount: Large prominent amount to display
    ///   - subtitle: Optional text below main amount
    ///   - backgroundColor: Card background color (defaults to primary brand)
    ///   - content: Additional content below main amount section
    public init(
        title: String,
        mainAmount: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.mainAmount = mainAmount
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Title label
            Text(title)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Main hero amount - largest text on screen
            Text(mainAmount)
                .font(AppTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textInverted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textInverted.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Custom content area
            content
                .foregroundStyle(AppColors.textInverted)
        }
        .environment(\.colorScheme, .dark)
        .padding(Spacing.lg)
        .background(
            ZStack {
                // Base vibrant color
                AppColors.primary.opacity(0.9)

                // Subtle material overlay for liquid glass texture
                // swiftlint:disable:next liquid_glass_materials_guideline
                Color.clear.background(.ultraThinMaterial).opacity(0.5)
            }
        )
        .overlay(
            // Glass reflection highlight
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppColors.textInverted.opacity(0.5), AppColors.textInverted.opacity(0.1), .clear, AppColors.textInverted.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(CornerRadius.large)
        .shadow(
            color: AppColors.primary.opacity(0.3),
            radius: Spacing.sm,
            x: 0,
            y: Spacing.xs / 2
        )
    }
}

// MARK: - Convenience Initializer (No Additional Content)

extension FinancialHeroCard where Content == EmptyView {
    /// Create a simple hero card with just title and amount (no additional content)
    /// - Parameters:
    ///   - title: Small label above main amount
    ///   - mainAmount: Large prominent amount to display
    ///   - subtitle: Optional text below main amount
    public init(
        title: String,
        mainAmount: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.mainAmount = mainAmount
        self.subtitle = subtitle
        self.content = EmptyView()
    }
}
