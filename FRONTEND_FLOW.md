# 🧭 FinFlow Frontend Execution Flow Guide

This document details the runtime flow of the `FinFlowIos` application, explaining how the architectural components interact to drive the user experience.

## 🏗️ Architectural Overview

The application follows a **Modular Clean Architecture** pattern with **MVVM** and a centralized **Router** for navigation.

### Key Components

1.  **`FinFlowIosApp` (Entry Point)**: The root SwiftUI `App` struct. It initializes the `DependencyContainer` and sets up the root `NavigationStack`.
2.  **`DependencyContainer` (DI)**: A singleton that holds and assembles all dependencies (Network, Repositories, UseCases, ViewModels). It acts as the "Composition Root".
3.  **`AppRouter` (Navigation)**: The central source of truth for navigation state. It manages the `NavigationPath` and the top-level `isAuthenticated` state.
4.  **`SessionManager` (State)**: Manages the global authentication state (Authenticated, Unauthenticated, Loading). It drives the `AppRouter`.

---

## 🚀 1. Boot Sequence (App Launch)

When the app launches, the following sequence occurs:

1.  **`FinFlowIosApp.init()`**:
    *   `DependencyContainer.shared` is accessed, initializing core services like `NetworkConfig`, `TokenStore` (Keychain), `APIClient`, and `AuthRepository`.
    *   `AppRouter` is initialized with `SessionManager`.
2.  **`FinFlowIosApp.body`**:
    *   Render `NavigationStack` bound to `router.path`.
    *   **Conditional Root View**: Checks `router.isAuthenticated`.
        *   `true` → `DashboardView`
        *   `false` → `LoginView`
3.  **`.task` Modifier**:
    *   Calls `container.sessionManager.restoreSession()`.
    *   `SessionManager` checks the `TokenStore` for a valid access token.
    *   **Result**: Updates `SessionManager.state`, which `AppRouter` observes to set `isAuthenticated` correctly.

---

## 🔐 2. Authentication Flow (Login)

Flow from user input to dashboard transition:

1.  **User Interaction**: User enters credentials in `LoginView` and taps "Login".
2.  **ViewModel**: `LoginViewModel.login()` is called.
    *   Validates input.
    *   Calls `LoginUseCase.execute(username, password)`.
3.  **UseCase (Business Logic)**: `LoginUseCase` calls `AuthRepository.login()`.
4.  **Repository (Data)**:
    *   `AuthRepository` calls `APIClient` to send request to Backend.
    *   Receives `AuthResponse` (Tokens + User Profile).
    *   Saves tokens to `TokenStore`.
    *   Caches user profile in `CacheService`.
5.  **State Update**:
    *   `LoginViewModel` calls `sessionManager.login(response)`.
    *   `SessionManager` updates state to `.authenticated`.
6.  **Navigation (The Magic)**:
    *   `AppRouter` observes `sessionManager.state`.
    *   Detects change to `.authenticated`.
    *   Sets `isAuthenticated = true`.
    *   **Root View Switch**: `FinFlowIosApp` automatically replaces `LoginView` with `DashboardView`.

---

## 🚪 3. Logout Flow

Flow from dashboard back to login:

1.  **User Interaction**: User taps "Logout" in `DashboardView`.
2.  **ViewModel**: `DashboardViewModel` calls `logoutUseCase.execute()`.
3.  **UseCase**: `LogoutUseCase` calls `AuthRepository.logout()`.
    *   Calls Backend API to revoke token.
    *   Clears local persistence (`TokenStore`, `CacheService`).
4.  **State Update**:
    *   ViewModel calls `sessionManager.logout()`.
    *   `SessionManager` updates state to `.unauthenticated`.
5.  **Navigation**:
    *   `AppRouter` observes state change.
    *   Sets `isAuthenticated = false`.
    *   **Root View Switch**: `FinFlowIosApp` replaces `DashboardView` with `LoginView`.

---

## 🗺️ 4. Navigation Flow (Internal Routes)

How to navigate between screens (e.g., Transaction Detail):

1.  **Trigger**: ViewModel or View calls `router.navigate(to: .transactionDetail(id: "123"))`.
2.  **Router**: `AppRouter` appends the `AppRoute.transactionDetail` enum to its `path` property.
3.  **NavigationStack**: Detects change in `path`.
4.  **Destination Factory**: `FinFlowIosApp.makeDestination(for:)` is called.
    *   Matches case `.transactionDetail`.
    *   Returns the corresponding View (e.g., `TransactionDetailView`).
5.  **Transition**: SwiftUI pushes the new view onto the stack.

---

## 📦 Module Interaction

Dependencies strictly follow Clean Architecture rules:

*   **`FinFlowIos` (App Layer)**: Knows everything (`Identity`, `Dashboard`, `FinFlowCore`). Connects them via `DependencyContainer`.
*   **`Identity` / `Dashboard` (Feature Layers)**:
    *   **DO NOT** know about each other.
    *   Interact only via `FinFlowCore` interfaces (e.g., `AppRouterProtocol`, `SessionManager`).
*   **`FinFlowCore` (Shared Kernel)**: Contains common logic (`Networking`, `Router Interface`, `Global State`) used by all modules.

This design ensures logical separation and ease of testing.
