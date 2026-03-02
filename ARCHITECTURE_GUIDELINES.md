# FinFlow Architecture & Development Guidelines

Welcome to the FinFlow iOS project. This document serves as the absolute source of truth for our Clean Architecture, Modular design, and State Management protocols. **All future feature developments MUST strictly adhere to these rules.**

---

## 1. Modular Dependency Rule

The project is divided into distinct local Swift Packages to enforce boundaries and isolation.

- **`FinFlowCore`**: The foundational layer. Contains shared models, networking, design system, and base routing protocols (`AppRoute`, `AppRouterProtocol`).
- **Feature Modules (`Identity`, `Dashboard`, `Profile`, etc.)**: These contain the specific domain and presentation logic for distinct capabilities.
- **`FinFlowIos` (App Target)**: The composition root. This is the **only** place where feature modules are wired together via the `DependencyContainer`.

### 🚨 Strict Rule: No Cross-Module Feature Imports
Feature modules **MUST NEVER** import each other. 
- You cannot `import Profile` inside `Identity`.
- You cannot `import Dashboard` inside `Profile`.
- Feature modules can **ONLY** import `FinFlowCore` and standard Apple frameworks. Any shared models or protocols must live in `FinFlowCore`.

---

## 2. The Centralized Routing Protocol

We utilize strictly centralized routing to prevent tightly coupled screens.

### 🚨 Strict Rule: No Local Navigation Controls in Features
Features **MUST NOT** instantiate other full screens.
- **NO** `NavigationLink(destination:)` or `NavigationLink(value:)`.
- **NO** `.sheet(isPresented:)` or `.sheet(item:)` for full-screen feature presentations.
- **NO** `.fullScreenCover()`.
*(Note: Exception granted ONLY for small, localized UI dialogs like a custom Alert, PIN Input confirm sheet, or ActionSheet).*

### How to Navigate:
All feature ViewModels must be initialized with an `any AppRouterProtocol`.
- **Push Navigation:** `router.navigate(to: .transactionDetail(id: "123"))`
- **Modal/Sheet Navigation:** `router.presentSheet(.createPIN(email: "test@test.com"))`
- **Back/Dismiss:** `router.pop()` or `router.dismissSheet()`

**Where do Views get created?**
Inside the App Target (`FinFlowIos`). The `AppRootView` observes the `AppRouter` and uses the `makeDestination(for: route)` factory (powered by the `DependencyContainer`) to instantiate and resolve the actual SwiftUI Views.

---

## 3. MVVM & State Management

We use modern Swift 5.9 Observation macros.

### 🚨 Strict Rule: No `@Published` or `ObservableObject`
- ViewModels **MUST** be annotated with `@Observable` and `@MainActor` (where appropriate).
- Views observe them directly, or via `@Bindable` if passing bindings down to sub-components.
- Do not use `@StateObject` or `@ObservedObject`. Use standard `@State` initialized in the View's `init`.

### 🚨 Strict Rule: No God Objects (Strict SRP)
- A ViewModel should manage exactly one logical scope of data/presentation.
- Do not create "Feature-level" God Object ViewModels that simply hold 3 or 4 other ViewModels. 
- If a View requires data from multiple domains (e.g., Profile info, Account settings, Security settings), inject the **individual** ViewModels directly into the View via its `init`, and let the `DependencyContainer` in the App Target assemble them.

---

## 4. Adding a New Feature (The 3-Step Checklist)

When building a new feature or screen, execute exactly these three steps:

### Step 1: Add the Route
1. Open `Packages/FinFlowCore/Sources/FinFlowCore/Navigation/NavigationTypes.swift`.
2. Add your new screen to the `AppRoute` enum.
   ```swift
   case addTransaction(accountId: String)
   ```

### Step 2: Build the Isolated Feature
1. In the appropriate feature module (e.g., `Packages/Dashboard`), create your isolated logic: `AddTransactionUseCase`, `AddTransactionViewModel`, and `AddTransactionView`.
2. The `AddTransactionViewModel` must accept its dependencies (Repository, Router) via `init` and be highly focused.
3. Do not import any other feature module. Rely entirely on `FinFlowCore`.

### Step 3: Wire it in the App Target
1. Open `FinFlowIos/FinFlow/Core/DI/DependencyContainer+AppViews.swift`.
2. Create your view factory method:
   ```swift
   func makeAddTransactionView(accountId: String, router: any AppRouterProtocol) -> some View {
       let viewModel = AddTransactionViewModel(repository: transactionRepository, router: router)
       return AddTransactionView(viewModel: viewModel)
   }
   ```
3. Open `FinFlowIos/FinFlow/App/FinFlowIosApp.swift` (inside `makeDestination(for:)`) and map the route to your factory:
   ```swift
   case .addTransaction(let accountId):
       container.makeAddTransactionView(accountId: accountId, router: router)
   ```

---
*Following these guidelines ensures FinFlow remains highly scalable, thoroughly testable, and completely decoupled.*
