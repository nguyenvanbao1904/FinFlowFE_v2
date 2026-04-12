import FinFlowCore
import SwiftUI

public struct StockAnalysisView: View {
    @Bindable var viewModel: StockAnalysisViewModel
    @State private var searchText = ""
    @State private var financialShowQuarterly = true
    /// Mặc định theo ngày (API Finfo + chỉ số theo từng ngày); chọn «Quý» trên segmented để xem điểm cuối kỳ.
    @State private var valuationGranularity: ValuationSeriesGranularity = .daily

    public init(viewModel: StockAnalysisViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    searchBar

                    if viewModel.isLoading {
                        loadingState
                    } else if let overview = viewModel.overview {
                        analysisContent(overview: overview)
                    } else {
                        emptyState
                    }
                }
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }

            if viewModel.isLoadingFullHistory {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Đang tải dữ liệu chi tiết...")
                                .font(AppTypography.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .task {
            if viewModel.overview == nil {
                await viewModel.load()
            }
        }
        .alertHandler($viewModel.error)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Tìm mã chứng khoán (VD: ACB, AAA)...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onSubmit {
                    Task {
                        await viewModel.load(
                            symbol: searchText.isEmpty ? "ACB" : searchText)
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Xóa mã cổ phiếu")
            }
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Analysis Content

    @ViewBuilder
    private func analysisContent(overview: StockOverview) -> some View {
        // Section 1: Company Info
        CompanyInfoCard(overview: overview, shareholders: viewModel.shareholders)
            .padding(.horizontal, Spacing.lg)

        // Section 2: Financial Health
        HStack(spacing: Spacing.md) {
            Text("Sức khỏe doanh nghiệp")
                .font(AppTypography.headline)
            Spacer()
            Picker("Kỳ", selection: $financialShowQuarterly) {
                Text("Năm").tag(false)
                Text("Quý").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .accessibilityHint("Đổi chu kỳ dữ liệu giữa năm và quý")
        }
        .padding(.horizontal, Spacing.lg)

        MobileInsightSnapshot(overview: overview)
            .padding(.horizontal, Spacing.lg)

        FinancialChartsSection(
            financials: viewModel.financials,
            showQuarterly: financialShowQuarterly,
            onRequestFullHistory: {
                Task {
                    await viewModel.loadFullFinancialsIfNeeded()
                }
            }
        )
        .padding(.horizontal, Spacing.lg)

        DividendHistoryTable(
            dividends: viewModel.dividends,
            onRequestFullHistory: {
                Task {
                    await viewModel.loadFullDividendsIfNeeded()
                }
            }
        )
            .padding(.horizontal, Spacing.lg)

        // Section 3: Valuation Charts
        HStack(spacing: Spacing.md) {
            Text("Khu vực định giá")
                .font(AppTypography.headline)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)

        ValuationChartGroup(
            valuations: viewModel.valuations,
            dailyValuations: viewModel.dailyValuations,
            granularity: $valuationGranularity,
            overview: overview,
            showQuarterly: true,
            onRequestFullHistory: {
                Task {
                    await viewModel.loadFullValuationsIfNeeded()
                }
            },
            onRequestValuationsForRange: { startDate, endDate, showQuarterly in
                Task {
                    await viewModel.loadFullValuationsForRange(
                        startDate: startDate,
                        endDate: endDate,
                        showQuarterly: showQuarterly
                    )
                }
            },
            onRequestDailyValuations: { startDate, endDate in
                Task {
                    await viewModel.loadDailyValuationsForRange(
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }
        )
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Đang tải dữ liệu phân tích...")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl * 2)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(AppTypography.displayXL)
                .foregroundStyle(.secondary)
            Text("Chào mừng đến thế giới Đầu tư giá trị")
                .font(AppTypography.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Nhập mã chứng khoán để phân tích 10 năm chỉ số tài chính")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl * 2)
    }
}
