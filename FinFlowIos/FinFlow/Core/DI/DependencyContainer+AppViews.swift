//
//  DependencyContainer+AppViews.swift
//  FinFlowIos


import Dashboard
import FinFlowCore
import Identity
import SwiftUI

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

    func makeDashboardView(router: any AppRouterProtocol) -> some View {
        DashboardView(viewModel: makeDashboardContainerViewModel(router: router))
    }
}
