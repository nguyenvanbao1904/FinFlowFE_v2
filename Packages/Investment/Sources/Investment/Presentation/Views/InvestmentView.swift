import FinFlowCore
import SwiftUI

public struct InvestmentView: View {
    @State private var selectedSegment = 0
    @State private var stockAnalysisVM: StockAnalysisViewModel
    @State private var showCreatePortfolio = false
    @State private var portfolios: [PortfolioResponse] = []
    @State private var isLoadingPortfolios = false
    @State private var loadError: AppErrorAlert?
    @State private var hasRequestedInitialLoad = false

    private let getPortfoliosUseCase: GetPortfoliosUseCase
    private let createPortfolioUseCase: CreatePortfolioUseCase
    private let sessionManager: any SessionManagerProtocol

    public init(
        getStockAnalysisUseCase: GetStockAnalysisUseCase,
        getPortfoliosUseCase: GetPortfoliosUseCase,
        createPortfolioUseCase: CreatePortfolioUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getPortfoliosUseCase = getPortfoliosUseCase
        self.createPortfolioUseCase = createPortfolioUseCase
        self.sessionManager = sessionManager
        _stockAnalysisVM = State(
            initialValue: StockAnalysisViewModel(
                getStockAnalysisUseCase: getStockAnalysisUseCase,
                sessionManager: sessionManager
            )
        )
    }

    private func loadPortfolios(force: Bool = false) async {
        if !force {
            if hasRequestedInitialLoad {
                return
            }
            hasRequestedInitialLoad = true
        }

        if isLoadingPortfolios {
            return
        }

        isLoadingPortfolios = true
        loadError = nil
        defer { isLoadingPortfolios = false }
        do {
            portfolios = try await getPortfoliosUseCase.execute()
        } catch {
            if error is CancellationError {
                return
            }
            if let appError = error as? AppError, case .unauthorized = appError {
                loadError = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await sessionManager.clearExpiredSession()
                    }
                }
                return
            }
            loadError = error.toAppAlert(defaultTitle: "Lỗi tải danh mục")
        }
    }

    private func createPortfolio(name: String) async {
        do {
            _ = try await createPortfolioUseCase.execute(request: CreatePortfolioRequest(name: name))
            await loadPortfolios(force: true)
        } catch {
            if error is CancellationError {
                return
            }
            if let appError = error as? AppError, case .unauthorized = appError {
                loadError = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    Task { @MainActor in
                        await sessionManager.clearExpiredSession()
                    }
                }
                return
            }
            loadError = error.toAppAlert(defaultTitle: "Lỗi tạo danh mục")
        }
    }

    public var body: some View {
        VStack(spacing: .zero) {
            segmentPicker

            TabView(selection: $selectedSegment) {
                PortfolioView(
                    portfolios: portfolios.map { .init(id: $0.id, name: $0.name) },
                    onAddPortfolio: { showCreatePortfolio = true }
                )
                .tag(0)

                StockAnalysisView(viewModel: stockAnalysisVM)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Đầu tư")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedSegment == 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePortfolio = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Tạo danh mục đầu tư")
                }
            }
        }
        .task { await loadPortfolios() }
        .refreshable { await loadPortfolios(force: true) }
        .alertHandler(
            Binding(
                get: { loadError },
                set: { loadError = $0 }
            )
        )
        .sheet(isPresented: $showCreatePortfolio) {
            CreatePortfolioSheet { name in
                await createPortfolio(name: name)
                showCreatePortfolio = false
            }
        }
    }

    private var segmentPicker: some View {
        Picker("Phân loại", selection: $selectedSegment) {
            Text("Danh mục").tag(0)
            Text("Phân tích cổ phiếu").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }
}
