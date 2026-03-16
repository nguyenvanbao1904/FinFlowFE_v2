//
//  PlanningView.swift
//  Planning
//
//  Created by FinFlow AI.
//

import SwiftUI
import FinFlowCore

/// Container view for the Planning tab (budget list).
public struct PlanningView: View {
    private let budgetListViewModel: BudgetListViewModel

    public init(router: any AppRouterProtocol, budgetListViewModel: BudgetListViewModel) {
        self.budgetListViewModel = budgetListViewModel
    }

    public var body: some View {
        BudgetListView(viewModel: budgetListViewModel)
            .background(AppColors.appBackground)
            .navigationTitle("Kế hoạch")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        budgetListViewModel.presentAddBudget()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Thêm ngân sách")
                }
            }
    }
}
