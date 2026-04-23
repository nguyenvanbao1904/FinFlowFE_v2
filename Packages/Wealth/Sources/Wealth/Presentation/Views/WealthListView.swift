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

    @Bindable var viewModel: WealthListViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var selectedTab: AccountListTab = .liquidity
    @State private var accountToEdit: WealthAccountResponse?
    @State private var accountToDelete: WealthAccountResponse?
    @State private var showDeleteConfirmation = false

    public init(viewModel: WealthListViewModel) {
        self.viewModel = viewModel
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
                            amount: viewModel.totalLiquidity
                        ),
                        items: viewModel.liquidityAccounts,
                        isLoading: viewModel.isLoading,
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
                            amount: viewModel.netWorth
                        ),
                        items: viewModel.otherAccounts,
                        isLoading: viewModel.isLoading,
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
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData(force: true) }
        .alertHandler($viewModel.loadError)
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            NavigationStack {
                AddWealthAccountView(
                    viewModel: AddWealthAccountViewModel(
                        getWealthAccountTypesUseCase: viewModel.getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: viewModel.createWealthAccountUseCase,
                        sessionManager: viewModel.sessionManager,
                        onSuccess: {
                            activeSheet = nil
                            Task { await viewModel.loadData(force: true) }
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
                        getWealthAccountTypesUseCase: viewModel.getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: viewModel.createWealthAccountUseCase,
                        updateWealthAccountUseCase: viewModel.updateWealthAccountUseCase,
                        sessionManager: viewModel.sessionManager,
                        existingAccount: account,
                        onSuccess: {
                            accountToEdit = nil
                            Task { await viewModel.loadData(force: true) }
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
                        await viewModel.deleteAccount(account)
                    }
                }
                accountToDelete = nil
            }
        } message: {
            Text(
                "Bạn có chắc chắn muốn xóa tài khoản này? Giao dịch liên quan có thể bị ảnh hưởng.")
        }
    }

}
