//
//  LoginView.swift
//  Identity
//
//  Modern login screen with glassmorphism design
//

import FinFlowCore
import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @Environment(\.colorScheme) var colorScheme

    public init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Background gradient
            backgroundLayer
                .ignoresSafeArea()

            // Main content with safe area
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        headerSection
                            .padding(.top, Spacing.lg)

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
        .showCustomAlert(alert: $viewModel.alert)
    }

    // MARK: - Sub-components

    private var backgroundLayer: some View {
        LinearGradient(
            colors: colorScheme == .dark ? AppColors.backgroundDark : AppColors.backgroundLight,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            // App Logo - Try custom asset first, fallback to SF Symbol
            Group {
                if UIImage(named: AppAssets.appLogo) != nil {
                    Image(AppAssets.appLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                } else {
                    // Fallback to SF Symbol
                    Image(systemName: AppAssets.chartIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(AppColors.primary.gradient)
                }
            }
            .shadow(
                color: ShadowStyle.soft().color,
                radius: ShadowStyle.soft().radius,
                x: ShadowStyle.soft().x,
                y: ShadowStyle.soft().y
            )

            Text("FinFlow")
                .font(AppTypography.largeTitle)

            Text("Quản lý tài chính thông minh")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loginForm: some View {
        VStack(spacing: 18) {
            GlassyTextField(
                icon: AppAssets.personIcon,
                placeholder: "Tên đăng nhập hoặc Email",
                text: $viewModel.username
            )

            VStack(alignment: .trailing, spacing: 8) {
                GlassyTextField(
                    icon: AppAssets.lockIcon,
                    placeholder: "Mật khẩu",
                    text: $viewModel.password,
                    isSecure: true
                )

                Button("Quên mật khẩu?") {
                    // TODO: Handle forgot password
                }
                .font(AppTypography.buttonTitle)
                .foregroundStyle(AppColors.primary)
                .padding(.trailing, 5)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: Spacing.lg) {
            // Login button
            PrimaryButton(
                title: "Đăng nhập",
                isLoading: viewModel.isLoading
            ) {
                Task { await viewModel.login() }
            }

            // Social login section
            VStack(spacing: Spacing.md) {
                DividerWithText("Hoặc tiếp tục với")

                HStack(spacing: 25) {
                    SocialLoginButton(provider: .google) {
                        Task {
                            await viewModel.handleGoogleLogin()
                        }
                    }

                    SocialLoginButton(provider: .facebook) {
                        // TODO: Handle Facebook login
                        print("Facebook login tapped")
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text("Chưa có tài khoản?")
                .foregroundColor(.secondary)

            Button("Đăng ký ngay") {
                // TODO: Navigate to register screen
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
