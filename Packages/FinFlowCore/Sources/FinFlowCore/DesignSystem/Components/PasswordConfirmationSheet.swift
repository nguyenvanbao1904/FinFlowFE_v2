//
//  PasswordConfirmationSheet.swift
//  FinFlowCore
//
//  REFACTORED: Now uses SheetContainer + FormField primitives
//  Reduced from 132 lines → 76 lines (-42%)
//
//  Sheet nhập mật khẩu dùng chung cho:
//  - WelcomeBackView: Quên mã PIN (user có password) -> xác thực để khôi phục PIN
//  - DashboardView: Xóa tài khoản (user có password) -> xác thực trước khi gửi OTP
//

import SwiftUI

// MARK: - View Extension

extension View {
    /// Sheet nhập mật khẩu dùng chung cho: quên PIN (WelcomeBack), xóa tài khoản (Dashboard), v.v.
    public func passwordConfirmationSheet(
        isPresented: Binding<Bool>,
        password: Binding<String>,
        title: String = "Xác nhận mật khẩu",
        subtitle: String? = nil,
        placeholder: String = "Mật khẩu",
        confirmTitle: String = "Xác nhận",
        confirmRoleDestructive: Bool = false,
        allowDismissal: Bool = true,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        alert: Binding<AppErrorAlert?> = .constant(nil)
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            SheetContainer(
                title: title,
                detents: [.medium],
                allowDismissal: allowDismissal,
                onDismiss: onDismiss
            ) {
                PasswordConfirmationContent(
                    password: password,
                    alert: alert,
                    subtitle: subtitle,
                    placeholder: placeholder,
                    confirmTitle: confirmTitle,
                    confirmRoleDestructive: confirmRoleDestructive,
                    onConfirm: onConfirm,
                    onCancel: onCancel
                )
            }
        }
    }
}

// MARK: - Content

private struct PasswordConfirmationContent: View {
    @Binding var password: String
    @FocusState private var isFocused: Bool
    @Binding var alert: AppErrorAlert?

    let subtitle: String?
    let placeholder: String
    let confirmTitle: String
    let confirmRoleDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GlassField(
                text: $password,
                placeholder: placeholder,
                icon: "lock.fill",
                isSecure: true
            )

            HStack(spacing: Spacing.md) {
                Button("Hủy", action: onCancel)
                    .buttonStyle(.bordered)

                Button(
                    confirmTitle, role: confirmRoleDestructive ? .destructive : nil,
                    action: onConfirm
                )
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding()
        .alertHandler($alert)
    }
}
