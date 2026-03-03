//
//  DependencyContainer+AppViews.swift
//  FinFlowIos
//
//  Created by FinFlow AI.
//

import Dashboard
import FinFlowCore
import Identity
import SwiftUI
import Profile
import Transaction

// MARK: - App View Factories
extension DependencyContainer {

    @ViewBuilder
    func makeAuthenticationView(router: any AppRouterProtocol) -> some View {
        switch sessionManager.state {
        case .welcomeBack(let email, let firstName, let lastName):
            makeWelcomeBackView(router: router, email: email, firstName: firstName, lastName: lastName)
        case .sessionExpired(let email, let firstName, let lastName):
            let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            makeLoginView(router: router, prefillEmail: email, userDisplayName: displayName.isEmpty ? nil : displayName)
        default:
            makeLoginView(router: router)
        }
    }

    func makeLoginView(
        router: any AppRouterProtocol,
        prefillEmail: String? = nil,
        userDisplayName: String? = nil
    ) -> some View {
        let viewModel = makeLoginViewModel(router: router)
        if let email = prefillEmail {
            viewModel.username = email
            viewModel.isSessionExpired = true
            viewModel.userDisplayName = userDisplayName ?? email.components(separatedBy: "@").first
        }
        return LoginView(viewModel: viewModel)
    }

    func makeRegisterView(router: any AppRouterProtocol) -> some View {
        RegisterView(
            viewModel: makeRegisterViewModel(
                onSuccess: { router.popToRoot() },
                onNavigateToLogin: { router.popToRoot() }
            )
        )
    }

    func makeForgotPasswordView(router: any AppRouterProtocol) -> some View {
        ForgotPasswordView(
            viewModel: makeForgotPasswordViewModel(
                onSuccess: { email in
                    Task {
                        await self.userDefaultsManager.saveEmailForPrefill(email)
                        await MainActor.run { router.popToRoot() }
                    }
                }
            )
        )
    }

    func makeWelcomeBackView(
        router: any AppRouterProtocol,
        email: String,
        firstName: String?,
        lastName: String?
    ) -> some View {
        WelcomeBackView(
            viewModel: makeWelcomeBackViewModel(
                email: email,
                firstName: firstName,
                lastName: lastName,
                onSwitchAccount: {
                    Task {
                        await self.sessionManager.logoutCompletely()
                    }
                }
            )
        )
    }

    func makeLockScreenView(user: UserProfile, biometricAvailable: Bool) -> some View {
        LockScreenView(viewModel: makeLockScreenViewModel(user: user, biometricAvailable: biometricAvailable))
    }

    // Factory cho Main Tab View (Home + Profile)
    func makeMainTabView(router: any AppRouterProtocol) -> some View {
        let profileView = makeProfileView(router: router)
        let transactionView = TransactionListView(router: router)
        return MainTabView(profileView: profileView, transactionView: transactionView)
    }

    func makeProfileView(router: any AppRouterProtocol) -> ProfileView {
        let email = sessionManager.currentUser?.email ?? ""
        
        let profileVM = ProfileViewModel(
            getProfileUseCase: GetProfileUseCase(repository: authRepository),
            authRepository: authRepository,
            router: router,
            sessionManager: sessionManager
        )
        
        let securityVM = SecuritySettingsViewModel(
            userEmail: email,
            pinManager: pinManager,
            authRepository: authRepository,
            router: router,
            sessionManager: sessionManager,
            otpHandler: otpHandler
        )
        
        let accountVM = AccountManagementViewModel(
            userEmail: email,
            authRepository: authRepository,
            otpHandler: otpHandler,
            router: router,
            sessionManager: sessionManager,
            pinManager: pinManager
        )
        
        return ProfileView(
            profileVM: profileVM,
            securityVM: securityVM,
            accountVM: accountVM
        )
    }

    func makeUpdateProfileView(profile: UserProfile, router: any AppRouterProtocol) -> some View {
        UpdateProfileView(
            viewModel: UpdateProfileViewModel(
                authRepository: authRepository,
                sessionManager: sessionManager,
                currentProfile: profile,
                onSuccess: {
                    router.pop()
                }
            )
        )
    }

    func makeChangePasswordView(hasPassword: Bool, router: any AppRouterProtocol) -> some View {
        ChangePasswordView(
            viewModel: ChangePasswordViewModel(
                authRepository: authRepository,
                sessionManager: sessionManager,
                isCreatingPassword: !hasPassword,
                onSuccess: {
                    router.pop()
                }
            )
        )
    }

    func makeCreatePINView(email: String, router: any AppRouterProtocol) -> some View {
        CreatePINView(
            viewModel: CreatePINViewModel(
                email: email,
                pinManager: pinManager,
                onCompletion: {
                    router.pop()
                }
            )
        )
    }

    func makeAddTransactionView(router: any AppRouterProtocol) -> some View {
        AddTransactionView(router: router)
    }
}
