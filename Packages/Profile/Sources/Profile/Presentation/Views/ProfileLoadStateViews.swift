import FinFlowCore
import SwiftUI

struct ProfileLoadingStateView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView("Đang tải dữ liệu...")
                .tint(AppColors.primary)
            Spacer()
        }
    }
}

struct ProfileAuthExpiredStateView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
}

struct ProfileErrorRetryView: View {
    let onRetry: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Text("Không thể tải dữ liệu")
                .font(AppTypography.headline)
            Text("Vui lòng kiểm tra kết nối mạng và thử lại.")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Thử lại", action: onRetry)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            Spacer()
        }
    }
}

struct AccountRestorationSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Chào mừng quay lại!")
                .font(AppTypography.title)
                .fontWeight(.bold)
            Text("Tài khoản của bạn đã được khôi phục thành công.")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("OK") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding(Spacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}
