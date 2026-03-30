//
//  HomeView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import FinFlowCore
import SwiftUI

public struct HomeView: View {
    private let router: any AppRouterProtocol
    @Bindable private var viewModel: HomeViewModel

    public init(router: any AppRouterProtocol, viewModel: HomeViewModel) {
        self.router = router
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let error = viewModel.loadError, viewModel.snapshot == nil, !isAuthAlert(error) {
                errorState(error)
            } else if let snapshot = viewModel.snapshot {
                homeContent(snapshot: snapshot)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground)
        .loadingOverlay(viewModel.isLoading)
        .alertHandler(
            Binding(
                get: { viewModel.loadError },
                set: { _ in viewModel.dismissAlert() }
            )
        )
        .task {
            await viewModel.load()
        }
        .navigationTitle("Tổng quan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentSheet(.profile)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Hồ sơ cá nhân")
            }
        }
    }

    @ViewBuilder
    private func errorState(_ error: AppErrorAlert) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppColors.error)
                .accessibilityHidden(true)
            Text(error.title)
                .font(AppTypography.displaySmall)
                .multilineTextAlignment(.center)
            Text(error.message)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load(force: true) }
            } label: {
                Text("Thử lại")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Tải lại dữ liệu tổng quan")
        }
        .padding(Spacing.xl)
    }

    private func homeContent(snapshot: HomeDashboardSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                FinancialHeroCard(
                    title: "Tổng giá trị các danh mục",
                    mainAmount: CurrencyFormatter.format(snapshot.investmentTotalValue),
                    subtitle: "Tiền mặt và cổ phiếu · mọi danh mục"
                )

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Tóm tắt nhanh")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
                        CompactMetricCard(
                            title: "Thu",
                            value: CurrencyFormatter.format(snapshot.totalIncome),
                            caption: "Tổng thu nhập",
                            accent: AppColors.chartGrowthStrong
                        )
                        CompactMetricCard(
                            title: "Chi",
                            value: CurrencyFormatter.format(snapshot.totalExpense),
                            caption: "Tổng chi tiêu",
                            accent: AppColors.expense
                        )
                        CompactMetricCard(
                            title: "Kế hoạch",
                            value: budgetPercentValue(snapshot),
                            caption: budgetCaption(snapshot),
                            accent: budgetAccent(snapshot)
                        )
                        CompactMetricCard(
                            title: "Đầu tư",
                            value: investmentPrimaryValue(snapshot),
                            caption: investmentCaption(snapshot),
                            accent: AppColors.chartRevenue
                        )
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Lối tắt")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
                        quickNavButton(title: "Giao dịch", symbol: "list.clipboard.fill", tab: .transaction, accent: AppColors.chartCapitalDeposits)
                        quickNavButton(title: "Kế hoạch", symbol: "target", tab: .planning, accent: AppColors.chartGrowthStrong)
                        quickNavButton(title: "Tài sản", symbol: "chart.pie.fill", tab: .wealth, accent: AppColors.chartProfit)
                        quickNavButton(title: "Đầu tư", symbol: "chart.line.uptrend.xyaxis", tab: .investment, accent: AppColors.chartRevenue)
                    }
                }
                .accessibilityElement(children: .contain)
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                FinFlowBotGlassOrb(
                    mascotAssetName: "FinFlowBotMascot",
                    mascotBundle: .main,
                    showsNotificationDot: true
                ) {
                    router.presentSheet(.finFlowBotChat)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xs)
        }
    }

    private func quickNavButton(title: String, symbol: String, tab: AppTab, accent: Color) -> some View {
        Button {
            router.selectTab(tab)
        } label: {
            CompactMetricCard(systemImage: symbol, headline: title, accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chuyển tới \(title)")
    }

    private func budgetCaption(_ snapshot: HomeDashboardSnapshot) -> String {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        if target > 0 {
            return "Đã chi \(CurrencyFormatter.format(spent)) · Ngân sách \(CurrencyFormatter.format(target))"
        }
        return "Chưa đặt ngân sách"
    }

    private func budgetPercentValue(_ snapshot: HomeDashboardSnapshot) -> String {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        guard target > 0 else { return "—" }

        let pct = min(spent / target, 1.0)
        return "\(Int((pct * 100).rounded()))%"
    }

    private func budgetAccent(_ snapshot: HomeDashboardSnapshot) -> Color {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        if target > 0, spent > target {
            return AppColors.error
        }
        if target > 0, spent > target * 0.85 {
            return AppColors.chartGrowthStable
        }
        return AppColors.chartCapitalDeposits
    }

    private func investmentPrimaryValue(_ snapshot: HomeDashboardSnapshot) -> String {
        guard snapshot.portfolioCount > 0 else { return "—" }
        return "\(snapshot.portfolioCount)"
    }

    private func investmentCaption(_ snapshot: HomeDashboardSnapshot) -> String {
        if snapshot.portfolioCount == 0 {
            return "Chưa có danh mục"
        }

        let cash = CurrencyFormatter.format(snapshot.portfolioCashTotal)
        let primaryName = snapshot.primaryPortfolioName ?? "Danh mục"
        return "Tiền mặt \(cash) · Danh mục chính: \(primaryName)"
    }

    private func isAuthAlert(_ alert: AppErrorAlert) -> Bool {
        if case .auth = alert { return true }
        if case .authWithAction = alert { return true }
        return false
    }
}
