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
            AIInsightCard(items: insights.map(\.cardItem))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
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
}

private extension TransactionAIInsight {
    var cardItem: AIInsightCardItem {
        AIInsightCardItem(
            id: id,
            title: title,
            message: message,
            systemImage: icon,
            tint: color
        )
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
