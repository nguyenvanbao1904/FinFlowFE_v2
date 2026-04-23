import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ImportSnapshotViewModel {
    // MARK: - Form State

    var cashBalanceText: String = "" {
        didSet {
            let formatted = CurrencyFormatter.formatInput(cashBalanceText, allowNegative: false)
            if cashBalanceText != formatted { cashBalanceText = formatted }
        }
    }
    var transactionDate: Date = Date()
    var rows: [RowDraft] = [RowDraft()]

    // MARK: - UI State

    var errorMessage: String?
    var isSaving = false
    var activeSuggestionRowId: UUID?
    var suggestionsByRowId: [UUID: [CompanySuggestionResponse]] = [:]
    private var suggestTasksByRowId: [UUID: Task<Void, Never>] = [:]
    var isSelectingSuggestionByRowId: [UUID: Bool] = [:]

    // MARK: - Dependencies

    private let onSuggest: @Sendable (_ query: String) async throws -> [CompanySuggestionResponse]
    private let onSubmit: @Sendable (
        Double,
        [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest],
        Date
    ) async throws -> Void

    init(
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

    // MARK: - Actions

    func addRow() {
        let newRow = RowDraft()
        rows.append(newRow)
        activeSuggestionRowId = newRow.id
    }

    func removeRow(_ rowId: UUID) {
        suggestTasksByRowId[rowId]?.cancel()
        suggestTasksByRowId.removeValue(forKey: rowId)
        suggestionsByRowId.removeValue(forKey: rowId)
        if activeSuggestionRowId == rowId {
            activeSuggestionRowId = nil
        }
        rows.removeAll { $0.id == rowId }
    }

    func selectSuggestion(_ suggestion: CompanySuggestionResponse, forRow rowId: UUID) {
        if let idx = rows.firstIndex(where: { $0.id == rowId }) {
            isSelectingSuggestionByRowId[rowId] = true
            rows[idx].symbol = suggestion.id
        }
        activeSuggestionRowId = nil
        suggestionsByRowId[rowId] = []
        suggestTasksByRowId[rowId]?.cancel()
    }

    func symbolChanged(rowId: UUID, newValue: String) {
        if isSelectingSuggestionByRowId[rowId] == true {
            isSelectingSuggestionByRowId[rowId] = false
            return
        }
        scheduleSuggest(for: rowId, query: newValue)
    }

    /// Returns `true` on success.
    func submit() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        guard let cashBalance = CurrencyFormatter.parseCurrencyInput(cashBalanceText) else {
            errorMessage = "Tiền mặt phải là số hợp lệ."
            return false
        }
        if cashBalance < 0 {
            errorMessage = "Tiền mặt không được âm."
            return false
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
            return true
        } catch {
            if error is CancellationError { return false }
            errorMessage = (error as? AppError)?.errorDescription
                ?? error.localizedDescription
            return false
        }
    }

    // MARK: - Private

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
            try? await Task.sleep(for: AnimationTiming.navigationDelay)
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

    // MARK: - Row Draft

    struct RowDraft: Identifiable {
        let id = UUID()
        var symbol: String = ""
        var quantityText: String = ""
        var avgPriceText: String = ""
    }
}
