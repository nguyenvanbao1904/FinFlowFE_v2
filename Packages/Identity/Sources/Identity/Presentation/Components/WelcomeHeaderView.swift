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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.md)

            // Login Buttons
            HStack(spacing: 12) {
                PrimaryButton(
                    title: "Đăng nhập",
                    isLoading: false, // Loading handled by parent or specific button state
                    action: onLogin
                )

                // Biometric button
                Button {
                    onBiometricLogin()
                } label: {
                    Image(systemName: biometryType == .faceID ? "faceid" : "touchid")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading)
            }
            .padding(.top, Spacing.xl)
        }
    }
}
