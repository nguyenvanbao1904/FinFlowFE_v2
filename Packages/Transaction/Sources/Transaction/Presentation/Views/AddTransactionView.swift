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

    public init(viewModel: AddTransactionViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: .zero) {

                // Custom Header
                HStack {
                    Button("Hủy") {
                        viewModel.cancel()
                    }
                    .foregroundColor(AppColors.primary)

                    Spacer()

                    Text(viewModel.isEditMode ? "Sửa giao dịch" : "Thêm giao dịch")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button("Hủy") {}
                        .opacity(0)
                        .accessibilityHidden(true)
                }
                .padding()

                // 1. The "Brain" - Smart Input Bar (Pinned at top)
                AISmartInputBar(
                    text: $aiInputText,
                    isAnalyzing: $isAnalyzing,
                    placeholder: "Ví dụ: Đổ xăng 50 cành...",
                    onSubmit: { text in
                        triggerAIAnalysis(text: text)
                    },
                    onVoice: {
                        triggerVoiceInput()
                    },
                    onCamera: {
                        // Trigger Camera UI
                    }
                )
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)
                .zIndex(1)  // Keep above scrollview

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {

                        // 2. Centralized Big Amount Input
                        amountHeaderSection

                        // 3. Type Selector
                        typeSelectorSection

                        // 4. Details Form
                        detailsFormSection

                        // 5. Save Button
                        Button("Lưu Giao Dịch") {
                            Task {
                                await viewModel.saveTransaction()
                            }
                        }
                        .primaryButton(isLoading: viewModel.isLoading)
                        .disabled(!viewModel.isSaveEnabled || viewModel.isLoading)
                        .opacity(viewModel.isSaveEnabled ? 1.0 : OpacityLevel.medium)
                        .padding(.top, Spacing.md)

                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onTapGesture {
                hideKeyboard()
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

    private var detailsFormSection: some View {
        VStack(spacing: Spacing.md) {
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
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(
                            showMagicEffect
                                ? AppColors.accent.opacity(OpacityLevel.strong)
                                : AppColors.disabled.opacity(OpacityLevel.medium),
                            lineWidth: showMagicEffect ? BorderWidth.medium : BorderWidth.hairline)
                )
            }
            .buttonStyle(.plain)

            // Note Field
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                    .frame(width: Spacing.iconSmall)

                TextField("Ví dụ: Ăn sáng tại phở Hùng...", text: $viewModel.note)
                    .font(AppTypography.body)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        showMagicEffect
                            ? AppColors.primary.opacity(OpacityLevel.strong)
                            : AppColors.disabled.opacity(OpacityLevel.medium),
                        lineWidth: showMagicEffect ? BorderWidth.medium : BorderWidth.hairline)
            )

            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: Spacing.iconSmall)
                DatePicker("Ngày", selection: $viewModel.date, displayedComponents: .date)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        AppColors.disabled.opacity(OpacityLevel.medium),
                        lineWidth: BorderWidth.hairline)
            )
        }
    }

    // MARK: - Helpers & Mock Logic

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
    }

    private func triggerAIAnalysis(text: String) {
        hideKeyboard()
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

    private func animateAmount(to target: Int) {
        let steps = 15
        let stepDuration = 0.03
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * stepDuration)) {
                let currentVal = (target / steps) * i
                self.viewModel.amount = "\(currentVal)"
            }
        }
    }

    private func triggerVoiceInput() {
        hideKeyboard()
        aiInputText = "Đổ xăng 50 cành"
        triggerAIAnalysis(text: "Đổ xăng 50 cành")
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func formatCurrency(_ input: String) -> String {
        return CurrencyFormatter.formatInput(input)
    }
}
