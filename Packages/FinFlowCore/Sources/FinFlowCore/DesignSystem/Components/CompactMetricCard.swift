//
//  CompactMetricCard.swift
//  FinFlowCore
//
//  Ô snapshot dùng chung: Trang chủ (Tóm tắt / Đi nhanh), Phân tích cổ phiếu (MobileInsightSnapshot), …
//

import SwiftUI

// MARK: - Lưới 2×2 dùng chung

/// Cột và khoảng cách cho mọi màn dùng ô snapshot giống nhau.
public enum SnapshotGridLayout {
    public static let spacing: CGFloat = Spacing.sm
    public static var twoColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm),
        ]
    }
}

// MARK: - Shell

fileprivate struct SnapshotGridCell<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

// MARK: - CompactMetricCard

/// Ô metric hoặc lối tắt (cùng khung: nhãn / giá trị / mô tả / thanh accent).
public struct CompactMetricCard: View {
    private let accent: Color
    private let kind: Kind

    private enum Kind {
        case metric(title: String, value: String, caption: String)
        case shortcut(systemImage: String, headline: String, caption: String)
    }

    /// Snapshot số liệu (ROE, Thu, Chi, …).
    public init(title: String, value: String, caption: String, accent: Color) {
        self.accent = accent
        self.kind = .metric(title: title, value: value, caption: caption)
    }

    /// Lối tắt tab: icon + dòng đậm + dòng phụ (mặc định “Chạm để mở”) — cùng ô với metric.
    public init(systemImage: String, headline: String, caption: String = "Chạm để mở", accent: Color) {
        self.accent = accent
        self.kind = .shortcut(systemImage: systemImage, headline: headline, caption: caption)
    }

    public var body: some View {
        SnapshotGridCell {
            switch kind {
            case .metric(let title, let value, let caption):
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Text(value)
                        .font(AppTypography.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.apple)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(caption)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    accentBar(accent)
                }

            case .shortcut(let systemImage, let headline, let caption):
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: systemImage)
                        .font(AppTypography.headline)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(accent.opacity(0.85))
                        .accessibilityHidden(true)

                    Text(headline)
                        .font(AppTypography.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.apple)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(caption)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    accentBar(accent)
                }
            }
        }
    }
}

private func accentBar(_ accent: Color) -> some View {
    Rectangle()
        .fill(accent.opacity(0.85))
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.hairline))
}
