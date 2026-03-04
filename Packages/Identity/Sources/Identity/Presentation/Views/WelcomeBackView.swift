//
//  WelcomeBackView.swift
//  Identity
//

import FinFlowCore
import SwiftUI
import LocalAuthentication

public struct WelcomeBackView: View {
    @State private var viewModel: WelcomeBackViewModel

    public init(viewModel: WelcomeBackViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ZStack {
            AppBackgroundGradient()

            VStack(spacing: Spacing.xl) {
                // Logo
                AppLogoHeader()
                    .padding(.top, Spacing.xl * 2)

                Spacer()

                // Welcome Screen (always show)
                WelcomeHeaderView(
                    displayName: viewModel.displayName,
                    email: viewModel.email,
                    isLoading: viewModel.isLoading,
                    biometryType: viewModel.biometricType,
                    onLogin: { 
                        viewModel.showPINInputScreen() 
                    },
                    onBiometricLogin: { 
                        Task { await viewModel.loginWithBiometric() } 
                    }
                )

                Spacer()

                // Switch Account Button
                Button(action: viewModel.switchAccount) {
                    Text("Đăng nhập tài khoản khác")
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, Spacing.lg)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .ignoresSafeArea()
        .pinInputSheet(
            isPresented: $viewModel.showPINInput,
            pin: $viewModel.pin,
            title: "Nhập mã PIN",
            subtitle: "Để tiếp tục với \(viewModel.email)",
            showConfirmButton: true,
            isLoading: viewModel.isLoading,
            allowDismissal: true,
            onComplete: { _ in Task { await viewModel.authenticateWithPIN() } },
            onCancel: {
                viewModel.showPINInput = false
                viewModel.pin = ""
            },
            onForgotPIN: viewModel.forgotPIN,
            alert: $vm.alert
        )
        // OTP Input Sheet for PIN Reset
        .pinInputSheet(
            isPresented: $vm.showOtpInput,
            pin: $vm.otpCode,
            title: "Đặt lại mã PIN",
            subtitle: "Mã OTP đã gửi đến\n\(viewModel.email)",
            showConfirmButton: true,
            isLoading: viewModel.isLoading,
            displayMode: .numbers,
            allowDismissal: true,
            onComplete: { _ in Task { await viewModel.verifyPinResetOTP() } },
            onCancel: {
                viewModel.otpCode = ""
                viewModel.showOtpInput = false
            },
            onDismiss: { viewModel.otpCode = "" },
            alert: $vm.alert
        )
        // Password Input Sheet for Reset PIN (dùng chung với Dashboard xóa tài khoản)
        .passwordConfirmationSheet(
            isPresented: $vm.showPasswordForReset,
            password: $vm.resetPasswordInput,
            title: "Xác nhận mật khẩu",
            subtitle: "Vui lòng nhập mật khẩu đăng nhập để xác thực và tạo mã PIN mới.",
            placeholder: "Mật khẩu",
            confirmTitle: "Xác nhận",
            confirmRoleDestructive: false,
            allowDismissal: true,
            onConfirm: { viewModel.verifyPasswordAndResetPIN() },
            onCancel: {
                viewModel.resetPasswordInput = ""
                viewModel.showPasswordForReset = false
            },
            onDismiss: { viewModel.resetPasswordInput = "" },
            alert: $vm.alert
        )
        // Overlay Alert Handler (khi không có sheet nào đang mở)
        .overlay {
            if !viewModel.showPINInput && !viewModel.showPasswordForReset && !viewModel.showOtpInput {
                Color.clear.alertHandler($viewModel.alert)
            }
        }
    }
}

// swiftlint:disable force_try no_business_logic_in_view
#Preview {
    WelcomeBackView(
        viewModel: WelcomeBackViewModel(
            email: "bao@example.com",
            firstName: "Bảo",
            lastName: "Nguyễn Văn",
            sessionManager: SessionManager(
                tokenStore: AuthTokenStore(keychain: KeychainService()),
                authRepository: AuthRepository(
                    client: APIClient(
                        config: NetworkConfig(baseURL: "https://api.example.com"),
                        tokenStore: AuthTokenStore(keychain: KeychainService()),
                        apiVersion: "1"
                    ),
                    tokenStore: AuthTokenStore(keychain: KeychainService()),
                    cacheService: try! FileCacheService()
                ),
                userDefaultsManager: UserDefaultsManager(),
                pinManager: PINManager(keychain: KeychainService())
            ),
            authRepository: AuthRepository(
                client: APIClient(
                    config: NetworkConfig(baseURL: "https://api.example.com"),
                    tokenStore: AuthTokenStore(keychain: KeychainService()),
                    apiVersion: "1"
                ),
                tokenStore: AuthTokenStore(keychain: KeychainService()),
                cacheService: try! FileCacheService()
            ),
            otpHandler: OTPInputHandler(
                repository: AuthRepository(
                    client: APIClient(
                        config: NetworkConfig(baseURL: "https://api.example.com"),
                        tokenStore: AuthTokenStore(keychain: KeychainService()),
                        apiVersion: "1"
                    ),
                    tokenStore: AuthTokenStore(keychain: KeychainService()),
                    cacheService: try! FileCacheService()
                )
            ),
            onSwitchAccount: {}
        )
    )
}
// swiftlint:enable force_try no_business_logic_in_view
