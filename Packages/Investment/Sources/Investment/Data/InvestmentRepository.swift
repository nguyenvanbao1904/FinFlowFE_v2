import Foundation
import FinFlowCore

public actor InvestmentRepository: InvestmentRepositoryProtocol {
    private let client: any HTTPClientProtocol

    private nonisolated(unsafe) static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getAnalysis(
        symbol: String,
        annualLimit: Int?,
        quarterlyLimit: Int?
    ) async throws -> InvestmentAnalysisBundle {
        let endpoint = analysisEndpoint(
            symbol: symbol,
            pathSuffix: "analysis",
            annualLimit: annualLimit,
            quarterlyLimit: quarterlyLimit
        )
        let response: InvestmentAnalysisDTO = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return map(dto: response)
    }

    public func getFinancialSeries(
        symbol: String,
        annualLimit: Int?,
        quarterlyLimit: Int?
    ) async throws -> FinancialDataSeries? {
        let endpoint = analysisEndpoint(
            symbol: symbol,
            pathSuffix: "analysis/financials",
            annualLimit: annualLimit,
            quarterlyLimit: quarterlyLimit
        )
        let response: FinancialSeriesDTO = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return mapFinancialSeries(dto: response)
    }

    public func getValuations(
        symbol: String,
        annualLimit: Int?,
        startDate: Date?,
        endDate: Date?,
        showQuarterly: Bool?
    ) async throws -> [ValuationDataPoint] {
        let endpoint = analysisEndpoint(
            symbol: symbol,
            pathSuffix: "analysis/valuations",
            annualLimit: annualLimit,
            quarterlyLimit: nil,
            startDate: startDate,
            endDate: endDate,
            showQuarterly: showQuarterly
        )
        let response: [ValuationDTO] = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return mapValuations(response)
    }

    public func getDailyValuations(symbol: String, startDate: Date, endDate: Date) async throws -> [DailyValuationDataPoint] {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let s = Self.dateFormatter.string(from: startDate)
        let e = Self.dateFormatter.string(from: endDate)
        let endpoint =
            "/investments/companies/\(normalized)/analysis/valuations/daily?startDate=\(s)&endDate=\(e)"
        let response: [DailyValuationDTO] = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return mapDailyValuations(response)
    }

    public func getDividends(
        symbol: String,
        annualLimit: Int?
    ) async throws -> [DividendDataPoint] {
        let endpoint = analysisEndpoint(
            symbol: symbol,
            pathSuffix: "analysis/dividends",
            annualLimit: annualLimit,
            quarterlyLimit: nil
        )
        let response: [DividendDTO] = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return mapDividends(response)
    }

    public func suggestCompanies(
        query: String,
        limit: Int?
    ) async throws -> [CompanySuggestionResponse] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        var queryItems: [String] = ["q=\(urlEncode(trimmed))"]
        if let limit, limit > 0 {
            queryItems.append("limit=\(min(limit, 20))")
        }
        let endpoint = "/investments/companies/suggest?" + queryItems.joined(separator: "&")

        return try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getCompanyIndustries(symbols: [String]) async throws -> [CompanyIndustryResponse] {
        let normalized = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        if normalized.isEmpty { return [] }

        let query = normalized
            .map { "symbols=\(urlEncode($0))" }
            .joined(separator: "&")
        let endpoint = "/investments/companies/industries?" + query

        return try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    private func map(dto: InvestmentAnalysisDTO) -> InvestmentAnalysisBundle {
        let overviewDTO = dto.overview
        let overview = StockOverview(
            symbol: overviewDTO.symbol,
            companyName: overviewDTO.companyName ?? "",
            exchange: overviewDTO.exchange ?? "",
            companyType: overviewDTO.companyType,
            industryIcbCode: overviewDTO.industryIcbCode,
            industryLabel: overviewDTO.industryLabel ?? "",
            description: overviewDTO.description ?? "",
            roe: normalizePercent(overviewDTO.roe) ?? 0,
            roa: normalizePercent(overviewDTO.roa) ?? 0,
            eps: overviewDTO.eps ?? 0,
            bvps: overviewDTO.bvps ?? 0,
            cplh: normalizeSharesToBillion(overviewDTO.cplh) ?? 0,
            currentPE: overviewDTO.currentPE ?? 0,
            medianPE: overviewDTO.medianPE ?? 0,
            meanPE: overviewDTO.meanPE,
            currentPB: overviewDTO.currentPB ?? 0,
            medianPB: overviewDTO.medianPB ?? 0,
            meanPB: overviewDTO.meanPB,
            currentPS: overviewDTO.currentPS ?? 0,
            medianPS: overviewDTO.medianPS ?? 0,
            meanPS: overviewDTO.meanPS,
            livePE: overviewDTO.livePe,
            livePB: overviewDTO.livePb,
            livePS: overviewDTO.livePs,
            livePriceVnd: overviewDTO.livePriceVnd,
            livePriceSource: overviewDTO.livePriceSource
        )

        let shareholders = dto.shareholders.map {
            ShareholderDataPoint(
                name: $0.name ?? "",
                percentage: normalizePercent($0.percentage) ?? 0,
                quantity: $0.quantity ?? 0
            )
        }

        let valuations = mapValuations(dto.valuations)

        let financials = mapFinancialSeries(dto: dto.financials)

        let dividends = mapDividends(dto.dividends)

        return InvestmentAnalysisBundle(
            overview: overview,
            shareholders: shareholders,
            valuations: valuations,
            financials: financials,
            dividends: dividends
        )
    }

    private func mapFinancialSeries(dto: FinancialSeriesDTO) -> FinancialDataSeries? {
        if dto.companyType.uppercased() == "BANK" {
            let bank = dto.bank.map { item in
                BankFinancialDataPoint(
                    year: item.year ?? 0,
                    quarter: item.quarter ?? 0,
                    cashAndEquivalents: item.cashAndEquivalents,
                    depositsAtSBV: item.depositsAtSBV,
                    interbankPlacements: item.interbankPlacements,
                    tradingSecurities: item.tradingSecurities,
                    investmentSecurities: item.investmentSecurities,
                    customerLoans: item.customerLoans,
                    shortTermLoans: item.shortTermLoans,
                    mediumLongTermLoans: item.mediumLongTermLoans,
                    personalLoans: item.personalLoans,
                    corporateLoans: item.corporateLoans,
                    sbvBorrowings: item.sbvBorrowings,
                    customerDeposits: item.customerDeposits,
                    valuablePapers: item.valuablePapers,
                    equity: item.equity,
                    roe: normalizePercent(item.roe),
                    roa: normalizePercent(item.roa),
                    netInterestIncome: item.netInterestIncome,
                    feeAndCommissionIncome: item.feeAndCommissionIncome,
                    otherIncome: item.otherIncome,
                    profitAfterTax: item.profitAfterTax,
                    depositsBorrowingsOthers: item.depositsBorrowingsOthers,
                    totalLiabilities: item.totalLiabilities,
                    interestExpense: item.interestExpense
                )
            }
            return .bank(bank)
        } else {
            let nonBank = dto.nonBank.map { item in
                NonBankFinancialDataPoint(
                    year: item.year ?? 0,
                    quarter: item.quarter ?? 0,
                    cashAndEquivalents: item.cashAndEquivalents,
                    shortTermInvestments: item.shortTermInvestments,
                    shortTermReceivables: item.shortTermReceivables,
                    inventories: item.inventories,
                    fixedAssets: item.fixedAssets,
                    longTermReceivables: item.longTermReceivables,
                    totalAssetsReported: item.totalAssets,
                    equity: item.equity,
                    shortTermBorrowings: item.shortTermBorrowings,
                    longTermBorrowings: item.longTermBorrowings,
                    advancesFromCustomers: item.advancesFromCustomers,
                    totalCapitalReported: item.totalCapital,
                    roe: normalizePercent(item.roe),
                    roa: normalizePercent(item.roa),
                    netRevenue: item.netRevenue,
                    profitAfterTax: item.profitAfterTax,
                    grossMargin: normalizePercent(item.grossMargin),
                    netMargin: normalizePercent(item.netMargin),
                    totalLiabilities: item.totalLiabilities,
                    totalRevenue: item.totalRevenue
                )
            }
            return .nonBank(nonBank)
        }
    }

    private func mapValuations(_ valuations: [ValuationDTO]) -> [ValuationDataPoint] {
        valuations.map {
            ValuationDataPoint(
                year: $0.year ?? 0,
                quarter: $0.quarter ?? 4,
                pe: $0.pe ?? 0,
                pb: $0.pb ?? 0,
                ps: $0.ps ?? 0
            )
        }
    }

    private func mapDailyValuations(_ rows: [DailyValuationDTO]) -> [DailyValuationDataPoint] {
        rows.map {
            DailyValuationDataPoint(
                date: $0.date ?? "",
                pe: $0.pe,
                pb: $0.pb,
                ps: $0.ps
            )
        }
    }

    private func mapDividends(_ dividends: [DividendDTO]) -> [DividendDataPoint] {
        dividends.map {
            DividendDataPoint(
                eventTitle: $0.eventTitle ?? "",
                eventType: $0.eventType ?? "",
                ratio: $0.ratio ?? "",
                value: $0.value ?? 0,
                recordDate: parseDate($0.recordDate),
                exrightDate: parseDate($0.exrightDate),
                issueDate: parseDate($0.issueDate)
            )
        }
    }

    private func analysisEndpoint(
        symbol: String,
        pathSuffix: String,
        annualLimit: Int?,
        quarterlyLimit: Int?,
        startDate: Date? = nil,
        endDate: Date? = nil,
        showQuarterly: Bool? = nil
    ) -> String {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var queryItems: [String] = []
        if let annualLimit {
            queryItems.append("annualLimit=\(max(annualLimit, 0))")
        }
        if let quarterlyLimit {
            queryItems.append("quarterlyLimit=\(max(quarterlyLimit, 0))")
        }
        if let startDate {
            queryItems.append("startDate=\(Self.dateFormatter.string(from: startDate))")
        }
        if let endDate {
            queryItems.append("endDate=\(Self.dateFormatter.string(from: endDate))")
        }
        if let showQuarterly {
            queryItems.append("showQuarterly=\(showQuarterly ? "true" : "false")")
        }
        let query = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
        return "/investments/companies/\(normalized)/\(pathSuffix)\(query)"
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return Self.dateFormatter.date(from: value)
    }

    private func normalizePercent(_ value: Double?) -> Double? {
        guard let value else { return nil }
        // Some sources return ratio (0.18), others return percent (18).
        return abs(value) <= 1 ? value * 100 : value
    }

    private func normalizeSharesToBillion(_ value: Double?) -> Double? {
        guard let value else { return nil }
        // UI expects "tỷ cổ phiếu":
        // - absolute shares: 5,136,656,599 -> 5.14
        // - million shares: 5,136.7 -> 5.14
        if abs(value) >= 1_000_000 { return value / 1_000_000_000 }
        if abs(value) >= 1_000 { return value / 1_000 }
        return value
    }
}

private struct InvestmentAnalysisDTO: Codable, Sendable {
    let overview: OverviewDTO
    let shareholders: [ShareholderDTO]
    let valuations: [ValuationDTO]
    let financials: FinancialSeriesDTO
    let dividends: [DividendDTO]
}

private struct OverviewDTO: Codable, Sendable {
    let symbol: String
    let companyName: String?
    let exchange: String?
    let companyType: String?
    let industryIcbCode: String?
    let industryLabel: String?
    let description: String?
    let roe: Double?
    let roa: Double?
    let eps: Double?
    let bvps: Double?
    let cplh: Double?
    let currentPE: Double?
    let medianPE: Double?
    let meanPE: Double?
    let currentPB: Double?
    let medianPB: Double?
    let meanPB: Double?
    let currentPS: Double?
    let medianPS: Double?
    let meanPS: Double?
    let livePe: Double?
    let livePb: Double?
    let livePs: Double?
    let livePriceVnd: Double?
    let livePriceSource: String?
}

private struct ShareholderDTO: Codable, Sendable {
    let name: String?
    let percentage: Double?
    let quantity: Double?
}

private struct ValuationDTO: Codable, Sendable {
    let year: Int?
    let quarter: Int?
    let pe: Double?
    let pb: Double?
    let ps: Double?
}

private struct DailyValuationDTO: Codable, Sendable {
    let date: String?
    let pe: Double?
    let pb: Double?
    let ps: Double?
}

private struct FinancialSeriesDTO: Codable, Sendable {
    let companyType: String
    let bank: [BankPointDTO]
    let nonBank: [NonBankPointDTO]
}

private struct BankPointDTO: Codable, Sendable {
    let year: Int?
    let quarter: Int?
    let cashAndEquivalents: Double?
    let depositsAtSBV: Double?
    let interbankPlacements: Double?
    let tradingSecurities: Double?
    let investmentSecurities: Double?
    let customerLoans: Double?
    let shortTermLoans: Double?
    let mediumLongTermLoans: Double?
    let personalLoans: Double?
    let corporateLoans: Double?
    let sbvBorrowings: Double?
    let customerDeposits: Double?
    let valuablePapers: Double?
    let equity: Double?
    let roe: Double?
    let roa: Double?
    let netInterestIncome: Double?
    let feeAndCommissionIncome: Double?
    let otherIncome: Double?
    let profitAfterTax: Double?
    let depositsBorrowingsOthers: Double?
    let totalLiabilities: Double?
    let interestExpense: Double?
}

private struct NonBankPointDTO: Codable, Sendable {
    let year: Int?
    let quarter: Int?
    let cashAndEquivalents: Double?
    let shortTermInvestments: Double?
    let shortTermReceivables: Double?
    let inventories: Double?
    let fixedAssets: Double?
    let longTermReceivables: Double?
    let totalAssets: Double?
    let equity: Double?
    let shortTermBorrowings: Double?
    let longTermBorrowings: Double?
    let advancesFromCustomers: Double?
    let totalCapital: Double?
    let roe: Double?
    let roa: Double?
    let netRevenue: Double?
    let profitAfterTax: Double?
    let grossMargin: Double?
    let netMargin: Double?
    let totalLiabilities: Double?
    let totalRevenue: Double?
}

private struct DividendDTO: Codable, Sendable {
    let eventTitle: String?
    let eventType: String?
    let ratio: String?
    let value: Double?
    let recordDate: String?
    let exrightDate: String?
    let issueDate: String?
}
