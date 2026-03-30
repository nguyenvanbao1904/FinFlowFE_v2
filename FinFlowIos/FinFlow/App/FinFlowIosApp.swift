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
    private let router: AppRouter

    @State private var isFirstLaunch = true

    init() {
        self.router = AppRouter(sessionManager: DependencyContainer.shared.sessionManager)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router, container: container)
                .task {
                    if isFirstLaunch {
                        await container.sessionManager.restoreSession()
                        isFirstLaunch = false
                    }
                }
        }
    }
}

struct AppRootView: View {
    let router: AppRouter
    let container: DependencyContainer

    // Lifecycle & State
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastBackgroundDate: Date?
    @State private var isPrivacyBlurVisible = false

    // Constants
    private let backgroundTimeout: TimeInterval = 60  // 1 minute

    var body: some View {
        @Bindable var observableRouter = router

        ZStack {
            // Main Content Switching
            Group {
                switch observableRouter.root {
                case .splash:
                    ProgressView()  // Or SplashView
                case .authentication, .welcomeBack:
                    NavigationStack(path: $observableRouter.authPath) {
                        container.makeAuthenticationView(router: router)
                            .navigationDestination(for: AppRoute.self) { route in
                                makeDestination(for: route)
                            }
                    }
                case .dashboard:
                    container.makeMainTabView(router: router) { route in
                        makeDestination(for: route)
                    }
                case .locked:
                    if case .locked(let user, let bioAvailable) = container.sessionManager.state {
                        container.makeLockScreenView(
                            user: user, biometricAvailable: bioAvailable)
                    } else {
                        container.makeLoginView(router: router)
                    }
                }
            }
            .id(observableRouter.root)
            .sheet(item: $observableRouter.presentedSheet) { route in
                NavigationStack {
                    makeDestination(for: route)
                }
                .presentationDetents(route == .finFlowBotChat ? [.medium, .large] : [.large])
                .presentationDragIndicator(route == .finFlowBotChat ? .visible : .hidden)
            }

            // Privacy Blur Overlay
            if isPrivacyBlurVisible {
                PrivacyBlurView()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase: newPhase)
        }
        .onChange(of: observableRouter.root) { _, newRoot in
            if newRoot != .dashboard {
                container.resetCachedHomeViewModel()
            }
        }
    }

    // MARK: - Lifecycle Handlers

    private func handleScenePhaseChange(newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Remove blur
            withAnimation(.easeOut(duration: 0.2)) {
                isPrivacyBlurVisible = false
            }
            // Check timeout
            if let date = lastBackgroundDate, Date().timeIntervalSince(date) > backgroundTimeout {
                Task {
                    await container.sessionManager.lockSession()
                }
            }
            lastBackgroundDate = nil

        case .inactive:
            // Fix: Don't show privacy blur if Biometric Auth is in progress
            if !container.sessionManager.isBiometricAuthenticationInProgress {
                // Show blur immediately
                withAnimation(.easeIn(duration: 0.2)) {
                    isPrivacyBlurVisible = true
                }
            } else {
                Logger.debug("Privacy Blur suppressed due to Biometric Auth", category: "App")
            }

        case .background:
            // Ensure blur is visible (duplicate check safe)
            isPrivacyBlurVisible = true
            // Save timestamp
            lastBackgroundDate = Date()

        @unknown default:
            break
        }
    }

    // MARK: - View Factories (Router Factory Pattern)

    @ViewBuilder
    // swiftlint:disable:next cyclomatic_complexity
    private func makeDestination(for route: AppRoute) -> some View {
        switch route {
        case .login:
            container.makeLoginView(router: router)
        case .register:
            container.makeRegisterView(router: router)
        case .forgotPassword:
            container.makeForgotPasswordView(router: router)
                .navigationTitle("Quên Mật Khẩu")
        case .dashboard:
            container.makeMainTabView(router: router) { route in
                AnyView(makeDestination(for: route))
            }
        case .profile:
            container.makeProfileView(router: router)
        case .settings:
            ContentUnavailableView(
                "Cài đặt", systemImage: "gear", description: Text("Mục này đang được hoàn thiện."))
        case .transactionDetail(let id):
            ContentUnavailableView(
                "Chi tiết giao dịch", systemImage: "doc.text.magnifyingglass",
                description: Text("Không tìm thấy nội dung cho giao dịch #\(id)."))
        case .updateProfile(let profile):
            container.makeUpdateProfileView(profile: profile, router: router)
        case .changePassword(let hasPassword):
            container.makeChangePasswordView(hasPassword: hasPassword, router: router)
        case .createPIN(let email):
            container.makeCreatePINView(email: email, router: router)
        case .addTransaction:
            container.makeAddTransactionView(router: router)
        case .editTransaction(let transaction):
            container.makeAddTransactionView(router: router, transactionToEdit: transaction)
        case .categoryList:
            container.makeCategoryListView(router: router)
        case .addBudget:
            container.makeAddBudgetView(router: router)
        case .editBudget(let budget):
            container.makeAddBudgetView(router: router, budgetToEdit: budget)
        case .finFlowBotChat:
            FinFlowBotChatPlaceholderView()
        }
    }
}

// Simple Privacy Blur View
struct PrivacyBlurView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
            Rectangle()
                .fill(.ultraThinMaterial)
            VStack(spacing: Spacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(AppTypography.displayXL)
                    .foregroundColor(AppColors.disabled)
                Text("FinFlow Protected")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.disabled)
            }
        }
    }
}
