//
//  HomeViewModel.swift
//  Dashboard
//

import FinFlowCore
import Foundation
import Observation

@MainActor
@Observable
public final class HomeViewModel {
    private let dashboardService: any HomeDashboardService
    private let sessionManager: any SessionManagerProtocol

    private static let loadTimeoutSeconds: UInt64 = 20

    public private(set) var snapshot: HomeDashboardSnapshot?
    public private(set) var isLoading = false
    public private(set) var loadError: AppErrorAlert?
    private var hasCompletedInitialLoad = false

    public init(
        dashboardService: any HomeDashboardService,
        sessionManager: any SessionManagerProtocol
    ) {
        self.dashboardService = dashboardService
        self.sessionManager = sessionManager
    }

    public func load(force: Bool = false) async {
        if hasCompletedInitialLoad && !force { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            snapshot = try await loadSnapshotWithTimeout()
            hasCompletedInitialLoad = true
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Không tải được Tổng quan")
        }
    }

    private func loadSnapshotWithTimeout() async throws -> HomeDashboardSnapshot {
        try await withThrowingTaskGroup(of: HomeDashboardSnapshot.self) { group in
            group.addTask {
                try await self.dashboardService.loadSnapshot()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.loadTimeoutSeconds))
                throw HomeDashboardLoadTimeoutError()
            }
            guard let first = try await group.next() else {
                throw HomeDashboardLoadTimeoutError()
            }
            group.cancelAll()
            return first
        }
    }

    public func dismissAlert() {
        loadError = nil
    }
}
