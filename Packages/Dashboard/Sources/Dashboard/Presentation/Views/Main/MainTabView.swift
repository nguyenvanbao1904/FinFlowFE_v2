//
//  MainTabView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import SwiftUI
import FinFlowCore

public struct MainTabView<
    HomeContent: View,
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

    private let homeView: HomeContent
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
        homeView: HomeContent,
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
        self.homeView = homeView
        self.transactionView = transactionView
        self.planningView = planningView
        self.wealthView = wealthView
        self.investmentView = investmentView
        self.destinationFactory = destinationFactory
        self.router = router
    }

    public var body: some View {
        TabView(selection: $activeTab) {
            tabRoot(path: $homePath, content: homeView)
            .tabItem {
                Label("Trang chủ", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            tabRoot(path: $transactionPath, content: transactionView)
            .tabItem {
                Label("Giao dịch", systemImage: "list.clipboard.fill")
            }
            .tag(AppTab.transaction)

            tabRoot(path: $planningPath, content: planningView)
            .tabItem {
                Label("Kế hoạch", systemImage: "target")
            }
            .tag(AppTab.planning)

            tabRoot(path: $wealthPath, content: wealthView)
            .tabItem {
                Label("Tài sản", systemImage: "chart.pie.fill")
            }
            .tag(AppTab.wealth)

            tabRoot(path: $investmentPath, content: investmentView)
            .tabItem {
                Label("Đầu tư", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.investment)
        }
    }

    private func tabRoot<Content: View>(
        path: Binding<[AppRoute]>,
        content: Content
    ) -> some View {
        NavigationStack(path: path) {
            content
                .navigationDestination(for: AppRoute.self) { route in
                    destinationFactory(route)
                }
        }
    }
}
