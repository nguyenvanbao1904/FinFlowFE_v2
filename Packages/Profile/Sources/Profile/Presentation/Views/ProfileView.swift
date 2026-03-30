//
//  ProfileView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//
// swiftlint:disable file_length
// Justification: Main profile screen with settings sections. Well-structured with MARK sections.
// Alternative would be to extract SettingsRowIcon and extension methods, but they're tightly coupled.

import FinFlowCore
import SwiftUI

public struct ProfileView: View {
    private enum ActiveSheet: String, Identifiable {
        case restorationAlert
        var id: String { rawValue }
    }

    @State private var profileVM: ProfileViewModel
    @State private var securityVM: SecuritySettingsViewModel
    @State private var accountVM: AccountManagementViewModel
    @State private var verificationPIN: String = ""
    @State private var activeSheet: ActiveSheet?
    @Environment(\.dismiss) private var dismiss

    public init(
        profileVM: ProfileViewModel,
        securityVM: SecuritySettingsViewModel,
        accountVM: AccountManagementViewModel
    ) {
        _profileVM = State(wrappedValue: profileVM)
        _securityVM = State(wrappedValue: securityVM)
        _accountVM = State(wrappedValue: accountVM)
    }

    public var body: some View {
        @Bindable var profileVM = profileVM

        Group {
            if profileVM.isLoading && profileVM.profile == nil {
                ProfileLoadingStateView()
            } else if profileVM.hasAuthExpiredError {
                ProfileAuthExpiredStateView()
            } else if profileVM.hasLoadError {
                ProfileErrorRetryView(
                    onRetry: { Task { await profileVM.refresh() } },
                    isLoading: profileVM.isLoading
                )
            } else {
                ProfileSettingsListContent(
                    profileVM: profileVM,
                    securityVM: securityVM,
                    accountVM: accountVM,
                    onDismiss: { dismiss() },
                    onNavigateUpdateProfile: {
                        profileVM.navigateToUpdateProfile()
                    }
                )
            }
        }
        .navigationTitle("Tài khoản")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Xong") {
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundStyle(AppColors.primary)
            }
        }
        .task {
            await profileVM.loadProfile()
            if let profile = profileVM.profile {
                securityVM.updateUserEmail(profile.email)
                securityVM.isBiometricEnabled = profile.isBiometricEnabled ?? false
                accountVM.updateUserEmail(profile.email)

                // Check PIN requirement after profile is complete
                if profile.firstName != nil && profile.lastName != nil && profile.dob != nil {
                    await securityVM.checkPINRequirement()
                }
            }
        }
        .settingsSheets(
            securityVM: securityVM,
            accountVM: accountVM,
            profileVM: profileVM,
            verificationPIN: $verificationPIN
        )
        // Gộp chung Alert Handler
        .alertHandler(
            Binding<AppErrorAlert?>(
                get: {
                    if let alert = profileVM.alert { return alert }
                    if !accountVM.showOTPInput && !accountVM.showDeletePasswordConfirmation,
                        let alert = accountVM.alert {
                        return alert
                    }
                    if !securityVM.showPINVerification, let alert = securityVM.pinAlert {
                        return alert
                    }
                    return nil
                },
                set: { newValue in
                    if profileVM.alert != nil {
                        profileVM.alert = newValue
                    } else if accountVM.alert != nil {
                        accountVM.alert = newValue
                    } else if securityVM.pinAlert != nil {
                        securityVM.pinAlert = newValue
                    }
                }
            )
        )
        .onAppear {
            if case .authenticated(_, let isRestored) = accountVM.sessionManager.state, isRestored {
                activeSheet = .restorationAlert
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            AccountRestorationSheetView(
                isPresented: Binding(
                    get: { activeSheet == .restorationAlert },
                    set: { isPresented in
                        if !isPresented { activeSheet = nil }
                    }
                )
            )
        }
        .alert(
            "Xóa tài khoản",
            isPresented: Binding(
                get: { accountVM.showDeleteAccountConfirmation },
                set: { accountVM.showDeleteAccountConfirmation = $0 }
            )
        ) {
            Button("Hủy", role: .cancel) {}
            Button("Xác nhận", role: .destructive) {
                Task { await accountVM.sendDeleteAccountOTP() }
            }
        } message: {
            Text(
                "Bạn có chắc chắn muốn xóa tài khoản? Chúng tôi sẽ gửi mã OTP đến email của bạn để xác nhận."
            )
        }
    }
}

// MARK: - Extensions for Clean Code

extension View {
    fileprivate func settingsSheets(
        securityVM: SecuritySettingsViewModel,
        accountVM: AccountManagementViewModel,
        profileVM: ProfileViewModel,
        verificationPIN: Binding<String>
    ) -> some View {
        self
            .pinInputSheet(
                isPresented: Binding(
                    get: { securityVM.showPINVerification },
                    set: { securityVM.showPINVerification = $0 }),
                pin: verificationPIN,
                title: "Nhập mã PIN",
                subtitle: "Xác nhận mã PIN để thay đổi cài đặt",
                showConfirmButton: true,
                allowDismissal: true,
                onComplete: { pin in
                    Task {
                        await securityVM.verifyPINAndToggleBiometric(pin: pin)
                        verificationPIN.wrappedValue = ""
                    }
                },
                onCancel: {
                    verificationPIN.wrappedValue = ""
                    securityVM.showPINVerification = false
                    securityVM.pendingBiometricToggle = nil
                },
                onForgotPIN: { securityVM.forgotPINForSettings() },
                alert: Binding(get: { securityVM.pinAlert }, set: { securityVM.pinAlert = $0 })
            )
            .passwordConfirmationSheet(
                isPresented: Binding(
                    get: { accountVM.showDeletePasswordConfirmation },
                    set: { accountVM.showDeletePasswordConfirmation = $0 }),
                password: Binding(
                    get: { accountVM.deletePasswordInput },
                    set: { accountVM.deletePasswordInput = $0 }),
                title: "Xác nhận mật khẩu",
                subtitle: "Vui lòng nhập mật khẩu đăng nhập để xác nhận xóa tài khoản.",
                placeholder: "Mật khẩu hiện tại",
                confirmTitle: "Tiếp tục",
                confirmRoleDestructive: true,
                allowDismissal: true,
                onConfirm: { Task { await accountVM.confirmDeletePassword() } },
                onCancel: {
                    accountVM.deletePasswordInput = ""
                    accountVM.showDeletePasswordConfirmation = false
                },
                onDismiss: nil,  // Không xóa deletePasswordInput ở đây - cần giữ để gửi lên API khi confirm OTP
                alert: Binding(get: { accountVM.alert }, set: { accountVM.alert = $0 })
            )
            .pinInputSheet(
                isPresented: Binding(
                    get: { accountVM.showOTPInput }, set: { accountVM.showOTPInput = $0 }),
                pin: Binding(get: { accountVM.otpCode }, set: { accountVM.otpCode = $0 }),
                title: "Xác nhận xóa tài khoản",
                subtitle: "Mã OTP đã được gửi đến\n\(profileVM.profile?.email ?? "")",
                showConfirmButton: true,
                isLoading: accountVM.isLoading,
                displayMode: .numbers,
                allowDismissal: true,
                onComplete: { _ in Task { await accountVM.confirmDeleteAccountWithOTP() } },
                onCancel: {
                    accountVM.otpCode = ""
                    accountVM.showOTPInput = false
                    accountVM.deletePasswordInput = ""
                },
                onDismiss: { accountVM.otpCode = "" },
                alert: Binding(get: { accountVM.otpAlert }, set: { accountVM.otpAlert = $0 })
            )
            .pinInputSheet(
                isPresented: Binding(
                    get: { securityVM.showResetPinOtpInput },
                    set: { securityVM.showResetPinOtpInput = $0 }),
                pin: Binding(
                    get: { securityVM.resetPinOtpCode }, set: { securityVM.resetPinOtpCode = $0 }),
                title: "Đặt lại mã PIN",
                subtitle: "Mã OTP đã được gửi đến\n\(profileVM.profile?.email ?? "")",
                showConfirmButton: true,
                isLoading: securityVM.isLoading,
                displayMode: .numbers,
                allowDismissal: true,
                onComplete: { _ in Task { await securityVM.confirmResetPinWithOTP() } },
                onCancel: {
                    securityVM.resetPinOtpCode = ""
                    securityVM.showResetPinOtpInput = false
                },
                onDismiss: { securityVM.resetPinOtpCode = "" },
                alert: Binding(get: { securityVM.pinAlert }, set: { securityVM.pinAlert = $0 })
            )
            .alert(
                "Quên mã PIN?",
                isPresented: Binding(
                    get: { securityVM.showForgotPINAlert },
                    set: { securityVM.showForgotPINAlert = $0 })
            ) {
                Button("Gửi OTP & Đặt lại", role: .destructive) {
                    Task { await securityVM.sendResetPinOTP() }
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text(
                    "Bạn đang sử dụng tài khoản mạng xã hội (Google/Apple). Chúng tôi sẽ gửi mã OTP đến email để xác minh và đặt lại PIN mới."
                )
            }
    }
}
