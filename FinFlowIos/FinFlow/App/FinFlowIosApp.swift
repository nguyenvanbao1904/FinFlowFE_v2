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
    private let container = DependencyContainer.shared
    
    @State private var router = AppRouter(sessionManager: DependencyContainer.shared.sessionManager)

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router, container: container)
                .task {
                    // Restore session on app launch
                    await container.sessionManager.restoreSession()
                }
        }
    }
}

// ✅ Dedicated Root View to handle Navigation and Binding
struct AppRootView: View {
    @Bindable var router: AppRouter
    let container: DependencyContainer
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                if router.isAuthenticated {
                    makeDashboardView()
                } else {
                    makeLoginView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                makeDestination(for: route)
            }
        }
        .environment(router)
        // Trick: Recreate stack when auth state changes to prevent navigation bugs
        .id(router.isAuthenticated)
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
                .navigationTitle("Quên Mật Khẩu")
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
    
    // MARK: - Helper Methods
    
    private func makeLoginView() -> some View {
        LoginView(viewModel: container.makeLoginViewModel(router: router))
    }
    
    private func makeDashboardView() -> some View {
        DashboardView(viewModel: container.makeDashboardViewModel(router: router))
    }
    
    private func makeRegisterView() -> some View {
        RegisterView(viewModel: container.makeRegisterViewModel())
    }
    
    private func makeForgotPasswordView() -> some View {
        ForgotPasswordView(viewModel: container.makeForgotPasswordViewModel())
    }
}
