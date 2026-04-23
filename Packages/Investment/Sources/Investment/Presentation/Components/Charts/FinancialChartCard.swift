import FinFlowCore
import SwiftUI

struct FinancialChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let subtitleColor: Color
    let onExpand: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption2)
                            .foregroundStyle(subtitleColor)
                    }
                }
                Spacer()
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: UILayout.toolbarButton, height: UILayout.toolbarButton)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Circle())
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Phóng to biểu đồ \(title)")
            }

            content()
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}
