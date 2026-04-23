//
//  EmailFieldWithOTP.swift
//  Identity
//
//  MOVED FROM: FinFlowCore (Identity-specific component)
//  Reusable Email field with OTP verification
//

import FinFlowCore
import SwiftUI

/// Configuration struct grouping EmailFieldWithOTP state flags
struct EmailOTPConfig {
    var isEmailVerified: Bool = false
    var isEmailValid: Bool = true
    var showOTPInput: Bool = false
    var isSendingOTP: Bool = false
    var isVerifyingOTP: Bool = false
    var isCheckingEmail: Bool = false
    var canSendOTP: Bool = true
    var cooldownRemaining: Int = 0
    var showSendButton: Bool = true
    var validationMessage: String?
}

/// Reusable Email field với OTP verification
/// Dùng cho Register và ForgotPassword flows
struct EmailFieldWithOTP: View {
    @Binding var email: String
    @Binding var otpCode: String

    let config: EmailOTPConfig
    let onSendOTP: () async -> Void
    let onVerifyOTP: () async -> Void

    init(
        email: Binding<String>,
        otpCode: Binding<String>,
        config: EmailOTPConfig,
        onSendOTP: @escaping () async -> Void,
        onVerifyOTP: @escaping () async -> Void
    ) {
        self._email = email
        self._otpCode = otpCode
        self.config = config
        self.onSendOTP = onSendOTP
        self.onVerifyOTP = onVerifyOTP
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Email Input with Action Button
            EmailFieldRow(
                email: $email,
                isVerified: config.isEmailVerified,
                isValid: config.isEmailValid,
                isChecking: config.isCheckingEmail,
                isSending: config.isSendingOTP,
                showButton: config.showSendButton,
                canSend: config.canSendOTP,
                cooldown: config.cooldownRemaining,
                onSendOTP: onSendOTP
            )

            // Validation Message
            if let message = config.validationMessage {
                HStack {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.expense)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xs)
                .transition(.opacity)
            }

            // OTP Input
            if config.showOTPInput {
                OTPFieldRow(
                    otpCode: $otpCode,
                    isVerifying: config.isVerifyingOTP,
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
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
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
                            otpCode.count == 6 ? AppColors.primary : AppColors.disabled)
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
                        (canSend && cooldown == 0) ? AppColors.primary : AppColors.disabled)
            }
        }
        .disabled(!canSend || isSending || cooldown > 0)
    }
}
