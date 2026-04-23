import SwiftUI
import Observation
import FinFlowCore

@MainActor
@Observable
public final class AddWealthAccountViewModel {
    public var name = ""
    public var amount = ""
    public var accountTypes: [AccountTypeOptionResponse] = []
    public var selectedAccountType: AccountTypeOptionResponse?
    public var isLoadingTypes = false
    public var isLoading = false
    public var showTypePicker = false
    public var alert: AppErrorAlert?
    public var includeInNetWorth = true

    private let getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase
    private let createWealthAccountUseCase: CreateWealthAccountUseCase
    private let updateWealthAccountUseCase: UpdateWealthAccountUseCase?
    private let sessionManager: any SessionManagerProtocol
    private let existingAccount: WealthAccountResponse?
    private let onSuccess: () -> Void

    public var isEditMode: Bool { existingAccount != nil }

    public init(
        getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase,
        createWealthAccountUseCase: CreateWealthAccountUseCase,
        updateWealthAccountUseCase: UpdateWealthAccountUseCase? = nil,
        sessionManager: any SessionManagerProtocol,
        existingAccount: WealthAccountResponse? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.getWealthAccountTypesUseCase = getWealthAccountTypesUseCase
        self.createWealthAccountUseCase = createWealthAccountUseCase
        self.updateWealthAccountUseCase = updateWealthAccountUseCase
        self.sessionManager = sessionManager
        self.existingAccount = existingAccount
        self.onSuccess = onSuccess
        if let existing = existingAccount {
            self.name = existing.name
            // Format số dư hiện tại thành string cho text field (giữ dấu âm nếu có)
            let absBalance = abs(existing.balance)
            let formatted = CurrencyFormatter.format(absBalance).replacingOccurrences(of: " ₫", with: "")
            self.amount = existing.balance < 0 ? "-" + formatted : formatted
            self.includeInNetWorth = existing.includeInNetWorth
        }
    }

    /// UI-level check: có đủ input để bật nút Save không.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !amount.isEmpty
            && selectedAccountType != nil
    }

    public func loadAccountTypes() async {
        guard accountTypes.isEmpty, !isLoadingTypes else { return }
        isLoadingTypes = true
        defer { isLoadingTypes = false }
        do {
            let types = try await getWealthAccountTypesUseCase.execute()
            accountTypes = types
            if selectedAccountType == nil {
                if let existing = existingAccount {
                    selectedAccountType = types.first { $0.id == existing.accountType.id }
                }
                if selectedAccountType == nil {
                    selectedAccountType = types.first
                }
            }
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

    public func save() async {
        guard isValid, let type = selectedAccountType else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            if let existing = existingAccount, let updateUC = updateWealthAccountUseCase {
                _ = try await updateUC.execute(
                    id: existing.id,
                    name: name,
                    amountString: amount,
                    accountType: type,
                    includeInNetWorth: includeInNetWorth
                )
            } else {
                _ = try await createWealthAccountUseCase.execute(
                    name: name,
                    amountString: amount,
                    accountType: type,
                    includeInNetWorth: includeInNetWorth
                )
            }
            onSuccess()
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
        }
    }
}
