import FinFlowCore
import SwiftUI

public struct AddCashTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let getWealthAccountsUseCase: GetWealthAccountsUseCase
    private let portfolioWealthAccountId: String?
    private let onSubmit: @Sendable (TradeType, Double, String, Date) async throws -> Void

    @State private var tradeType: TradeType = .DEPOSIT
    @State private var amountText: String = ""
    @State private var transactionDate: Date = Date()
    @State private var accounts: [WealthAccountResponse] = []
    @State private var selectedAccountId: String?
    @State private var isLoadingAccounts = false

    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(
        getWealthAccountsUseCase: GetWealthAccountsUseCase,
        portfolioWealthAccountId: String?,
        onSubmit: @escaping @Sendable (TradeType, Double, String, Date) async throws -> Void
    ) {
        self.getWealthAccountsUseCase = getWealthAccountsUseCase
        self.portfolioWealthAccountId = portfolioWealthAccountId
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
                            selectDefaultAccountIfNeeded()
                        }

                        TypeOptionButton(
                            title: "Rút tiền",
                            isSelected: tradeType == .WITHDRAW,
                            color: AppColors.expense
                        ) {
                            tradeType = .WITHDRAW
                            selectDefaultAccountIfNeeded()
                        }
                    }

                    accountPicker

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
                    .disabled(
                        isSaving
                            || amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || selectedAccountId == nil
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .task { await loadAccounts() }
    }

    @ViewBuilder
    private var accountPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(tradeType == .DEPOSIT ? "Tài khoản nguồn" : "Tài khoản nhận")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(eligibleTransferAccounts) { account in
                    Button {
                        selectedAccountId = account.id
                    } label: {
                        Text("\(account.name) - \(CurrencyFormatter.format(account.balance))")
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: selectedAccount?.accountType.icon ?? "building.columns.fill")
                        .foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text(selectedAccount?.name ?? (isLoadingAccounts ? "Đang tải tài khoản..." : "Chọn tài khoản"))
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                        if let selectedAccount {
                            Text(CurrencyFormatter.format(selectedAccount.balance))
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(AppColors.settingsCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)
            .disabled(isLoadingAccounts || eligibleTransferAccounts.isEmpty)
        }
    }

    private var eligibleTransferAccounts: [WealthAccountResponse] {
        accounts.filter { account in
            account.id != portfolioWealthAccountId
                && account.accountType.code != "BROKERAGE"
                && account.accountType.transactionEligible
                && !account.accountType.debt
        }
    }

    private var selectedAccount: WealthAccountResponse? {
        eligibleTransferAccounts.first { $0.id == selectedAccountId }
    }

    private func loadAccounts() async {
        guard accounts.isEmpty, !isLoadingAccounts else { return }
        isLoadingAccounts = true
        defer { isLoadingAccounts = false }
        do {
            accounts = try await getWealthAccountsUseCase.execute()
            selectDefaultAccountIfNeeded()
        } catch {
            errorMessage = "Không thể tải danh sách tài khoản."
        }
    }

    private func selectDefaultAccountIfNeeded() {
        if let selectedAccountId, eligibleTransferAccounts.contains(where: { $0.id == selectedAccountId }) {
            return
        }
        selectedAccountId = eligibleTransferAccounts.first?.id
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
        guard let selectedAccountId else {
            errorMessage = tradeType == .DEPOSIT
                ? "Chọn tài khoản nguồn để nạp tiền."
                : "Chọn tài khoản nhận khi rút tiền."
            return
        }

        do {
            try await onSubmit(tradeType, amount, selectedAccountId, transactionDate)
            dismiss()
        } catch {
            errorMessage = "Không thể thêm giao dịch. Vui lòng thử lại."
        }
    }
}
