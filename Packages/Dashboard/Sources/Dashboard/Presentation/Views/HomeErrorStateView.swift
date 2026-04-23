import FinFlowCore
import SwiftUI

struct HomeErrorStateView: View {
    let error: AppErrorAlert
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.error)
                .accessibilityHidden(true)
            Text(error.title)
                .font(AppTypography.displaySmall)
                .multilineTextAlignment(.center)
            Text(error.message)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("Thử lại")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Tải lại dữ liệu tổng quan")
        }
        .padding(Spacing.xl)
    }
}
