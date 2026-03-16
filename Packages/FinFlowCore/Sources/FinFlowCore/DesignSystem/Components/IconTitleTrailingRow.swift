//
//  IconTitleTrailingRow.swift
//  FinFlowCore
//
//  Shared list row: icon (circle + SF Symbol) + title/subtitle + trailing content.
//  Used by Transaction list and Budget list for consistent appearance.
//

import SwiftUI

/// A list row with a colored icon, title, optional subtitle, and trailing view.
/// Optionally shows a bottom view (e.g. ProgressBar for budget).
public struct IconTitleTrailingRow<Trailing: View, Bottom: View>: View {
    private let icon: String
    private let color: Color
    private let title: String
    private let subtitle: String?
    @ViewBuilder private let trailing: () -> Trailing
    @ViewBuilder private let bottom: () -> Bottom

    public init(
        icon: String,
        color: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.icon = icon
        self.color = color
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.bottom = bottom
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(OpacityLevel.ultraLight))
                        .frame(
                            width: Spacing.lg + Spacing.sm,
                            height: Spacing.lg + Spacing.sm
                        )
                    Image(systemName: icon)
                        .font(AppTypography.iconMedium)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                trailing()
            }

            bottom()
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - No bottom content

extension IconTitleTrailingRow where Bottom == EmptyView {
    public init(
        icon: String,
        color: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.color = color
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.bottom = { EmptyView() }
    }
}
