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
        
        NavigationStack {
            ZStack {
                AppBackgroundGradient()
                
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: Spacing.md) {
                            if !viewModel.isCreatingPassword {
                                GlassSecureField(
                                    text: $vm.oldPassword,
                                    placeholder: "Mật khẩu hiện tại",
                                    icon: "lock"
                                )
                                .focused($focusedField, equals: .oldPassword)
                            }
                            
                            PasswordFieldGroup(
                                password: $vm.newPassword,
                                passwordConfirmation: $vm.confirmPassword,
                                passwordPlaceholder: "Mật khẩu mới (tối thiểu 6 ký tự)",
                                confirmationPlaceholder: "Xác nhận mật khẩu mới",
                                passwordMessage: nil, // Add real-time validation if available
                                passwordConfirmationMessage: nil,
                                focusedField: $focusedField,
                                passwordFieldIdentifier: .newPassword,
                                confirmationFieldIdentifier: .confirmPassword,
                                onPasswordFocusChange: { _ in },
                                onConfirmationFocusChange: { _ in }
                            )
                        }
                        .padding(.top, Spacing.xl)
                        .padding(.horizontal)
                        
                        PrimaryButton(
                            title: viewModel.isCreatingPassword ? "Tạo mật khẩu" : "Đổi mật khẩu",
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.changePassword()
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle(viewModel.isCreatingPassword ? "Tạo Mật Khẩu" : "Đổi Mật Khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .loadingOverlay(viewModel.isLoading)
            .alertHandler($viewModel.alert)
        }
    }
}
