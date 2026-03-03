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
    private let backgroundTimeout: TimeInterval = 60 // 1 minute

    var body: some View {
        @Bindable var observableRouter = router

        ZStack {
            NavigationStack(path: $observableRouter.path) {
                // Main Content Switching
                Group {
                    switch observableRouter.root {
                    case .splash:
                        ProgressView() // Or SplashView
                    case .authentication:
                        container.makeAuthenticationView(router: router)
                    case .welcomeBack:
                        container.makeAuthenticationView(router: router)
                    case .dashboard:
                        container.makeMainTabView(router: router)
                    case .locked:
                        if case .locked(let user, let bioAvailable) = container.sessionManager.state {
                            container.makeLockScreenView(user: user, biometricAvailable: bioAvailable)
                        } else {
                            container.makeLoginView(router: router)
                        }
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    makeDestination(for: route)
                }
            }
            .id(observableRouter.root)
            .sheet(item: $observableRouter.presentedSheet) { route in
                makeDestination(for: route)
            }
            
            // Privacy Blur Overlay
            if isPrivacyBlurVisible {
                PrivacyBlurView()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase: newPhase)
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
            container.makeMainTabView(router: router)
        case .profile:
            Text("Profile View - Coming Soon")
        case .settings:
            Text("Settings View - Coming Soon")
        case .transactionDetail(let id):
            Text("Transaction Detail: \(id) - Coming Soon")
        case .updateProfile(let profile):
            container.makeUpdateProfileView(profile: profile, router: router)
        case .changePassword(let hasPassword):
            container.makeChangePasswordView(hasPassword: hasPassword, router: router)
        case .createPIN(let email):
            container.makeCreatePINView(email: email, router: router)
        case .addTransaction:
            container.makeAddTransactionView(router: router)
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
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("FinFlow Protected")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
    }
}
