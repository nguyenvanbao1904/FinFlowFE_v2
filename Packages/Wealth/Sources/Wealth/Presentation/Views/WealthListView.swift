import FinFlowCore
import SwiftUI

enum AccountListTab: String, CaseIterable, Identifiable {
    case liquidity = "Thanh khoản"
    case assets = "Tài sản & Nợ"

    var id: String { rawValue }
}

/// Main view for the Wealth tab: list of accounts (thanh khoản + tài sản & nợ).
public struct WealthListView: View {
    private enum ActiveSheet: String, Identifiable {
        case addAccount
        var id: String { rawValue }
    }

    private let getWealthAccountsUseCase: GetWealthAccountsUseCase
    private let getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase
    private let createWealthAccountUseCase: CreateWealthAccountUseCase
    private let updateWealthAccountUseCase: UpdateWealthAccountUseCase
    private let deleteWealthAccountUseCase: DeleteWealthAccountUseCase
    private let sessionManager: any SessionManagerProtocol

    @State private var activeSheet: ActiveSheet?
    @State private var selectedTab: AccountListTab = .liquidity
    @State private var accounts: [WealthAccountResponse] = []
    @State private var isLoading = false
    @State private var loadError: AppErrorAlert?
    @State private var accountToEdit: WealthAccountResponse?
    @State private var accountToDelete: WealthAccountResponse?
    @State private var showDeleteConfirmation = false
    @State private var hasRequestedInitialLoad = false

    public init(
        getWealthAccountsUseCase: GetWealthAccountsUseCase,
        getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase,
        createWealthAccountUseCase: CreateWealthAccountUseCase,
        updateWealthAccountUseCase: UpdateWealthAccountUseCase,
        deleteWealthAccountUseCase: DeleteWealthAccountUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getWealthAccountsUseCase = getWealthAccountsUseCase
        self.getWealthAccountTypesUseCase = getWealthAccountTypesUseCase
        self.createWealthAccountUseCase = createWealthAccountUseCase
        self.updateWealthAccountUseCase = updateWealthAccountUseCase
        self.deleteWealthAccountUseCase = deleteWealthAccountUseCase
        self.sessionManager = sessionManager
    }

    private func loadData(force: Bool = false) async {
        if !force {
            if hasRequestedInitialLoad {
                return
            }
            hasRequestedInitialLoad = true
        }

        if isLoading {
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            accounts = try await getWealthAccountsUseCase.execute()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

    private var liquidityAccounts: [WealthAccountResponse] {
        accounts.filter { $0.accountType.transactionEligible }
    }

    private var otherAccounts: [WealthAccountResponse] {
        accounts.filter { !$0.accountType.transactionEligible }
    }

    private var totalLiquidity: Double {
        liquidityAccounts.reduce(0) { $0 + $1.balance }
    }

    private var netWorth: Double {
        accounts.filter { $0.includeInNetWorth }.reduce(0) { $0 + $1.balance }
    }

    public var body: some View {
        VStack(spacing: .zero) {
            Picker("Chế độ xem", selection: $selectedTab) {
                ForEach(AccountListTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, Spacing.sm)
            .background(AppColors.settingsCardBackground)

            Group {
                switch selectedTab {
                case .liquidity:
                    WealthAccountSectionList(
                        config: AccountSectionConfig(
                            sectionHeader: "Tài khoản khả dụng",
                            title: "Tổng số dư (Thanh khoản)",
                            subtitle: "Sẵn sàng giao dịch",
                            amount: totalLiquidity
                        ),
                        items: liquidityAccounts,
                        isLoading: isLoading,
                        actions: AccountSectionActions(
                            onEdit: { accountToEdit = $0 },
                            onDelete: {
                                accountToDelete = $0
                                showDeleteConfirmation = true
                            },
                            onAdd: { activeSheet = .addAccount }
                        )
                    )
                case .assets:
                    WealthAccountSectionList(
                        config: AccountSectionConfig(
                            sectionHeader: "Tài sản & Nợ",
                            title: "Tài sản ròng",
                            subtitle: "Tài sản + Tiêu sản − Nợ",
                            amount: netWorth
                        ),
                        items: otherAccounts,
                        isLoading: isLoading,
                        actions: AccountSectionActions(
                            onEdit: { accountToEdit = $0 },
                            onDelete: {
                                accountToDelete = $0
                                showDeleteConfirmation = true
                            },
                            onAdd: { activeSheet = .addAccount }
                        )
                    )
                }
            }
            .animation(.default, value: selectedTab)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Tài sản")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .addAccount
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel("Thêm tài khoản")
            }
        }
        .task { await loadData() }
        .refreshable { await loadData(force: true) }
        .alertHandler(
            Binding(
                get: { loadError },
                set: { loadError = $0 }
            )
        )
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            NavigationStack {
                AddWealthAccountView(
                    viewModel: AddWealthAccountViewModel(
                        getWealthAccountTypesUseCase: getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: createWealthAccountUseCase,
                        sessionManager: sessionManager,
                        onSuccess: {
                            activeSheet = nil
                            Task { await loadData(force: true) }
                        }
                    )
                )
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $accountToEdit) { account in
            NavigationStack {
                AddWealthAccountView(
                    viewModel: AddWealthAccountViewModel(
                        getWealthAccountTypesUseCase: getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: createWealthAccountUseCase,
                        updateWealthAccountUseCase: updateWealthAccountUseCase,
                        sessionManager: sessionManager,
                        existingAccount: account,
                        onSuccess: {
                            accountToEdit = nil
                            Task { await loadData(force: true) }
                        }
                    )
                )
            }
        }
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {
                accountToDelete = nil
            }
            Button("Xóa", role: .destructive) {
                if let account = accountToDelete {
                    Task {
                        await deleteAccount(account)
                    }
                }
                accountToDelete = nil
            }
        } message: {
            Text(
                "Bạn có chắc chắn muốn xóa tài khoản này? Giao dịch liên quan có thể bị ảnh hưởng.")
        }
    }

    private func deleteAccount(_ account: WealthAccountResponse) async {
        do {
            try await deleteWealthAccountUseCase.execute(id: account.id)
            await loadData(force: true)
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

}
