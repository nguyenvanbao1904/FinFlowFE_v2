//
//  LoginView.swift
//  Identity
//
//  Modern login screen with glassmorphism design
//

import FinFlowCore
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
        .showCustomAlert(alert: $vm.alert)
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

                    SocialLoginButton(provider: .apple) {
                        viewModel.handleAppleLogin()
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
                viewModel.navigateToRegister()
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
