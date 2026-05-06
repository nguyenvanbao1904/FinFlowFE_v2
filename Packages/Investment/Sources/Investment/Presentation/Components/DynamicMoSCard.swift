import FinFlowCore
import SwiftUI

/// Thẻ Biên An Toàn — hiển thị trong phần Khu vực định giá của StockAnalysisView.
/// Tổng quát, cố định biên 25%. Cá nhân hóa chỉ nằm trong tab Danh mục.
public struct DynamicMoSCard: View {
    let overview: StockOverview
    let getFairValueUseCase: GetFairValueUseCase

    @State private var selectedYear: Int
    @State private var marginPct: Int = 20
    @State private var fairValueResult: FairValueResult?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showExplanation = false

    private static let currentYear = Calendar.current.component(.year, from: Date())
    private let availableYears: [Int]

    public init(overview: StockOverview, getFairValueUseCase: GetFairValueUseCase) {
        self.overview = overview
        self.getFairValueUseCase = getFairValueUseCase
        let cur = Self.currentYear
        self.availableYears = Array(cur...(cur + 5))
        self._selectedYear = State(initialValue: cur)
    }

    // MARK: - Computed

    private var requiredMargin: Double { Double(marginPct) / 100.0 }

    private var fairValue: Double? {
        if let result = fairValueResult, result.priceComposite > 0 {
            return result.priceComposite
        }
        // Fallback: BVPS × medianPB
        let bvps = overview.bvps
        let medPB = overview.medianPB
        guard bvps > 0, medPB > 0 else { return nil }
        return bvps * medPB
    }

    private var fairValueLabel: String {
        if let result = fairValueResult, result.priceComposite > 0 {
            return "Giá trị hợp lý (\(result.weightsUsed.isEmpty ? result.method : result.weightsUsed))"
        }
        return "Giá trị hợp lý ước tính (PB trung vị)"
    }

    private var referencePrice: Double? {
        guard let fv = fairValue else { return nil }
        return fv * (1 - requiredMargin)
    }

    private var upperBound: Double? {
        guard let fv = fairValue else { return nil }
        return fv * (1 + requiredMargin)
    }

    private var currentPrice: Double? { overview.livePriceVnd }

    private var upsideFromCurrent: Double? {
        guard let price = currentPrice, price > 0, let fv = fairValue else { return nil }
        return ((fv - price) / price) * 100
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerRow
            Divider()
            controlsRow
            Divider()
            if isLoading {
                loadingRow
            } else {
                if fairValue != nil && currentPrice != nil {
                    priceBar
                }
                priceSection
            }
            disclaimer
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .sheet(isPresented: $showExplanation) { explanationSheet }
        .task { await fetchFairValue() }
        .onChange(of: selectedYear) { _, _ in
            Task { await fetchFairValue() }
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Tầm nhìn")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Tầm nhìn", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { yr in
                        Text(String(yr)).tag(yr)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Biên an toàn")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: $marginPct,
                    in: 10...50,
                    step: 5
                ) {
                    Text("\(marginPct)%")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .fixedSize()
            }
        }
    }

    // MARK: - Loading

    private var loadingRow: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Đang tính giá trị hợp lý \(overview.symbol) tầm nhìn \(String(selectedYear))...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Giá Trị Hợp Lý & Biên An Toàn")
                .font(AppTypography.headline)
            Spacer()
            if let result = fairValueResult, !result.verdict.isEmpty, !isLoading {
                verdictBadge(result.verdict)
            }
            Button {
                showExplanation = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppColors.primary)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Giải thích biên an toàn")
        }
    }

    private func verdictBadge(_ verdict: String) -> some View {
        let isCheap = verdict.contains("THẤP") || verdict.contains("rẻ") || verdict.contains("HỢP LÝ")
        return Text(verdict)
            .font(AppTypography.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(isCheap ? AppColors.success : AppColors.chartRatioLine)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xs / 4)
            .background((isCheap ? AppColors.success : AppColors.chartRatioLine).opacity(0.12))
            .clipShape(Capsule())
            .fixedSize()
    }

    // MARK: - Price Bar

    private var priceBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let prices = [currentPrice, referencePrice, fairValue, upperBound].compactMap { $0 }
            let lo = (prices.min() ?? 0) * 0.90
            let hi = (prices.max() ?? 1) * 1.06
            let range = hi - lo

            ZStack(alignment: .leading) {
                // 3-zone bar — rendered as one clipped HStack to avoid seam artifacts
                if let ref = referencePrice, let ub = upperBound, range > 0 {
                    let refFrac = max(0, min(1, CGFloat((ref - lo) / range)))
                    let ubFrac  = max(0, min(1, CGFloat((ub  - lo) / range)))

                    HStack(spacing: .zero) {
                        AppColors.success.opacity(0.35)
                            .frame(width: refFrac * width)
                        AppColors.chartRatioLine.opacity(0.30)
                            .frame(width: (ubFrac - refFrac) * width)
                        AppColors.expense.opacity(0.25)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                }

                // Marker: Tham khảo
                if let ref = referencePrice, range > 0 {
                    let x = CGFloat((ref - lo) / range) * width
                    markerLine(color: AppColors.success, label: "Mua", x: x, width: width, above: false)
                }

                // Marker: Hợp lý
                if let fv = fairValue, range > 0 {
                    let x = CGFloat((fv - lo) / range) * width
                    markerLine(color: AppColors.primary, label: "Hợp lý", x: x, width: width, above: false)
                }

                // Marker: Ngưng mua (upperBound)
                if let ub = upperBound, range > 0 {
                    let x = CGFloat((ub - lo) / range) * width
                    markerLine(color: AppColors.expense, label: "Bán", x: x, width: width, above: false)
                }

                // Marker: Giá hiện tại (nổi bật nhất, vẽ sau cùng)
                if let cur = currentPrice, range > 0 {
                    let x = CGFloat((cur - lo) / range) * width
                    let dotColor: Color = {
                        if let ref = referencePrice, cur <= ref { return AppColors.success }
                        if let ub = upperBound, cur >= ub { return AppColors.expense }
                        return AppColors.chartRatioLine
                    }()
                    markerDot(color: dotColor, label: "Hiện tại", x: x, width: width)
                }
            }
            .frame(height: 50)
        }
        .frame(height: 50)
    }

    private func markerLine(color: Color, label: String, x: CGFloat, width: CGFloat, above: Bool) -> some View {
        let cx = min(max(x, 2), width - 2)
        return Rectangle()
            .fill(color.opacity(0.5))
            .frame(width: 1, height: 14)
            .overlay(alignment: .center) {
                Text(label)
                    .font(AppTypography.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .fixedSize()
                    .offset(y: above ? -16 : 16)
                    .lineLimit(1)
            }
            .offset(x: cx - 0.5)
    }

    private func markerDot(color: Color, label: String, x: CGFloat, width: CGFloat) -> some View {
        let cx = min(max(x, 5), width - 5)
        return Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.4), radius: 3, y: 1)
            .overlay(alignment: .center) {
                Text(label)
                    .font(AppTypography.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .fixedSize()
                    .offset(y: -18)
                    .lineLimit(1)
            }
            .offset(x: cx - 7)
    }

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(spacing: Spacing.xs) {
            if let current = currentPrice {
                let dotColor: Color = {
                    if let ref = referencePrice, current <= ref { return AppColors.success }
                    if let ub = upperBound, current >= ub { return AppColors.expense }
                    return AppColors.chartRatioLine
                }()
                labelValueRow(label: "Giá hiện tại", value: CurrencyFormatter.format(current), valueColor: dotColor)
            }
            if let fv = fairValue {
                labelValueRow(label: fairValueLabel, value: CurrencyFormatter.format(fv), valueColor: AppColors.primary)
            }
            if let ref = referencePrice {
                let retainPct = 100 - marginPct
                labelValueRow(
                    label: "Vùng mua (≤ giá trị hợp lý × \(retainPct)%)",
                    value: "≤ \(CurrencyFormatter.format(ref))",
                    valueColor: AppColors.success
                )
            }
            if let ub = upperBound {
                let sellPct = 100 + marginPct
                labelValueRow(
                    label: "Ngưỡng bán (≥ giá trị hợp lý × \(sellPct)%)",
                    value: "≥ \(CurrencyFormatter.format(ub))",
                    valueColor: AppColors.expense
                )
            }
            if let upside = upsideFromCurrent {
                let prefix = upside >= 0 ? "+" : ""
                let color: Color = upside >= 0 ? AppColors.success : AppColors.chartRatioLine
                labelValueRow(
                    label: "Tiềm năng so với giá trị hợp lý",
                    value: "\(prefix)\(String(format: "%.1f", upside))%",
                    valueColor: color
                )
            }
            if let err = loadError {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppColors.chartRatioLine)
                    Text(err)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if fairValue == nil && !isLoading {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text("Chưa đủ dữ liệu để tính giá trị hợp lý cho \(overview.symbol)")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var disclaimer: some View {
        Text("Thông tin tham khảo theo lý thuyết đầu tư giá trị. Không phải khuyến nghị mua/bán.")
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Explanation Sheet

    private var explanationSheet: some View {
        SheetContainer(title: "Giá Trị Hợp Lý & Biên An Toàn", detents: [.medium]) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(
                        "Biên an toàn (Margin of Safety) là khái niệm trong đầu tư giá trị — mua thấp hơn giá trị hợp lý để có biên bảo vệ khi định giá sai."
                    )
                    .font(AppTypography.body)

                    Text(
                        "Giá trị hợp lý được tính theo playbook ngành: Ngân hàng dùng P/E + P/B, Bán lẻ dùng P/E + P/S, v.v. Vùng tham khảo = giá trị hợp lý × (1 − biên), nghĩa là giá nào thấp hơn mức này mới được coi là có biên an toàn."
                    )
                    .font(AppTypography.body)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Bảng tham chiếu phổ biến")
                            .font(AppTypography.headline)
                        tierRow(range: "Thận trọng thấp", margin: "15%")
                        tierRow(range: "Thận trọng trung bình", margin: "25%")
                        tierRow(range: "Thận trọng cao", margin: "35%")
                    }
                    .padding(Spacing.md)
                    .background(AppColors.settingsCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.medium))

                    Text("Điều chỉnh biên an toàn theo khẩu vị rủi ro cá nhân.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func tierRow(range: String, margin: String) -> some View {
        HStack {
            Text(range)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Biên \(margin)")
                .font(AppTypography.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helpers

    private func labelValueRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }

    private func fetchFairValue() async {
        isLoading = true
        loadError = nil
        do {
            let result = try await getFairValueUseCase.execute(symbol: overview.symbol, targetYear: selectedYear)
            fairValueResult = result
            if let err = result.error {
                loadError = err
            }
        } catch {
            loadError = "Không lấy được định giá. Dùng PB trung vị."
        }
        isLoading = false
    }
}
