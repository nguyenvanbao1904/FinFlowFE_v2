//
//  TransactionListView.swift
//  Transaction
//

import FinFlowCore
import SwiftUI

public struct TransactionListView: View {
    @State private var selectedTab: TransactionTab = .history
    @State private var transactionToDelete: TransactionResponse?
    @State private var showDeleteConfirmation: Bool = false

    enum TransactionTab: String, CaseIterable, Identifiable {
        case history = "Lịch sử"
        case analytics = "Thống kê"
        var id: String { self.rawValue }
    }

    @Bindable var viewModel: TransactionListViewModel

    public init(viewModel: TransactionListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: .zero) {
            headerSegmentedControl
            contentForSelectedTab
                .animation(.default, value: selectedTab)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Giao dịch")  // Fixed title for smooth transition
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Tìm kiếm giao dịch...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Spacing.md) {
                    Button {
                        viewModel.presentCategoryList()
                    } label: {
                        Image(systemName: "tag")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Quản lý danh mục")

                    Button {
                        viewModel.showFilterSheet = true
                    } label: {
                        Image(
                            systemName: viewModel.filterStartDate != nil
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease"
                        )
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.filterStartDate != nil
                                ? AppColors.success : AppColors.primary
                        )
                    }
                    .accessibilityLabel(
                        viewModel.filterStartDate != nil ? "Bộ lọc đang bật" : "Lọc theo ngày")

                    Button {
                        viewModel.presentAddTransaction()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Thêm giao dịch")
                }
            }
        }
        .task {
            await viewModel.fetchInitialDataIfNeeded()
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .analytics else { return }
            Task {
                await viewModel.loadAnalyticsTabDataIfNeeded()
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
                await viewModel.refreshAfterTransactionMutation()
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

    // MARK: - Header & Content

    private var headerSegmentedControl: some View {
        Picker("Chế độ xem", selection: $selectedTab) {
            ForEach(TransactionTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, Spacing.sm)
        .background(AppColors.settingsCardBackground)
    }

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .history:
            historyTab
        case .analytics:
            analyticsTab
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        List {
            Section {
                TransactionSummaryCard(
                    summary: viewModel.displaySummary,
                    isLoading: viewModel.isLoading
                )
                    .listRowInsets(
                        EdgeInsets(
                            top: Spacing.sm, leading: .zero, bottom: Spacing.sm, trailing: .zero)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

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
                } else if viewModel.hasHistoryLoadError {
                    VStack(spacing: Spacing.sm) {
                        Text("Không thể tải dữ liệu")
                            .font(AppTypography.headline)
                        Text("Vui lòng kiểm tra kết nối mạng và thử lại.")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Thử lại") {
                            Task {
                                viewModel.markAnalyticsInsightsStale()
                                await viewModel.fetchData(
                                    isInitial: true,
                                    refreshSummaryAndChart: true
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, Spacing.xl)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: "Chưa có giao dịch nào",
                        subtitle: "Thêm giao dịch để theo dõi thu chi",
                        buttonTitle: "Thêm giao dịch",
                        action: { viewModel.presentAddTransaction() }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xl)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(viewModel.groupedTransactions, id: \.title) { group in
                    Section {
                        ForEach(group.items) { transaction in
                            Button {
                                viewModel.presentEditTransaction(transaction)
                            } label: {
                                IconTitleTrailingRow(
                                    icon: transaction.category.icon ?? "tag",
                                    color: Color(hex: transaction.category.color),
                                    title: transaction.note ?? transaction.category.name,
                                    subtitle: transaction.category.name,
                                    trailing: {
                                        Text(
                                            CurrencyFormatter.formatWithSign(
                                                transaction.amount,
                                                isIncome: transaction.type == .income
                                            )
                                        )
                                        .font(AppTypography.headline)
                                        .foregroundStyle(
                                            transaction.type == .income ? AppColors.success : .primary)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
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
                                    await viewModel.loadMoreIfNeeded(currentItem: transaction)
                                }
                            }
                        }
                    } header: {
                        Text(group.title)
                            .font(AppTypography.headline)
                            .foregroundStyle(.secondary)
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
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: Spacing.xl * 2)
        }
    }

    // MARK: - Analytics Tab

    private var analyticsTab: some View {
        TransactionAnalyticsView(
            summary: viewModel.summary,
            insights: viewModel.mappedInsights,
            chartData: viewModel.chartData,
            currentRange: viewModel.chartRange,
            onRangeChange: { newRange in
                guard viewModel.chartRange != newRange else { return }
                viewModel.updateChartRange(newRange)
            },
            onNavigateBack: {
                viewModel.navigateChartBack()
            },
            onNavigateForward: {
                viewModel.navigateChartForward()
            },
            isChartLoading: viewModel.isChartLoading,
            hasLoadError: viewModel.hasChartLoadError,
            onRetry: {
                Task { await viewModel.fetchChartData() }
            },
            onGenerateReport: {
                viewModel.generateDetailedReport()
            }
        )
    }

}
