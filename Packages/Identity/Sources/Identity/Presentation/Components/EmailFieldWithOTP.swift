//
//  EmailFieldWithOTP.swift
//  Identity
//
//  MOVED FROM: FinFlowCore (Identity-specific component)
//  Reusable Email field with OTP verification
//

import FinFlowCore
import SwiftUI

/// Reusable Email field với OTP verification
/// Dùng cho Register và ForgotPassword flows
struct EmailFieldWithOTP: View {
    @Binding var email: String
    @Binding var otpCode: String

    let isEmailVerified: Bool
    let isEmailValid: Bool
    let showOTPInput: Bool
    let isSendingOTP: Bool
    let isVerifyingOTP: Bool
    let isCheckingEmail: Bool
    let canSendOTP: Bool
    let cooldownRemaining: Int
    let showSendButton: Bool
    let validationMessage: String?

    let onSendOTP: () async -> Void
    let onVerifyOTP: () async -> Void

    init(
        email: Binding<String>,
        otpCode: Binding<String>,
        isEmailVerified: Bool,
        isEmailValid: Bool,
        showOTPInput: Bool,
        isSendingOTP: Bool,
        isVerifyingOTP: Bool = false,
        isCheckingEmail: Bool = false,
        canSendOTP: Bool = true,
        cooldownRemaining: Int = 0,
        showSendButton: Bool = true,
        validationMessage: String? = nil,
        onSendOTP: @escaping () async -> Void,
        onVerifyOTP: @escaping () async -> Void
    ) {
        self._email = email
        self._otpCode = otpCode
        self.isEmailVerified = isEmailVerified
        self.isEmailValid = isEmailValid
        self.showOTPInput = showOTPInput
        self.isSendingOTP = isSendingOTP
        self.isVerifyingOTP = isVerifyingOTP
        self.isCheckingEmail = isCheckingEmail
        self.canSendOTP = canSendOTP
        self.cooldownRemaining = cooldownRemaining
        self.showSendButton = showSendButton
        self.validationMessage = validationMessage
        self.onSendOTP = onSendOTP
        self.onVerifyOTP = onVerifyOTP
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Email Input with Action Button
            EmailFieldRow(
                email: $email,
                isVerified: isEmailVerified,
                isValid: isEmailValid,
                isChecking: isCheckingEmail,
                isSending: isSendingOTP,
                showButton: showSendButton,
                canSend: canSendOTP,
                cooldown: cooldownRemaining,
                onSendOTP: onSendOTP
            )

            // Validation Message
            if let message = validationMessage {
                HStack {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(
                            message.contains("✅") ? AppColors.success : AppColors.expense)
                    Spacer()
                }
                // swiftlint:disable:next no_hardcoded_padding
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // OTP Input
            if showOTPInput {
                OTPFieldRow(
                    otpCode: $otpCode,
                    isVerifying: isVerifyingOTP,
                    onVerifyOTP: onVerifyOTP
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Email Field Row

private struct EmailFieldRow: View {
    @Binding var email: String
    @FocusState private var isFocused: Bool

    let isVerified: Bool
    let isValid: Bool
    let isChecking: Bool
    let isSending: Bool
    let showButton: Bool
    let canSend: Bool
    let cooldown: Int
    let onSendOTP: () async -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "envelope")
                .foregroundStyle(.secondary)
                .frame(width: UILayout.iconSize)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .disabled(isVerified)
                .focused($isFocused)

            Group {
                if isChecking {
                    ProgressView().scaleEffect(0.8)
                } else if isVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.primary)
                } else if showButton {
                    SendOTPButton(
                        isSending: isSending,
                        canSend: canSend,
                        cooldown: cooldown,
                        onSend: onSendOTP
                    )
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isValid ? AppColors.glassBorder : AppColors.errorBorder,
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - OTP Field Row

private struct OTPFieldRow: View {
    @Binding var otpCode: String
    @FocusState private var isFocused: Bool

    let isVerifying: Bool
    let onVerifyOTP: () async -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "key")
                .foregroundStyle(.secondary)
                .frame(width: UILayout.iconSize)

            TextField("Nhập mã OTP", text: $otpCode, axis: .horizontal)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isFocused = true
                    }
                }

            Button {
                Task { await onVerifyOTP() }
            } label: {
                if isVerifying {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("Xác nhận")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(
                            otpCode.count == 6 ? AppColors.primary : .gray)
                }
            }
            .disabled(isVerifying || otpCode.count != 6)
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
}

// MARK: - Send OTP Button

private struct SendOTPButton: View {
    let isSending: Bool
    let canSend: Bool
    let cooldown: Int
    let onSend: () async -> Void

    var body: some View {
        Button {
            Task { await onSend() }
        } label: {
            if isSending {
                ProgressView().scaleEffect(0.8)
            } else {
                Text(cooldown > 0 ? "\(cooldown)s" : "Gửi mã")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(
                        (canSend && cooldown == 0) ? AppColors.primary : .gray)
            }
        }
        .disabled(!canSend || isSending || cooldown > 0)
    }
}
