import FinFlowCore
import SwiftUI

public struct ImportPortfolioSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let onSuggest: @Sendable (_ query: String) async throws -> [CompanySuggestionResponse]
    private let onSubmit: @Sendable (
        _ cashBalance: Double,
        _ holdings: [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest],
        _ transactionDate: Date
    ) async throws -> Void

    @State private var cashBalanceText: String = ""
    @State private var transactionDate: Date = Date()

    @State private var errorMessage: String?
    @State private var isSaving = false

    @State private var rows: [RowDraft] = [
        RowDraft(symbol: "", quantityText: "", avgPriceText: "")
    ]
    @State private var activeSuggestionRowId: UUID?
    @State private var suggestionsByRowId: [UUID: [CompanySuggestionResponse]] = [:]
    @State private var suggestTasksByRowId: [UUID: Task<Void, Never>] = [:]
    @State private var isSelectingSuggestionByRowId: [UUID: Bool] = [:]

    public init(
        onSuggest: @escaping @Sendable (_ query: String) async throws -> [CompanySuggestionResponse],
        onSubmit: @escaping @Sendable (
            Double,
            [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest],
            Date
        ) async throws -> Void
    ) {
        self.onSuggest = onSuggest
        self.onSubmit = onSubmit
    }

    public var body: some View {
        SheetContainer(
            title: "Nhập danh mục mã hiện tại",
            detents: [.large],
            allowDismissal: !isSaving
        ) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    DatePicker("Ngày tham chiếu", selection: $transactionDate, displayedComponents: .date)
                        .tint(AppColors.primary)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Tiền mặt hiện có")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)

                        GlassField(
                            text: $cashBalanceText,
                            placeholder: "Ví dụ: 1000000",
                            icon: "dollarsign",
                            showsIcon: false,
                            keyboardType: .numberPad
                        )
                        .onChange(of: cashBalanceText) { _, newValue in
                            let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                            if newValue != formatted {
                                cashBalanceText = formatted
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Danh sách mã đang nắm giữ")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)

                        VStack(spacing: Spacing.sm) {
                            ForEach($rows) { $row in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        GlassField(
                                            text: $row.symbol,
                                            placeholder: "Mã cổ phiếu",
                                            icon: "tag.fill",
                                            showsIcon: false
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .onChange(of: row.symbol) { _, newValue in
                                            if isSelectingSuggestionByRowId[row.id] == true {
                                                isSelectingSuggestionByRowId[row.id] = false
                                                return
                                            }
                                            scheduleSuggest(for: row.id, query: newValue)
                                        }

                                        if activeSuggestionRowId == row.id,
                                            let suggestions = suggestionsByRowId[row.id],
                                            !suggestions.isEmpty {
                                            suggestionsList(rowId: row.id, suggestions: suggestions)
                                        }

                                        GlassField(
                                            text: $row.quantityText,
                                            placeholder: "Khối lượng",
                                            icon: "number",
                                            showsIcon: false,
                                            keyboardType: .numberPad
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        GlassField(
                                            text: $row.avgPriceText,
                                            placeholder: "Giá bình quân",
                                            icon: "dollarsign",
                                            showsIcon: false,
                                            keyboardType: .numberPad
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .onChange(of: $row.avgPriceText.wrappedValue) { _, newValue in
                                            let formatted =
                                                CurrencyFormatter.formatInput(
                                                    newValue,
                                                    allowNegative: false
                                                )
                                            if newValue != formatted {
                                                $row.avgPriceText.wrappedValue = formatted
                                            }
                                        }
                                    }

                                    if rows.count > 1 {
                                        Button(role: .destructive) {
                                            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                                                suggestTasksByRowId[row.id]?.cancel()
                                                suggestTasksByRowId.removeValue(forKey: row.id)
                                                suggestionsByRowId.removeValue(forKey: row.id)
                                                if activeSuggestionRowId == row.id {
                                                    activeSuggestionRowId = nil
                                                }
                                                rows.remove(at: idx)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(AppColors.error)
                                                .font(AppTypography.iconMedium)
                                                .padding(.top, Spacing.sm)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, Spacing.xs)
                                .padding(.horizontal, Spacing.xs)
                                .background(AppColors.settingsCardBackground)
                                .cornerRadius(CornerRadius.medium)
                            }
                        }
                    }

                    Button {
                        let newRow = RowDraft(symbol: "", quantityText: "", avgPriceText: "")
                        rows.append(newRow)
                        activeSuggestionRowId = newRow.id
                    } label: {
                        Label("Thêm cổ phiếu", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .textButton()
                    .padding(.top, Spacing.xs)

                    Text("Gợi ý: Bạn có thể nhập nhiều mã. Hệ thống sẽ ghi đè snapshot hiện tại.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                    .disabled(isSaving)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }
            .scrollDismissesKeyboard(.never)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        guard let cashBalance = CurrencyFormatter.parseCurrencyInput(cashBalanceText) else {
            errorMessage = "Tiền mặt phải là số hợp lệ."
            return
        }
        if cashBalance < 0 {
            errorMessage = "Tiền mặt không được âm."
            return
        }

        let parsedHoldings: [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest] = rows.compactMap { row in
            let symbol = row.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !symbol.isEmpty else { return nil }

            guard let qty = CurrencyFormatter.parseIntegerInput(row.quantityText), qty >= 0 else {
                return nil
            }
            guard let avg = CurrencyFormatter.parseCurrencyInput(row.avgPriceText), avg >= 0 else {
                return nil
            }

            return ImportPortfolioSnapshotRequest.HoldingSnapshotRequest(
                symbol: symbol,
                totalQuantity: qty,
                averagePrice: avg
            )
        }

        do {
            try await onSubmit(cashBalance, parsedHoldings, transactionDate)
            dismiss()
        } catch {
            errorMessage = "Không thể nhập danh mục. Vui lòng thử lại."
        }
    }

    @ViewBuilder
    private func suggestionsList(rowId: UUID, suggestions: [CompanySuggestionResponse]) -> some View {
        SymbolSuggestionsList(suggestions: suggestions, maxItems: 5) { suggestion in
            if let idx = rows.firstIndex(where: { $0.id == rowId }) {
                isSelectingSuggestionByRowId[rowId] = true
                rows[idx].symbol = suggestion.id
            }
            activeSuggestionRowId = nil
            suggestionsByRowId[rowId] = []
            suggestTasksByRowId[rowId]?.cancel()
        }
    }

    private func scheduleSuggest(for rowId: UUID, query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestTasksByRowId[rowId]?.cancel()

        if q.isEmpty {
            suggestionsByRowId[rowId] = []
            if activeSuggestionRowId == rowId {
                activeSuggestionRowId = nil
            }
            return
        }

        activeSuggestionRowId = rowId
        suggestTasksByRowId[rowId] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            do {
                let suggestions = try await onSuggest(q)
                if Task.isCancelled { return }
                suggestionsByRowId[rowId] = suggestions
            } catch {
                suggestionsByRowId[rowId] = []
            }
        }
    }

    // MARK: - Local Draft Models

    private struct RowDraft: Identifiable {
        let id = UUID()
        var symbol: String
        var quantityText: String
        var avgPriceText: String
    }
}

