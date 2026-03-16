import SwiftUI
import FinFlowCore

public struct InvestmentView: View {
    private let router: any AppRouterProtocol
    
    public init(router: any AppRouterProtocol) {
        self.router = router
    }
    
    public var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(AppTypography.displayXL)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
            VStack(spacing: Spacing.sm) {
                Text("Hệ Sinh Thái Đầu Tư")
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                
                Text("Hệ thống trực quan hóa báo cáo tài chính đồ sộ đang được ấp ủ và sẽ ra mắt trong tương lai.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.cardBackground)
                .frame(height: 200)
                .overlay(
                    Image(systemName: "chart.bar.xaxis")
                        .font(AppTypography.displayLarge)
                        .foregroundStyle(.secondary.opacity(OpacityLevel.medium))
                )
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground)
        .navigationTitle("Đầu tư")
        .navigationBarTitleDisplayMode(.large)
    }
}
