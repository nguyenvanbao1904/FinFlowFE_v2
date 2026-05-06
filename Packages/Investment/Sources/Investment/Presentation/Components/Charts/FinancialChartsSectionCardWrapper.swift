import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = AppColors.success,
        explanation: String? = nil,
        expandKind: ChartKind,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        FinancialChartCard(
            title: title,
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            explanation: explanation,
            onExpand: { expandChartFullscreen(expandKind) }
        ) {
            content()
        }
    }
}
