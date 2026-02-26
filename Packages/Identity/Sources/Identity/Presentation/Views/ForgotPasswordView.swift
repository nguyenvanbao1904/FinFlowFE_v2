import FinFlowCore
import SwiftUI

public struct ForgotPasswordView: View {
    @State private var viewModel: ForgotPasswordViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var otpFocused: Bool

    public init(viewModel: ForgotPasswordViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ZStack {
            // Background Gradient
            AppBackgroundGradient()

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
                                    .foregroundColor(.secondary)
                                Text(viewModel.email)
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.primary)

                                PINCodeInput(
                                    pin: $vm.otpCode,
                                    isFocused: $otpFocused,
                                    displayMode: .numbers
                                )
                                .padding(.vertical, Spacing.xs)

                                PrimaryButton(title: "Xác Thực") {
                                    Task {
                                        await viewModel.verifyOtp()
                                    }
                                }
                                .disabled(viewModel.otpCode.count < 6)

                                Button("Gửi lại mã?") {
                                    Task { await viewModel.sendOtp() }
                                }
                                .font(AppTypography.caption)
                                .foregroundColor(.secondary)
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
        @Bindable var vm = viewModel
        return VStack(spacing: Spacing.lg) {
            Text("Nhập email của bạn để nhận mã xác thực OTP")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Dùng EmailFieldWithOTP component (giống RegisterView)
            EmailFieldWithOTP(
                email: $vm.email,
                otpCode: .constant(""),  // Không dùng inline OTP ở đây
                isEmailVerified: false,  // Forgot password không cần verify inline
                isEmailValid: viewModel.isEmailValid,
                showOTPInput: false,  // Không show OTP input inline
                isSendingOTP: viewModel.isSendingOTP,
                isCheckingEmail: viewModel.isCheckingEmail,
                canSendOTP: false,  // Disable inline button
                showSendButton: false,  // Ẩn nút gửi mã trong input
                validationMessage: viewModel.emailValidationMessage,
                onSendOTP: {},  // No-op, dùng button bên dưới
                onVerifyOTP: {}  // No-op
            )

            PrimaryButton(
                title: "Gửi Mã OTP",
                isLoading: viewModel.isSendingOTP
            ) {
                Task {
                    await viewModel.sendOtp()
                }
            }
            .disabled(!viewModel.canSendOTP)
        }
    }


    // MARK: - Step 3: Reset Password
    private var resetPasswordView: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: Spacing.lg) {
            Text("Thiết lập mật khẩu mới")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.primary) // Used AppColors.primary for emphasis

            GlassSecureField(text: $vm.password, placeholder: "Mật khẩu mới", icon: "lock.fill")
            GlassSecureField(
                text: $vm.confirmPassword, placeholder: "Xác nhận mật khẩu", icon: "lock.rotation")

            PrimaryButton(title: "Đổi Mật Khẩu") {
                Task {
                    await viewModel.resetPassword()  // This is safe now, no double wrapping
                }
            }
        }
    }
}

