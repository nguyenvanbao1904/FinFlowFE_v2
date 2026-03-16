import FinFlowCore
import SwiftUI

public struct ChangePasswordView: View {
    @State private var viewModel: ChangePasswordViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case oldPassword
        case newPassword
        case confirmPassword
    }

    public init(viewModel: ChangePasswordViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.md) {
                        if !viewModel.isCreatingPassword {
                            GlassField(
                                text: $vm.oldPassword,
                                placeholder: "Mật khẩu hiện tại",
                                icon: "lock",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .oldPassword)
                        }

                        VStack(spacing: Spacing.xs) {
                            // New password field
                            GlassField(
                                text: $vm.newPassword,
                                placeholder: "Mật khẩu mới (tối thiểu 6 ký tự)",
                                icon: "lock",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .newPassword)
                            .textContentType(.newPassword)

                            // Password confirmation field
                            GlassField(
                                text: $vm.confirmPassword,
                                placeholder: "Xác nhận mật khẩu mới",
                                icon: "lock.fill",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .confirmPassword)
                            .textContentType(.newPassword)
                        }
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.horizontal)

                    Button(viewModel.isCreatingPassword ? "Tạo mật khẩu" : "Đổi mật khẩu") {
                        Task {
                            await viewModel.changePassword()
                        }
                    }
                    .primaryButton(isLoading: viewModel.isLoading)
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)

                    Spacer()
                }
            }
        }
        .navigationTitle(viewModel.isCreatingPassword ? "Tạo Mật Khẩu" : "Đổi Mật Khẩu")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(viewModel.isLoading)
        .alertHandler($viewModel.alert)
    }
}
