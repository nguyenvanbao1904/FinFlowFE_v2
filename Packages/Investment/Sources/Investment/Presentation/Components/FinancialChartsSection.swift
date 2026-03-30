import Charts
import FinFlowCore
import SwiftUI

// MARK: - Section Orchestrator

public struct FinancialChartsSection: View {
    let financials: FinancialDataSeries?
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?

    @State private var fullscreenChart: ChartKind?

    // Called by chart card wrappers living in separate files.
    // Keeps `fullscreenChart` itself `private` (SwiftUI ownership), while still allowing expansion.
    func expandChartFullscreen(_ kind: ChartKind) {
        fullscreenChart = kind
    }

    public init(
        financials: FinancialDataSeries?,
        showQuarterly: Bool = false,
        onRequestFullHistory: (() -> Void)? = nil
    ) {
        self.financials = financials
        self.showQuarterly = showQuarterly
        self.onRequestFullHistory = onRequestFullHistory
    }

    public var body: some View {
        if let financials {
            VStack(spacing: Spacing.md) {
                switch financials {
                case .bank(let items):
                    bankCharts(items)
                case .nonBank(let items):
                    nonBankCharts(items)
                }
            }
            .fullScreenCover(item: $fullscreenChart) { kind in
                ChartFullscreenContainer(title: kind.title) {
                    GeometryReader { proxy in
                        fullscreenContent(kind: kind, size: proxy.size)
                    }
                }
            }
            .onChange(of: fullscreenChart) { _, newValue in
                guard newValue != nil else { return }
                onRequestFullHistory?()
            }
        }
    }

    @ViewBuilder
    private func bankCharts(_ items: [BankFinancialDataPoint]) -> some View {
        let series = items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
        assetStructureBankCard(series)
        capitalStructureBankCard(series)
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })
        toiStructureBankCard(series)
        nimBankCard(series)
        let profitData = series.compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0) }
        }
        profitGrowthCard(profitData)
    }

    @ViewBuilder
    private func nonBankCharts(_ items: [NonBankFinancialDataPoint]) -> some View {
        let series = items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
        assetStructureNonBankCard(series)
        capitalStructureNonBankCard(series)
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })
        revenueYoYGrowthNonBankCard(series)
        profitYoYGrowthNonBankCard(series)
        nonBankMarginsCard(series)
    }

    @ViewBuilder
    private func fullscreenContent(kind: ChartKind, size: CGSize) -> some View {
        let height = ChartFullscreenSupport.preferredChartHeight(for: size)
        switch kind {
        case .assetBank:
            bankAssetChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .capitalBank:
            bankCapitalChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .roeRoa:
            roeRoaFullscreenChart(height: height)
        case .revenueYoYGrowthNonBank:
            nonBankRevenueYoYChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .profitYoYGrowthNonBank:
            nonBankProfitYoYChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .nonBankMargins:
            nonBankMarginsLineChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .profit:
            bankProfitYoYGrowthChart(bankProfitSeries(), height: height, fullScreen: true)
        case .incomeBank:
            bankIncomeYoYGrowthChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .nimBank:
            bankNimChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .assetNonBank:
            nonBankAssetChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .capitalNonBank:
            nonBankCapitalChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        }
    }

    private func filteredSortedBankSeries() -> [BankFinancialDataPoint] {
        guard case .bank(let items) = financials else { return [] }
        return items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
    }

    private func filteredSortedNonBankSeries() -> [NonBankFinancialDataPoint] {
        guard case .nonBank(let items) = financials else { return [] }
        return items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
    }

    private func bankProfitSeries() -> [(year: Int, quarter: Int, value: Double)] {
        filteredSortedBankSeries().compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0) }
        }
    }

    @ViewBuilder
    private func roeRoaFullscreenChart(height: CGFloat) -> some View {
        switch financials {
        case .bank:
            let pts = filteredSortedBankSeries().map {
                RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa)
            }
            roeRoaChart(pts, height: height, fullScreen: true)
        case .nonBank:
            let pts = filteredSortedNonBankSeries().map {
                RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa)
            }
            roeRoaChart(pts, height: height, fullScreen: true)
        case nil:
            EmptyView()
        }
    }
}
