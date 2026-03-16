//
//  EmptyStateView.swift
//  FinFlowCore
//
//  Reusable empty state: icon + title + optional subtitle + optional CTA.
//  Use in list or full-area layouts for consistent UX across tabs.
//

import SwiftUI

/// Empty state with icon, title, optional subtitle, and optional primary CTA.
/// Use for "no data" screens (e.g. no transactions, no accounts, no budgets).
public struct EmptyStateView: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let buttonTitle: String?
    private let action: (() -> Void)?

    /// - Parameters:
    ///   - icon: SF Symbol name (e.g. "tray", "creditcard", "chart.bar.doc.horizontal").
    ///   - title: Main message (e.g. "Chưa có giao dịch nào").
    ///   - subtitle: Optional secondary line; omit for minimal layout.
    ///   - buttonTitle: Optional CTA label; if nil, no button is shown.
    ///   - action: Optional closure run when the CTA is tapped; required if buttonTitle is set.
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(AppTypography.displaySmall)
                .foregroundStyle(.secondary)

            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle = buttonTitle, let action = action {
                Button(buttonTitle) {
                    action()
                }
                .primaryButton()
                .padding(.top, Spacing.sm)
            }
        }
        .padding()
    }
}

// MARK: - Full-area modifier

extension EmptyStateView {
    /// Use when the empty state should fill the available space (e.g. Planning tab).
    public func emptyStateFrame() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
