import FinFlowCore
import SwiftUI

public struct AddStockTradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let onSuggest: @Sendable (_ query: String) async throws -> [CompanySuggestionResponse]
    private let onSubmit: @Sendable (
        _ tradeType: TradeType,
        _ symbol: String,
        _ quantity: Double,
        _ price: Double,
        _ feePercent: Double,
        _ transactionDate: Date
    ) async throws -> Void

    @State private var tradeType: TradeType = .BUY
    @State private var symbol: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var feePercentText: String = "0.1"

    @State private var transactionDate: Date = Date()

    @State private var errorMessage: String?
    @State private var isSaving = false

    @State private var suggestions: [CompanySuggestionResponse] = []
    @State private var isSuggesting = false
    @State private var showSuggestions = false
    @State private var suggestTask: Task<Void, Never>?
    @State private var isSelectingSuggestion = false

    public init(
        onSuggest: @escaping @Sendable (_ query: String) async throws -> [CompanySuggestionResponse],
        onSubmit: @escaping @Sendable (
            TradeType,
            String,
            Double,
            Double,
            Double,
            Date
        ) async throws -> Void
    ) {
        self.onSuggest = onSuggest
        self.onSubmit = onSubmit
    }

    public var body: some View {
        SheetContainer(
            title: "Giao dịch chứng khoán",
            detents: [.large],
            allowDismissal: !isSaving
        ) {
            ScrollView(.vertical) {
                VStack(spacing: Spacing.lg) {
                    HStack(spacing: Spacing.md) {
                        TypeOptionButton(
                            title: "Mua",
                            isSelected: tradeType == .BUY,
                            color: AppColors.success
                        ) {
                            tradeType = .BUY
                        }

                        TypeOptionButton(
                            title: "Bán",
                            isSelected: tradeType == .SELL,
                            color: AppColors.google
                        ) {
                            tradeType = .SELL
                        }
                    }

                DatePicker("Ngày giao dịch", selection: $transactionDate, displayedComponents: .date)
                    .tint(AppColors.primary)

                    GlassField(
                        text: $symbol,
                        placeholder: "Mã cổ phiếu (VD: AAPL)",
                        icon: "tag.fill",
                        showsIcon: false
                    )
                    .onChange(of: symbol) { _, newValue in
                        if isSelectingSuggestion {
                            isSelectingSuggestion = false
                            return
                        }
                        scheduleSuggest(for: newValue)
                    }

                    if showSuggestions, !suggestions.isEmpty {
                        suggestionsList
                    }

                    GlassField(
                        text: $quantityText,
                        placeholder: "Khối lượng (VD: 100)",
                        icon: "number",
                        showsIcon: false,
                        keyboardType: .numberPad
                    )

                    GlassField(
                        text: $priceText,
                        placeholder: "Giá (VD: 100)",
                        icon: "dollarsign",
                        showsIcon: false,
                        keyboardType: .numberPad
                    )
                    .onChange(of: priceText) { _, newValue in
                        let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                        if newValue != formatted {
                            priceText = formatted
                        }
                    }

                    GlassField(
                        text: $feePercentText,
                        placeholder: "Phí (% - VD: 0.1)",
                        icon: "percent",
                        showsIcon: false,
                        keyboardType: .decimalPad
                    )

                    summaryRow

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { @MainActor in
                            await submit()
                        }
                    } label: {
                        Label("Thêm giao dịch", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .primaryButton(isLoading: isSaving)
                    .disabled(
                        isSaving ||
                            symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.never)
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: Spacing.xs) {
            if isSuggesting {
                HStack {
                    ProgressView()
                    Text("Đang gợi ý...")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
            }

            ScrollView {
                SymbolSuggestionsList(suggestions: suggestions, maxItems: suggestions.count) { item in
                    isSelectingSuggestion = true
                    symbol = item.id
                    suggestTask?.cancel()
                    suggestions = []
                    showSuggestions = false
                    isSuggesting = false
                }
            }
            .frame(maxHeight: 260)
        }
    }

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
            // debounce
            try? await Task.sleep(nanoseconds: AnimationTiming.navigationDelay)
            if Task.isCancelled { return }

            do {
                let result = try await onSuggest(q)
                if Task.isCancelled { return }
                suggestions = result
            } catch {
                // Keep it silent (autocomplete should not block form); just hide list on errors.
                suggestions = []
            }
            isSuggesting = false
        }
    }

    @ViewBuilder
    private var summaryRow: some View {
        let qty = CurrencyFormatter.parseIntegerInput(quantityText)
        let price = CurrencyFormatter.parseCurrencyInput(priceText)
        let feePercent = CurrencyFormatter.parsePercentInput(feePercentText)

        let totalAmount = (qty != nil && price != nil) ? (qty! * price!) : nil
        let feeAmount = (totalAmount != nil && feePercent != nil) ? (totalAmount! * (feePercent! / 100.0)) : nil
        let taxAmount = tradeType == .SELL && totalAmount != nil
            ? (totalAmount! * (0.1 / 100.0))
            : nil

        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let totalAmount {
                Text("Tổng giá trị: \(CurrencyFormatter.format(totalAmount))")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if let feeAmount, let _ = feePercent {
                Text("Phí ước tính: \(CurrencyFormatter.format(feeAmount))")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if let taxAmount {
                Text("Thuế ước tính: \(CurrencyFormatter.format(taxAmount))")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private func submit() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedSymbol.isEmpty else {
            errorMessage = "Mã cổ phiếu không được để trống."
            return
        }

        guard let quantity = CurrencyFormatter.parseIntegerInput(quantityText), quantity > 0 else {
            errorMessage = "Khối lượng phải là số nguyên dương."
            return
        }
        guard let price = CurrencyFormatter.parseCurrencyInput(priceText), price >= 0 else {
            errorMessage = "Giá không hợp lệ."
            return
        }
        guard let feePercent = CurrencyFormatter.parsePercentInput(feePercentText), feePercent >= 0 else {
            errorMessage = "Phí không hợp lệ."
            return
        }

        do {
            try await onSubmit(tradeType, trimmedSymbol, quantity, price, feePercent, transactionDate)
            dismiss()
        } catch {
            errorMessage = "Không thể thêm giao dịch. Vui lòng thử lại."
        }
    }

}

