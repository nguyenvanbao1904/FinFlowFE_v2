//
//  EmailFieldWithOTP.swift
//  FinFlowCore
//

import SwiftUI

/// Reusable Email field với OTP verification
/// Dùng cho Register và ForgotPassword flows
public struct EmailFieldWithOTP: View {
    @FocusState private var isOtpFocused: Bool
    @Binding public var email: String
    @Binding public var otpCode: String

    public let isEmailVerified: Bool
    public let isEmailValid: Bool
    public let showOTPInput: Bool
    public let isSendingOTP: Bool
    public let isVerifyingOTP: Bool
    public let isCheckingEmail: Bool
    public let canSendOTP: Bool
    public let cooldownRemaining: Int
    public let showSendButton: Bool  // NEW: Control whether to show button at all
    public let validationMessage: String?

    public let onSendOTP: () async -> Void
    public let onVerifyOTP: () async -> Void

    public init(
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
        showSendButton: Bool = true,  // NEW: Default to true
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
        self.showSendButton = showSendButton  // NEW
        self.validationMessage = validationMessage
        self.onSendOTP = onSendOTP
        self.onVerifyOTP = onVerifyOTP
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Email Input
            HStack(spacing: Spacing.sm) {
                Image(systemName: "envelope")
                    .foregroundColor(.secondary)
                    .frame(width: 25)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .disabled(isEmailVerified)

                if isCheckingEmail {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isEmailVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.primary)
                } else if showSendButton {
                    Button(action: {
                        Task { await onSendOTP() }
                    }) {
                        if isSendingOTP {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(cooldownRemaining > 0 ? "\(cooldownRemaining)s" : "Gửi mã")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(
                                    (canSendOTP && cooldownRemaining == 0) ? AppColors.primary
                                        : .gray)
                        }
                    }
                    .disabled(!canSendOTP || isSendingOTP || cooldownRemaining > 0)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, Spacing.sm)
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isEmailValid ? Color.white.opacity(0.1) : Color.red.opacity(0.3),
                        lineWidth: 0.5
                    )
            )

            // Validation Message
            if let message = validationMessage {
                HStack {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(message.contains("✅") ? .green : .red)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // OTP Input
            if showOTPInput {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "key")
                        .foregroundColor(.secondary)
                        .frame(width: 25)

                    TextField("Nhập mã OTP", text: $otpCode, axis: .horizontal)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .contentShape(Rectangle()) // keep tap area
                        .focused($isOtpFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isOtpFocused = true
                            }
                        }
                        .onTapGesture {
                            isOtpFocused = true
                        }

                    Button {
                        Task { await onVerifyOTP() }
                    } label: {
                        if isVerifyingOTP {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Xác nhận")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(
                                    otpCode.count == 6 ? AppColors.primary : .gray)
                        }
                    }
                    .disabled(isVerifyingOTP || otpCode.count != 6)
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
    }
}
