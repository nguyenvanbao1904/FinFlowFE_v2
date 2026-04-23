# Chapter 2 — Architecture Rules

## 2.1 Clean Architecture Overview

Every feature package follows a **three-layer** Clean Architecture:

```
┌─────────────────────────────────────────────┐
│              Presentation Layer              │
│   Views ← ViewModels ← Components           │
│   (SwiftUI)  (@Observable, @MainActor)       │
├─────────────────────────────────────────────┤
│                Domain Layer                  │
│   UseCases (pure business logic)             │
│   NO SwiftUI, NO UIKit imports               │
├─────────────────────────────────────────────┤
│                 Data Layer                   │
│   Repository implementations                │
│   Conforms to protocols defined in Core      │
└─────────────────────────────────────────────┘
         │
         ▼
    FinFlowCore (shared models, protocols, network, design system)
```

### Directory Layout (per feature package)

```
Sources/<PackageName>/
├── Data/
│   └── <Feature>Repository.swift       # Protocol implementation (API calls)
├── Domain/
│   ├── Models/                         # Feature-specific domain models (if any)
│   └── UseCases/
│       ├── <Action>UseCase.swift       # Single-responsibility use case
│       └── ...
└── Presentation/
    ├── Components/                     # Feature-specific reusable UI components
    ├── ViewModels/
    │   └── <Feature>ViewModel.swift    # @Observable @MainActor
    └── Views/
        └── <Feature>View.swift         # SwiftUI views
```

## 2.2 The Dependency Rule

Dependencies flow **inward only**: Presentation → Domain → Data → FinFlowCore.

| Layer | Can Import | Cannot Import |
|-------|-----------|---------------|
| Presentation | Domain, FinFlowCore, SwiftUI | Data layer directly |
| Domain | FinFlowCore only | SwiftUI, UIKit, any framework |
| Data | FinFlowCore only | SwiftUI, UIKit, Presentation |

**Domain layer isolation** is enforced by the `domain_layer_isolation` SwiftLint rule:

```yaml
domain_layer_isolation:
  included: ".*Domain.*\\.swift"
  regex: "import\\s+(?:SwiftUI|UIKit)\\b"
  message: "BANNED: Domain / UseCase layer is pure business logic."
  severity: error
```

## 2.3 Module Isolation

Feature packages are **completely isolated** from each other:

```
✅ Identity → FinFlowCore        (allowed)
✅ Transaction → FinFlowCore     (allowed)
❌ Identity → Transaction        (BANNED)
❌ Dashboard → Identity          (BANNED)
```

This is enforced by the `no_cross_module_import` SwiftLint rule:

```yaml
no_cross_module_import:
  included: ".*Packages/.*\\.swift"
  regex: "import\\s+(?:Identity|Dashboard|Profile|Transaction)\\b"
  message: "BANNED: Feature modules must not import each other."
  severity: error
```

**Why?** Cross-module imports create circular dependencies and make packages impossible to build/test independently. When features need to communicate, they go through:
- **FinFlowCore protocols** — shared contracts
- **App Target** — the `DependencyContainer` wires cross-package dependencies
- **Router** — navigation between features via `AppRoute` enum

## 2.4 Inversion of Control

Repository **protocols** live in `FinFlowCore`, not in feature packages:

```
FinFlowCore/Models/RepositoryProtocols.swift
├── AuthenticationRepositoryProtocol
├── ProfileRepositoryProtocol
├── OTPRepositoryProtocol
├── AccountRepositoryProtocol
├── TransactionRepositoryProtocol
├── WealthAccountRepositoryProtocol
├── BudgetRepositoryProtocol
├── PortfolioRepositoryProtocol
├── ChatRepositoryProtocol
└── AuthRepositoryProtocol          ← Composite (Auth + Profile + OTP + Account)
```

Feature packages provide **concrete implementations**:

```swift
// In Identity/Data/AuthRepository.swift
public final class AuthRepository: AuthRepositoryProtocol, Sendable { ... }

// In Transaction/Data/TransactionRepository.swift
public actor TransactionRepository: TransactionRepositoryProtocol { ... }
```

The **App Target's `DependencyContainer`** creates concrete repositories and injects them into ViewModels — feature packages never know which implementation they're using.

## 2.5 ViewModel Rules

All ViewModels follow these conventions:

```swift
@Observable                    // ← Swift Observation (NOT Combine)
@MainActor                     // ← All UI state mutations on main thread
final class SomeViewModel {
    // MARK: - Published State
    var items: [Item] = []
    var isLoading = false
    var error: AppError?

    // MARK: - Dependencies (injected via init)
    private let someUseCase: SomeUseCase
    private let router: any AppRouterProtocol

    init(someUseCase: SomeUseCase, router: any AppRouterProtocol) {
        self.someUseCase = someUseCase
        self.router = router
    }

    // MARK: - Actions
    func loadData() async { ... }
}
```

**Rules enforced:**

| Rule | SwiftLint Rule | Severity |
|------|---------------|----------|
| No `@Published` | `no_combine_property_wrappers` | error |
| No `@StateObject` / `@ObservedObject` | `no_combine_property_wrappers` | error |
| No `ObservableObject` conformance | `no_observable_object` | error |
| No UseCase/Repository construction in Views | `no_business_logic_in_view` | error |

## 2.6 View Rules

```swift
struct SomeView: View {
    let viewModel: SomeViewModel      // Injected, never constructed here

    var body: some View {
        // Use design system tokens:
        VStack(spacing: Spacing.sm) {  // ← NOT hardcoded numbers
            Text("Title")
                .font(AppTypography.headline)      // ← NOT .font(.headline)
                .foregroundStyle(AppColors.primary) // ← NOT .foregroundStyle(.blue)
        }
        .padding(Spacing.md)           // ← NOT .padding(20)
    }
}
```

**Rules enforced:**

| Rule | SwiftLint Rule | Severity |
|------|---------------|----------|
| No hardcoded padding values | `no_hardcoded_padding` | error |
| No hardcoded spacing in stacks | `no_hardcoded_spacing` | error |
| No hardcoded colors in modifiers | `no_hardcoded_colors` | warning |
| Prefer `AppTypography` tokens | `prefer_app_typography` | warning |
| No `NavigationLink(destination:)` | `no_navigation_link_destination` | error |
| No direct `.sheet`/`.fullScreenCover` for features | `no_direct_sheet_or_cover` | warning |

## 2.7 Navigation Rules

Navigation is **fully centralized** through the `AppRouter`:

```swift
// ✅ Correct — delegate to router
router.navigate(to: .transactionDetail(id: "123"))
router.presentSheet(.addTransaction)
router.selectTab(.transaction)

// ❌ Wrong — direct NavigationLink with destination
NavigationLink(destination: TransactionDetailView()) { ... }

// ❌ Wrong — direct sheet presentation
.sheet(isPresented: $showingDetail) { TransactionDetailView() }
```

### Navigation Architecture

```
AppRoute (enum in FinFlowCore)
    ↓
AppRouter (@Observable, App Target)
    ↓
AppRootView (switches on router.root)
    ├── .splash → ProgressView
    ├── .authentication / .welcomeBack → NavigationStack + authPath
    ├── .dashboard → MainTabView (5 tabs, each with own NavigationStack)
    └── .locked → LockScreenView
```

Each tab maintains its own navigation path:
- `homePath`, `transactionPath`, `planningPath`, `wealthPath`, `investmentPath`

The router listens to `SessionManager.state` changes via `withObservationTracking` and automatically transitions the root:

| SessionState | AppRoot |
|-------------|---------|
| `.loading` / `.refreshing` | `.splash` |
| `.authenticated(token:isRestored:)` | `.dashboard` |
| `.unauthenticated` / `.sessionExpired(email:firstName:lastName:)` | `.authentication` |
| `.welcomeBack(email:firstName:lastName:)` | `.welcomeBack` |
| `.locked(user:biometricAvailable:)` | `.locked` |

## 2.8 UseCase Pattern

Each use case encapsulates **one business operation**:

```swift
// Domain/UseCases/LoginUseCase.swift
public struct LoginUseCase: Sendable {
    private let repository: AuthenticationRepositoryProtocol

    public init(repository: AuthenticationRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(email: String, password: String) async throws -> AuthResponse {
        return try await repository.login(email: email, password: password)
    }
}
```

**Conventions:**
- Use cases are `struct` (value type), not `class`
- Marked `Sendable` for safe cross-actor passing
- Single `execute(...)` method
- Injected with repository protocol, not concrete implementation
- No UI imports, no side effects beyond the repository call

## 2.9 Architecture Summary Diagram

```
┌────────────────────────────────────────────────────────────┐
│                     App Target (FinFlowIos)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  AppRouter    │  │  DI Container │  │  AppRootView     │  │
│  │  (@Observable)│  │  (Singleton)  │  │  (Root SwiftUI)  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │             │
│    Observes          Creates &             Renders           │
│    SessionState      Injects               Views            │
├─────────┼─────────────────┼────────────────────┼────────────┤
│         ▼                 ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Feature Packages (isolated)             │    │
│  │  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌───────┐ │    │
│  │  │ Identity │ │Transaction│ │Investment│ │  ...  │ │    │
│  │  │Presentation│           │ │          │ │       │ │    │
│  │  │  Domain   │  Domain    │ │  Domain  │ │Domain │ │    │
│  │  │  Data     │  Data      │ │  Data    │ │ Data  │ │    │
│  │  └──────────┘ └───────────┘ └──────────┘ └───────┘ │    │
│  └────────────────────────┬────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    FinFlowCore                       │    │
│  │  Models · Protocols · Network · Design System        │    │
│  │  Navigation Types · State · Security · Utilities     │    │
│  └─────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────┘
```

---

*Previous: [Chapter 1 — Project Overview](./01-project-overview.md)*
*Next: [Chapter 3 — FinFlowCore Deep-Dive](./03-finflowcore.md)*
