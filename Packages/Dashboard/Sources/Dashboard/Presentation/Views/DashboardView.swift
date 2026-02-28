//
//  DashboardView.swift
//  Dashboard
//

import FinFlowCore
import Identity
import SwiftUI

public struct DashboardView: View {
    @State private var container: DashboardContainerViewModel
    @State private var verificationPIN: String = ""
    @State private var showRestorationAlert = false

    public init(viewModel: DashboardContainerViewModel) {
        _container = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var profileVM = container.profileVM
        @Bindable var securityVM = container.securityVM
        @Bindable var accountVM = container.accountVM
        
        // Hiển thị loading/full-screen placeholder khi chưa có profile và đang tải
        return Group {
            if profileVM.isLoading && container.profileVM.profile == nil {
                VStack(spacing: Spacing.md) {
                    Spacer()
                    ProgressView("Đang tải dữ liệu...")
                        .tint(AppColors.primary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let profile = container.profileVM.profile {
                            ProfileHeaderCard(profile: profile)
                            
                            Spacer()
                            
                            securitySection(securityVM: securityVM)
                            accountSection(accountVM: accountVM)
                            
                            logoutButton
                        } else if profileVM.hasAuthExpiredError {
                            Spacer()
                            ProgressView()
                            Spacer()
                        } else if profileVM.hasLoadError {
                            Spacer()
                            VStack(spacing: Spacing.sm) {
                                Text("Không thể tải dữ liệu")
                                    .font(AppTypography.headline)
                                Text("Vui lòng kiểm tra kết nối mạng và thử lại.")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("Thử lại") {
                                    Task { await container.profileVM.refresh() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(profileVM.isLoading)
                            }
                            .frame(maxWidth: .infinity)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .task { await container.loadInitialData() }
        .refreshable { await container.profileVM.refresh() }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $profileVM.shouldShowUpdateProfile, onDismiss: {
            Task { await container.profileVM.loadProfile() }
        }) {
            UpdateProfileView(viewModel: container.profileVM.makeUpdateProfileViewModel())
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $securityVM.shouldShowCreatePIN) {
            CreatePINView(viewModel: container.securityVM.makeCreatePINViewModel())
                .interactiveDismissDisabled()
        }
        .settingsSheets(
            securityVM: securityVM,
            accountVM: accountVM,
            profileVM: profileVM,
            verificationPIN: $verificationPIN,
            container: container
        )
        // Gộp chung Alert Handler để tránh xung đột (SwiftUI chỉ nhận 1 alert modifier trên cùng 1 view ở một số phiên bản)
        .alertHandler(Binding<AppErrorAlert?>(
            get: {
                // Ưu tiên hiển thị alert theo thứ tự quan trọng
                if let alert = profileVM.alert { return alert }
                
                // Account alerts (trừ khi đang nhập OTP/Pass)
                if !accountVM.showOTPInput && !accountVM.showDeletePasswordConfirmation, let alert = accountVM.alert {
                    return alert
                }
                
                // Security alerts (trừ khi đang verify PIN)
                if !securityVM.showPINVerification, let alert = securityVM.pinAlert {
                    return alert
                }
                
                return nil
            },
            set: { newValue in
                // Reset alert tương ứng
                if profileVM.alert != nil { profileVM.alert = newValue }
                else if accountVM.alert != nil { accountVM.alert = newValue }
                else if securityVM.pinAlert != nil { securityVM.pinAlert = newValue }
            }
        ))
        .onAppear {
            if case let .authenticated(_, isRestored) = container.sessionManager.state, isRestored {
                showRestorationAlert = true
            }
        }
        .sheet(isPresented: $showRestorationAlert) {
            VStack(spacing: Spacing.lg) {
                Text("Chào mừng quay lại!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Tài khoản của bạn đã được khôi phục thành công.")
                    .font(.body)
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
        // Confirmation Alert for Account Deletion (sau khi nhập password đúng hoặc user không có password)
        .alert(
            "Xóa tài khoản",
            isPresented: Binding(
                get: { container.accountVM.showDeleteAccountConfirmation },
                set: { container.accountVM.showDeleteAccountConfirmation = $0 }
            )
        ) {
            Button("Hủy", role: .cancel) { }
            Button("Xác nhận", role: .destructive) {
                Task { await container.accountVM.sendDeleteAccountOTP() }
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa tài khoản? Chúng tôi sẽ gửi mã OTP đến email của bạn để xác nhận.")
        }
    }

    // MARK: - Sections

    private func securitySection(securityVM: SecuritySettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(
                "Xác thực sinh trắc học",
                isOn: Binding(
                    get: { container.securityVM.isBiometricEnabled },
                    set: { container.securityVM.toggleBiometric($0) }
                )
            )
            .tint(.blue)
        }
        .settingsCardStyle(title: "Cài đặt bảo mật")
    }

    private func accountSection(accountVM: AccountManagementViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsActionButton(
                title: (container.profileVM.profile?.hasPassword == false) ? "Tạo mật khẩu" : "Đổi mật khẩu",
                icon: "lock.rotation"
            ) { container.accountVM.navigateToChangePassword() }
            
            Divider()
            
            SettingsActionButton(
                title: "Xóa tài khoản",
                icon: "trash",
                role: .destructive
            ) {
                container.accountVM.initiateAccountDeletion()
            }
        }
        .settingsCardStyle(title: "Cài đặt tài khoản")
    }

    private var logoutButton: some View {
        Button("Đăng xuất") {
            Task { await container.logout() }
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
}

// MARK: - Extensions for Clean Code

fileprivate extension View {
    // Extracting heavy sheets logic
    func settingsSheets(
        securityVM: SecuritySettingsViewModel,
        accountVM: AccountManagementViewModel,
        profileVM: ProfileViewModel,
        verificationPIN: Binding<String>,
        container: DashboardContainerViewModel
    ) -> some View {
        self
            .pinInputSheet(
                isPresented: Binding(get: { securityVM.showPINVerification }, set: { securityVM.showPINVerification = $0 }),
                pin: verificationPIN,
                title: "Nhập mã PIN",
                subtitle: "Xác nhận mã PIN để thay đổi cài đặt",
                showConfirmButton: true,
                allowDismissal: true,
                onComplete: { pin in
                    Task {
                        await container.securityVM.verifyPINAndToggleBiometric(pin: pin)
                        verificationPIN.wrappedValue = ""
                    }
                },
                onCancel: {
                    verificationPIN.wrappedValue = ""
                    container.securityVM.showPINVerification = false
                    container.securityVM.pendingBiometricToggle = nil
                },
                onForgotPIN: { container.securityVM.forgotPINForSettings() },
                alert: Binding(get: { securityVM.pinAlert }, set: { securityVM.pinAlert = $0 })
            )
            .sheet(isPresented: Binding(get: { accountVM.shouldShowChangePassword }, set: { accountVM.shouldShowChangePassword = $0 })) {
                ChangePasswordView(viewModel: container.accountVM.makeChangePasswordViewModel(hasPassword: container.profileVM.profile?.hasPassword ?? true))
            }
            .passwordConfirmationSheet(
                isPresented: Binding(get: { accountVM.showDeletePasswordConfirmation }, set: { accountVM.showDeletePasswordConfirmation = $0 }),
                password: Binding(get: { accountVM.deletePasswordInput }, set: { accountVM.deletePasswordInput = $0 }),
                title: "Xác nhận mật khẩu",
                subtitle: "Vui lòng nhập mật khẩu đăng nhập để xác nhận xóa tài khoản.",
                placeholder: "Mật khẩu hiện tại",
                confirmTitle: "Tiếp tục",
                confirmRoleDestructive: true,
                allowDismissal: true,
                onConfirm: { Task { await container.accountVM.confirmDeletePassword() } },
                onCancel: {
                    container.accountVM.deletePasswordInput = ""
                    container.accountVM.showDeletePasswordConfirmation = false
                },
                onDismiss: nil, // Không xóa deletePasswordInput ở đây - cần giữ để gửi lên API khi confirm OTP
                alert: Binding(get: { accountVM.alert }, set: { accountVM.alert = $0 })
            )
            .pinInputSheet(
                isPresented: Binding(get: { accountVM.showOTPInput }, set: { accountVM.showOTPInput = $0 }),
                pin: Binding(get: { accountVM.otpCode }, set: { accountVM.otpCode = $0 }),
                title: "Xác nhận xóa tài khoản",
                subtitle: "Mã OTP đã được gửi đến\n\(container.profileVM.profile?.email ?? "")",
                showConfirmButton: true,
                isLoading: container.accountVM.isLoading,
                displayMode: .numbers,
                allowDismissal: true,
                onComplete: { _ in Task { await container.accountVM.confirmDeleteAccountWithOTP() } },
                onCancel: {
                    container.accountVM.otpCode = ""
                    container.accountVM.showOTPInput = false
                    container.accountVM.deletePasswordInput = ""
                },
                onDismiss: { container.accountVM.otpCode = "" },
                alert: Binding(get: { accountVM.otpAlert }, set: { accountVM.otpAlert = $0 })
            )
            .pinInputSheet(
                isPresented: Binding(get: { securityVM.showResetPinOtpInput }, set: { securityVM.showResetPinOtpInput = $0 }),
                pin: Binding(get: { securityVM.resetPinOtpCode }, set: { securityVM.resetPinOtpCode = $0 }),
                title: "Đặt lại mã PIN",
                subtitle: "Mã OTP đã được gửi đến\n\(container.profileVM.profile?.email ?? "")",
                showConfirmButton: true,
                isLoading: container.securityVM.isLoading,
                displayMode: .numbers,
                allowDismissal: true,
                onComplete: { _ in Task { await container.securityVM.confirmResetPinWithOTP() } },
                onCancel: {
                    container.securityVM.resetPinOtpCode = ""
                    container.securityVM.showResetPinOtpInput = false
                },
                onDismiss: { container.securityVM.resetPinOtpCode = "" },
                alert: Binding(get: { securityVM.pinAlert }, set: { securityVM.pinAlert = $0 })
            )
            .alert("Quên mã PIN?", isPresented: Binding(get: { securityVM.showForgotPINAlert }, set: { securityVM.showForgotPINAlert = $0 })) {
                Button("Gửi OTP & Đặt lại", role: .destructive) {
                    Task { await container.securityVM.sendResetPinOTP() }
                }
                Button("Hủy", role: .cancel) { }
            } message: {
                Text("Bạn đang sử dụng tài khoản mạng xã hội (Google/Apple). Chúng tôi sẽ gửi mã OTP đến email để xác minh và đặt lại PIN mới.")
            }
    }
}
