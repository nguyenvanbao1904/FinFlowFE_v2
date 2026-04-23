import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = AppColors.success,
        expandKind: ChartKind,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        FinancialChartCard(
            title: title,
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            onExpand: { expandChartFullscreen(expandKind) }
        ) {
            content()
        }
    }
}

