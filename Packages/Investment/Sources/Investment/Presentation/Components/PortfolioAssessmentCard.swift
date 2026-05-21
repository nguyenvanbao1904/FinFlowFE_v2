import FinFlowCore
import SwiftUI

private struct PortfolioAssessmentInsight: Identifiable {
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

struct PortfolioAssessmentCard: View {
    let viewModel: InvestmentPortfolioViewModel
    let repository: PortfolioRepository
    var onAskAI: ((String) -> Void)?

    @State private var insights: [PortfolioAssessmentInsight] = []
    @State private var isLoading = false
    @State private var fetchedPortfolioId: String?

    var body: some View {
        Group {
            if isLoading || !insights.isEmpty {
                AIInsightCard(
                    items: insights.map(\.cardItem),
                    isLoading: isLoading,
                    loadingMessage: "Đang phân tích danh mục...",
                    actionTitle: "Phân tích chi tiết với AI",
                    onAction: askDetailedAnalysis
                )
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
        guard let portfolio = viewModel.selectedPortfolio else { return }
        guard !viewModel.assets.isEmpty else { return }
        guard fetchedPortfolioId != portfolio.id else { return }

        isLoading = true
        insights = []
        fetchedPortfolioId = portfolio.id

        do {
            let response = try await repository.getPortfolioInsights(portfolioId: portfolio.id)
            insights = response.insights.compactMap { item in
                let category: PortfolioAssessmentInsight.Category
                switch item.category {
                case "nhan_xet": category = .nhanXet
                case "canh_bao": category = .canhBao
                case "loi_khuyen": category = .loiKhuyen
                default:
                    Logger.error("Unknown category '\(item.category)'", category: "PortfolioAssessmentCard")
                    return nil
                }
                return PortfolioAssessmentInsight(category: category, message: item.message)
            }
        } catch {
            Logger.error("fetch failed: \(error.localizedDescription)", category: "PortfolioAssessmentCard")
            fetchedPortfolioId = nil
        }

        isLoading = false
    }

    private func askDetailedAnalysis() {
        onAskAI?("Phân tích chi tiết danh mục \"\(viewModel.selectedPortfolio?.name ?? "")\" của tôi")
    }
}

private extension PortfolioAssessmentInsight {
    var cardItem: AIInsightCardItem {
        AIInsightCardItem(
            id: id.uuidString,
            title: category.label,
            message: message,
            systemImage: category.icon,
            tint: category.color
        )
    }
}
