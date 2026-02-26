//
//  PasswordConfirmationSheet.swift
//  FinFlowCore
//
//  Sheet nhập mật khẩu dùng chung cho:
//  - WelcomeBackView: Quên mã PIN (user có password) -> xác thực để khôi phục PIN
//  - DashboardView: Xóa tài khoản (user có password) -> xác thực trước khi gửi OTP
//  Dùng alertHandler cho lỗi (sai mật khẩu, v.v.)
//

import SwiftUI

public struct PasswordConfirmationSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var password: String

    let title: String
    let subtitle: String?
    let placeholder: String
    let confirmTitle: String
    let confirmRoleDestructive: Bool
    let allowDismissal: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onDismiss: (() -> Void)?
    @Binding var alert: AppErrorAlert?

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                PasswordConfirmationSheetContent(
                    password: $password,
                    alert: $alert,
                    title: title,
                    subtitle: subtitle,
                    placeholder: placeholder,
                    confirmTitle: confirmTitle,
                    confirmRoleDestructive: confirmRoleDestructive,
                    onConfirm: onConfirm,
                    onCancel: onCancel
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(!allowDismissal)
            }
    }
}

private struct PasswordConfirmationSheetContent: View {
    @Binding var password: String
    @Binding var alert: AppErrorAlert?

    let title: String
    let subtitle: String?
    let placeholder: String
    let confirmTitle: String
    let confirmRoleDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
            }

            GlassSecureField(
                text: $password,
                placeholder: placeholder,
                icon: "lock.fill"
            )

            HStack(spacing: Spacing.md) {
                Button("Hủy", action: onCancel)
                    .buttonStyle(.bordered)

                Button(confirmTitle, role: confirmRoleDestructive ? .destructive : nil, action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty)
            }
        }
        .padding()
        .alertHandler($alert)
    }
}

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
        self.modifier(
            PasswordConfirmationSheetModifier(
                isPresented: isPresented,
                password: password,
                title: title,
                subtitle: subtitle,
                placeholder: placeholder,
                confirmTitle: confirmTitle,
                confirmRoleDestructive: confirmRoleDestructive,
                allowDismissal: allowDismissal,
                onConfirm: onConfirm,
                onCancel: onCancel,
                onDismiss: onDismiss,
                alert: alert
            )
        )
    }
}
