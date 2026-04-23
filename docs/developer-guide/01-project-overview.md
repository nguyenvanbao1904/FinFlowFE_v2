# Chapter 1 — Project Overview

## 1.1 What Is FinFlow?

FinFlow is a personal finance management iOS application built entirely in **SwiftUI** targeting **iOS 17+** with **Swift 6.2**. The app covers:

- **Transaction tracking** — manual entry, receipt OCR, speech-to-text input
- **Budget planning** — create and manage spending budgets per category
- **Wealth management** — track bank accounts, savings, and net worth
- **Investment portfolio** — stock/fund analysis with interactive charts
- **AI assistant (FinFlow Bot)** — natural language chat for financial insights and quick transaction entry
- **Security** — PIN code, biometric authentication, privacy blur, session locking

## 1.2 Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6.2 (Strict Concurrency) |
| UI Framework | SwiftUI (no UIKit in feature modules) |
| Minimum Target | iOS 17 |
| State Management | `@Observable` (Swift Observation framework) — Combine is **banned** |
| Concurrency | Swift Structured Concurrency (`async/await`, `actor`, `async let`, `withTaskGroup`) |
| Architecture | Clean Architecture (Presentation → Domain → Data) per feature module |
| Navigation | Centralized `AppRouter` with `NavigationStack` path-based routing |
| Dependency Injection | Manual constructor injection via `DependencyContainer` (no third-party DI frameworks) |
| Networking | Custom `APIClient` actor wrapping `URLSession` |
| Linting | SwiftLint with 14 custom rules enforcing architecture boundaries |
| External Dependencies | GoogleSignIn-iOS 9.1.0 (Identity package only) |
| Build System | Swift Package Manager (local packages) + Xcode project |

## 1.3 Project Structure

```
FinFlow_Project/
├── FinFlowIos/                          # Xcode project (App Target)
│   └── FinFlow/
│       ├── App/
│       │   └── FinFlowIosApp.swift       # @main entry point + AppRootView
│       └── Core/
│           ├── Configuration/
│           │   └── AppConfig.swift        # Dev/Prod environment config
│           ├── DI/
│           │   ├── DependencyContainer.swift           # Singleton DI container
│           │   ├── DependencyContainer+AppViews.swift  # View factory methods
│           │   ├── DependencyContainer+Identity.swift   # Identity-specific factories
│           │   └── BotChatGateway.swift                # AI chat orchestration actor
│           ├── Home/
│           │   └── HomeDashboardServiceImpl.swift      # Cross-package data aggregation
│           ├── BotChat/
│           │   ├── BotChatCreatorView.swift             # Thread-creating wrapper (auto-creates if nil)
│           │   ├── BotChatView.swift                    # AI chat interface (per-thread)
│           │   ├── BotChatViewModel.swift               # Chat state management (per-thread)
│           │   ├── BotChatMessageRow.swift              # Message bubble component
│           │   ├── BotGlassOrb.swift                    # Animated bot avatar
│           │   ├── ChatThreadListView.swift             # Thread list screen (swipe-delete, create)
│           │   └── ChatThreadListViewModel.swift        # Thread list state management
│           └── Navigation/
│               └── AppRouter.swift                     # @Observable centralized router
├── Packages/                            # Local Swift Packages
│   ├── FinFlowCore/    (65 files)       # Shared foundation — models, network, design system
│   ├── Identity/       (27 files)       # Auth, profile, PIN, lock screen
│   ├── Transaction/    (31 files)       # CRUD, OCR, speech-to-text, analytics
│   ├── Dashboard/      (5 files)        # Home hub + tab bar
│   ├── Planning/       (9 files)        # Budget management
│   ├── Wealth/         (10 files)       # Bank accounts & net worth
│   ├── Investment/     (57 files)       # Portfolio, stock analysis, charts
│   └── Profile/        (12 files)       # User profile settings
├── .swiftlint.yml                       # 14 custom lint rules
└── .gitignore
```

**Total:** ~240 Swift source files (225 in Packages + 15 in App Target, excluding tests, build artifacts, and third-party checkouts).

## 1.4 Package Dependency Graph

```
                    ┌──────────────┐
                    │  FinFlowCore │  ← Foundation layer (zero external deps)
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────────────────┐
        │          │       │       │       │       │       │
   Dashboard  Identity Transaction Planning Wealth Investment Profile
                  │
             GoogleSignIn   ← Only external dependency in the entire project
```

**Rule:** Feature packages depend **only** on `FinFlowCore`. They never import each other. This is enforced by the `no_cross_module_import` SwiftLint rule.

## 1.5 Environment Configuration

| Environment | Base URL | Trigger |
|-------------|----------|---------|
| Development | `http://192.168.1.8:8080/api` | `#if DEBUG` |
| Production  | `https://api.finflow.com/api` | Release build |

API versioning is header-based (`apiVersion: "1"`), configured in `AppConfig.swift`.

## 1.6 Key Design Decisions

1. **No Combine** — The project exclusively uses Swift Observation (`@Observable`) and Structured Concurrency. `@Published`, `@StateObject`, `@ObservedObject`, and `ObservableObject` are banned via SwiftLint rules.

2. **No UIKit in features** — All UI is pure SwiftUI. UIKit usage is limited to semantic color references (e.g., `Color(UIColor.systemGroupedBackground)`) in the design system.

3. **No third-party DI** — `DependencyContainer` is a hand-rolled singleton with constructor injection. This avoids framework lock-in and keeps the dependency graph explicit.

4. **Single external dependency** — Only GoogleSignIn is imported (in the Identity package). Everything else is built in-house.

5. **Centralized navigation** — All navigation routes are defined in `FinFlowCore` as the `AppRoute` enum. Feature packages never own navigation logic — they call `router.navigate(to:)`.

---

*Next: [Chapter 2 — Architecture Rules](./02-architecture-rules.md)*
