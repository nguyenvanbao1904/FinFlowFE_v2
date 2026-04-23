//
//  AddTransactionView.swift
//  Transaction
//

import FinFlowCore
import PhotosUI
import SwiftUI
import UIKit

public struct AddTransactionView: View {
    private enum ActiveSheet: String, Identifiable {
        case categoryPicker
        case accountPicker

        var id: String { rawValue }
    }

    private enum CameraSheet: String, Identifiable {
        case camera

        var id: String { rawValue }
    }

    private enum InputField: Hashable {
        case amount
        case note
    }

    @Bindable var viewModel: AddTransactionViewModel
    @State private var assistant = TransactionInputAssistant()
    @State private var cameraSheet: CameraSheet?
    @State private var activeSheet: ActiveSheet?
    @FocusState private var focusedField: InputField?

    public init(viewModel: AddTransactionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: .zero) {
            AISmartInputBar(
                text: $assistant.aiInputText,
                isAnalyzing: Binding(
                    get: { assistant.isProcessing },
                    set: { _ in }
                ),
                placeholder: "Ví dụ: Đổ xăng 50 cành...",
                onSubmit: { text in
                    focusedField = nil
                    assistant.submitTextForAnalysis(text, mirrorToInput: true, analyze: { await viewModel.analyzeText(input: $0) }, alertAfter: { viewModel.alert != nil })
                },
                onVoice: {
                    focusedField = nil
                    assistant.toggleVoiceInput(analyze: { await viewModel.analyzeText(input: $0) }, alertAfter: { viewModel.alert != nil })
                },
                onCamera: {
                    assistant.handleCameraTap()
                }
            )
            .padding(.horizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .zIndex(1)

            Form {
                Section {
                    amountHeaderSection
                        .padding(.vertical, Spacing.sm)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    typeSelectorSection
                        .padding(.vertical, Spacing.sm)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                detailsFormSection

                Section {
                    Button("Lưu Giao Dịch") {
                        Task { await viewModel.saveTransaction() }
                    }
                    .primaryButton(isLoading: viewModel.isLoading)
                    .disabled(!viewModel.isSaveEnabled || viewModel.isLoading)
                    .opacity(viewModel.isSaveEnabled ? 1.0 : OpacityLevel.medium)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.appBackground)
        .navigationTitle(viewModel.isEditMode ? "Sửa giao dịch" : "Thêm giao dịch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Hủy") { viewModel.cancel() }
                    .foregroundStyle(AppColors.primary)
            }
        }
        .task { await viewModel.fetchCategories() }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .categoryPicker:
                CategorySelectionSheet(
                    isPresented: Binding(
                        get: { activeSheet == .categoryPicker },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    selectedCategory: $viewModel.selectedCategory,
                    categories: viewModel.filteredCategories
                )
            case .accountPicker:
                AccountSelectionSheet(
                    isPresented: Binding(
                        get: { activeSheet == .accountPicker },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    selectedAccount: $viewModel.selectedAccount,
                    accounts: viewModel.transactionEligibleAccounts
                )
            }
        }
        .alertHandler(
            Binding<AppErrorAlert?>(
                get: { viewModel.alert },
                set: { viewModel.alert = $0 }
            )
        )
        .alert("Lỗi ghi âm", isPresented: Binding(
            get: { assistant.speechErrorMessage != nil },
            set: { if !$0 { assistant.speechErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(assistant.speechErrorMessage ?? "")
        }
        .alert("Lỗi OCR", isPresented: Binding(
            get: { assistant.ocrErrorMessage != nil },
            set: { if !$0 { assistant.ocrErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(assistant.ocrErrorMessage ?? "")
        }
        .confirmationDialog(
            "Chọn nguồn hoá đơn",
            isPresented: $assistant.showCameraOptions,
            titleVisibility: .visible
        ) {
            Button("Chụp ảnh") { cameraSheet = .camera }
            Button("Ảnh đã có") {
                assistant.selectedPhotoItem = nil
                assistant.showPhotoPicker = true
            }
            Button("Hủy", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $assistant.showPhotoPicker,
            selection: $assistant.selectedPhotoItem,
            matching: .images
        )
        .sheet(item: $cameraSheet) { _ in
            CameraImagePicker(
                onImagePicked: { image in
                    cameraSheet = nil
                    assistant.handleImagePicked(image, analyze: { await viewModel.analyzeText(input: $0) }, alertAfter: { viewModel.alert != nil })
                }
            ) {
                cameraSheet = nil
            }
            .ignoresSafeArea()
        }
        .onChange(of: assistant.selectedPhotoItem) { _, newItem in
            assistant.handlePhotoSelected(newItem, analyze: { await viewModel.analyzeText(input: $0) }, alertAfter: { viewModel.alert != nil })
        }
        .onDisappear { assistant.stopListening() }
    }

    // MARK: - Core UI Sections

    private var amountHeaderSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("Số tiền")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: Spacing.xs / 2) {
                Text("₫")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(.primary)

                TextField("0", text: $viewModel.amount)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .font(AppTypography.displayXL)
                    .foregroundStyle(viewModel.isIncome ? AppColors.success : AppColors.expense)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: Layout.inputRowHeight)
                    .blur(radius: assistant.isAnalyzing ? 3 : 0)
                    .scaleEffect(assistant.showMagicEffect ? 1.05 : 1.0)
                    .onChange(of: viewModel.amount) { _, newValue in
                        let formatted = CurrencyFormatter.formatInput(newValue)
                        if viewModel.amount != formatted {
                            viewModel.amount = formatted
                        }
                    }
            }
            .padding(.horizontal)
        }
    }

    private var typeSelectorSection: some View {
        HStack(spacing: Spacing.md) {
            TypeOptionButton(
                title: "Chi tiêu",
                isSelected: !viewModel.isIncome,
                color: AppColors.expense
            ) {
                withAnimation { viewModel.isIncome = false }
            }

            TypeOptionButton(
                title: "Thu nhập",
                isSelected: viewModel.isIncome,
                color: AppColors.success
            ) {
                withAnimation { viewModel.isIncome = true }
            }
        }
    }

    @ViewBuilder
    private var detailsFormSection: some View {
        Section {
            // Category Selector
            Button {
                activeSheet = .categoryPicker
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .scaleEffect(assistant.showMagicEffect ? 1.1 : 1.0)

                        Image(
                            systemName: viewModel.selectedCategory?.icon ?? "square.grid.2x2.fill"
                        )
                        .foregroundStyle(AppColors.accent)
                        .font(AppTypography.iconMedium)
                        .rotationEffect(.degrees(assistant.showMagicEffect ? 360 : 0))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Danh mục")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedCategory?.name ?? "Chọn danh mục")
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(AppTypography.caption)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(assistant.showMagicEffect ? AppColors.accent.opacity(0.1) : nil)

            // Account Selector
            Button {
                if !viewModel.transactionEligibleAccounts.isEmpty {
                    activeSheet = .accountPicker
                } else {
                    viewModel.alert = AppError
                        .validationError("Chưa có tài khoản khả dụng. Thêm tài khoản trong tab \"Tài sản\".")
                        .toAppAlert(defaultTitle: "Thiếu tài khoản")
                }
            } label: {
                HStack {
                    ZStack {
                        let rawHex = viewModel.selectedAccount?.accountType.color
                        let iconColor = rawHex.map { Color(hex: $0) } ?? AppColors.success
                        Circle()
                            .fill(iconColor.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        Image(systemName: viewModel.selectedAccount?.accountType.icon ?? "banknote.fill")
                            .foregroundStyle(iconColor)
                            .font(AppTypography.iconMedium)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Tài khoản")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedAccount?.name ?? "Chọn tài khoản")
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                    }
                    Spacer()

                    if let account = viewModel.selectedAccount {
                        BalanceLabel(balance: account.balance, style: .signed)
                            .font(AppTypography.caption)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(AppTypography.caption)
                        .padding(.leading, Spacing.xs)
                }
            }
            .buttonStyle(.plain)

            // Note Field
            HStack {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .frame(width: Spacing.touchTarget)

                TextField("Ví dụ: Ăn sáng tại phở Hùng...", text: $viewModel.note)
                    .focused($focusedField, equals: .note)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
            }
            .listRowBackground(assistant.showMagicEffect ? AppColors.primary.opacity(0.1) : nil)

            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                    .frame(width: Spacing.touchTarget)
                DatePicker("Ngày", selection: $viewModel.date, displayedComponents: .date)
                    .foregroundStyle(.primary)
            }
        }
    }
}
