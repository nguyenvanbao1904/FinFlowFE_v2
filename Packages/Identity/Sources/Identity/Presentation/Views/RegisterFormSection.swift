import FinFlowCore
import SwiftUI

enum RegisterField: Hashable {
    case username, email, firstName, lastName, password, passwordConfirmation
}

struct RegisterFormSection: View {
    let vm: RegisterViewModel
    let focusedField: FocusState<RegisterField?>.Binding

    var body: some View {
        VStack(spacing: Spacing.md) {
            usernameField
            emailSection
            nameFields
            dobPicker
            passwordGroup
        }
    }

    private var dobPicker: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: UILayout.iconSize)

            DatePicker(
                "Ngày sinh", selection: Binding(get: { vm.dob }, set: { vm.dob = $0 }),
                displayedComponents: .date
            )
            .tint(AppColors.primary)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.glassBorder, lineWidth: 0.5)
        )
    }

    private var usernameField: some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            GlassField(
                text: $vm.username,
                placeholder: "Tên đăng nhập",
                icon: "person"
            )
            .focused(focusedField, equals: .username)
            .textContentType(.username)
            .onChange(of: focusedField.wrappedValue == .username) { _, isFocused in
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
                        .foregroundStyle(
                            message.contains("✅") ? AppColors.success : AppColors.expense)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private var emailSection: some View {
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

    private var nameFields: some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            VStack(spacing: Spacing.xs) {
                GlassField(
                    text: $vm.firstName,
                    placeholder: "Họ",
                    icon: "person.fill"
                )
                .focused(focusedField, equals: .firstName)
                .onChange(of: focusedField.wrappedValue == .firstName) { _, isFocused in
                    if !isFocused { vm.validate(.firstName) }
                }

                if let message = vm.firstNameMessage {
                    HStack {
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundStyle(
                                message.contains("✅") ? AppColors.success : AppColors.expense)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }

            VStack(spacing: Spacing.xs) {
                GlassField(
                    text: $vm.lastName,
                    placeholder: "Tên",
                    icon: "person"
                )
                .focused(focusedField, equals: .lastName)
                .onChange(of: focusedField.wrappedValue == .lastName) { _, isFocused in
                    if !isFocused { vm.validate(.lastName) }
                }

                if let message = vm.lastNameMessage {
                    HStack {
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundStyle(
                                message.contains("✅") ? AppColors.success : AppColors.expense)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }
        }
    }

    private var passwordGroup: some View {
        @Bindable var vm = vm
        return VStack(spacing: Spacing.xs) {
            GlassField(
                text: $vm.password,
                placeholder: "Mật khẩu",
                icon: "lock",
                isSecure: true
            )
            .focused(focusedField, equals: .password)
            .onChange(of: focusedField.wrappedValue == .password) { _, isFocused in
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
                        .foregroundStyle(
                            message.contains("✅") ? AppColors.success : AppColors.expense)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }

            GlassField(
                text: $vm.passwordConfirmation,
                placeholder: "Xác nhận mật khẩu",
                icon: "lock.fill",
                isSecure: true
            )
            .focused(focusedField, equals: .passwordConfirmation)
            .onChange(of: focusedField.wrappedValue == .passwordConfirmation) { _, isFocused in
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
                        .foregroundStyle(
                            message.contains("✅") ? AppColors.success : AppColors.expense)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }
}
