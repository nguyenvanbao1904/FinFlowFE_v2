import FinFlowCore
import SwiftUI

public struct TransactionAIInsight: Identifiable {
    public let id: String
    public let title: String
    public let message: String
    public let icon: String
    public let color: Color

    public init(id: String, title: String, message: String, icon: String, color: Color) {
        self.id = id
        self.title = title
        self.message = message
        self.icon = icon
        self.color = color
    }
}

struct TransactionAnalyticsAIInsightsSection: View {
    let insights: [TransactionAIInsight]

    var body: some View {
        Section {
            ForEach(insights) { insight in
                insightRow(insight)
                    .padding(.vertical, AppSpacing.xs)
            }
        } header: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColors.accent)
                Text("Trợ lý AI Phân Tích")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
            }
            .textCase(nil)
        }
    }

    private func insightRow(_ insight: TransactionAIInsight) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle()
                .fill(insight.color.opacity(OpacityLevel.light))
                .frame(width: AppSpacing.iconMedium, height: AppSpacing.iconMedium)
                .overlay {
                    Image(systemName: insight.icon)
                        .foregroundStyle(insight.color)
                        .font(AppTypography.caption)
                }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(insight.title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(insight.message)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(AppSpacing.xs / 2)
            }
        }
    }
}

struct TransactionAnalyticsChartStateView: View {
    let icon: String?
    let title: String?
    let showProgress: Bool
    let hasLoadError: Bool
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if showProgress {
                ProgressView()
            } else {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.displayLarge)
                        .foregroundStyle(.secondary.opacity(OpacityLevel.strong))
                }
                if let title {
                    Text(title)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }
                if hasLoadError, let onRetry {
                    Button("Thử lại") { onRetry() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}
