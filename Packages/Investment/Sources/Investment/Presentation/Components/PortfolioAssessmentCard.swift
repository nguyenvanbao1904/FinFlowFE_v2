import FinFlowCore
import SwiftUI

struct PortfolioAssessmentCard: View {
    let viewModel: InvestmentPortfolioViewModel
    let repository: PortfolioRepository
    var onAskAI: ((String) -> Void)?

    @State private var insights: [PortfolioInsight] = []
    @State private var isLoading = false
    @State private var fetchedPortfolioId: String?

    private struct PortfolioInsight: Identifiable {
        let id = UUID()
        let category: Category
        let message: String

        enum Category {
            case nhanXet, canhBao, loiKhuyen

            var label: String {
                switch self {
                case .nhanXet: return "Nhận xét"
                case .canhBao: return "Cảnh báo"
                case .loiKhuyen: return "Lời khuyên"
                }
            }

            var icon: String {
                switch self {
                case .nhanXet: return "chart.bar.fill"
                case .canhBao: return "exclamationmark.triangle.fill"
                case .loiKhuyen: return "lightbulb.fill"
                }
            }

            var color: Color {
                switch self {
                case .nhanXet: return AppColors.primary
                case .canhBao: return AppColors.error
                case .loiKhuyen: return Color.orange
                }
            }
        }
    }

    var body: some View {
        let _ = Logger.debug("body evaluated | portfolio=\(viewModel.selectedPortfolio?.id ?? "nil") assets=\(viewModel.assets.count) isLoading=\(isLoading) insightCount=\(insights.count)", category: "PortfolioAssessmentCard")
        Group {
            if isLoading {
                HStack(spacing: Spacing.sm) {
                    ProgressView().scaleEffect(0.8)
                    Text("Đang phân tích danh mục...")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColors.cardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.large))
            } else if !insights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(insights) { insight in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: insight.category.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(insight.category.color)
                                Text(insight.category.label.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(insight.category.color)
                                    .tracking(0.5)
                            }
                            Text(insight.message)
                                .font(AppTypography.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(insight.category.color.opacity(0.08))
                        .clipShape(.rect(cornerRadius: CornerRadius.small))
                    }

                    Divider()

                    Button {
                        onAskAI?("Phân tích chi tiết danh mục \"\(viewModel.selectedPortfolio?.name ?? "")\" của tôi")
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "brain").font(AppTypography.subheadline)
                            Text("Phân tích chi tiết với AI")
                                .font(AppTypography.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(AppColors.cardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.large))
            }
        }
        .onAppear {
            Task { await fetchSummary() }
        }
        .onChange(of: viewModel.selectedPortfolio?.id) { _, _ in
            Task { await fetchSummary() }
        }
        .onChange(of: viewModel.assets.isEmpty) { _, isEmpty in
            if !isEmpty { Task { await fetchSummary() } }
        }
    }

    private func fetchSummary() async {
        Logger.debug("fetchSummary | portfolio=\(viewModel.selectedPortfolio?.id ?? "nil") assets=\(viewModel.assets.count) fetchedFor=\(fetchedPortfolioId ?? "nil")", category: "PortfolioAssessmentCard")
        guard let portfolio = viewModel.selectedPortfolio else { return }
        guard !viewModel.assets.isEmpty else { return }
        guard fetchedPortfolioId != portfolio.id else { return }

        isLoading = true
        insights = []
        fetchedPortfolioId = portfolio.id

        do {
            let response = try await repository.getPortfolioInsights(portfolioId: portfolio.id)
            Logger.info("got \(response.insights.count) insights", category: "PortfolioAssessmentCard")
            insights = response.insights.compactMap { item in
                let category: PortfolioInsight.Category
                switch item.category {
                case "nhan_xet": category = .nhanXet
                case "canh_bao": category = .canhBao
                case "loi_khuyen": category = .loiKhuyen
                default:
                    Logger.error("Unknown category '\(item.category)'", category: "PortfolioAssessmentCard")
                    return nil
                }
                return PortfolioInsight(category: category, message: item.message)
            }
        } catch {
            Logger.error("fetch failed: \(error.localizedDescription)", category: "PortfolioAssessmentCard")
            fetchedPortfolioId = nil
        }

        isLoading = false
    }
}
