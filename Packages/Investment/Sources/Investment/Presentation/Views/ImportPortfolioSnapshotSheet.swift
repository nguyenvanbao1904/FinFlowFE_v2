import FinFlowCore
import SwiftUI

public struct ImportPortfolioSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ImportSnapshotViewModel

    public init(
        onSuggest: @escaping @Sendable (_ query: String) async throws -> [CompanySuggestionResponse],
        onSubmit: @escaping @Sendable (
            Double,
            [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest],
            Date
        ) async throws -> Void
    ) {
        self._viewModel = State(initialValue: ImportSnapshotViewModel(
            onSuggest: onSuggest,
            onSubmit: onSubmit
        ))
    }

    public var body: some View {
        SheetContainer(
            title: "Nhập danh mục mã hiện tại",
            detents: [.large],
            allowDismissal: !viewModel.isSaving
        ) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    datePicker
                    cashBalanceSection
                    holdingsSection
                    addRowButton
                    hintText
                    errorRow
                    submitButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }
            .scrollDismissesKeyboard(.never)
        }
    }

    // MARK: - Subviews

    private var datePicker: some View {
        DatePicker("Ngày tham chiếu", selection: $viewModel.transactionDate, displayedComponents: .date)
            .tint(AppColors.primary)
    }

    private var cashBalanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Tiền mặt hiện có")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            GlassField(
                text: $viewModel.cashBalanceText,
                placeholder: "Ví dụ: 1000000",
                icon: "dollarsign",
                showsIcon: false,
                keyboardType: .numberPad
            )
        }
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Danh sách mã đang nắm giữ")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: Spacing.sm) {
                ForEach($viewModel.rows) { $row in
                    holdingRow(row: $row)
                }
            }
        }
    }

    private func holdingRow(row: Binding<ImportSnapshotViewModel.RowDraft>) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                GlassField(
                    text: row.symbol,
                    placeholder: "Mã cổ phiếu",
                    icon: "tag.fill",
                    showsIcon: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: row.wrappedValue.symbol) { _, newValue in
                    viewModel.symbolChanged(rowId: row.wrappedValue.id, newValue: newValue)
                }

                if viewModel.activeSuggestionRowId == row.wrappedValue.id,
                   let suggestions = viewModel.suggestionsByRowId[row.wrappedValue.id],
                   !suggestions.isEmpty
                {
                    SymbolSuggestionsList(suggestions: suggestions, maxItems: 5) { suggestion in
                        viewModel.selectSuggestion(suggestion, forRow: row.wrappedValue.id)
                    }
                }

                GlassField(
                    text: row.quantityText,
                    placeholder: "Khối lượng",
                    icon: "number",
                    showsIcon: false,
                    keyboardType: .numberPad
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                GlassField(
                    text: row.avgPriceText,
                    placeholder: "Giá bình quân",
                    icon: "dollarsign",
                    showsIcon: false,
                    keyboardType: .numberPad
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: row.wrappedValue.avgPriceText) { _, newValue in
                    let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                    if newValue != formatted {
                        row.avgPriceText.wrappedValue = formatted
                    }
                }
            }

            if viewModel.rows.count > 1 {
                Button(role: .destructive) {
                    viewModel.removeRow(row.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppColors.error)
                        .font(AppTypography.iconMedium)
                        .padding(.top, Spacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xoá mã cổ phiếu")
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.xs)
        .background(AppColors.settingsCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
    }

    private var addRowButton: some View {
        Button {
            viewModel.addRow()
        } label: {
            Label("Thêm cổ phiếu", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .textButton()
        .padding(.top, Spacing.xs)
    }

    private var hintText: some View {
        Text("Gợi ý: Bạn có thể nhập nhiều mã. Hệ thống sẽ ghi đè snapshot hiện tại.")
            .font(AppTypography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var errorRow: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button {
            Task { @MainActor in
                let success = await viewModel.submit()
                if success { dismiss() }
            }
        } label: {
            Label("Thêm giao dịch", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .primaryButton(isLoading: viewModel.isSaving)
        .disabled(viewModel.isSaving)
    }
}
