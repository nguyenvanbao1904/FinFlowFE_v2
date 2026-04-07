//
//  HomeView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import FinFlowCore
import SwiftUI

public struct HomeView: View {
    private let router: any AppRouterProtocol
    @Bindable private var viewModel: HomeViewModel

    public init(router: any AppRouterProtocol, viewModel: HomeViewModel) {
        self.router = router
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let error = viewModel.loadError, viewModel.snapshot == nil, !isAuthAlert(error) {
                HomeErrorStateView(error: error) {
                    Task { await viewModel.load(force: true) }
                }
            } else if let snapshot = viewModel.snapshot {
                HomeDashboardContentView(
                    snapshot: snapshot,
                    onSelectTab: { router.selectTab($0) }
                )
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground)
        .loadingOverlay(viewModel.isLoading)
        .alertHandler(
            Binding(
                get: { viewModel.loadError },
                set: { _ in viewModel.dismissAlert() }
            )
        )
        .task {
            await viewModel.load()
        }
        .navigationTitle("Tổng quan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentSheet(.profile)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Hồ sơ cá nhân")
            }
        }
    }

    private func isAuthAlert(_ alert: AppErrorAlert) -> Bool {
        if case .auth = alert { return true }
        if case .authWithAction = alert { return true }
        return false
    }
}
