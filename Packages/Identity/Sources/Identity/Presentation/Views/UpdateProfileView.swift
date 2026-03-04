import FinFlowCore
import SwiftUI

public struct UpdateProfileView: View {
    @State private var viewModel: UpdateProfileViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName
    }

    public init(viewModel: UpdateProfileViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return NavigationView {
            ZStack {
                AppBackgroundGradient()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: Spacing.md) {
                            ValidatedTextField(
                                text: $vm.lastName,
                                placeholder: "Họ",
                                icon: "person.fill",
                                validationMessage: nil,
                                focusedField: $focusedField,
                                fieldIdentifier: .lastName,
                                onFocusChange: { _ in }
                            )

                            ValidatedTextField(
                                text: $vm.firstName,
                                placeholder: "Tên",
                                icon: "person",
                                validationMessage: nil,
                                focusedField: $focusedField,
                                fieldIdentifier: .firstName,
                                onFocusChange: { _ in }
                            )

                            GlassDatePicker(date: $vm.dob, label: "Ngày sinh", icon: "calendar")
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.lg)

                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundColor(AppColors.google)
                                .font(AppTypography.caption)
                                .padding(.horizontal)
                        }

                        PrimaryButton(
                            title: "Cập nhật",
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.updateProfile()
                            }
                        }
                        .padding(.horizontal)
                        .disabled(!viewModel.isValid)
                    }
                }
            }
            .navigationTitle("Cập nhật hồ sơ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        // Dismiss handled by parent or environment
                    }
                }
            }
        }
    }
}
