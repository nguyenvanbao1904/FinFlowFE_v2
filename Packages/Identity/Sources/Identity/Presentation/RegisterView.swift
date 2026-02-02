import FinFlowCore
import SwiftUI

public struct RegisterView: View {
    @State private var viewModel: RegisterViewModel
    // Environment dismiss to close view or we rely on Router navigation (here usually Router)
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    public init(viewModel: RegisterViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel
        
        return ZStack {
            // Background Gradient
            backgroundLayer
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    
                    logoSection
                        .padding(.top, Spacing.lg)

                    // Form
                    VStack(spacing: Spacing.md) {
                        // Username
                        GlassTextField(
                            text: $vm.username,
                            placeholder: "Tên đăng nhập",
                            icon: "person"
                        )
                        .textContentType(.username)

                        // Email with Verification
                        VStack(spacing: 12) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                    .frame(width: 25)

                                TextField("Email", text: $vm.email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                
                                if viewModel.isEmailVerified {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.primary)
                                } else if viewModel.isEmailValid {
                                    Button(action: {
                                        Task { await viewModel.sendOTP() }
                                    }) {
                                        if viewModel.isSendingOTP {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Gửi mã")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(AppColors.primary)
                                        }
                                    }
                                    .disabled(viewModel.isSendingOTP)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, Spacing.sm)
                            .background(.ultraThinMaterial)
                            .cornerRadius(CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(
                                        viewModel.isEmailValid ? Color.white.opacity(0.1) : Color.red.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            )
                            
                            // OTP Input
                            if viewModel.showOTPInput {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "key")
                                        .foregroundColor(.secondary)
                                        .frame(width: 25)

                                    TextField("Nhập mã OTP (123456)", text: $vm.otpCode)
                                        .keyboardType(.numberPad)
                                    
                                    Button("Xác nhận") {
                                        Task { await viewModel.verifyOTP() }
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, Spacing.sm)
                                .background(.ultraThinMaterial)
                                .cornerRadius(CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Names
                        HStack(spacing: Spacing.sm) {
                            GlassTextField(
                                text: $vm.firstName,
                                placeholder: "Họ",
                                icon: "person.fill"
                            )
                            GlassTextField(
                                text: $vm.lastName,
                                placeholder: "Tên",
                                icon: "person"
                            )
                        }

                        // Date of Birth
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            
                            DatePicker("Ngày sinh", selection: $vm.dob, displayedComponents: .date)
                                .tint(AppColors.primary)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, Spacing.sm)
                        .background(.ultraThinMaterial)
                        .cornerRadius(CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )

                        // Password
                        GlassSecureField(
                            text: $vm.password,
                            placeholder: "Mật khẩu",
                            icon: "lock"
                        )
                        .textContentType(.newPassword)

                        // Password Confirm
                        GlassSecureField(
                            text: $vm.passwordConfirmation,
                            placeholder: "Xác nhận mật khẩu",
                            icon: "lock.fill"
                        )
                        .textContentType(.newPassword)
                    }
                    .padding(.horizontal)

                    // Register Button
                    PrimaryButton(
                        title: "Đăng ký",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                             await viewModel.register()
                        }
                    }
                    .padding(.horizontal)
                    
                    footerSection
                        .padding(.bottom, 20)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $vm.alert) { appAlert in
            Alert(
                title: Text(appAlert.title),
                message: Text(appAlert.message),
                dismissButton: .default(Text("OK")) {
                    // Logic to navigate logic back or clear form if success
                    if viewModel.isRegistrationSuccess {
                        dismiss()
                    }
                }
            )
        }
    }
    
    // MARK: - Sub-components

    private var backgroundLayer: some View {
        LinearGradient(
            colors: colorScheme == .dark ? AppColors.backgroundDark : AppColors.backgroundLight,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var logoSection: some View {
        VStack(spacing: Spacing.sm) {
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

            Text("Tạo tài khoản mới")
                .font(AppTypography.largeTitle.weight(.bold))
                .font(.system(size: 28)) 
                
            Text("Bắt đầu quản lý tài chính thông minh")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var footerSection: some View {
        HStack {
            Text("Đã có tài khoản?")
                .foregroundColor(.secondary)

            Button("Đăng nhập") {
                dismiss()
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
