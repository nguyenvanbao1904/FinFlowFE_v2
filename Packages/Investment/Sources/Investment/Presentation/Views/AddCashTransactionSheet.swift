import FinFlowCore
import SwiftUI

public struct AddCashTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let onSubmit: @Sendable (TradeType, Double, Date) async throws -> Void

    @State private var tradeType: TradeType = .DEPOSIT
    @State private var amountText: String = ""
    @State private var transactionDate: Date = Date()

    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(
        onSubmit: @escaping @Sendable (TradeType, Double, Date) async throws -> Void
    ) {
        self.onSubmit = onSubmit
    }

    public var body: some View {
        SheetContainer(
            title: "Nạp/Rút tiền",
            detents: [.large],
            allowDismissal: !isSaving
        ) {
            ScrollView(.vertical) {
                VStack(spacing: Spacing.lg) {
                    HStack(spacing: Spacing.md) {
                        TypeOptionButton(
                            title: "Nạp tiền",
                            isSelected: tradeType == .DEPOSIT,
                            color: AppColors.success
                        ) {
                            tradeType = .DEPOSIT
                        }

                        TypeOptionButton(
                            title: "Rút tiền",
                            isSelected: tradeType == .WITHDRAW,
                            color: AppColors.expense
                        ) {
                            tradeType = .WITHDRAW
                        }
                    }

                DatePicker("Ngày giao dịch", selection: $transactionDate, displayedComponents: .date)
                    .tint(AppColors.primary)

                    GlassField(
                        text: $amountText,
                        placeholder: "Số tiền (VD: 100000)",
                        icon: "dollarsign",
                        showsIcon: false,
                        keyboardType: .numberPad
                    )
                    .onChange(of: amountText) { _, newValue in
                        let formatted = CurrencyFormatter.formatInput(newValue, allowNegative: false)
                        if newValue != formatted {
                            amountText = formatted
                        }
                    }

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
                    .disabled(isSaving || amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let amount = CurrencyFormatter.parseCurrencyInput(amountText)
        guard let amount, amount > 0 else {
            errorMessage = "Số tiền phải là số dương."
            return
        }

        do {
            try await onSubmit(tradeType, amount, transactionDate)
            dismiss()
        } catch {
            errorMessage = "Không thể thêm giao dịch. Vui lòng thử lại."
        }
    }
}
