import FinFlowCore
import SwiftUI

struct FinancialChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let subtitleColor: Color
    let explanation: String?
    let onExpand: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var showExplanation = false

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
                if explanation != nil {
                    Button { showExplanation = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.primary)
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Giải thích \(title)")
                }
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
        .sheet(isPresented: $showExplanation) {
            if let text = explanation {
                SheetContainer(title: title, detents: [.medium]) {
                    ScrollView {
                        Text(text)
                            .font(AppTypography.body)
                            .padding(Spacing.lg)
                    }
                }
            }
        }
    }
}
