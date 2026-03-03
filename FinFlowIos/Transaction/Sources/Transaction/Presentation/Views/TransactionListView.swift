//
//  TransactionListView.swift
//  Transaction
//

import SwiftUI
import FinFlowCore

/// UI for the new Transaction List View
/// Designed with Apple's Liquid Glass style leveraging FinFlowCore DesignSystem
public struct TransactionListView: View {
    // For prototype purposes, we use simple state
    @State private var searchText = ""
    @State private var selectedTab: TransactionTab = .history 
    
    enum TransactionTab: String, CaseIterable, Identifiable {
        case history = "Lịch sử"
        case analytics = "Thống kê"
        var id: String { self.rawValue }
    }
    
    // Router for centralized navigation
    private let router: any AppRouterProtocol
    
    public init(router: any AppRouterProtocol) {
        self.router = router
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // 1. Core Background
                AppBackgroundGradient()
                
                VStack(spacing: Spacing.lg) {
                    // 2. Tab Segmented Control
                    Picker("Chế độ xem", selection: $selectedTab) {
                        ForEach(TransactionTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, Spacing.sm)
                    
                    if selectedTab == .history {
                        // 3. Summary Glass Card
                        summaryCard
                            .padding(.horizontal)
                        
                        // 4. Search & Filter
                        HStack(spacing: Spacing.sm) {
                            GlassTextField(
                                text: $searchText,
                                placeholder: "Tìm kiếm giao dịch...",
                                icon: "magnifyingglass"
                            )
                            
                            Button {
                                // Filter Action
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AppColors.primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 5. Content List
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: Spacing.md) {
                                // Section Header
                                HStack {
                                    Text("Hôm nay")
                                        .font(AppTypography.headline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                // Transaction Items
                                transactionItem(
                                    title: "Ăn trưa",
                                    category: "Ăn uống",
                                    amount: "- 150,000 ₫",
                                    isIncome: false,
                                    icon: "fork.knife",
                                    color: .orange
                                )
                                
                                transactionItem(
                                    title: "Lương tháng 2",
                                    category: "Lương",
                                    amount: "+ 25,000,000 ₫",
                                    isIncome: true,
                                    icon: "banknote",
                                    color: .green
                                )
                                
                                HStack {
                                    Text("Hôm qua")
                                        .font(AppTypography.headline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, Spacing.sm)
                                
                                transactionItem(
                                    title: "Tiền điện",
                                    category: "Hóa đơn",
                                    amount: "- 850,000 ₫",
                                    isIncome: false,
                                    icon: "bolt.fill",
                                    color: .yellow
                                )
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // Padding for FAB
                        }
                    } else {
                        // Analytics View
                        TransactionAnalyticsView()
                    }
                }
            }
            .navigationTitle("Giao dịch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Profile/Settings action
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
            // Floating Action Button for "Add Transaction"
            .overlay(alignment: .bottomTrailing) {
                Button {
                    router.presentSheet(.addTransaction)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Components
    
    private var summaryCard: some View {
        VStack(spacing: Spacing.sm) {
            Text("Tổng số dư")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
            
            Text("24,000,000 ₫")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
            
            HStack(spacing: Spacing.xl) {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Thu nhập")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("25,000,000 ₫")
                        .font(AppTypography.headline)
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.primary.opacity(0.1))
                
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                        Text("Chi tiêu")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("1,000,000 ₫")
                        .font(AppTypography.headline)
                }
            }
            .padding(.top, 8)
        }
        .padding(Spacing.lg)
        // Liquid Glass Effect
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func transactionItem(
        title: String,
        category: String,
        amount: String,
        isIncome: Bool,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: Spacing.md) {
            // Category Icon with Glass background
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 46, height: 46)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Text(category)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(amount)
                .font(AppTypography.headline)
                .foregroundStyle(isIncome ? .green : .primary)
        }
        .padding(Spacing.md)
        // Liquid Glass Effect for List Items
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview
// #Preview {
//     TransactionListView(router: MockAppRouter()) // Needs a mock router to preview
// }
