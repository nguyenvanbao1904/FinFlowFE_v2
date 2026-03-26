//
//  BudgetListView.swift
//  Planning
//
//  Main budget list screen with summary and budget cards (API-backed).
//  Apple HIG: List-based layout, swipe to delete, confirmation before delete.
//

import FinFlowCore
import SwiftUI

public struct BudgetListView: View {
    @State private var viewModel: BudgetListViewModel
    @State private var budgetToDelete: BudgetResponse?
    @State private var showDeleteConfirmation = false

    public init(viewModel: BudgetListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.budgets.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                List {
                    Section {
                        summaryCard
                            .listRowInsets(EdgeInsets(top: Spacing.sm, leading: .zero, bottom: Spacing.sm, trailing: .zero))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if viewModel.hasExceededBudgets || viewModel.hasWarningBudgets {
                        Section {
                            warningBanner
                                .listRowInsets(EdgeInsets(top: Spacing.sm, leading: .zero, bottom: Spacing.sm, trailing: .zero))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }

                    Section {
                        ForEach(viewModel.budgets) { budgetWithSpending in
                            Button {
                                viewModel.presentEditBudget(budgetWithSpending.budget)
                            } label: {
                                BudgetRow(
                                    budget: budgetWithSpending.budget,
                                    spentAmount: budgetWithSpending.spentAmount
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    budgetToDelete = budgetWithSpending.budget
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    viewModel.presentEditBudget(budgetWithSpending.budget)
                                } label: {
                                    Label("Sửa", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    budgetToDelete = budgetWithSpending.budget
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Danh sách ngân sách")
                            .font(AppTypography.headline)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: Spacing.xl * 2)
                }
            }
        }
        .task { await viewModel.loadBudgets() }
        .refreshable { await viewModel.loadBudgets(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .budgetDidSave)) { _ in
            Task { await viewModel.loadBudgets(force: true) }
        }
        .alertHandler(Binding(
            get: { viewModel.loadError },
            set: { viewModel.loadError = $0 }
        ))
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {
                budgetToDelete = nil
            }
            Button("Xóa", role: .destructive) {
                if let budget = budgetToDelete {
                    Task { await viewModel.deleteBudget(budget) }
                }
                budgetToDelete = nil
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa ngân sách này?")
        }
    }

    private var summaryCard: some View {
        FinancialHeroCard(
            title: "Tổng quan ngân sách",
            mainAmount: CurrencyFormatter.format(viewModel.totalBudget),
            subtitle: "\(Int(viewModel.overallProgress * 100))% đã chi tiêu"
        ) {
            VStack(spacing: Spacing.md) {
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Đã chi")
                            .font(AppTypography.caption)
                        Spacer()
                        Text(CurrencyFormatter.format(viewModel.totalSpent))
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                    }
                    ProgressBar(
                        current: viewModel.totalSpent,
                        total: viewModel.totalBudget,
                        color: .white
                    )
                }
                Divider()
                HStack(spacing: Spacing.lg) {
                    heroStatItem(icon: "chart.bar.fill", label: "Ngân sách", value: "\(viewModel.budgets.count)")
                    Spacer()
                    heroStatItem(
                        icon: "exclamationmark.triangle.fill",
                        label: "Cảnh báo",
                        value: "\(viewModel.budgets.filter { $0.isNearLimit || $0.isExceeded }.count)"
                    )
                }
            }
        }
    }

    private func heroStatItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(AppTypography.caption)
                Text(label)
                    .font(AppTypography.caption)
            }
            .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))
            Text(value)
                .font(AppTypography.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textInverted)
        }
    }

    private var warningBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppTypography.iconMedium)
                .foregroundStyle(AppColors.google)
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                Text("Cảnh báo ngân sách")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.primary)
                Text(
                    viewModel.hasExceededBudgets
                        ? "Bạn đã vượt giới hạn một số ngân sách" : "Một số ngân sách sắp hết"
                )
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColors.google.opacity(OpacityLevel.ultraLight))
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.google.opacity(OpacityLevel.low), lineWidth: BorderWidth.thin)
        )
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.bar.doc.horizontal",
            title: "Chưa có ngân sách nào",
            subtitle: "Tạo ngân sách để kiểm soát chi tiêu của bạn",
            buttonTitle: "Tạo ngân sách đầu tiên",
            action: { viewModel.presentAddBudget() }
        )
        .emptyStateFrame()
    }
}

// MARK: - Budget Row

private struct BudgetRow: View {
    let budget: BudgetResponse
    let spentAmount: Double

    private var progressColor: Color {
        let progress = budget.targetAmount > 0 ? spentAmount / budget.targetAmount : 0
        if progress >= 1.0 { return AppColors.google }
        if progress >= 0.9 { return AppColors.google }
        if progress >= 0.75 { return AppColors.accent }
        return AppColors.success
    }

    var body: some View {
        IconTitleTrailingRow(
            icon: budget.categoryIcon,
            color: Color(hex: budget.categoryColor),
            title: budget.categoryName,
            subtitle: budget.isRecurring ? "Tự động lặp lại" : nil,
            trailing: {
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(CurrencyFormatter.format(spentAmount))
                        .font(AppTypography.subheadline)
                        .foregroundStyle(progressColor)
                    Text("Giới hạn: \(CurrencyFormatter.format(budget.targetAmount))")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            },
            bottom: {
                ProgressBar(
                    current: spentAmount,
                    total: budget.targetAmount,
                    color: progressColor,
                    height: Spacing.xs
                )
            }
        )
    }
}
