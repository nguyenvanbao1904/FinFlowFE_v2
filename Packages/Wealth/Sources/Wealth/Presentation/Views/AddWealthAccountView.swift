import FinFlowCore
import SwiftUI

public struct AddWealthAccountView: View {
    private enum ActiveSheet: String, Identifiable {
        case accountTypePicker
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddWealthAccountViewModel
    @State private var activeSheet: ActiveSheet?

    public init(viewModel: AddWealthAccountViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                        .frame(width: Spacing.touchTarget)
                    TextField("Tên tài khoản", text: $viewModel.name)
                        .font(AppTypography.body)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Số dư / Giá trị")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .center, spacing: Spacing.xs / 2) {
                        Text("₫")
                            .font(AppTypography.displayMedium)
                        TextField("0", text: $viewModel.amount)
                            .keyboardType(
                                viewModel.selectedAccountType?.debt == true
                                    ? .numbersAndPunctuation : .numberPad
                            )
                            .font(AppTypography.displayXL)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .frame(height: Layout.inputRowHeight)
                            .onChange(of: viewModel.amount) { _, newValue in
                                let allowNegative = viewModel.selectedAccountType?.debt == true
                                let formatted = CurrencyFormatter.formatInput(
                                    newValue, allowNegative: allowNegative)
                                if viewModel.amount != formatted {
                                    viewModel.amount = formatted
                                }
                            }
                            .onChange(of: viewModel.selectedAccountType?.id) { _, _ in
                                if viewModel.selectedAccountType?.debt != true,
                                    viewModel.amount.hasPrefix("-") {
                                    viewModel.amount = CurrencyFormatter.formatInput(
                                        String(viewModel.amount.dropFirst()), allowNegative: false)
                                }
                            }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, Spacing.sm)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                Toggle("Tính vào tổng tài sản", isOn: $viewModel.includeInNetWorth)
            }

            Section {
                Button {
                    activeSheet = .accountTypePicker
                } label: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                            .frame(width: Spacing.touchTarget)
                        Text("Loại tài khoản")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedAccountType?.displayName ?? "Chọn loại")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                Button("Lưu") {
                    Task { await viewModel.save() }
                }
                .primaryButton(isLoading: viewModel.isLoading)
                .disabled(!viewModel.isValid || viewModel.isLoading)
                .opacity(viewModel.isValid ? 1.0 : OpacityLevel.medium)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.appBackground)
        .navigationTitle(viewModel.isEditMode ? "Sửa tài khoản" : "Thêm tài khoản")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Hủy") {
                    dismiss()
                }
                .foregroundStyle(AppColors.primary)
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            typePickerSheet
        }
        .alertHandler(
            Binding(
                get: { viewModel.alert },
                set: { viewModel.alert = $0 }
            )
        )
        .task {
            await viewModel.loadAccountTypes()
        }
    }

    private var typePickerSheet: some View {
        NavigationStack {
            List {
                if viewModel.isLoadingTypes {
                    ProgressView("Đang tải...")
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.lg)
                } else {
                    ForEach(viewModel.accountTypes) { typeOption in
                        Button {
                            viewModel.selectedAccountType = typeOption
                            activeSheet = nil
                        } label: {
                            let typeColor = Color(hex: typeOption.color)
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(typeColor.opacity(OpacityLevel.ultraLight))
                                        .frame(
                                            width: Spacing.touchTarget, height: Spacing.touchTarget)
                                    Image(systemName: typeOption.icon)
                                        .font(AppTypography.iconMedium)
                                        .foregroundStyle(typeColor)
                                }
                                Text(typeOption.displayName)
                                    .font(AppTypography.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedAccountType?.id == typeOption.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.primary)
                                }
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Chọn loại tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
