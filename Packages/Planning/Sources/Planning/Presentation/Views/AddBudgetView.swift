//
//  AddBudgetView.swift
//  Planning
//
//  Form for creating/editing budget (API-backed). Apple HIG: Form-style layout.
//

import FinFlowCore
import SwiftUI

public struct AddBudgetView: View {
    private enum ActiveSheet: String, Identifiable {
        case categoryPicker
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddBudgetViewModel
    @State private var activeSheet: ActiveSheet?
    @FocusState private var isAmountFocused: Bool

    public init(viewModel: AddBudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                categorySection
                amountSection
            }

            Section {
                periodSection
                recurringSection
            }

            Section {
                Button(viewModel.isEditing ? "Cập nhật" : "Tạo ngân sách") {
                    Task { await viewModel.saveBudget() }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(viewModel.isValid ? AppColors.primary : AppColors.disabled)
                .foregroundStyle(viewModel.isValid ? AppColors.textInverted : .secondary)
                .clipShape(.rect(cornerRadius: CornerRadius.medium))
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .navigationTitle(viewModel.isEditing ? "Sửa ngân sách" : "Tạo ngân sách")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Hủy") { dismiss() }
                    .foregroundStyle(AppColors.primary)
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .alertHandler(
            Binding(
                get: { viewModel.loadError },
                set: { viewModel.loadError = $0 }
            )
        )
        .task { await viewModel.loadCategories() }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            CategorySelectionSheet(
                isPresented: Binding(
                    get: { activeSheet == .categoryPicker },
                    set: { isPresented in
                        if !isPresented { activeSheet = nil }
                    }
                ),
                selectedCategory: $viewModel.selectedCategory,
                categories: viewModel.expenseCategories,
                title: "Chọn danh mục"
            )
        }
    }

    private var categorySection: some View {
        Button {
            activeSheet = .categoryPicker
        } label: {
            HStack(spacing: Spacing.sm) {
                if let category = viewModel.selectedCategory {
                    let categoryColor = Color(hex: category.color)
                    Image(systemName: category.icon ?? "tag")
                        .font(AppTypography.iconMedium)
                        .foregroundStyle(categoryColor)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                } else {
                    Image(systemName: "tag")
                        .font(AppTypography.iconMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                Text("Danh mục")
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.selectedCategory?.name ?? "Chọn")
                    .font(AppTypography.body)
                    .foregroundStyle(viewModel.selectedCategory == nil ? .secondary : .primary)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Chọn danh mục")
    }

    private var amountSection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "dollarsign.circle")
                .font(AppTypography.iconMedium)
                .foregroundStyle(AppColors.primary)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            Text("Số tiền")
                .font(AppTypography.body)
            Spacer()
            TextField("0", text: $viewModel.targetAmount)
                .keyboardType(.numberPad)
                .focused($isAmountFocused)
                .multilineTextAlignment(.trailing)
                .font(AppTypography.body)
                .onChange(of: viewModel.targetAmount) { _, newValue in
                    let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                    if viewModel.targetAmount != formatted {
                        viewModel.targetAmount = formatted
                    }
                }
            Text("₫")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "calendar")
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                Text("Kỳ ngân sách")
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            DatePicker("Từ ngày", selection: $viewModel.startDate, displayedComponents: .date)
                .font(AppTypography.body)
                .tint(AppColors.primary)
            DatePicker("Đến ngày", selection: $viewModel.endDate, displayedComponents: .date)
                .font(AppTypography.body)
                .tint(AppColors.primary)
            if !viewModel.budgetPeriodSummary.isEmpty {
                Text(viewModel.budgetPeriodSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recurringSection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "repeat")
                .font(AppTypography.iconMedium)
                .foregroundStyle(AppColors.primary)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            Toggle("Tự động lặp lại", isOn: $viewModel.isRecurring)
                .font(AppTypography.body)
                .tint(AppColors.primary)
        }
    }
}

