import Foundation

public struct FairValueResult: Sendable, Equatable {
    public let symbol: String
    public let companyName: String
    public let targetYear: Int
    public let industryKey: String
    public let method: String
    public let weightsUsed: String
    public let priceComposite: Double
    public let pricePE: Double
    public let pricePB: Double
    public let pricePS: Double
    public let livePrice: Double
    public let upsidePct: Double
    public let verdict: String
    public let peTarget: Double
    public let pbTarget: Double
    public let cagr: Double
    public let error: String?

    public var hasError: Bool { error != nil }

    public init(
        symbol: String,
        companyName: String,
        targetYear: Int,
        industryKey: String,
        method: String,
        weightsUsed: String,
        priceComposite: Double,
        pricePE: Double,
        pricePB: Double,
        pricePS: Double,
        livePrice: Double,
        upsidePct: Double,
        verdict: String,
        peTarget: Double,
        pbTarget: Double,
        cagr: Double,
        error: String? = nil
    ) {
        self.symbol = symbol
        self.companyName = companyName
        self.targetYear = targetYear
        self.industryKey = industryKey
        self.method = method
        self.weightsUsed = weightsUsed
        self.priceComposite = priceComposite
        self.pricePE = pricePE
        self.pricePB = pricePB
        self.pricePS = pricePS
        self.livePrice = livePrice
        self.upsidePct = upsidePct
        self.verdict = verdict
        self.peTarget = peTarget
        self.pbTarget = pbTarget
        self.cagr = cagr
        self.error = error
    }
}
