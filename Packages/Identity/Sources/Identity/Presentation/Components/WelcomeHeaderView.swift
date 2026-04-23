import FinFlowCore
import LocalAuthentication
import SwiftUI

public struct WelcomeHeaderView: View {
    let displayName: String
    let email: String
    let isLoading: Bool
    let biometryType: LABiometryType
    let onLogin: () -> Void
    let onBiometricLogin: () -> Void

    public init(
        displayName: String,
        email: String,
        isLoading: Bool,
        biometryType: LABiometryType,
        onLogin: @escaping () -> Void,
        onBiometricLogin: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.email = email
        self.isLoading = isLoading
        self.biometryType = biometryType
        self.onLogin = onLogin
        self.onBiometricLogin = onBiometricLogin
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            // Welcome Message
            VStack(spacing: Spacing.xs) {
                Text("Chào mừng trở lại,")
                    .font(AppTypography.title)
                    .foregroundStyle(.primary)

                Text(displayName)
                    .font(AppTypography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.primary)
                    .multilineTextAlignment(.center)
            }

            // Email
            Text(email)
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.md)

            // Login Buttons
            HStack(spacing: Spacing.sm) {
                Button("Đăng nhập", action: onLogin)
                    .primaryButton()

                // Biometric button
                Button {
                    onBiometricLogin()
                } label: {
                    Image(systemName: biometryType == .faceID ? "faceid" : "touchid")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(AppColors.textInverted)
                        .frame(
                            width: UILayout.biometricButtonSize,
                            height: UILayout.biometricButtonSize
                        )
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading)
                .accessibilityLabel(biometryType == .faceID ? "Đăng nhập bằng Face ID" : "Đăng nhập bằng Touch ID")
            }
            .padding(.top, Spacing.xl)
        }
    }
}
