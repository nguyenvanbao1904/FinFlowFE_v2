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
    @State private var profileVM: ProfileViewModel
    @State private var securityVM: SecuritySettingsViewModel
    @State private var accountVM: AccountManagementViewModel
    @State private var verificationPIN: String = ""
    @State private var showRestorationAlert = false

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
        @Bindable var securityVM = securityVM
        @Bindable var accountVM = accountVM

        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: .zero) {
                // Custom Navigation Bar
                HStack {
                    Spacer()
                    Text("Tài khoản")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding()

                Group {
                    if profileVM.isLoading && profileVM.profile == nil {
                        VStack(spacing: Spacing.md) {
                            Spacer()
                            ProgressView("Đang tải dữ liệu...")
                                .tint(AppColors.primary)
                            Spacer()
                        }
                    } else if profileVM.hasAuthExpiredError {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if profileVM.hasLoadError {
                        // Retry View
                        VStack(spacing: Spacing.sm) {
                            Spacer()
                            Text("Không thể tải dữ liệu")
                                .font(AppTypography.headline)
                            Text("Vui lòng kiểm tra kết nối mạng và thử lại.")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Thử lại") {
                                Task { await profileVM.refresh() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(profileVM.isLoading)
                            Spacer()
                        }
                    } else {
                        List {
                            // SECTION 1: User Info
                            if let profile = profileVM.profile {
                                Section {
                                    HStack(spacing: Spacing.lg) {
                                        // Avatar
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.primary.opacity(0.1))
                                                .frame(
                                                    width: UILayout.avatarSize,
                                                    height: UILayout.avatarSize)

                                            Text(profile.initials)
                                                .font(AppTypography.displaySmall)
                                                .foregroundStyle(AppColors.primary)
                                        }

                                        VStack(alignment: .leading, spacing: Spacing.xs) {
                                            Text(
                                                profile.fullName.isEmpty
                                                    ? profile.email : profile.fullName
                                            )
                                            .font(AppTypography.headline)
                                            .foregroundStyle(.primary)

                                            if !profile.fullName.isEmpty {
                                                Text(profile.email)
                                                    .font(AppTypography.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, Spacing.xs)
                                }
                            }

                            // SECTION 2: Security Settings
                            Section {
                                // Biometric Toggle
                                HStack {
                                    SettingsRowIcon(icon: "faceid", color: AppColors.primary)
                                    Toggle(
                                        isOn: Binding(
                                            get: { securityVM.isBiometricEnabled },
                                            set: { securityVM.toggleBiometric($0) }
                                        )
                                    ) {
                                        Text("Đăng nhập sinh trắc học")
                                            .font(AppTypography.body)
                                    }
                                }
                            } header: {
                                Text("Bảo mật")
                                    .font(AppTypography.caption)
                            } footer: {
                                Text("Sử dụng Face ID hoặc Touch ID để đăng nhập nhanh hơn.")
                                    .font(AppTypography.caption)
                            }

                            // SECTION 3: Account Settings
                            Section {
                                Button {
                                    accountVM.navigateToChangePassword()
                                } label: {
                                    HStack {
                                        SettingsRowIcon(icon: "lock.rotation", color: .gray)
                                        Text(
                                            (profileVM.profile?.hasPassword == false)
                                                ? "Tạo mật khẩu" : "Đổi mật khẩu"
                                        )
                                        .font(AppTypography.body)
                                        .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Button(role: .destructive) {
                                    accountVM.initiateAccountDeletion()
                                } label: {
                                    HStack {
                                        SettingsRowIcon(icon: "trash.fill", color: .red)
                                        Text("Xóa tài khoản")
                                            .font(AppTypography.body)
                                    }
                                }
                            } header: {
                                Text("Tài khoản")
                                    .font(AppTypography.caption)
                            }

                            // SECTION 4: Logout
                            Section {
                                Button {
                                    Task { await accountVM.logout() }
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Đăng xuất")
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.google)
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)  // The "Apple Settings" style
                        .refreshable { await profileVM.refresh() }
                    }  // End of else
                }  // End of Group
            }  // End of VStack
        }  // End of ZStack
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
                showRestorationAlert = true
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(isPresented: $showRestorationAlert) {
            VStack(spacing: Spacing.lg) {
                Text("Chào mừng quay lại!")
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                Text("Tài khoản của bạn đã được khôi phục thành công.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("OK") {
                    showRestorationAlert = false
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding(Spacing.xl)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
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

// MARK: - Helper Views

struct SettingsRowIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: UILayout.socialIconSize, height: UILayout.socialIconSize)

            Image(systemName: icon)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.textInverted)
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
