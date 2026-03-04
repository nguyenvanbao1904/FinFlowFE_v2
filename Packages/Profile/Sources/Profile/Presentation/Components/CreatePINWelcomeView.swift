import FinFlowCore
import SwiftUI

struct CreatePINWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon với animation
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 30, x: 0, y: 15)

                Image(systemName: "lock.shield.fill")
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(AppColors.primary)
            }

            VStack(spacing: Spacing.md) {
                Text("Bảo Mật Tài Khoản")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(.primary)

                Text("Tạo mã PIN để bảo vệ tài khoản của bạn")
                    .font(AppTypography.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            VStack(alignment: .leading, spacing: Spacing.lg) {
                FeatureRow(
                    icon: "checkmark.shield.fill",
                    title: "Bảo mật cao",
                    description: "Mã PIN được mã hóa SHA-256"
                )

                FeatureRow(
                    icon: "key.fill",
                    title: "Bảo vệ tokens",
                    description: "Access & Refresh Token được bảo vệ"
                )

                FeatureRow(
                    icon: "faceid",
                    title: "Dễ dàng sử dụng",
                    description: "Chỉ cần 6 số đơn giản"
                )
            }
            .padding(.horizontal, Spacing.lg)
            
            Spacer()

            // Next Button
            GradientButton(
                title: "Bắt Đầu",
                icon: "arrow.right",
                style: .primary,
                action: onNext
            )
            .padding(.horizontal, Spacing.md)
            // swiftlint:disable:next no_hardcoded_padding
            .padding(.bottom, 60.0)
        }
    }
}

// MARK: - Feature Row Component
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
