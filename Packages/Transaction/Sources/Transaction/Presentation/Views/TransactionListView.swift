//
//  TransactionListView.swift
//  Transaction
//
// swiftlint:disable file_length
// Justification: Main transaction list with summary card and filtering UI. All components are related.
// Extracting would create artificial separation. Well-organized with MARK sections.

import FinFlowCore
import SwiftUI

/// UI for the new Transaction List View
/// Designed with Apple's Liquid Glass style leveraging FinFlowCore DesignSystem
public struct TransactionListView: View {
    // For prototype purposes, we use simple state
    @State private var selectedTab: TransactionTab = .history
    @State private var transactionToDelete: TransactionResponse?
    @State private var showDeleteConfirmation: Bool = false

    enum TransactionTab: String, CaseIterable, Identifiable {
        case history = "Lịch sử"
        case analytics = "Thống kê"
        var id: String { self.rawValue }
    }

    // ViewModel
    @State private var viewModel: TransactionListViewModel

    public init(viewModel: TransactionListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 1. Core Background
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: .zero) {
                // Custom Navigation Bar
                HStack {
                    Spacer()
                    Text("Giao dịch")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding()

                VStack(spacing: Spacing.lg) {
                    // 2. Tab Segmented Control
                    Picker("Chế độ xem", selection: $selectedTab) {
                        ForEach(TransactionTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, Spacing.sm)

                    if selectedTab == .history {
                        // 3. Summary Glass Card
                        summaryCard
                            .padding(.horizontal)

                        // 4. Search & Filter
                        HStack(spacing: Spacing.sm) {
                            GlassField(
                                text: $viewModel.searchText,
                                placeholder: "Tìm kiếm giao dịch...",
                                icon: "magnifyingglass",
                                isSecure: false
                            )

                            // Filter Button (shows badge if filter is active)
                            Button {
                                viewModel.showFilterSheet = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(AppColors.cardBackground)
                                        .frame(
                                            width: Spacing.lg + Spacing.md,
                                            height: Spacing.lg + Spacing.md)

                                    Image(
                                        systemName: viewModel.filterStartDate != nil
                                            ? "line.3.horizontal.decrease.circle.fill"
                                            : "line.3.horizontal.decrease.circle"
                                    )
                                    .font(AppTypography.iconMedium)
                                    .foregroundStyle(AppColors.primary)

                                    // Active filter badge
                                    if viewModel.filterStartDate != nil {
                                        Circle()
                                            .fill(AppColors.success)
                                            .frame(width: Spacing.xs, height: Spacing.xs)
                                            .offset(x: Spacing.sm, y: -Spacing.sm)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // 5. Content List
                        List {
                            // Grouped Transactions by Date
                            if viewModel.transactions.isEmpty {
                                if viewModel.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding(.top, Spacing.xl)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                } else if viewModel.hasLoadError {
                                    VStack(spacing: Spacing.sm) {
                                        Text("Không thể tải dữ liệu")
                                            .font(AppTypography.headline)
                                        Text("Vui lòng kiểm tra kết nối mạng và thử lại.")
                                            .font(AppTypography.body)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                        Button("Thử lại") {
                                            Task { await viewModel.fetchData(isInitial: true) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding(.top, Spacing.xl)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                } else {
                                    VStack(spacing: Spacing.md) {
                                        Image(systemName: "tray")
                                            .font(AppTypography.displaySmall)
                                            .foregroundColor(.secondary)
                                        Text("Chưa có giao dịch nào")
                                            .font(AppTypography.body)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, Spacing.xl)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            } else {
                                ForEach(viewModel.groupedTransactions, id: \.title) { group in
                                    Section {
                                        // Transaction Items in this group
                                        ForEach(group.items) { transaction in
                                            transactionItem(
                                                title: transaction.note
                                                    ?? transaction.category.name,
                                                category: transaction.category.name,
                                                amount: CurrencyFormatter.formatWithSign(
                                                    transaction.amount,
                                                    isIncome: transaction.type == .income),
                                                isIncome: transaction.type == .income,
                                                icon: transaction.category.icon,
                                                color: Color(hex: transaction.category.color)
                                            )
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(
                                                EdgeInsets(
                                                    top: Spacing.xs / 2,
                                                    leading: Spacing.sm2,
                                                    bottom: Spacing.xs / 2,
                                                    trailing: Spacing.sm2)
                                            )
                                            .onTapGesture {
                                                viewModel.presentEditTransaction(transaction)
                                            }
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    transactionToDelete = transaction
                                                    showDeleteConfirmation = true
                                                } label: {
                                                    Label("Xóa", systemImage: "trash")
                                                }
                                            }
                                            .onAppear {
                                                Task {
                                                    await viewModel.loadMoreIfNeeded(
                                                        currentItem: transaction)
                                                }
                                            }
                                        }
                                    } header: {
                                        HStack {
                                            Text(group.title)
                                                .font(AppTypography.headline)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, Spacing.sm2)
                                        .padding(.top, Spacing.xs)
                                        .padding(.bottom, Spacing.xs / 2)
                                        .textCase(nil)
                                    }
                                }

                                if viewModel.isLoading && !viewModel.transactions.isEmpty {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: Spacing.xl * 2)
                        }
                    } else {
                        // Analytics View
                        TransactionAnalyticsView(
                            summary: viewModel.summary,
                            chartData: viewModel.chartData,
                            currentRange: viewModel.chartRange,
                            onRangeChange: { newRange in
                                viewModel.updateChartRange(newRange)
                            },
                            onNavigateBack: {
                                viewModel.navigateChartBack()
                            },
                            onNavigateForward: {
                                viewModel.navigateChartForward()
                            },
                            isLoading: viewModel.isChartLoading,
                            hasLoadError: viewModel.hasLoadError,
                            onRetry: {
                                Task { await viewModel.fetchChartData() }
                            }
                        )
                    }
                }
            }  // End of VStack

            // Custom FAB
            Button {
                viewModel.presentAddTransaction()
            } label: {
                Image(systemName: "plus")
                    .font(AppTypography.displaySmall)
                    .foregroundStyle(AppColors.textInverted)
                    .frame(width: Spacing.lg * 2, height: Spacing.lg * 2)
                    .background(
                        LinearGradient(
                            colors: [
                                AppColors.primary, AppColors.primary.opacity(OpacityLevel.high)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(
                        color: AppColors.primary.opacity(OpacityLevel.low),
                        radius: ShadowStyle.soft().radius,
                        x: ShadowStyle.soft().x,
                        y: ShadowStyle.soft().y)
            }
            .padding()
        }
        .task {
            if viewModel.transactions.isEmpty {
                await viewModel.fetchData(isInitial: true)
            }
        }
        .dateRangeFilterSheet(
            isPresented: $viewModel.showFilterSheet,
            startDate: $viewModel.filterStartDate,
            endDate: $viewModel.filterEndDate,
            onApply: {
                viewModel.applyFilter()
            },
            onClear: {
                viewModel.clearFilter()
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .transactionDidSave)) { _ in
            Task {
                await viewModel.fetchData(isInitial: true)
            }
        }
        .alertHandler(
            Binding<AppErrorAlert?>(
                get: { viewModel.alert },
                set: { viewModel.alert = $0 }
            )
        )
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                if let transaction = transactionToDelete {
                    Task {
                        await viewModel.deleteTransaction(id: transaction.id)
                    }
                }
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa giao dịch này không?")
        }
    }

    // MARK: - Components

    private var summaryCard: some View {
        VStack(spacing: Spacing.sm) {
            Text("Tổng số dư")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: Spacing.xl)
            } else {
                Text(
                    viewModel.displaySummary.map {
                        CurrencyFormatter.formatBalance($0.totalBalance)
                    }
                        ?? "--"
                )
                .font(AppTypography.displayLarge)
                .foregroundStyle(.primary)

                HStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.success)
                            Text("Thu nhập")
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            viewModel.displaySummary.map {
                                CurrencyFormatter.formatWithSign($0.totalIncome, isIncome: true)
                            }
                                ?? "--"
                        )
                        .font(AppTypography.headline)
                    }

                    Divider()
                        .frame(height: Spacing.xl)
                        .background(AppColors.disabled.opacity(OpacityLevel.strong))

                    VStack(spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(AppColors.google)
                            Text("Chi tiêu")
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            viewModel.displaySummary.map {
                                CurrencyFormatter.formatWithSign($0.totalExpense, isIncome: false)
                            } ?? "--"
                        )
                        .font(AppTypography.headline)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.large)
        .shadow(
            color: AppColors.disabled.opacity(OpacityLevel.strong),
            radius: Spacing.xs,
            x: 0,
            y: Spacing.xs / 4)
    }

    // swiftlint:disable:next function_parameter_count
    private func transactionItem(
        title: String,
        category: String,
        amount: String,
        isIncome: Bool,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: Spacing.md) {
            // Category Icon with Glass background
            ZStack {
                Circle()
                    .fill(color.opacity(OpacityLevel.ultraLight))
                    .frame(
                        width: Spacing.lg + Spacing.sm2,
                        height: Spacing.lg + Spacing.sm2)

                Image(systemName: icon)
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Text(category)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(amount)
                .font(AppTypography.headline)
                .foregroundStyle(isIncome ? AppColors.success : .primary)
        }
        .padding(Spacing.md)
        // Solid Card Effect for List Items
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}
