//
//  HomeViewModel.swift
//  Dashboard
//

import FinFlowCore
import Observation

@MainActor
@Observable
public final class HomeViewModel {
    private let dashboardService: any HomeDashboardService
    private let insightService: (any HomeInsightService)?
    private let sessionManager: any SessionManagerProtocol

    private static let loadTimeoutSeconds: UInt64 = 20
    private static let insightTimeoutSeconds: UInt64 = 18

    public private(set) var snapshot: HomeDashboardSnapshot?
    public private(set) var insight: HomeInsight?
    public private(set) var isLoadingInsight = false
    public private(set) var isLoading = false
    public private(set) var loadError: AppErrorAlert?
    @ObservationIgnored
    private var hasCompletedInitialLoad = false
    @ObservationIgnored
    private var insightTask: Task<Void, Never>?

    public init(
        dashboardService: any HomeDashboardService,
        insightService: (any HomeInsightService)? = nil,
        sessionManager: any SessionManagerProtocol
    ) {
        self.dashboardService = dashboardService
        self.insightService = insightService
        self.sessionManager = sessionManager
    }

    public func load(force: Bool = false) async {
        if hasCompletedInitialLoad && !force { return }
        isLoading = true
        loadError = nil
        if force { insight = nil }
        defer { isLoading = false }

        do {
            let loadedSnapshot = try await loadSnapshotWithTimeout()
            snapshot = loadedSnapshot
            hasCompletedInitialLoad = true
            scheduleInsightLoad(for: loadedSnapshot, force: force)
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

    private func scheduleInsightLoad(for snapshot: HomeDashboardSnapshot, force: Bool) {
        guard insightService != nil else {
            insight = fallbackInsight(for: snapshot)
            return
        }
        if insight != nil && !force { return }

        insightTask?.cancel()
        isLoadingInsight = true
        insightTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loadedInsight = try await self.loadInsightWithTimeout(snapshot: snapshot)
                guard !Task.isCancelled else { return }
                self.insight = loadedInsight
            } catch {
                guard !Task.isCancelled else { return }
                self.insight = self.fallbackInsight(for: snapshot)
            }
            self.isLoadingInsight = false
        }
    }

    private func loadInsightWithTimeout(snapshot: HomeDashboardSnapshot) async throws -> HomeInsight {
        guard let insightService else {
            return fallbackInsight(for: snapshot)
        }

        return try await withThrowingTaskGroup(of: HomeInsight.self) { group in
            group.addTask {
                try await insightService.loadInsight(for: snapshot)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.insightTimeoutSeconds))
                throw HomeDashboardLoadTimeoutError()
            }
            guard let first = try await group.next() else {
                throw HomeDashboardLoadTimeoutError()
            }
            group.cancelAll()
            return first
        }
    }

    private func fallbackInsight(for snapshot: HomeDashboardSnapshot) -> HomeInsight {
        let cashflow = snapshot.totalIncome - snapshot.totalExpense
        if cashflow < 0 {
            return HomeInsight(
                title: "Dòng tiền cần chú ý",
                message: "Chi đang cao hơn thu. Hãy rà lại khoản lớn trước khi tăng đầu tư."
            )
        }
        if snapshot.totalExpense > 0, snapshot.liquidAssets / snapshot.totalExpense < 3 {
            return HomeInsight(
                title: "Ưu tiên quỹ dự phòng",
                message: "Thanh khoản dưới 3 tháng chi tiêu. Hãy tăng tiền mặt trước."
            )
        }
        return HomeInsight(
            title: "Bức tranh đang ổn",
            message: "Dòng tiền dương. Hãy tiếp tục cân bằng tiền mặt và danh mục."
        )
    }
}
