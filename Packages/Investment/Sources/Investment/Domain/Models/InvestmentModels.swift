import Foundation

// MARK: - Overview
public struct StockOverview: Equatable, Sendable {
    public let symbol: String
    public let companyName: String
    public let exchange: String
    /// Ví dụ `BANK` — P/S theo ngày không áp dụng (backend chỉ tính DTT kiểu non-bank).
    public let companyType: String?
    /// Mã ICB — nhãn ngành lấy từ bảng `industries` (API join), không duplicate trên company.
    public let industryIcbCode: String?
    /// Nhãn ngành hiển thị (từ `industries.label` hoặc mock).
    public let industryLabel: String
    public let description: String
    
    // Key stats
    public let roe: Double
    public let roa: Double
    public let eps: Double
    public let bvps: Double
    public let cplh: Double // Cổ phiếu lưu hành (tỷ)
    
    // Valuation vs lịch sử (trung vị + trung bình trên các quý có chỉ số trong DB)
    public let currentPE: Double
    public let medianPE: Double
    public let meanPE: Double?
    public let currentPB: Double
    public let medianPB: Double
    public let meanPB: Double?
    public let currentPS: Double
    public let medianPS: Double
    public let meanPS: Double?

    /// Bội số theo giá VPS gần nhất (backend: close hoặc last fallback) và BCTC (EPS TTM, BVPS, DTT TTM…).
    public let livePE: Double?
    public let livePB: Double?
    public let livePS: Double?
    public let livePriceVnd: Double?
    public let livePriceSource: String?

    public var displayPE: Double { livePE ?? currentPE }
    public var displayPB: Double { livePB ?? currentPB }
    public var displayPS: Double { livePS ?? currentPS }

    public var isBankCompany: Bool {
        (companyType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "BANK"
    }

    public init(
        symbol: String,
        companyName: String,
        exchange: String,
        companyType: String? = nil,
        industryIcbCode: String? = nil,
        industryLabel: String,
        description: String,
        roe: Double,
        roa: Double,
        eps: Double,
        bvps: Double,
        cplh: Double,
        currentPE: Double,
        medianPE: Double,
        meanPE: Double? = nil,
        currentPB: Double,
        medianPB: Double,
        meanPB: Double? = nil,
        currentPS: Double,
        medianPS: Double,
        meanPS: Double? = nil,
        livePE: Double? = nil,
        livePB: Double? = nil,
        livePS: Double? = nil,
        livePriceVnd: Double? = nil,
        livePriceSource: String? = nil
    ) {
        self.symbol = symbol
        self.companyName = companyName
        self.exchange = exchange
        self.companyType = companyType
        self.industryIcbCode = industryIcbCode
        self.industryLabel = industryLabel
        self.description = description
        self.roe = roe
        self.roa = roa
        self.eps = eps
        self.bvps = bvps
        self.cplh = cplh
        self.currentPE = currentPE
        self.medianPE = medianPE
        self.meanPE = meanPE
        self.currentPB = currentPB
        self.medianPB = medianPB
        self.meanPB = meanPB
        self.currentPS = currentPS
        self.medianPS = medianPS
        self.meanPS = meanPS
        self.livePE = livePE
        self.livePB = livePB
        self.livePS = livePS
        self.livePriceVnd = livePriceVnd
        self.livePriceSource = livePriceSource
    }
}

// MARK: - Shareholders
public struct ShareholderDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let name: String
    public let percentage: Double
    public let quantity: Double
    
    public init(name: String, percentage: Double, quantity: Double) {
        self.name = name
        self.percentage = percentage
        self.quantity = quantity
    }
}

/// Chuỗi định giá theo ngày (API `.../valuations/daily`).
public struct DailyValuationDataPoint: Identifiable, Equatable, Sendable {
    public var id: String { date }
    public let date: String
    public let pe: Double?
    public let pb: Double?
    public let ps: Double?

    public init(date: String, pe: Double?, pb: Double?, ps: Double?) {
        self.date = date
        self.pe = pe
        self.pb = pb
        self.ps = ps
    }
}

public enum ValuationSeriesGranularity: String, CaseIterable, Sendable {
    case quarterly = "Quý"
    case daily = "Ngày"
}

// MARK: - Time-series Financial Data
public struct ValuationDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let year: Int
    public let quarter: Int
    public let pe: Double
    public let pb: Double
    public let ps: Double
    
    public var periodLabel: String {
        return "\(year)Q\(quarter)"
    }
    
    public init(year: Int, quarter: Int, pe: Double, pb: Double, ps: Double) {
        self.year = year
        self.quarter = quarter
        self.pe = pe
        self.pb = pb
        self.ps = ps
    }
}

public struct BankFinancialDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let year: Int
    public let quarter: Int

    public var periodLabel: String {
        quarter != 0 ? "Q\(quarter) \(year % 100)" : "\(year)"
    }

    // Balance sheet — assets
    public let cashAndEquivalents: Double?
    public let depositsAtSBV: Double?
    public let interbankPlacements: Double?
    public let tradingSecurities: Double?
    public let investmentSecurities: Double?
    public let customerLoans: Double?
    public let shortTermLoans: Double?
    public let mediumLongTermLoans: Double?
    public let personalLoans: Double?
    public let corporateLoans: Double?

    // Balance sheet — liabilities & equity
    public let sbvBorrowings: Double?
    public let customerDeposits: Double?
    public let valuablePapers: Double?
    public let equity: Double?
    public let depositsBorrowingsOthers: Double?
    public let totalLiabilities: Double?
    public let totalEquity: Double?
    public let issuingValuablePaper: Double?

    // Balance sheet — loan quality
    public let customerLoan: Double?
    public let standardDebt: Double?
    public let watchlistDebt: Double?
    public let substandardDebt: Double?
    public let doubtfulDebt: Double?
    public let badDebt: Double?
    public let provisionForCustomerLoanLoss: Double?

    // Indicators
    public let roe: Double?
    public let roa: Double?
    public let nim: Double?
    public let yoea: Double?
    public let cof: Double?
    public let cir: Double?
    public let ldr: Double?
    public let nplToLoan: Double?
    public let loanlossReservesToNPL: Double?
    public let pe: Double?
    public let pb: Double?
    public let eps: Double?
    public let bvps: Double?
    public let saleGrowth: Double?
    public let profitGrowth: Double?
    public let payoutRatio: Double?
    public let cashDividend: Double?
    public let shareAtPeriodEnd: Double?

    // Income statement
    public let netInterestIncome: Double?
    public let feeAndCommissionIncome: Double?
    public let otherIncome: Double?
    public let profitAfterTax: Double?
    public let interestExpense: Double?
    public let totalOperatingIncome: Double?
    public let totalOperatingExpense: Double?
    public let creditRiskProvisionsExpense: Double?
    public let interestAndSimilarIncome: Double?

    public var totalAssets: Double? {
        let parts = [cashAndEquivalents, depositsAtSBV, interbankPlacements, tradingSecurities, investmentSecurities, customerLoans].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public var totalCapital: Double? {
        let parts = [sbvBorrowings, customerDeposits, valuablePapers, depositsBorrowingsOthers, equity].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public var npl: Double? {
        let parts = [substandardDebt, doubtfulDebt, badDebt].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public init(
        year: Int, quarter: Int = 0,
        cashAndEquivalents: Double? = nil, depositsAtSBV: Double? = nil,
        interbankPlacements: Double? = nil, tradingSecurities: Double? = nil,
        investmentSecurities: Double? = nil, customerLoans: Double? = nil,
        shortTermLoans: Double? = nil, mediumLongTermLoans: Double? = nil,
        personalLoans: Double? = nil, corporateLoans: Double? = nil,
        sbvBorrowings: Double? = nil, customerDeposits: Double? = nil,
        valuablePapers: Double? = nil, equity: Double? = nil,
        depositsBorrowingsOthers: Double? = nil, totalLiabilities: Double? = nil,
        totalEquity: Double? = nil, issuingValuablePaper: Double? = nil,
        customerLoan: Double? = nil, standardDebt: Double? = nil,
        watchlistDebt: Double? = nil, substandardDebt: Double? = nil,
        doubtfulDebt: Double? = nil, badDebt: Double? = nil,
        provisionForCustomerLoanLoss: Double? = nil,
        roe: Double? = nil, roa: Double? = nil,
        nim: Double? = nil, yoea: Double? = nil, cof: Double? = nil,
        cir: Double? = nil, ldr: Double? = nil,
        nplToLoan: Double? = nil, loanlossReservesToNPL: Double? = nil,
        pe: Double? = nil, pb: Double? = nil,
        eps: Double? = nil, bvps: Double? = nil,
        saleGrowth: Double? = nil, profitGrowth: Double? = nil,
        payoutRatio: Double? = nil, cashDividend: Double? = nil,
        shareAtPeriodEnd: Double? = nil,
        netInterestIncome: Double? = nil, feeAndCommissionIncome: Double? = nil,
        otherIncome: Double? = nil, profitAfterTax: Double? = nil,
        interestExpense: Double? = nil,
        totalOperatingIncome: Double? = nil, totalOperatingExpense: Double? = nil,
        creditRiskProvisionsExpense: Double? = nil, interestAndSimilarIncome: Double? = nil
    ) {
        self.year = year; self.quarter = quarter
        self.cashAndEquivalents = cashAndEquivalents; self.depositsAtSBV = depositsAtSBV
        self.interbankPlacements = interbankPlacements; self.tradingSecurities = tradingSecurities
        self.investmentSecurities = investmentSecurities; self.customerLoans = customerLoans
        self.shortTermLoans = shortTermLoans; self.mediumLongTermLoans = mediumLongTermLoans
        self.personalLoans = personalLoans; self.corporateLoans = corporateLoans
        self.sbvBorrowings = sbvBorrowings; self.customerDeposits = customerDeposits
        self.valuablePapers = valuablePapers; self.equity = equity
        self.depositsBorrowingsOthers = depositsBorrowingsOthers; self.totalLiabilities = totalLiabilities
        self.totalEquity = totalEquity; self.issuingValuablePaper = issuingValuablePaper
        self.customerLoan = customerLoan; self.standardDebt = standardDebt
        self.watchlistDebt = watchlistDebt; self.substandardDebt = substandardDebt
        self.doubtfulDebt = doubtfulDebt; self.badDebt = badDebt
        self.provisionForCustomerLoanLoss = provisionForCustomerLoanLoss
        self.roe = roe; self.roa = roa
        self.nim = nim; self.yoea = yoea; self.cof = cof
        self.cir = cir; self.ldr = ldr
        self.nplToLoan = nplToLoan; self.loanlossReservesToNPL = loanlossReservesToNPL
        self.pe = pe; self.pb = pb; self.eps = eps; self.bvps = bvps
        self.saleGrowth = saleGrowth; self.profitGrowth = profitGrowth
        self.payoutRatio = payoutRatio; self.cashDividend = cashDividend
        self.shareAtPeriodEnd = shareAtPeriodEnd
        self.netInterestIncome = netInterestIncome; self.feeAndCommissionIncome = feeAndCommissionIncome
        self.otherIncome = otherIncome; self.profitAfterTax = profitAfterTax
        self.interestExpense = interestExpense
        self.totalOperatingIncome = totalOperatingIncome; self.totalOperatingExpense = totalOperatingExpense
        self.creditRiskProvisionsExpense = creditRiskProvisionsExpense
        self.interestAndSimilarIncome = interestAndSimilarIncome
    }
}

public struct NonBankFinancialDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let year: Int
    public let quarter: Int

    public var periodLabel: String {
        quarter != 0 ? "Q\(quarter) \(year % 100)" : "\(year)"
    }

    // Balance sheet — assets
    public let cashAndEquivalents: Double?
    public let shortTermInvestments: Double?
    public let shortTermReceivables: Double?
    public let inventories: Double?
    public let fixedAssets: Double?
    public let longTermReceivables: Double?
    public let totalAssetsReported: Double?
    public let inProgressLongTermAsset: Double?

    // Balance sheet — liabilities & equity
    public let equity: Double?
    public let shortTermBorrowings: Double?
    public let longTermBorrowings: Double?
    public let advancesFromCustomers: Double?
    public let totalCapitalReported: Double?
    public let totalLiabilities: Double?
    public let convertibleBond: Double?

    // Indicators
    public let roe: Double?
    public let roa: Double?
    public let grossMargin: Double?
    public let netMargin: Double?
    public let pe: Double?
    public let pb: Double?
    public let eps: Double?
    public let bvps: Double?
    public let saleGrowth: Double?
    public let profitGrowth: Double?
    public let currentRatio: Double?
    public let totalDebtOverEquity: Double?
    public let evOverEbitda: Double?
    public let inventoryTurnover: Double?
    public let payoutRatio: Double?
    public let cashDividend: Double?
    public let shareAtPeriodEnd: Double?

    // Income statement
    public let netRevenue: Double?
    public let profitAfterTax: Double?
    public let totalRevenue: Double?
    public let grossProfit: Double?
    public let costOfGoodsSold: Double?
    public let sellingExpense: Double?
    public let managingExpense: Double?

    public var knownAssetComponentsSum: Double? {
        let parts = [cashAndEquivalents, shortTermInvestments, shortTermReceivables, inventories, fixedAssets, longTermReceivables, inProgressLongTermAsset].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public var totalAssets: Double? {
        let known = knownAssetComponentsSum ?? 0
        if let reported = totalAssetsReported, reported > 0 { return reported }
        return known > 0 ? known : nil
    }

    public var otherAssets: Double {
        guard let reported = totalAssetsReported, reported > 0 else { return 0 }
        let known = knownAssetComponentsSum ?? 0
        return max(0, reported - known)
    }

    public var knownCapitalComponentsSum: Double? {
        let parts = [equity, shortTermBorrowings, longTermBorrowings, advancesFromCustomers, convertibleBond].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    public var totalCapitalDisplay: Double? {
        let known = knownCapitalComponentsSum ?? 0
        if let reported = totalCapitalReported, reported > 0 { return reported }
        return known > 0 ? known : nil
    }

    public var otherCapital: Double {
        guard let reported = totalCapitalReported, reported > 0 else { return 0 }
        let known = knownCapitalComponentsSum ?? 0
        return max(0, reported - known)
    }

    public init(
        year: Int, quarter: Int = 0,
        cashAndEquivalents: Double? = nil, shortTermInvestments: Double? = nil,
        shortTermReceivables: Double? = nil, inventories: Double? = nil,
        fixedAssets: Double? = nil, longTermReceivables: Double? = nil,
        totalAssetsReported: Double? = nil, inProgressLongTermAsset: Double? = nil,
        equity: Double? = nil, shortTermBorrowings: Double? = nil,
        longTermBorrowings: Double? = nil, advancesFromCustomers: Double? = nil,
        totalCapitalReported: Double? = nil, totalLiabilities: Double? = nil,
        convertibleBond: Double? = nil,
        roe: Double? = nil, roa: Double? = nil,
        grossMargin: Double? = nil, netMargin: Double? = nil,
        pe: Double? = nil, pb: Double? = nil,
        eps: Double? = nil, bvps: Double? = nil,
        saleGrowth: Double? = nil, profitGrowth: Double? = nil,
        currentRatio: Double? = nil, totalDebtOverEquity: Double? = nil,
        evOverEbitda: Double? = nil, inventoryTurnover: Double? = nil,
        payoutRatio: Double? = nil, cashDividend: Double? = nil,
        shareAtPeriodEnd: Double? = nil,
        netRevenue: Double? = nil, profitAfterTax: Double? = nil,
        totalRevenue: Double? = nil,
        grossProfit: Double? = nil, costOfGoodsSold: Double? = nil,
        sellingExpense: Double? = nil, managingExpense: Double? = nil
    ) {
        self.year = year; self.quarter = quarter
        self.cashAndEquivalents = cashAndEquivalents; self.shortTermInvestments = shortTermInvestments
        self.shortTermReceivables = shortTermReceivables; self.inventories = inventories
        self.fixedAssets = fixedAssets; self.longTermReceivables = longTermReceivables
        self.totalAssetsReported = totalAssetsReported; self.inProgressLongTermAsset = inProgressLongTermAsset
        self.equity = equity; self.shortTermBorrowings = shortTermBorrowings
        self.longTermBorrowings = longTermBorrowings; self.advancesFromCustomers = advancesFromCustomers
        self.totalCapitalReported = totalCapitalReported; self.totalLiabilities = totalLiabilities
        self.convertibleBond = convertibleBond
        self.roe = roe; self.roa = roa
        self.grossMargin = grossMargin; self.netMargin = netMargin
        self.pe = pe; self.pb = pb; self.eps = eps; self.bvps = bvps
        self.saleGrowth = saleGrowth; self.profitGrowth = profitGrowth
        self.currentRatio = currentRatio; self.totalDebtOverEquity = totalDebtOverEquity
        self.evOverEbitda = evOverEbitda; self.inventoryTurnover = inventoryTurnover
        self.payoutRatio = payoutRatio; self.cashDividend = cashDividend
        self.shareAtPeriodEnd = shareAtPeriodEnd
        self.netRevenue = netRevenue; self.profitAfterTax = profitAfterTax
        self.totalRevenue = totalRevenue
        self.grossProfit = grossProfit; self.costOfGoodsSold = costOfGoodsSold
        self.sellingExpense = sellingExpense; self.managingExpense = managingExpense
    }
}

public struct CashFlowDataPoint: Identifiable, Equatable, Sendable {
    public var id: String { "\(year)-\(quarter)" }
    public let year: Int
    public let quarter: Int
    public let operatingCashflow: Double?
    public let investingCashflow: Double?
    public let financingCashflow: Double?

    public var periodLabel: String {
        quarter != 0 ? "Q\(quarter) \(year % 100)" : "\(year)"
    }

    public init(year: Int, quarter: Int = 0, operatingCashflow: Double? = nil, investingCashflow: Double? = nil, financingCashflow: Double? = nil) {
        self.year = year; self.quarter = quarter
        self.operatingCashflow = operatingCashflow; self.investingCashflow = investingCashflow
        self.financingCashflow = financingCashflow
    }
}

public enum FinancialDataSeries: Equatable, Sendable {
    case bank([BankFinancialDataPoint], cashFlows: [CashFlowDataPoint])
    case nonBank([NonBankFinancialDataPoint], cashFlows: [CashFlowDataPoint])
}

// MARK: - Dividends
public struct DividendDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let eventTitle: String
    public let eventType: String // CASH or STOCK
    public let ratio: String
    public let value: Double
    public let recordDate: Date?
    public let exrightDate: Date?
    public let issueDate: Date?

    public init(eventTitle: String, eventType: String, ratio: String, value: Double, recordDate: Date?, exrightDate: Date?, issueDate: Date?) {
        self.eventTitle = eventTitle
        self.eventType = eventType
        self.ratio = ratio
        self.value = value
        self.recordDate = recordDate
        self.exrightDate = exrightDate
        self.issueDate = issueDate
    }
}
