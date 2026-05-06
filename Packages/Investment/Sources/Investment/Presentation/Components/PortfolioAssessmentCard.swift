import BotChat
import FinFlowCore
import SwiftUI

struct PortfolioAssessmentCard: View {
    let viewModel: InvestmentPortfolioViewModel
    let gateway: BotChatGateway
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
            let thread = try await gateway.createThread(title: nil)
            let result = try await gateway.sendMessage(buildPrompt(portfolioName: portfolio.name), threadId: thread.id)
            Logger.info("got response len=\(result.content.count)", category: "PortfolioAssessmentCard")
            insights = parseInsights(from: result.content)
        } catch {
            Logger.error("fetch failed: \(error.localizedDescription)", category: "PortfolioAssessmentCard")
            fetchedPortfolioId = nil
        }

        isLoading = false
    }

    private func parseInsights(from text: String) -> [PortfolioInsight] {
        Logger.debug("parseInsights raw text: \(text.prefix(200))", category: "PortfolioAssessmentCard")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else {
            Logger.error("Failed to parse JSON, falling back to single insight", category: "PortfolioAssessmentCard")
            return [PortfolioInsight(category: .nhanXet, message: text)]
        }

        Logger.debug("Parsed \(json.count) insights from JSON", category: "PortfolioAssessmentCard")

        // Fallback: nếu LLM không trả đúng category, dùng thứ tự để map
        let expectedCategories: [PortfolioInsight.Category] = [.nhanXet, .canhBao, .loiKhuyen]

        return json.enumerated().compactMap { index, item in
            guard let msg = item["message"] else {
                Logger.error("Missing message in item: \(item)", category: "PortfolioAssessmentCard")
                return nil
            }

            let cat = item["category"] ?? ""
            let category: PortfolioInsight.Category

            switch cat {
            case "nhan_xet": category = .nhanXet
            case "canh_bao": category = .canhBao
            case "loi_khuyen": category = .loiKhuyen
            default:
                // Fallback: dùng thứ tự nếu LLM không trả đúng category
                if index < expectedCategories.count {
                    category = expectedCategories[index]
                    Logger.debug("Using fallback category for index \(index): \(category)", category: "PortfolioAssessmentCard")
                } else {
                    Logger.error("Unknown category '\(cat)' at index \(index)", category: "PortfolioAssessmentCard")
                    category = .nhanXet
                }
            }

            Logger.debug("Parsed insight[\(index)]: category=\(category) msg=\(msg.prefix(50))", category: "PortfolioAssessmentCard")
            return PortfolioInsight(category: category, message: msg)
        }
    }

    private func buildPrompt(portfolioName: String) -> String {
        var fsiNote = ""
        let expenses = viewModel.monthlyExpensesProvider()
        if expenses > 0 {
            let runway = viewModel.liquidAssetsProvider() / expenses
            if runway < 3 {
                fsiNote += " Quỹ dự phòng còn \(String(format: "%.1f", runway)) tháng (dưới mức an toàn 3 tháng)."
            }
        }
        if let ratio = viewModel.monthlyInvestRatio, ratio > 0.80 {
            fsiNote += " ~\(Int(round(ratio * 100)))% thu nhập thặng dư đang đổ vào đầu tư."
        }

        return """
        Dùng get_portfolio_analysis và get_personal_finance_report để lấy dữ liệu, rồi đưa ra đánh giá về danh mục "\(portfolioName)".\(fsiNote)

        Trả lời bằng JSON array với ĐÚNG 3 mục theo thứ tự:
        1. "nhan_xet" — Tình trạng tổng thể: danh mục đang lãi/lỗ bao nhiêu, có ổn không (1 câu ngắn)
        2. "canh_bao" — Rủi ro chính: tập trung quá cao, thiếu đa dạng hóa, hoặc vấn đề tài chính cá nhân (1 câu ngắn)
        3. "loi_khuyen" — Hành động cụ thể: nên làm gì tiếp theo để cải thiện (1 câu ngắn)

        Format:
        [
          {"category": "nhan_xet", "message": "Danh mục đang lãi 3.26 triệu (9.2%), tình hình tốt"},
          {"category": "canh_bao", "message": "VCB và HPG chiếm 60% danh mục — rủi ro tập trung cao"},
          {"category": "loi_khuyen", "message": "Xây dựng quỹ dự phòng 3-6 tháng chi tiêu trước khi tăng đầu tư"}
        ]

        Chỉ trả JSON, không thêm text nào khác. Mỗi message ngắn gọn, có số liệu cụ thể.
        """
    }
}
