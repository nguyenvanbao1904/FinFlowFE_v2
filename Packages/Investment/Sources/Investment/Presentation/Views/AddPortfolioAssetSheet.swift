import FinFlowCore
import SwiftUI

public struct AddPortfolioAssetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var symbol: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    let onAdd: (String, Double, Double) async throws -> Void

    public init(
        onAdd: @escaping @Sendable (String, Double, Double) async throws -> Void
    ) {
        self.onAdd = onAdd
    }

    public var body: some View {
        SheetContainer(
            title: "Thêm tài sản",
            detents: [.medium, .large],
            allowDismissal: !isSaving
        ) {
            VStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    GlassField(
                        text: $symbol,
                        placeholder: "Mã cổ phiếu (VD: AAPL)",
                        icon: "tag.fill"
                    )

                    GlassField(
                        text: $quantityText,
                        placeholder: "Khối lượng (VD: 100)",
                        icon: "number",
                        keyboardType: .numberPad
                    )

                    GlassField(
                        text: $priceText,
                        placeholder: "Giá bình quân (VD: 100)",
                        icon: "dollarsign",
                        keyboardType: .numberPad
                    )
                    .onChange(of: priceText) { _, newValue in
                        let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                        if newValue != formatted {
                            priceText = formatted
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    Task { @MainActor in
                        await submit()
                    }
                } label: {
                    Text("Lưu")
                }
                .primaryButton(isLoading: isSaving)
                .disabled(isSaving || symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
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

        guard let qty = CurrencyFormatter.parseIntegerInput(quantityText), qty > 0 else {
            errorMessage = "Khối lượng phải là số nguyên dương."
            return
        }
        guard let price = CurrencyFormatter.parseCurrencyInput(priceText), price >= 0 else {
            errorMessage = "Giá bình quân không hợp lệ."
            return
        }

        do {
            try await onAdd(trimmedSymbol, qty, price)
            dismiss()
        } catch {
            // Parent will map backend errors to AppError; inline message stays user-friendly.
            errorMessage = "Không thể thêm tài sản. Vui lòng thử lại."
        }
    }
}

