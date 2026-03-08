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
                AppColors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: Spacing.md) {
                            GlassField(
                                text: $vm.lastName,
                                placeholder: "Họ",
                                icon: "person.fill"
                            )
                            .focused($focusedField, equals: .lastName)

                            GlassField(
                                text: $vm.firstName,
                                placeholder: "Tên",
                                icon: "person"
                            )
                            .focused($focusedField, equals: .firstName)

                            // Date of birth picker
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                    .frame(width: UILayout.iconSize)

                                DatePicker(
                                    "Ngày sinh", selection: $vm.dob, displayedComponents: .date
                                )
                                .tint(AppColors.primary)
                            }
                            .padding(.vertical, Spacing.sm2)
                            .padding(.horizontal, Spacing.sm)
                            .background(AppColors.cardBackground)
                            .cornerRadius(CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(AppColors.glassBorder, lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.lg)

                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundColor(AppColors.google)
                                .font(AppTypography.caption)
                                .padding(.horizontal)
                        }

                        Button("Cập nhật") {
                            Task {
                                await viewModel.updateProfile()
                            }
                        }
                        .primaryButton(isLoading: viewModel.isLoading)
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
