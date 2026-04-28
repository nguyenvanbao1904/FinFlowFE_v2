import Charts
import FinFlowCore
import SwiftUI

// MARK: - Section Orchestrator

public struct FinancialChartsSection: View {
    let financials: FinancialDataSeries?
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?

    @State private var fullscreenChart: ChartKind?

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
                case .bank(let items, let cashFlows):
                    bankCharts(items, cashFlows: cashFlows)
                case .nonBank(let items, let cashFlows):
                    nonBankCharts(items, cashFlows: cashFlows)
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
    private func bankCharts(_ items: [BankFinancialDataPoint], cashFlows: [CashFlowDataPoint]) -> some View {
        let series = items.filter {
            showQuarterly ? $0.quarter != 0 : ($0.quarter == 0 && ($0.quarterCount ?? 4) == 4)
        }
        assetStructureBankCard(series)
        capitalStructureBankCard(series)
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })
        toiStructureBankCard(series)
        profitabilityBankCard(series)
        let profitData = series.compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0, yoy: item.yoyGrowth) }
        }
        profitGrowthCard(profitData)
        nplCompositeBankCard(series)
        customerLoanBankCard(series)
        dividendCard(bankDividendRows(items))
        cashFlowCard(cashFlows)
    }

    @ViewBuilder
    private func nonBankCharts(_ items: [NonBankFinancialDataPoint], cashFlows: [CashFlowDataPoint]) -> some View {
        let series = items.filter {
            showQuarterly ? $0.quarter != 0 : ($0.quarter == 0 && ($0.quarterCount ?? 4) == 4)
        }
        assetStructureNonBankCard(series)
        capitalStructureNonBankCard(series)
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })
        revenueYoYGrowthNonBankCard(series)
        profitYoYGrowthNonBankCard(series)
        nonBankMarginsCard(series)
        cashFlowCard(cashFlows)
        inventoryTurnoverNonBankCard(series)
        dividendCard(nonBankDividendRows(items))
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
        case .assetNonBank:
            nonBankAssetChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .capitalNonBank:
            nonBankCapitalChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .cashFlow:
            cashFlowChart(filteredCashFlows(), height: height, fullScreen: true)
        case .nplCompositeBank:
            nplCompositeBankChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .customerLoanBank:
            customerLoanBankChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .inventoryTurnoverNonBank:
            inventoryTurnoverChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .dividend:
            dividendFullscreenChart(height: height)
        case .profitabilityBank:
            profitabilityBankChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        }
    }

    private func filteredSortedBankSeries() -> [BankFinancialDataPoint] {
        guard case .bank(let items, _) = financials else { return [] }
        return items.filter {
            showQuarterly ? $0.quarter != 0 : ($0.quarter == 0 && ($0.quarterCount ?? 4) == 4)
        }
    }

    private func filteredSortedNonBankSeries() -> [NonBankFinancialDataPoint] {
        guard case .nonBank(let items, _) = financials else { return [] }
        return items.filter {
            showQuarterly ? $0.quarter != 0 : ($0.quarter == 0 && ($0.quarterCount ?? 4) == 4)
        }
    }

    private func filteredCashFlows() -> [CashFlowDataPoint] {
        let cfs: [CashFlowDataPoint]
        switch financials {
        case .bank(_, let cashFlows): cfs = cashFlows
        case .nonBank(_, let cashFlows): cfs = cashFlows
        case nil: return []
        }
        return cfs.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
    }

    private func bankProfitSeries() -> [(year: Int, quarter: Int, value: Double, yoy: Double?)] {
        filteredSortedBankSeries().compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0, yoy: item.yoyGrowth) }
        }
    }

    private func bankDividendRows(_ items: [BankFinancialDataPoint]) -> [DividendChartRow] {
        items.map { item in
            let divPaid: Double? = {
                guard let cd = item.cashDividend, let sh = item.shareAtPeriodEnd else { return nil }
                return cd * sh
            }()
            return DividendChartRow(
                year: item.year, quarter: item.quarter,
                profitAfterTax: item.profitAfterTax,
                dividendPaid: divPaid,
                payoutRatio: item.payoutRatio
            )
        }
    }

    private func nonBankDividendRows(_ items: [NonBankFinancialDataPoint]) -> [DividendChartRow] {
        items.map { item in
            let divPaid: Double? = {
                guard let cd = item.cashDividend, let sh = item.shareAtPeriodEnd else { return nil }
                return cd * sh
            }()
            return DividendChartRow(
                year: item.year, quarter: item.quarter,
                profitAfterTax: item.profitAfterTax,
                dividendPaid: divPaid,
                payoutRatio: item.payoutRatio
            )
        }
    }

    @ViewBuilder
    private func dividendFullscreenChart(height: CGFloat) -> some View {
        switch financials {
        case .bank(let items, _):
            let series = items.filter { $0.quarter == 0 }
            dividendChart(bankDividendRows(series), height: height, fullScreen: true)
        case .nonBank(let items, _):
            let series = items.filter { $0.quarter == 0 }
            dividendChart(nonBankDividendRows(series), height: height, fullScreen: true)
        case nil:
            EmptyView()
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
