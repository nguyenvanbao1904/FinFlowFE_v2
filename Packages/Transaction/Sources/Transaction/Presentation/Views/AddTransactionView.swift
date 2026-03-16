//
//  AddTransactionView.swift
//  Transaction
//

import FinFlowCore
import SwiftUI

public struct AddTransactionView: View {
    // Removed unused router property

    // ViewModel
    @State private var viewModel: AddTransactionViewModel

    // AI / Smart State - Keeping locally for UI effect
    @State private var aiInputText: String = ""
    @State private var isAnalyzing: Bool = false

    // Animation trigger for "Magical" auto-fill effect
    @State private var showMagicEffect: Bool = false

    // Category Selection State
    @State private var showCategoryPicker: Bool = false

    @State private var showAccountPicker: Bool = false

    public init(viewModel: AddTransactionViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: .zero) {
            // 1. The "Brain" - Smart Input Bar (Pinned at top)
            AISmartInputBar(
                text: $aiInputText,
                isAnalyzing: $isAnalyzing,
                placeholder: "Ví dụ: Đổ xăng 50 cành...",
                onSubmit: { text in
                    triggerAIAnalysis(text: text)
                },
                onVoice: {
                    // TODO: Implement real voice input (Speech framework)
                },
                onCamera: {
                    // Trigger Camera UI
                }
            )
            .padding(.horizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .zIndex(1)  // Keep above scrollview

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

                // 4. Details Form
                detailsFormSection

                Section {
                    // 5. Save Button
                    Button("Lưu Giao Dịch") {
                        Task {
                            await viewModel.saveTransaction()
                        }
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
                Button("Hủy") {
                    viewModel.cancel()
                }
                .foregroundColor(AppColors.primary)
            }
        }
        .task {
            await viewModel.fetchCategories()
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(isPresented: $showCategoryPicker) {
            CategorySelectionSheet(
                isPresented: $showCategoryPicker,
                selectedCategory: $viewModel.selectedCategory,
                categories: viewModel.filteredCategories
            )
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(isPresented: $showAccountPicker) {
            AccountSelectionSheet(
                isPresented: $showAccountPicker,
                selectedAccount: $viewModel.selectedAccount,
                accounts: viewModel.transactionEligibleAccounts
            )
        }
        .alertHandler(
            Binding<AppErrorAlert?>(
                get: { viewModel.alert },
                set: { viewModel.alert = $0 }
            )
        )
    }

    // MARK: - Core UI Sections

    private var amountHeaderSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("Số tiền")
                .font(AppTypography.subheadline)
                .foregroundColor(.secondary)

            HStack(alignment: .center, spacing: Spacing.xs / 2) {
                Text("₫")
                    .font(AppTypography.displayMedium)
                    .foregroundColor(.primary)

                TextField("0", text: $viewModel.amount)
                    .keyboardType(.numberPad)
                    .font(AppTypography.displayXL)
                    .foregroundColor(viewModel.isIncome ? AppColors.success : AppColors.google)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: Layout.inputRowHeight)
                    .blur(radius: isAnalyzing ? 3 : 0)
                    .scaleEffect(showMagicEffect ? 1.05 : 1.0)
                    .onChange(of: viewModel.amount) { _, newValue in
                        let formatted = formatCurrency(newValue)
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
            typeButton(title: "Chi tiêu", isSelected: !viewModel.isIncome, color: AppColors.google) {
                withAnimation { viewModel.isIncome = false }
            }
            typeButton(title: "Thu nhập", isSelected: viewModel.isIncome, color: AppColors.success) {
                withAnimation { viewModel.isIncome = true }
            }
        }
    }

    @ViewBuilder
    private var detailsFormSection: some View {
        Section {
            // Category Selector
            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .scaleEffect(showMagicEffect ? 1.1 : 1.0)

                        // Icon mapping will require a helper, using default for now
                        Image(
                            systemName: viewModel.selectedCategory?.icon ?? "square.grid.2x2.fill"
                        )
                        .foregroundColor(AppColors.accent)
                        .font(AppTypography.iconMedium)
                        .rotationEffect(.degrees(showMagicEffect ? 360 : 0))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Danh mục")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.selectedCategory?.name ?? "Chọn danh mục")
                            .font(AppTypography.body)
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())  // iOS 16+ fluid text transition
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(AppTypography.caption)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(showMagicEffect ? AppColors.accent.opacity(0.1) : nil)

            // Account Selector (transaction-eligible only)
            Button {
                if !viewModel.transactionEligibleAccounts.isEmpty {
                    showAccountPicker = true
                } else {
                    viewModel.alert = AppError
                        .validationError("Chưa có tài khoản khả dụng. Thêm tài khoản trong tab \"Tài sản\".")
                        .toAppAlert(defaultTitle: "Thiếu tài khoản")
                }
            } label: {
                HStack {
                    ZStack {
                        let iconColor = Color(hex: viewModel.selectedAccount?.accountType.color ?? "#10B981")
                        Circle()
                            .fill(iconColor.opacity(OpacityLevel.ultraLight))
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        Image(systemName: viewModel.selectedAccount?.accountType.icon ?? "banknote.fill")
                            .foregroundColor(iconColor)
                            .font(AppTypography.iconMedium)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Tài khoản")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.selectedAccount?.name ?? "Chọn tài khoản")
                            .font(AppTypography.body)
                            .foregroundColor(.primary)
                    }
                    Spacer()

                    if let account = viewModel.selectedAccount {
                        BalanceLabel(balance: account.balance, style: .signed)
                            .font(AppTypography.caption)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(AppTypography.caption)
                        .padding(.leading, Spacing.xs)
                }
            }
            .buttonStyle(.plain)

            // Note Field
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                    .frame(width: Spacing.touchTarget)

                TextField("Ví dụ: Ăn sáng tại phở Hùng...", text: $viewModel.note)
                    .font(AppTypography.body)
                    .foregroundColor(.primary)
            }
            .listRowBackground(showMagicEffect ? AppColors.primary.opacity(0.1) : nil)

            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: Spacing.touchTarget)
                DatePicker("Ngày", selection: $viewModel.date, displayedComponents: .date)
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Helpers

    private func typeButton(
        title: String, isSelected: Bool, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background {
                    if isSelected {
                        color.opacity(OpacityLevel.light)
                    } else {
                        Rectangle().fill(AppColors.cardBackground)
                    }
                }
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isSelected
                                ? color.opacity(OpacityLevel.strong)
                                : AppColors.disabled.opacity(OpacityLevel.medium),
                            lineWidth: BorderWidth.thin)
                )
        }
        .buttonStyle(.borderless)
    }

    private func triggerAIAnalysis(text: String) {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isAnalyzing = true
        }

        Task {
            await viewModel.analyzeText(input: text)

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    isAnalyzing = false
                }
            }

            guard viewModel.alert == nil else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showMagicEffect = true
                    aiInputText = ""
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showMagicEffect = false }
                }
            }
        }
    }

    private func formatCurrency(_ input: String) -> String {
        return CurrencyFormatter.formatInput(input)
    }
}
