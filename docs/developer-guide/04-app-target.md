# Chapter 4 — App Target Composition

## 4.1 File Inventory

The app target lives at `FinFlowIos/FinFlow/` and contains **no business logic** — only wiring and composition:

```
FinFlowIos/FinFlow/
├── App/
│   └── FinFlowIosApp.swift               ← @main entry point + AppRootView
├── Core/
│   ├── Configuration/
│   │   └── AppConfig.swift               ← Environment / base URL config
│   ├── BotChat/
│   │   ├── BotChatCreatorView.swift      ← Thread-creating wrapper (auto-creates if threadId nil)
│   │   ├── BotChatView.swift             ← Per-thread AI chat view
│   │   ├── BotChatViewModel.swift        ← Per-thread chat state management
│   │   ├── BotChatMessageRow.swift       ← Single message bubble component
│   │   ├── BotGlassOrb.swift             ← Floating action button
│   │   ├── ChatThreadListView.swift      ← Multi-thread list (swipe-delete, create new)
│   │   └── ChatThreadListViewModel.swift ← Thread list state management
│   ├── DI/
│   │   ├── DependencyContainer.swift     ← Composition root (singleton)
│   │   ├── DependencyContainer+AppViews.swift  ← View factories (non-Identity)
│   │   ├── DependencyContainer+Identity.swift  ← View factories (auth/identity)
│   │   ├── BotChatGateway.swift          ← AI chat orchestration actor
│   │   └── ChatRepository.swift          ← Chat API concrete implementation
│   ├── Home/
│   │   └── HomeDashboardServiceImpl.swift ← Cross-feature data aggregator
│   └── Navigation/
│       └── AppRouter.swift               ← App-wide router (@Observable)
```

> **No `AppDelegate` / `SceneDelegate`** — pure SwiftUI lifecycle via `@main` + `WindowGroup`.

## 4.2 App Entry Point

```swift
@main @MainActor
struct FinFlowIosApp: App {
    private let container = DependencyContainer.shared
    private let router: AppRouter

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
```

Startup sequence:
1. `DependencyContainer.shared` initializes all infrastructure, repositories, and `SessionManager`.
2. `AppRouter` is created and begins observing `SessionManager.state`.
3. `restoreSession()` determines initial auth state → router transitions `root` accordingly.

## 4.3 AppRootView — Navigation Shell

`AppRootView` is a `ZStack` composing three layers:

### Layer 1: Main Content Switch

Driven by `router.root` (`AppRoot` enum):

| `AppRoot` | View |
|-----------|------|
| `.splash` | `ProgressView` |
| `.authentication` / `.welcomeBack` | `NavigationStack` with auth flow |
| `.dashboard` | `MainTabView` (5 tabs) |
| `.locked` | `LockScreenView` or `LoginView` |

### Layer 2: Global Bot Orb

`BotGlassOrb` — a floating action button visible only on `.dashboard`. Tapping presents the **chat thread list** (`.chatThreadList`) as a `.medium/.large` detent sheet. From the thread list, users can browse previous conversations, create new threads, or swipe-to-delete old ones.

### Layer 3: Privacy Blur Overlay

`PrivacyBlurView` — full-screen `.ultraThinMaterial` blur shown when the app enters inactive/background state. Suppressed during biometric authentication to avoid covering the system prompt.

### Additional Behaviors

- **Sheet presentation** — via `router.presentedSheet`; `chatThreadList` and `finFlowBotChat` get `[.medium, .large]` detents, others get `[.large]`.
- **Post-dismiss notification** — closing the chat thread list or bot chat sheet posts `.transactionDidSave` so transaction lists refresh.
- **Background timeout** — after 60 seconds in background, `sessionManager.lockSession()` is called on return.
- **ViewModel cache invalidation** — leaving `.dashboard` clears `cachedHomeViewModel` and `cachedTransactionListViewModel` to prevent stale data after logout.

## 4.4 Dependency Injection — DependencyContainer

### Pattern

Manual DI via a **singleton composition root** (`DependencyContainer.shared`). No DI framework. Annotated `@MainActor`.

### Initialization Order

```
private init() {
    // 1. Infrastructure
    KeychainService → PINManager → UserDefaultsManager → AuthTokenStore → FileCacheService

    // 2. Network
    APIClient(config, tokenStore, apiVersion)

    // 3. Repositories (all actors)
    AuthRepository, TransactionRepository, WealthAccountRepository,
    BudgetRepository, InvestmentRepository, PortfolioRepository, ChatRepository

    // 4. Gateways
    BotChatGateway(chatRepository)

    // 5. Auth hook wiring (breaks circular dependency)
    Task { await apiClient.configureAuthHooks(...) }

    // 6. SessionManager (centralized state machine)
    SessionManager(tokenStore, authRepository, userDefaultsManager, pinManager)
}
```

### Circular Dependency Break

`APIClient` needs `AuthRepository.refreshToken()` for 401 retry, but `AuthRepository` needs `APIClient` for HTTP calls. Solution:

1. Create `APIClient` **without** refresh handler.
2. Create `AuthRepository` with the `APIClient`.
3. Call `apiClient.configureAuthHooks(refreshHandler:onUnauthorized:)` asynchronously in a `Task`.

### Use Case Lifetime: Transient

Use cases are **created on demand** inside factory methods — never stored as container properties:

```swift
func makeAddTransactionView(router: any AppRouterProtocol, ...) -> some View {
    let addUseCase = AddTransactionUseCase(repository: transactionRepository)    // ← created here
    let viewModel = AddTransactionViewModel(addUseCase: addUseCase, ...)
    return AddTransactionView(viewModel: viewModel)
}
```

This keeps the container lean and ties use-case lifetimes to view lifetimes.

### ViewModel Caching

Two ViewModels survive `AppRootView` rebuilds (which happen when sheets open/close):

```swift
var cachedHomeViewModel: HomeViewModel?
var cachedTransactionListViewModel: TransactionListViewModel?
```

Both are reset to `nil` when `router.root` leaves `.dashboard` (i.e., on logout).

**Why?** Opening a sheet changes `presentedSheet` → SwiftUI re-evaluates `AppRootView.body` → factory methods run again. Without caching, new ViewModels would be created, triggering fresh API calls and losing existing `snapshot` data.

### Container File Split

| File | Responsibility |
|------|---------------|
| `DependencyContainer.swift` | Infrastructure, repositories, session, cached VMs |
| `DependencyContainer+AppViews.swift` | View + ViewModel factories for all non-Identity features |
| `DependencyContainer+Identity.swift` | ViewModel factories for auth/identity screens |

## 4.5 AppRouter — Navigation State Machine

### State

```swift
@MainActor @Observable
public final class AppRouter: AppRouterProtocol {
    var root: AppRoot                    // .splash | .authentication | .welcomeBack | .dashboard | .locked
    var activeTab: AppTab                // .home | .transaction | .planning | .wealth | .investment
    var presentedSheet: AppRoute?

    // Per-tab navigation stacks
    var homePath: [AppRoute] = []
    var transactionPath: [AppRoute] = []
    var planningPath: [AppRoute] = []
    var wealthPath: [AppRoute] = []
    var investmentPath: [AppRoute] = []
    var authPath: [AppRoute] = []
}
```

### Reactive Session Observation

`AppRouter` uses `withObservationTracking` in a recursive loop to watch `SessionManager.state` and auto-transition `root`:

```swift
private func startSessionObservation() {
    withObservationTracking {
        self.handleStateChange(self.sessionManager.state)
    } onChange: { [weak self] in
        Task { @MainActor [weak self] in
            self?.startSessionObservation()    // re-register observation
        }
    }
}
```

| `SessionState` | → `AppRoot` |
|----------------|-------------|
| `.authenticated` | `.dashboard` (all paths cleared) |
| `.welcomeBack` | `.welcomeBack` |
| `.unauthenticated` / `.sessionExpired` | `.authentication` |
| `.loading` / `.refreshing` | `.splash` |
| `.locked` | `.locked` |

On every non-`.authenticated` transition, `presentedSheet` is set to `nil` to dismiss orphan sheets.

### Navigation API

| Method | Behavior |
|--------|----------|
| `navigate(to:)` | Push route onto active tab's path (or `authPath`) |
| `pop()` | Pop last route from current path |
| `popToRoot()` | Clear current path |
| `replacePath(with:)` | Replace entire path |
| `presentSheet(_:)` | Set `presentedSheet` |
| `dismissSheet()` | Clear `presentedSheet` |
| `selectTab(_:)` | Switch tab (auto-dismisses open sheet) |

### Route Resolution

`AppRootView.makeDestination(for:)` is a `@ViewBuilder` switch over `AppRoute` that calls the appropriate `container.make*View(...)` factory. The `makeMainTabView(router:destinationFactory:)` method passes this factory closure **into** `MainTabView` so sub-navigation within each tab can resolve routes without importing feature modules directly.

## 4.6 Cross-Feature Aggregation — HomeDashboardServiceImpl

The app target is the **only place** where multiple feature packages meet. `HomeDashboardServiceImpl` demonstrates this:

```swift
struct HomeDashboardServiceImpl: HomeDashboardService {
    private let getTransactionSummary: GetTransactionSummaryUseCase
    private let getBudgets: GetBudgetsUseCase
    private let getPortfolios: GetPortfoliosUseCase
    private let getPortfolioAssets: GetPortfolioAssetsUseCase
    private let getPortfolioHealth: GetPortfolioHealthUseCase

    func loadSnapshot() async throws -> HomeDashboardSnapshot {
        async let summary = getTransactionSummary.execute()
        async let budgets = getBudgets.execute()
        async let portfolios = getPortfolios.execute()
        // ... aggregate into HomeDashboardSnapshot
    }
}
```

It composes use cases from **Transaction**, **Planning**, and **Investment** packages into a single `HomeDashboardSnapshot` for the `Dashboard` package's `HomeViewModel`. The `Dashboard` package only knows about the `HomeDashboardService` protocol (defined in `FinFlowCore`) — it never imports `Transaction` or `Investment`.

## 4.7 AppConfig — Environment Configuration

```swift
struct AppConfig {
    enum Environment { case development, production }

    static let shared = AppConfig()
    let apiVersion: String = "1"

    var networkConfig: NetworkConfig {
        switch environment {
        case .development: NetworkConfig(baseURL: "http://192.168.1.8:8080/api")
        case .production:  NetworkConfig(baseURL: "https://api.finflow.com/api")
        }
    }
}
```

Environment is determined at compile time via `#if DEBUG`. To add staging/UAT, extend the `Environment` enum and add a build configuration.

## 4.8 BotChatGateway — AI Chat Actor

`BotChatGateway` is a Swift `actor` in the app target that wraps `ChatRepository` (also in the app target) with stateless, multi-thread operations:

- `loadThreads()` — lists all user threads (delegates to `ChatRepository.listThreads()`).
- `createThread(title:)` — creates a new chat thread.
- `deleteThread(threadId:)` — deletes a thread and all its messages (cascade on backend).
- `loadMessages(threadId:)` — fetches messages for a specific thread, maps `ChatMessageResponse` → `FinFlowBotChatMessage`.
- `sendMessage(_:threadId:)` — sends a user message and returns the AI response as `FinFlowBotSendResult`.

All methods take an explicit `threadId` parameter — there is no internal `activeThreadId` state. Thread lifecycle is managed by `ChatThreadListViewModel` (list/create/delete) and `BotChatViewModel` (per-thread chat). `BotChatCreatorView` bridges the case where a caller needs to auto-create a thread before chatting (e.g., the "Generate Report" shortcut from Transaction).

Lives in the app target (not FinFlowCore) because it's a **composition concern** — it bridges the generic `ChatRepositoryProtocol` with app-specific UI models.

## 4.9 Key Patterns Summary

| Concern | Approach |
|---------|----------|
| Entry point | `@main` SwiftUI `App` struct, no AppDelegate |
| DI | Manual singleton `DependencyContainer` with extension-split factories |
| Use case lifetime | Transient — created per factory call, not stored |
| ViewModel caching | Explicit `cached*ViewModel` for dashboard stability |
| Routing | `@Observable AppRouter` with per-tab `[AppRoute]` paths + `AppRoot` root switch |
| Session → navigation | `withObservationTracking` loop observing `SessionManager.state` |
| Feature isolation | Swift Package per feature; app target owns all wiring |
| Cross-feature aggregation | `HomeDashboardServiceImpl` bridges Transaction + Planning + Investment → Dashboard |
| Privacy / security | `ScenePhase`-driven blur overlay + 60s background lock timeout |
| AI assistant | `BotChatGateway` actor + `ChatThreadListView` (multi-thread) + global `BotGlassOrb` floating button |

---

*Previous: [Chapter 3 — FinFlowCore Deep-Dive](./03-finflowcore.md)*
*Next: [Chapter 5 — Feature Packages](./05-feature-packages.md)*
