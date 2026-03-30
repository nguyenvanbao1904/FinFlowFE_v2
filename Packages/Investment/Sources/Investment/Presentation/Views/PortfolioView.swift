import FinFlowCore
import SwiftUI

public struct PortfolioView: View {
    private let onAddPortfolio: () -> Void

    public init(onAddPortfolio: @escaping () -> Void) {
        self.onAddPortfolio = onAddPortfolio
    }

    public var body: some View {
        EmptyStateView(
            icon: "badge",
            title: "Danh mục của bạn đang trống",
            subtitle: "Bắt đầu xây dựng danh mục đầu tư của bạn bằng cách tạo danh mục đầu tiên.",
            buttonTitle: "Tạo danh mục đầu tiên",
            action: onAddPortfolio
        )
        .emptyStateFrame()
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xl)
    }
}
