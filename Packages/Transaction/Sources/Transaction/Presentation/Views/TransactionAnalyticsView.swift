//
//  TransactionAnalyticsView.swift
//  Transaction
//

import SwiftUI
import Charts
import FinFlowCore

public struct TransactionAnalyticsView: View {
    // Mock Data for Charts
    let incomeData: [ExpenseData] = [
        .init(period: "Tuần 1", amount: 15_000_000),
        .init(period: "Tuần 2", amount: 5_000_000),
        .init(period: "Tuần 3", amount: 0),
        .init(period: "Tuần 4", amount: 25_000_000)
    ]
    
    let expenseData: [ExpenseData] = [
        .init(period: "Tuần 1", amount: 3_500_000),
        .init(period: "Tuần 2", amount: 2_100_000),
        .init(period: "Tuần 3", amount: 4_800_000),
        .init(period: "Tuần 4", amount: 1_200_000)
    ]
    
    @State private var timeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Tuần"
        case month = "Tháng"
        case quarter = "Quý"
        case year = "Năm"
        var id: String { self.rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // 1. Time Range Picker
                Picker("Thời gian", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 2. Chart Section
                chartSection
                
                // 3. AI Insights Section
                aiInsightsSection
                
                // Bottom padding to avoid tab bar collision
                Color.clear.frame(height: 100)
            }
            .padding(.top, Spacing.md)
        }
    }
    
    // MARK: - Components
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Biến động Số Dư")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack {
                Chart {
                    ForEach(incomeData) { item in
                        BarMark(
                            x: .value("Thời gian", item.period),
                            y: .value("Số tiền", item.amount)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .position(by: .value("Loại", "Thu nhập"))
                    }
                    
                    ForEach(expenseData) { item in
                        BarMark(
                            x: .value("Thời gian", item.period),
                            y: .value("Số tiền", item.amount)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .position(by: .value("Loại", "Chi tiêu"))
                    }
                }
                .chartLegend(position: .top, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.primary.opacity(0.1))
                        AxisValueLabel() {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue / 1_000_000)M")
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel() {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .padding()
            }
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.large)
            .padding(.horizontal)
        }
    }
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Trợ lý AI Phân Tích")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Insight 1
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cảnh báo chi tiêu")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("Bạn đã chi tiêu nhiều hơn 35% cho mục Ăn uống so với tháng trước. Hãy cân nhắc nấu ăn tại nhà để tiết kiệm khoảng 2.000.000 ₫ tháng tới.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Insight 2
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mẹo Tài Chính")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("Thu nhập tháng này của bạn rất tốt. Nếu bạn trích 15% (khoảng 3.750.000 ₫) vào quỹ dự phòng khẩn cấp, bạn sẽ đạt mục tiêu an toàn tài chính sớm hơn 2 tháng.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.large)
            .padding(.horizontal)
            
            // Generate Detailed Report Button
            Button(action: {
                // Trigger AI Report Generation
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Tạo Báo Cáo Chi Tiết")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.top, Spacing.sm)
        }
    }
}

// Mock Data Model
struct ExpenseData: Identifiable {
    let id = UUID()
    let period: String
    let amount: Double
}

#Preview {
    ZStack {
        AppBackgroundGradient()
        TransactionAnalyticsView()
    }
}
