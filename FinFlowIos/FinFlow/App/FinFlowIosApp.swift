//
//  FinFlowIosApp.swift
//  FinFlowIos
//
//  Created by Nguyễn Văn Bảo on 26/12/25.
//

import Dashboard
import FinFlowCore
import Identity
import SwiftUI

@main
@MainActor
struct FinFlowIosApp: App {
    // 1. Dependency Container (includes SessionManager)
    private let container = DependencyContainer.shared

    // 2. Central Router - Observes SessionManager for automatic navigation
    @StateObject private var router: AppRouter

    init() {
        // Initialize router with SessionManager
        let sessionManager = DependencyContainer.shared.sessionManager
        _router = StateObject(wrappedValue: AppRouter(sessionManager: sessionManager))
    }

    var body: some Scene {
        WindowGroup {
            // 3. NavigationStack binds to router's path
            NavigationStack(path: $router.path) {
                // 4. Root view based on authentication state
                Group {
                    if router.isAuthenticated {
                        // Main app flow
                        makeDashboardView()
                    } else {
                        // Authentication flow
                        makeLoginView()
                    }
                }
                // 5. Navigation destination mapping (Router Factory)
                .navigationDestination(for: AppRoute.self) { route in
                    makeDestination(for: route)
                }
            }
            .environmentObject(router)
            .task {
                // 🆕 Restore session on app launch
                await container.sessionManager.restoreSession()
            }
        }
    }

    // MARK: - View Factories (Router Factory Pattern)

    @ViewBuilder
    private func makeDestination(for route: AppRoute) -> some View {
        switch route {
        // Authentication
        case .login:
            makeLoginView()
        case .register:
            makeRegisterView()
        case .forgotPassword:
            makeForgotPasswordView()
                .navigationTitle("Quên Mật Khẩu") // Optional title
        case .verifyOTP(let email):
            Text("Verify OTP for \(email)")
                .navigationTitle("Xác thực OTP")

        // Main Flow
        case .dashboard:
            makeDashboardView()
        case .profile:
            Text("Profile View - Coming Soon")
                .navigationTitle("Hồ sơ")
        case .settings:
            Text("Settings View - Coming Soon")
                .navigationTitle("Cài đặt")

        // Transactions
        case .transactions:
            Text("Transactions View - Coming Soon")
                .navigationTitle("Giao dịch")
        case .transactionDetail(let id):
            Text("Transaction Detail: \(id)")
                .navigationTitle("Chi tiết")
        case .createTransaction:
            Text("Create Transaction - Coming Soon")
                .navigationTitle("Tạo giao dịch")

        // Budgets
        case .budgets:
            Text("Budgets View - Coming Soon")
                .navigationTitle("Ngân sách")
        case .budgetDetail(let id):
            Text("Budget Detail: \(id)")
                .navigationTitle("Chi tiết ngân sách")
        case .createBudget:
            Text("Create Budget - Coming Soon")
                .navigationTitle("Tạo ngân sách")
        }
    }

    // MARK: - Root Views

    private func makeLoginView() -> some View {
        LoginView(
            viewModel: container.makeLoginViewModel(router: router)
        )
    }

    private func makeDashboardView() -> some View {
        DashboardView(
            viewModel: container.makeDashboardViewModel(router: router)
        )
    }

    private func makeRegisterView() -> some View {
        RegisterView(
            viewModel: container.makeRegisterViewModel()
        )
    }

    private func makeForgotPasswordView() -> some View {
        ForgotPasswordView(
            viewModel: container.makeForgotPasswordViewModel()
        )
    }
}
