import FinFlowCore
import SwiftUI  // BẮT BUỘC - Để dùng View, State, Environment...

public struct RegisterView: View {
    @State private var viewModel: RegisterViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username, email, firstName, lastName, password, passwordConfirmation
    }

    public init(viewModel: RegisterViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        // Main view logic
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    headerSection
                        .padding(.top, Spacing.lg)

                    formSection(vm: viewModel)
                        .padding(.horizontal)

                    registerButton
                        .padding(.horizontal)

                    footerSection
                        .padding(.bottom, Spacing.lg)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alertHandler($viewModel.alert)
    }

    // MARK: - Subcomponents

    private var headerSection: some View {
        AppLogoHeader(
            title: "Tạo tài khoản mới",
            subtitle: "Bắt đầu quản lý tài chính thông minh"
        )
    }

    private func formSection(vm: RegisterViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            usernameField(vm: vm)
            emailSection(vm: vm)
            nameFields(vm: vm)
            dobPicker(vm: vm)
            passwordGroup(vm: vm)
        }
    }

    private func dobPicker(vm: RegisterViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
                .frame(width: UILayout.iconSize)

            DatePicker(
                "Ngày sinh", selection: Binding(get: { vm.dob }, set: { vm.dob = $0 }),
                displayedComponents: .date
            )
            .tint(AppColors.primary)
        }
        .padding(.vertical, Spacing.sm2)
        .padding(.horizontal, Spacing.sm)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.glassBorder, lineWidth: 0.5)
        )
    }

    private func usernameField(vm: RegisterViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            GlassField(
                text: $vm.username,
                placeholder: "Tên đăng nhập",
                icon: "person"
            )
            .focused($focusedField, equals: .username)
            .textContentType(.username)
            .onChange(of: focusedField == .username) { _, isFocused in
                if !isFocused {
                    vm.validate(.username)
                } else {
                    vm.usernameMessage = nil
                }
            }

            if let message = vm.usernameMessage {
                HStack {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(
                            message.contains("✅") ? AppColors.success : AppColors.google)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private func emailSection(vm: RegisterViewModel) -> some View {
        @Bindable var vm = vm
        return EmailFieldWithOTP(
            email: $vm.email,
            otpCode: $vm.otpCode,
            isEmailVerified: vm.isEmailVerified,
            isEmailValid: vm.isEmailValid,
            showOTPInput: vm.showOTPInput,
            isSendingOTP: vm.isSendingOTP,
            isCheckingEmail: vm.isCheckingEmail,
            canSendOTP: vm.canSendOTP,
            cooldownRemaining: vm.otpCooldownRemaining,
            validationMessage: vm.emailValidationMessage,
            onSendOTP: { await vm.sendOTP() },
            onVerifyOTP: { await vm.verifyOTP() }
        )
    }

    private func nameFields(vm: RegisterViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            // First name field
            VStack(spacing: Spacing.xs) {
                GlassField(
                    text: $vm.firstName,
                    placeholder: "Họ",
                    icon: "person.fill"
                )
                .focused($focusedField, equals: .firstName)
                .onChange(of: focusedField == .firstName) { _, isFocused in
                    if !isFocused { vm.validate(.firstName) }
                }

                if let message = vm.firstNameMessage {
                    HStack {
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundColor(
                                message.contains("✅") ? AppColors.success : AppColors.google)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }

            // Last name field
            VStack(spacing: Spacing.xs) {
                GlassField(
                    text: $vm.lastName,
                    placeholder: "Tên",
                    icon: "person"
                )
                .focused($focusedField, equals: .lastName)
                .onChange(of: focusedField == .lastName) { _, isFocused in
                    if !isFocused { vm.validate(.lastName) }
                }

                if let message = vm.lastNameMessage {
                    HStack {
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundColor(
                                message.contains("✅") ? AppColors.success : AppColors.google)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }
        }
    }

    private func passwordGroup(vm: RegisterViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            // Password field
            GlassField(
                text: $vm.password,
                placeholder: "Mật khẩu",
                icon: "lock",
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            .onChange(of: focusedField == .password) { _, isFocused in
                if !isFocused {
                    vm.validate(.password)
                } else {
                    vm.passwordMessage = nil
                }
            }
            .textContentType(.newPassword)

            if let message = vm.passwordMessage {
                HStack {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(
                            message.contains("✅") ? AppColors.success : AppColors.google)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }

            // Password confirmation field
            GlassField(
                text: $vm.passwordConfirmation,
                placeholder: "Xác nhận mật khẩu",
                icon: "lock.fill",
                isSecure: true
            )
            .focused($focusedField, equals: .passwordConfirmation)
            .onChange(of: focusedField == .passwordConfirmation) { _, isFocused in
                if !isFocused {
                    vm.validate(.passwordConfirmation)
                } else {
                    vm.passwordConfirmationMessage = nil
                }
            }
            .textContentType(.newPassword)

            if let message = vm.passwordConfirmationMessage {
                HStack {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(
                            message.contains("✅") ? AppColors.success : AppColors.google)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private var registerButton: some View {
        Button("Đăng ký") {
            Task { await viewModel.register() }
        }
        .primaryButton(isLoading: viewModel.isLoading)
        .disabled(!viewModel.isFormValid)
    }

    private var footerSection: some View {
        HStack {
            Text("Đã có tài khoản?")
                .foregroundColor(.secondary)
            Button("Đăng nhập") {
                viewModel.navigateToLogin()
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
