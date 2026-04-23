//
//  LoginView.swift
//  Identity
//
//  Modern login screen with glassmorphism design
//

import FinFlowCore
import GoogleSignIn
import SwiftUI

public struct LoginView: View {
    @Bindable var viewModel: LoginViewModel
    @Environment(\.colorScheme) var colorScheme

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ZStack {
            // Background gradient
            AppColors.appBackground
                .ignoresSafeArea()

            // Main content with safe area
            VStack(spacing: .zero) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        AppLogoHeader()
                            .padding(.top, Spacing.lg)

                        // Hiển thị chào mừng nếu có thông tin lưu trong UserDefaults
                        if let name = viewModel.userDisplayName ?? viewModel.savedEmail {
                            sessionExpiredMessage(name: name, email: viewModel.savedEmail)
                        }

                        loginForm

                        actionSection
                    }
                }

                Spacer()

                footerSection
                    .padding(.bottom, Spacing.sm)
            }
            .padding(.horizontal)
        }
        .loadingOverlay(viewModel.isLoading)
        .alertHandler($viewModel.alert)
        .task {
            await viewModel.refreshSavedUserInfo()
            await viewModel.checkBiometricAvailability()

            // Nếu phiên trước vừa hết hạn (sessionExpired -> Login), hiển thị alert một lần
            if viewModel.isSessionExpired, viewModel.alert == nil {
                viewModel.alert = .auth(
                    message:
                        "Phiên đăng nhập đã hết hạn hoặc không còn hiệu lực. Vui lòng đăng nhập lại."
                )
                viewModel.isSessionExpired = false
            }
        }
    }

    // MARK: - Sub-components

    private func sessionExpiredMessage(name: String, email: String?) -> some View {
        VStack(spacing: Spacing.xs) {
            Text("Xin chào \(name)!")
                .font(AppTypography.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if let email {
                Text(email)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Chào mừng trở lại, vui lòng đăng nhập")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }

    private var loginForm: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: Spacing.md) {
            GlassField(
                text: $vm.username,
                placeholder: "Tên đăng nhập hoặc Email",
                icon: AppAssets.personIcon,
                isSecure: false
            )

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                GlassField(
                    text: $vm.password,
                    placeholder: "Mật khẩu",
                    icon: AppAssets.lockIcon,
                    isSecure: true
                )

                Button("Quên mật khẩu?") {
                    viewModel.navigateToForgotPassword()
                }
                .font(AppTypography.buttonTitle)
                .foregroundStyle(AppColors.primary)
                .padding(.trailing, Spacing.xs)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                Button("Đăng nhập") {
                    Task { await viewModel.login() }
                }
                .primaryButton(isLoading: viewModel.isLoading)

                // Hiển thị nút sinh trắc (disabled nếu thiết bị không hỗ trợ)
                Button {
                    Task { await viewModel.loginWithBiometric() }
                } label: {
                    Image(systemName: viewModel.biometricType == .touchID ? "touchid" : "faceid")
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
                .disabled(viewModel.isLoading)
                .accessibilityLabel(viewModel.biometricType == .touchID ? "Đăng nhập bằng Touch ID" : "Đăng nhập bằng Face ID")
            }

            // Social login section
            VStack(spacing: Spacing.md) {
                // Divider with text
                HStack {
                    Divider()
                    Text("Hoặc tiếp tục với")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                }

                HStack(spacing: Spacing.xl) {
                    SocialLoginButton(provider: .google) {
                        Task { await handleGoogleLogin() }
                    }

                    SocialLoginButton(provider: .apple) {
                        viewModel.handleAppleLogin()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleGoogleLogin() async {
        // The View is responsible for UIKit presentation and Google SDK call only.
        // It extracts the raw idToken and hands it to the ViewModel —
        // no isLoading or error state management here.
        do {
            guard
                let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                let presenter = windowScene.windows.first(where: { $0.isKeyWindow })?
                    .rootViewController
            else {
                viewModel.alert = AppError.validationError("Không tìm thấy cửa sổ hiện tại")
                    .toAppAlert(defaultTitle: "Lỗi")
                return
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                viewModel.alert = AppError.validationError("Không lấy được Google ID token")
                    .toAppAlert(defaultTitle: "Lỗi")
                return
            }

            // Pass only the raw String token — ViewModel handles the rest
            await viewModel.handleGoogleLogin(idToken: idToken)
        } catch {
            // Only GIDSignIn-level errors (e.g. user cancelled) are handled here
            // AppError / network errors are handled inside the ViewModel
            viewModel.alert = error.toAppAlert(defaultTitle: "Lỗi Google Login")
        }
    }
    private var footerSection: some View {
        HStack {
            Text("Chưa có tài khoản?")
                .foregroundStyle(.secondary)

            Button("Đăng ký ngay") {
                viewModel.navigateToRegister()
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
