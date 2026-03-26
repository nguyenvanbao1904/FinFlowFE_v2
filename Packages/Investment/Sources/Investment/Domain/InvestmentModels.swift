import Foundation

// MARK: - Overview
public struct StockOverview: Equatable, Sendable {
    public let symbol: String
    public let companyName: String
    public let exchange: String
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
    
    // Valuation compared to median
    public let currentPE: Double
    public let medianPE: Double
    public let currentPB: Double
    public let medianPB: Double
    public let currentPS: Double
    public let medianPS: Double
    
    public init(symbol: String, companyName: String, exchange: String, industryIcbCode: String? = nil, industryLabel: String, description: String, roe: Double, roa: Double, eps: Double, bvps: Double, cplh: Double, currentPE: Double, medianPE: Double, currentPB: Double, medianPB: Double, currentPS: Double, medianPS: Double) {
        self.symbol = symbol
        self.companyName = companyName
        self.exchange = exchange
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
        self.currentPB = currentPB
        self.medianPB = medianPB
        self.currentPS = currentPS
        self.medianPS = medianPS
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

// Chuyên biệt cho Ngân Hàng (Áp dụng cho ACB)
public struct BankFinancialDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let year: Int
    public let quarter: Int
    
    // Cơ cấu tài sản
    public let cashAndEquivalents: Double?
    public let depositsAtSBV: Double?
    public let interbankPlacements: Double?
    public let tradingSecurities: Double?
    public let investmentSecurities: Double?
    public let customerLoans: Double?
    
    // Phân rã cho vay
    public let shortTermLoans: Double?
    public let mediumLongTermLoans: Double?
    public let personalLoans: Double?
    public let corporateLoans: Double?
    
    // Cơ cấu nguồn vốn
    public let sbvBorrowings: Double?
    public let customerDeposits: Double?
    public let valuablePapers: Double? // Giấy tờ có giá
    public let equity: Double? // Vốn chủ sở hữu
    
    // Hiệu quả hoạt động / Ngân hàng chuyên sâu
    public let roe: Double?
    public let roa: Double?
    
    // Thu nhập
    public let netInterestIncome: Double? // Thu nhập lãi thuần
    public let feeAndCommissionIncome: Double? // Lãi thuần hoạt động dịch vụ
    public let otherIncome: Double? // Thu nhập khác
    public let profitAfterTax: Double? // Lợi nhuận sau thuế
    public let depositsBorrowingsOthers: Double? // Tiền gửi và vay TCTD khác
    public let totalLiabilities: Double? // Tổng nợ phải trả
    public let interestExpense: Double? // Chi phí lãi
    
    // Computed Total Asset
    public var totalAssets: Double? {
        let parts = [cashAndEquivalents, depositsAtSBV, interbankPlacements, tradingSecurities, investmentSecurities, customerLoans].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }
    
    // Computed Total Capital
    public var totalCapital: Double? {
        let parts = [sbvBorrowings, customerDeposits, valuablePapers, depositsBorrowingsOthers, equity].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }
    
    public init(
        year: Int,
        quarter: Int = 0,
        cashAndEquivalents: Double?,
        depositsAtSBV: Double?,
        interbankPlacements: Double?,
        tradingSecurities: Double?,
        investmentSecurities: Double?,
        customerLoans: Double?,
        shortTermLoans: Double?,
        mediumLongTermLoans: Double?,
        personalLoans: Double?,
        corporateLoans: Double?,
        sbvBorrowings: Double?,
        customerDeposits: Double?,
        valuablePapers: Double?,
        equity: Double?,
        roe: Double?,
        roa: Double?,
        netInterestIncome: Double?,
        feeAndCommissionIncome: Double?,
        otherIncome: Double?,
        profitAfterTax: Double?,
        depositsBorrowingsOthers: Double?,
        totalLiabilities: Double?,
        interestExpense: Double?
    ) {
        self.year = year
        self.quarter = quarter
        self.cashAndEquivalents = cashAndEquivalents
        self.depositsAtSBV = depositsAtSBV
        self.interbankPlacements = interbankPlacements
        self.tradingSecurities = tradingSecurities
        self.investmentSecurities = investmentSecurities
        self.customerLoans = customerLoans
        self.shortTermLoans = shortTermLoans
        self.mediumLongTermLoans = mediumLongTermLoans
        self.personalLoans = personalLoans
        self.corporateLoans = corporateLoans
        self.sbvBorrowings = sbvBorrowings
        self.customerDeposits = customerDeposits
        self.valuablePapers = valuablePapers
        self.equity = equity
        self.roe = roe
        self.roa = roa
        self.netInterestIncome = netInterestIncome
        self.feeAndCommissionIncome = feeAndCommissionIncome
        self.otherIncome = otherIncome
        self.profitAfterTax = profitAfterTax
        self.depositsBorrowingsOthers = depositsBorrowingsOthers
        self.totalLiabilities = totalLiabilities
        self.interestExpense = interestExpense
    }
}

// Chuyên biệt cho Công ty thường (Áp dụng cho AAA và các non-bank)
public struct NonBankFinancialDataPoint: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let year: Int
    public let quarter: Int
    
    // Cơ cấu tài sản
    public let cashAndEquivalents: Double?
    public let shortTermInvestments: Double?
    public let shortTermReceivables: Double?
    public let inventories: Double?
    public let fixedAssets: Double?
    public let longTermReceivables: Double?
    /// Tổng tài sản theo BCTC (`total_assets`); dùng để bổ sung khoản "khác" khi các chỉ tiêu chi tiết không gộp hết.
    public let totalAssetsReported: Double?
    
    // Cơ cấu nguồn vốn
    public let equity: Double?
    public let shortTermBorrowings: Double?
    public let longTermBorrowings: Double?
    public let advancesFromCustomers: Double?
    /// Tổng nguồn vốn theo BCTC (`total_capital`).
    public let totalCapitalReported: Double?
    
    // Hiệu quả hoạt động
    public let roe: Double?
    public let roa: Double?
    
    // Thu nhập
    public let netRevenue: Double?
    public let profitAfterTax: Double?
    /// Biên LN gộp (%) — từ API `grossMargin` (lng); không suy từ LNST/DT.
    public let grossMargin: Double?
    /// Biên LN ròng (%) — từ API `netMargin` (lnr); backend có thể suy từ LNST/DT khi thiếu.
    public let netMargin: Double?
    
    public let totalLiabilities: Double? // Tổng nợ phải trả
    public let totalRevenue: Double? // Tổng doanh thu
    
    /// Tổng các khoản chi tiết đã có trong API (không gồm "khác").
    public var knownAssetComponentsSum: Double? {
        let parts = [cashAndEquivalents, shortTermInvestments, shortTermReceivables, inventories, fixedAssets, longTermReceivables].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    /// Tổng tài sản hiển thị: ưu tiên số liệu BCTC, không thì cộng các khoản đã biết.
    public var totalAssets: Double? {
        let known = knownAssetComponentsSum ?? 0
        if let reported = totalAssetsReported, reported > 0 { return reported }
        return known > 0 ? known : nil
    }

    /// Phần chưa phân loại vào 6 khoản trên (BĐS đầu tư, XDCB dở dang, v.v.).
    public var otherAssets: Double {
        guard let reported = totalAssetsReported, reported > 0 else { return 0 }
        let known = knownAssetComponentsSum ?? 0
        return max(0, reported - known)
    }

    public var knownCapitalComponentsSum: Double? {
        let parts = [equity, shortTermBorrowings, longTermBorrowings, advancesFromCustomers].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +)
    }

    /// Tổng nguồn vốn hiển thị: ưu tiên BCTC, không thì cộng 4 khoản đã biết.
    public var totalCapitalDisplay: Double? {
        let known = knownCapitalComponentsSum ?? 0
        if let reported = totalCapitalReported, reported > 0 { return reported }
        return known > 0 ? known : nil
    }

    /// Nợ phải trả / nguồn khác chưa tách riêng trong API (so với `total_capital`).
    public var otherCapital: Double {
        guard let reported = totalCapitalReported, reported > 0 else { return 0 }
        let known = knownCapitalComponentsSum ?? 0
        return max(0, reported - known)
    }
    
    public init(
        year: Int,
        quarter: Int = 0,
        cashAndEquivalents: Double?,
        shortTermInvestments: Double?,
        shortTermReceivables: Double?,
        inventories: Double?,
        fixedAssets: Double?,
        longTermReceivables: Double?,
        totalAssetsReported: Double?,
        equity: Double?,
        shortTermBorrowings: Double?,
        longTermBorrowings: Double?,
        advancesFromCustomers: Double?,
        totalCapitalReported: Double?,
        roe: Double?,
        roa: Double?,
        netRevenue: Double?,
        profitAfterTax: Double?,
        grossMargin: Double? = nil,
        netMargin: Double? = nil,
        totalLiabilities: Double? = nil,
        totalRevenue: Double? = nil
    ) {
        self.year = year
        self.quarter = quarter
        self.cashAndEquivalents = cashAndEquivalents
        self.shortTermInvestments = shortTermInvestments
        self.shortTermReceivables = shortTermReceivables
        self.inventories = inventories
        self.fixedAssets = fixedAssets
        self.longTermReceivables = longTermReceivables
        self.totalAssetsReported = totalAssetsReported
        self.equity = equity
        self.shortTermBorrowings = shortTermBorrowings
        self.longTermBorrowings = longTermBorrowings
        self.advancesFromCustomers = advancesFromCustomers
        self.totalCapitalReported = totalCapitalReported
        self.roe = roe
        self.roa = roa
        self.netRevenue = netRevenue
        self.profitAfterTax = profitAfterTax
        self.grossMargin = grossMargin
        self.netMargin = netMargin
        self.totalLiabilities = totalLiabilities
        self.totalRevenue = totalRevenue
    }
}

public enum FinancialDataSeries: Equatable, Sendable {
    case bank([BankFinancialDataPoint])
    case nonBank([NonBankFinancialDataPoint])
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
