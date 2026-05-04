import FinFlowCore
import SwiftUI

public struct AddStockTradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddTradeViewModel

    public init(
        assets: [PortfolioAssetResponse] = [],
        onSuggest: @escaping @Sendable (_ query: String) async throws -> [CompanySuggestionResponse],
        onSubmit: @escaping @Sendable (
            TradeType, String, Double, Double, Double, Date
        ) async throws -> Void
    ) {
        self._viewModel = State(initialValue: AddTradeViewModel(
            assets: assets,
            onSuggest: onSuggest,
            onSubmit: onSubmit
        ))
    }

    public var body: some View {
        SheetContainer(
            title: "Giao dịch chứng khoán",
            detents: [.large],
            allowDismissal: !viewModel.isSaving
        ) {
            ScrollView(.vertical) {
                VStack(spacing: Spacing.lg) {
                    tradeTypePicker
                    datePicker
                    symbolField
                    if viewModel.showSuggestions, !viewModel.suggestions.isEmpty {
                        suggestionsList
                    }
                    symbolInfoBox
                    quantityField
                    priceField
                    feeField
                    summaryRow
                    errorRow
                    submitButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.never)
        }
    }

    // MARK: - Subviews

    private var tradeTypePicker: some View {
        HStack(spacing: Spacing.md) {
            TypeOptionButton(title: "Mua", isSelected: viewModel.tradeType == .BUY, color: AppColors.success) {
                viewModel.tradeType = .BUY
            }
            TypeOptionButton(title: "Bán", isSelected: viewModel.tradeType == .SELL, color: AppColors.expense) {
                viewModel.tradeType = .SELL
            }
        }
    }

    private var datePicker: some View {
        DatePicker("Ngày giao dịch", selection: $viewModel.transactionDate, displayedComponents: .date)
            .tint(AppColors.primary)
    }

    private var symbolField: some View {
        GlassField(
            text: $viewModel.symbol,
            placeholder: "Mã cổ phiếu (VD: VCB, HPG, FPT)",
            icon: "tag.fill",
            showsIcon: false
        )
        .textInputAutocapitalization(.characters)
    }

    @ViewBuilder
    private var symbolInfoBox: some View {
        if let warning = viewModel.sellSymbolWarning {
            infoRow(icon: "exclamationmark.triangle.fill", text: warning, color: AppColors.error)
        } else if let maxQty = viewModel.maxSellQuantity,
                  let asset = viewModel.matchedAsset {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                infoRow(
                    icon: "checkmark.circle.fill",
                    text: "Đang nắm giữ \(CurrencyFormatter.formatQuantity(maxQty)) cổ phiếu \(asset.symbol)",
                    color: AppColors.chartGrowthStrong
                )
                infoRow(
                    icon: "info.circle.fill",
                    text: "Giá vốn bình quân: \(CurrencyFormatter.format(asset.averagePrice))",
                    color: AppColors.primary
                )
            }
        }
    }

    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(AppTypography.caption)
                .foregroundStyle(color)
            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: CornerRadius.small))
    }

    private var suggestionsList: some View {
        VStack(spacing: Spacing.xs) {
            if viewModel.isSuggesting {
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
                SymbolSuggestionsList(suggestions: viewModel.suggestions, maxItems: viewModel.suggestions.count) { item in
                    viewModel.selectSuggestion(item)
                }
            }
            .frame(maxHeight: UILayout.suggestionListMaxHeight)
        }
    }

    private var quantityField: some View {
        GlassField(
            text: $viewModel.quantityText,
            placeholder: "Khối lượng (VD: 100)",
            icon: "number",
            showsIcon: false,
            keyboardType: .numberPad
        )
    }

    private var priceField: some View {
        GlassField(
            text: $viewModel.priceText,
            placeholder: "Giá (VD: 100)",
            icon: "dollarsign",
            showsIcon: false,
            keyboardType: .numberPad
        )
    }

    private var feeField: some View {
        GlassField(
            text: $viewModel.feePercentText,
            placeholder: "Phí (% - VD: 0.1)",
            icon: "percent",
            showsIcon: false,
            keyboardType: .decimalPad
        )
    }

    @ViewBuilder
    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let totalAmount = viewModel.totalAmount {
                Text("Tổng giá trị: \(CurrencyFormatter.format(totalAmount))")
                    .font(AppTypography.caption).foregroundStyle(.secondary)
            }
            if let feeAmount = viewModel.feeAmount {
                Text("Phí ước tính: \(CurrencyFormatter.format(feeAmount))")
                    .font(AppTypography.caption).foregroundStyle(.secondary)
            }
            if let taxAmount = viewModel.taxAmount {
                Text("Thuế ước tính: \(CurrencyFormatter.format(taxAmount))")
                    .font(AppTypography.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
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
        .disabled(viewModel.isSubmitDisabled)
    }
}
