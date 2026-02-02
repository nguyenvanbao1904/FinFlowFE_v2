import FinFlowCore
import SwiftUI

public struct ForgotPasswordView: View {
    @State private var viewModel: ForgotPasswordViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: ForgotPasswordViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
    
    public var body: some View {
        @Bindable var vm = viewModel
        
        return ZStack {
            // Background Gradient
            LinearGradient(
                colors: colorScheme == .dark ? AppColors.backgroundDark : AppColors.backgroundLight,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    // Header
                    Text("Quên Mật Khẩu")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .padding(.top, 60)
                    
                    // Steps Content
                    VStack(spacing: 20) {
                        switch viewModel.step {
                        case .inputEmail:
                            emailInputView
                        case .inputOtp:
                            otpInputView
                        case .resetPassword:
                            resetPasswordView
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .alert(item: $vm.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onChange(of: viewModel.isSuccess) { _, success in
            if success {
                dismiss() // Go back to Login
            }
        }
    }
    
    // MARK: - Step 1: Input Email
    private var emailInputView: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 25) {
            Text("Nhập email của bạn để nhận mã xác thực OTP")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 5) {
                GlassTextField(text: $vm.email, placeholder: "Email", icon: "envelope.fill", keyboardType: .emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                
                if let errorMsg = viewModel.emailValidationMessage {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 5)
                        .transition(.opacity)
                }
            }
            
            PrimaryButton(title: "Gửi Mã OTP") {
                Task {
                    await viewModel.sendOtp()
                }
            }
            .disabled(!viewModel.isEmailExistenceVerified || viewModel.email.isEmpty)
            .opacity((!viewModel.isEmailExistenceVerified || viewModel.email.isEmpty) ? 0.6 : 1.0)
        }
    }
    
    // MARK: - Step 2: Input OTP
    private var otpInputView: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 25) {
            Text("Mã OTP đã được gửi đến")
                .foregroundColor(.secondary)
            Text(viewModel.email)
                .font(.headline)
                .foregroundColor(.primary)
            
            GlassTextField(text: $vm.otpCode, placeholder: "Nhập mã OTP (6 số)", icon: "lock.shield.fill", keyboardType: .numberPad)
                .textContentType(.oneTimeCode)
            
            PrimaryButton(title: "Xác Thực") {
                Task {
                    await viewModel.verifyOtp()
                }
            }
            .disabled(viewModel.otpCode.count < 6)
            
            Button("Gửi lại mã?") {
                Task { await viewModel.sendOtp() }
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Step 3: Reset Password
    private var resetPasswordView: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 25) {
            Text("Thiết lập mật khẩu mới")
                .font(.headline)
                .foregroundColor(.primary)
            
            GlassSecureField(text: $vm.password, placeholder: "Mật khẩu mới", icon: "lock.fill")
            GlassSecureField(text: $vm.confirmPassword, placeholder: "Xác nhận mật khẩu", icon: "lock.rotation")
            
            PrimaryButton(title: "Đổi Mật Khẩu") {
                Task {
                    await viewModel.resetPassword() // This is safe now, no double wrapping
                }
            }
        }
    }
}
