import FinFlowCore
import SwiftUI

struct ProfileSettingsListContent: View {
    let profileVM: ProfileViewModel
    let securityVM: SecuritySettingsViewModel
    let accountVM: AccountManagementViewModel
    let onDismiss: () -> Void
    let onNavigateUpdateProfile: () -> Void

    var body: some View {
        @Bindable var profileVM = profileVM
        @Bindable var securityVM = securityVM
        @Bindable var accountVM = accountVM

        List {
            if let profile = profileVM.profile {
                Section {
                    Button {
                        onDismiss()
                        Task {
                            try? await Task.sleep(for: AnimationTiming.navigationDelay)
                            onNavigateUpdateProfile()
                        }
                    } label: {
                        HStack(spacing: Spacing.lg) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.1))
                                    .frame(
                                        width: UILayout.avatarSize * 1.2,
                                        height: UILayout.avatarSize * 1.2)

                                Text(profile.initials)
                                    .font(AppTypography.displaySmall)
                                    .foregroundStyle(AppColors.primary)
                            }

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(profile.fullName.isEmpty ? profile.email : profile.fullName)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(.primary)

                                if !profile.fullName.isEmpty {
                                    Text(profile.email)
                                        .font(AppTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }

            Section {
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

            Section {
                Button {
                    onDismiss()
                    Task {
                        try? await Task.sleep(for: AnimationTiming.navigationDelay)
                        accountVM.navigateToChangePassword()
                    }
                } label: {
                    HStack {
                        SettingsRowIcon(icon: "lock.rotation", color: AppColors.disabled)
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
                        SettingsRowIcon(icon: "trash.fill", color: AppColors.destructive)
                        Text("Xóa tài khoản")
                            .font(AppTypography.body)
                    }
                }
            } header: {
                Text("Tài khoản")
                    .font(AppTypography.caption)
            }

            Section {
                Button {
                    Task { await accountVM.logout() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Đăng xuất")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.expense)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await profileVM.refresh() }
    }
}
