//
//  MainTabView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import SwiftUI
import FinFlowCore

public struct MainTabView<
    TransactionContent: View,
    PlanningContent: View,
    WealthContent: View,
    InvestmentContent: View,
    DestinationView: View
>: View {
    @Binding private var activeTab: AppTab
    @Binding private var homePath: [AppRoute]
    @Binding private var transactionPath: [AppRoute]
    @Binding private var planningPath: [AppRoute]
    @Binding private var wealthPath: [AppRoute]
    @Binding private var investmentPath: [AppRoute]

    private let transactionView: TransactionContent
    private let planningView: PlanningContent
    private let wealthView: WealthContent
    private let investmentView: InvestmentContent
    private let destinationFactory: (AppRoute) -> DestinationView
    private let router: any AppRouterProtocol

    public init(
        router: any AppRouterProtocol,
        activeTab: Binding<AppTab>,
        homePath: Binding<[AppRoute]>,
        transactionPath: Binding<[AppRoute]>,
        planningPath: Binding<[AppRoute]>,
        wealthPath: Binding<[AppRoute]>,
        investmentPath: Binding<[AppRoute]>,
        transactionView: TransactionContent,
        planningView: PlanningContent,
        wealthView: WealthContent,
        investmentView: InvestmentContent,
        @ViewBuilder destinationFactory: @escaping (AppRoute) -> DestinationView
    ) {
        self._activeTab = activeTab
        self._homePath = homePath
        self._transactionPath = transactionPath
        self._planningPath = planningPath
        self._wealthPath = wealthPath
        self._investmentPath = investmentPath
        self.transactionView = transactionView
        self.planningView = planningView
        self.wealthView = wealthView
        self.investmentView = investmentView
        self.destinationFactory = destinationFactory
        self.router = router
    }

    public var body: some View {
        TabView(selection: $activeTab) {
            // Tab 1: Home
            NavigationStack(path: $homePath) {
                HomeView(router: router)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationFactory(route)
                    }
            }
            .tabItem {
                Label("Trang chủ", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            // Tab 2: Transaction
            NavigationStack(path: $transactionPath) {
                transactionView
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationFactory(route)
                    }
            }
            .tabItem {
                Label("Giao dịch", systemImage: "list.clipboard.fill")
            }
            .tag(AppTab.transaction)

            // Tab 3: Planning (Budget)
            NavigationStack(path: $planningPath) {
                planningView
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationFactory(route)
                    }
            }
            .tabItem {
                Label("Kế hoạch", systemImage: "target")
            }
            .tag(AppTab.planning)

            // Tab 4: Wealth (Tài sản)
            NavigationStack(path: $wealthPath) {
                wealthView
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationFactory(route)
                    }
            }
            .tabItem {
                Label("Tài sản", systemImage: "chart.pie.fill")
            }
            .tag(AppTab.wealth)

            // Tab 5: Investment
            NavigationStack(path: $investmentPath) {
                investmentView
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationFactory(route)
                    }
            }
            .tabItem {
                Label("Đầu tư", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.investment)
        }
    }
}
