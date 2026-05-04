import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
final class AddTradeViewModel {
    // MARK: - Form State

    var tradeType: TradeType = .BUY
    var symbol: String = "" {
        didSet {
            guard symbol != oldValue else { return }
            if isSelectingSuggestion {
                isSelectingSuggestion = false
                return
            }
            scheduleSuggest(for: symbol)
        }
    }
    var quantityText: String = ""
    var priceText: String = "" {
        didSet {
            let formatted = CurrencyFormatter.formatInput(priceText, allowNegative: false)
            if priceText != formatted { priceText = formatted }
        }
    }
    var feePercentText: String = "0.1"
    var transactionDate: Date = Date()

    // MARK: - UI State

    var errorMessage: String?
    var isSaving = false
    var suggestions: [CompanySuggestionResponse] = []
    var isSuggesting = false
    var showSuggestions = false
    private var suggestTask: Task<Void, Never>?
    private(set) var isSelectingSuggestion = false

    // MARK: - Dependencies

    private let assets: [PortfolioAssetResponse]
    private let onSuggest: @Sendable (_ query: String) async throws -> [CompanySuggestionResponse]
    private let onSubmit: @Sendable (TradeType, String, Double, Double, Double, Date) async throws -> Void

    init(
        assets: [PortfolioAssetResponse],
        onSuggest: @escaping @Sendable (_ query: String) async throws -> [CompanySuggestionResponse],
        onSubmit: @escaping @Sendable (TradeType, String, Double, Double, Double, Date) async throws -> Void
    ) {
        self.assets = assets
        self.onSuggest = onSuggest
        self.onSubmit = onSubmit
    }

    // MARK: - Computed

    private var trimmedSymbol: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Asset trong danh mục khớp mã đang nhập (chỉ dùng khi SELL).
    var matchedAsset: PortfolioAssetResponse? {
        guard tradeType == .SELL, !trimmedSymbol.isEmpty else { return nil }
        return assets.first { $0.symbol == trimmedSymbol }
    }

    /// Cảnh báo khi SELL mã không có trong danh mục (sau khi user đã nhập xong suggestion).
    var sellSymbolWarning: String? {
        guard tradeType == .SELL,
              !trimmedSymbol.isEmpty,
              !showSuggestions
        else { return nil }
        if matchedAsset == nil {
            return "\(trimmedSymbol) không có trong danh mục. Kiểm tra lại mã cổ phiếu."
        }
        return nil
    }

    /// Số lượng tối đa có thể bán.
    var maxSellQuantity: Double? {
        matchedAsset.map { $0.totalQuantity }
    }

    var isSubmitDisabled: Bool {
        isSaving
            || symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var totalAmount: Double? {
        guard let qty = CurrencyFormatter.parseIntegerInput(quantityText),
              let price = CurrencyFormatter.parseCurrencyInput(priceText)
        else { return nil }
        return qty * price
    }

    var feeAmount: Double? {
        guard let total = totalAmount,
              let feePercent = CurrencyFormatter.parsePercentInput(feePercentText)
        else { return nil }
        return total * (feePercent / 100.0)
    }

    var taxAmount: Double? {
        guard tradeType == .SELL, let total = totalAmount else { return nil }
        return total * (0.1 / 100.0)
    }

    // MARK: - Actions

    func selectSuggestion(_ item: CompanySuggestionResponse) {
        isSelectingSuggestion = true
        symbol = item.id
        suggestTask?.cancel()
        suggestions = []
        showSuggestions = false
        isSuggesting = false
    }

    /// Returns `true` on success, `false` on validation/network error.
    func submit() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let sym = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !sym.isEmpty else {
            errorMessage = "Mã cổ phiếu không được để trống."
            return false
        }

        if tradeType == .SELL, !assets.contains(where: { $0.symbol == sym }) {
            errorMessage = "\(sym) không có trong danh mục. Không thể bán."
            return false
        }

        guard let quantity = CurrencyFormatter.parseIntegerInput(quantityText), quantity > 0 else {
            errorMessage = "Khối lượng phải là số nguyên dương."
            return false
        }

        if tradeType == .SELL,
           let asset = assets.first(where: { $0.symbol == sym }),
           quantity > asset.totalQuantity {
            errorMessage = "Khối lượng bán (\(CurrencyFormatter.formatQuantity(quantity))) vượt quá số cổ phiếu đang có (\(CurrencyFormatter.formatQuantity(asset.totalQuantity)))."
            return false
        }
        guard let price = CurrencyFormatter.parseCurrencyInput(priceText), price >= 0 else {
            errorMessage = "Giá không hợp lệ."
            return false
        }
        guard let feePercent = CurrencyFormatter.parsePercentInput(feePercentText), feePercent >= 0 else {
            errorMessage = "Phí không hợp lệ."
            return false
        }

        do {
            try await onSubmit(tradeType, sym, quantity, price, feePercent, transactionDate)
            return true
        } catch {
            errorMessage = "Không thể thêm giao dịch. Vui lòng thử lại."
            return false
        }
    }

    // MARK: - Private

    private func scheduleSuggest(for raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestTask?.cancel()

        if q.isEmpty {
            suggestions = []
            showSuggestions = false
            isSuggesting = false
            return
        }

        showSuggestions = true
        isSuggesting = true

        suggestTask = Task { @MainActor in
            try? await Task.sleep(for: AnimationTiming.navigationDelay)
            if Task.isCancelled { return }

            do {
                let result = try await onSuggest(q)
                if Task.isCancelled { return }
                suggestions = result
            } catch {
                suggestions = []
            }
            isSuggesting = false
        }
    }
}
