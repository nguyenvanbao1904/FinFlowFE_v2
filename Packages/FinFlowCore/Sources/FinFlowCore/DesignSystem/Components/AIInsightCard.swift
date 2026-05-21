//
//  AIInsightCard.swift
//  FinFlowCore
//
//  Shared AI insight card for Dashboard, Transaction analytics, and Investment.
//

import SwiftUI

public struct AIInsightCardItem: Identifiable {
    public let id: String
    public let title: String
    public let message: String
    public let systemImage: String
    public let tint: Color

    public init(
        id: String,
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }
}

public struct AIInsightCard: View {
    private let items: [AIInsightCardItem]
    private let isLoading: Bool
    private let loadingMessage: String
    private let actionTitle: String?
    private let actionSystemImage: String
    private let onAction: (() -> Void)?

    public init(
        items: [AIInsightCardItem],
        isLoading: Bool = false,
        loadingMessage: String = "Đang phân tích...",
        actionTitle: String? = nil,
        actionSystemImage: String = "chevron.right",
        onAction: (() -> Void)? = nil
    ) {
        self.items = items
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isLoading {
                loadingRow
            } else {
                ForEach(items) { item in
                    insightRow(item)

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }

            if let actionTitle, let onAction, !isLoading, !items.isEmpty {
                Divider()
                actionButton(title: actionTitle, action: onAction)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.large))
    }

    private var loadingRow: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .tint(AppColors.primary)

            Text(loadingMessage)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightRow(_ item: AIInsightCardItem) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            icon(systemImage: item.systemImage, tint: item.tint)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.message)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func icon(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(AppTypography.subheadline)
            .foregroundStyle(tint)
            .frame(width: Spacing.iconMedium, height: Spacing.iconMedium)
            .background(tint.opacity(OpacityLevel.ultraLight))
            .clipShape(.circle)
            .accessibilityHidden(true)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "brain")
                    .font(AppTypography.subheadline)

                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: actionSystemImage)
                    .font(AppTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(AppColors.primary)
        }
        .buttonStyle(.plain)
    }
}
