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
    @State private var viewModel: LoginViewModel
    @Environment(\.colorScheme) var colorScheme

    public init(viewModel: LoginViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ZStack {
            // Background gradient
            AppBackgroundGradient()

            // Main content with safe area
            VStack(spacing: 0) {
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
                    .padding(.bottom, 10)
            }
            .padding(.horizontal)
        }
        .loadingOverlay(viewModel.isLoading)
        .alertHandler($viewModel.alert)
        .task {
            await viewModel.refreshSavedUserInfo()
            await viewModel.checkBiometricAvailability()
        }
    }

    // MARK: - Sub-components

    private func sessionExpiredMessage(name: String, email: String?) -> some View {
        VStack(spacing: 8) {
            Text("Xin chào \(name)!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if let email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Chào mừng trở lại, vui lòng đăng nhập")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }

    private var loginForm: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 18) {
            GlassTextField(
                text: $vm.username,
                placeholder: "Tên đăng nhập hoặc Email",
                icon: AppAssets.personIcon
            )

            VStack(alignment: .trailing, spacing: 8) {
                GlassSecureField(
                    text: $vm.password,
                    placeholder: "Mật khẩu",
                    icon: AppAssets.lockIcon
                )

                Button("Quên mật khẩu?") {
                    viewModel.navigateToForgotPassword()
                }
                .font(AppTypography.buttonTitle)
                .foregroundStyle(AppColors.primary)
                .padding(.trailing, 5)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: 12) {
                PrimaryButton(
                    title: "Đăng nhập",
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.login() }
                }

                // Hiển thị nút sinh trắc (disabled nếu thiết bị không hỗ trợ)
                Button {
                    Task { await viewModel.loginWithBiometric() }
                } label: {
                    Image(systemName: viewModel.biometricType == .touchID ? "touchid" : "faceid")
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
                .disabled(viewModel.isLoading)
            }

            // Social login section
            VStack(spacing: Spacing.md) {
                DividerWithText("Hoặc tiếp tục với")

                HStack(spacing: 25) {
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
        viewModel.isLoading = true
        defer { viewModel.isLoading = false }

        do {
            guard
                let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                let presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
                throw AppError.validationError("Không tìm thấy cửa sổ hiện tại")
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppError.validationError("Không lấy được Google ID token")
            }

            await viewModel.loginWithGoogle(idToken: idToken)
        } catch {
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
