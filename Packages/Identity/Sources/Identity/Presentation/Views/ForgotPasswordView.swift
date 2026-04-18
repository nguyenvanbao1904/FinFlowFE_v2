import FinFlowCore
import SwiftUI

public struct ForgotPasswordView: View {
    @Bindable var viewModel: ForgotPasswordViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var otpFocused: Bool

    public init(viewModel: ForgotPasswordViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Background Gradient
            AppColors.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Header
                    // Replaced manual Text with AppLogoHeader for consistency
                    AppLogoHeader(
                        title: "Quên Mật Khẩu",
                        subtitle: "Khôi phục quyền truy cập tài khoản"
                    )
                    .padding(.top, Spacing.xl * 2)

                    // Steps Content - inline to allow FocusState to work properly
                    VStack(spacing: Spacing.lg) {
                        switch viewModel.step {
                        case .inputEmail:
                            emailInputView
                        case .inputOtp:
                            // Inline OTP view to fix FocusState warning
                            VStack(spacing: Spacing.lg) {
                                Text("Mã OTP đã được gửi đến")
                                    .foregroundStyle(.secondary)
                                Text(viewModel.email)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(AppColors.primary)

                                PINCodeInput(
                                    pin: $viewModel.otpCode,
                                    isFocused: $otpFocused,
                                    displayMode: .numbers
                                )
                                .padding(.vertical, Spacing.xs)

                                Button("Xác Thực") {
                                    Task {
                                        await viewModel.verifyOtp()
                                    }
                                }
                                .primaryButton()
                                .disabled(viewModel.otpCode.count < 6)

                                Button("Gửi lại mã?") {
                                    Task { await viewModel.sendOtp() }
                                }
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                            }
                            .task(id: viewModel.step) {
                                // Activate focus when entering OTP step
                                // .task automatically handles lifecycle
                                if viewModel.step == .inputOtp {
                                    otpFocused = true
                                }
                            }
                        case .resetPassword:
                            resetPasswordView
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                    Spacer(minLength: Spacing.xl)
                }
                .padding()
            }
        }
        .loadingOverlay(viewModel.isLoading)
        .alertHandler($viewModel.alert, onDismiss: { viewModel.handleSuccessAlertDismissed() })
    }

    // MARK: - Step 1: Input Email
    private var emailInputView: some View {
        VStack(spacing: Spacing.lg) {
            Text("Nhập email của bạn để nhận mã xác thực OTP")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Dùng EmailFieldWithOTP component (giống RegisterView)
            EmailFieldWithOTP(
                email: $viewModel.email,
                otpCode: .constant(""),
                config: EmailOTPConfig(
                    isEmailValid: viewModel.isEmailValid,
                    isSendingOTP: viewModel.isSendingOTP,
                    isCheckingEmail: viewModel.isCheckingEmail,
                    canSendOTP: false,
                    showSendButton: false,
                    validationMessage: viewModel.emailValidationMessage
                ),
                onSendOTP: {},
                onVerifyOTP: {}
            )

            Button("Gửi Mã OTP") {
                Task {
                    await viewModel.sendOtp()
                }
            }
            .primaryButton(isLoading: viewModel.isSendingOTP)
            .disabled(!viewModel.canSendOTP)
        }
    }

    // MARK: - Step 3: Reset Password
    private var resetPasswordView: some View {
        VStack(spacing: Spacing.lg) {
            Text("Thiết lập mật khẩu mới")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)

            GlassField(
                text: $viewModel.password, placeholder: "Mật khẩu mới", icon: "lock.fill", isSecure: true)
            GlassField(
                text: $viewModel.confirmPassword, placeholder: "Xác nhận mật khẩu", icon: "lock.rotation",
                isSecure: true)

            Button("Đổi Mật Khẩu") {
                Task {
                    await viewModel.resetPassword()  // This is safe now, no double wrapping
                }
            }
            .primaryButton()
        }
    }
}
