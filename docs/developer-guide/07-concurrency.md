# Chapter 7 — Concurrency Model

## 7.1 Overview

FinFlow targets **Swift 6.2 with Strict Concurrency** enabled by default (via `swift-tools-version: 6.2`). The concurrency model is built on three pillars:

| Pillar | Mechanism |
|--------|-----------|
| **Thread safety** | Swift `actor` for all mutable shared state |
| **UI isolation** | `@MainActor` for all ViewModels and UI-facing classes |
| **Structured concurrency** | `async`/`await`, `TaskGroup`, `async let` — no raw GCD |

**Zero Combine usage** — the project bans `@Published`, `@StateObject`, `@ObservedObject`, and `ObservableObject` via SwiftLint rules. All reactivity uses Swift Observation (`@Observable`).

## 7.2 The Actor Layer

Every repository and infrastructure service is a Swift `actor`, providing compile-time data-race safety:

### Core Infrastructure Actors

| Actor | Location | Purpose |
|-------|----------|---------|
| `APIClient` | FinFlowCore/Network | HTTP client with token injection + 401 retry |
| `AuthTokenStore` | FinFlowCore/Storage | Keychain-backed token read/write |
| `KeychainService` | FinFlowCore/Security | Low-level Keychain access |
| `PINManager` | FinFlowCore/Security | PIN storage + brute-force protection |
| `UserDefaultsManager` | FinFlowCore/Storage | User preferences + refresh token expiry |
| `FileCacheService` | FinFlowCore/Storage | Disk cache for API responses |
| `OTPInputHandler` | FinFlowCore/Security | Thread-safe OTP state machine |
| `ChatRepository` | FinFlowCore/Network | AI chat API calls |

### Feature Repository Actors

| Actor | Package |
|-------|---------|
| `TransactionRepository` | Transaction |
| `WealthAccountRepository` | Wealth |
| `BudgetRepository` | Planning |
| `InvestmentRepository` | Investment |
| `PortfolioRepository` | Investment |

### App-Level Actors

| Actor | Location | Purpose |
|-------|----------|---------|
| `BotChatGateway` | App Target | Chat thread management + response mapping |
| `AutoSubmitDebouncer` | Transaction (private) | Debounce speech-to-text auto-submit |
| `SpeechAudioActor` | Transaction (private) | Isolate AVAudioEngine + SFSpeechRecognizer state |

### Why Actors Everywhere?

Repositories make network calls and may be accessed from multiple tasks simultaneously (e.g., `HomeDashboardServiceImpl` fires three repository calls in parallel via `async let`). Making them actors guarantees:

- No data races on internal cache/state
- Automatic serialization of mutations
- Compiler enforcement — callers must `await` every method

## 7.3 @MainActor Isolation

All UI-facing types are `@MainActor`:

```swift
@MainActor @Observable
public final class SessionManager: SessionManagerProtocol { ... }

@MainActor @Observable
public final class AppRouter: AppRouterProtocol { ... }

@MainActor @Observable
public final class HomeViewModel { ... }

@MainActor
public class DependencyContainer { ... }
```

**Rule:** Every `@Observable` class in the project is also `@MainActor`. This eliminates the common "publishing changes from background thread" crash by construction.

### How Views Invoke Async Work

Views bridge into async contexts using `Task { }` or `.task { }`:

```swift
// In a View — .task modifier (structured, tied to view lifetime)
.task { await viewModel.load() }

// In a View — button action (unstructured, fires once)
Button("Save") {
    Task { await viewModel.save() }
}
```

Since ViewModels are `@MainActor`, the `Task { }` inherits `@MainActor` context. The `await` inside suspends at the actor boundary when calling into repository actors, but resumes on `@MainActor` to update UI state — no manual `DispatchQueue.main.async` needed.

## 7.4 Structured Concurrency Patterns

### Pattern 1: `async let` — Parallel Independent Calls

Used when multiple API calls are independent and all results are needed:

```swift
// HomeDashboardServiceImpl.swift
func loadSnapshot() async throws -> HomeDashboardSnapshot {
    async let summary = getTransactionSummary.execute()
    async let budgets = getBudgets.execute()
    async let portfolios = getPortfolios.execute()

    let s = try await summary
    let b = try await budgets
    let p = try await portfolios
    // ... combine results
}
```

All three calls start immediately; the function suspends until all complete. If any throws, the others are implicitly cancelled.

### Pattern 2: `withTaskGroup` — Dynamic Fan-Out

Used when the number of parallel tasks is determined at runtime:

```swift
// HomeDashboardServiceImpl.swift — compute market value for N portfolios
await withTaskGroup(of: (name: String, value: Double).self) { group in
    for portfolio in portfolios {
        group.addTask {
            do {
                let health = try await getHealth.execute(portfolioId: portfolio.id, quarters: 1)
                return (name: portfolio.name, value: health.current.totalValueClose)
            } catch {
                // Fallback: use cash + cost basis
                return (name: portfolio.name, value: portfolio.cashBalance)
            }
        }
    }
    for await result in group {
        totalValue += result.value
    }
}
```

Each portfolio's health check runs concurrently. Errors in individual tasks are caught and handled with fallback values — the group continues.

### Pattern 3: `withThrowingTaskGroup` — Timeout Race

Used to implement timeouts without `URLSession` timeout (for aggregate operations):

```swift
// HomeViewModel.swift
func loadSnapshotWithTimeout() async throws -> HomeDashboardSnapshot {
    try await withThrowingTaskGroup(of: HomeDashboardSnapshot.self) { group in
        group.addTask {
            try await self.dashboardService.loadSnapshot()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(20))
            throw HomeDashboardLoadTimeoutError()
        }
        guard let first = try await group.next() else {
            throw HomeDashboardLoadTimeoutError()
        }
        group.cancelAll()    // Cancel the loser
        return first
    }
}
```

Whichever task completes first wins — either the real data or the timeout error.

### Pattern 4: `Task.detached` — CPU-Bound Work Off Main Actor

Used sparingly for heavy computation that must not block the main actor:

```swift
// ReceiptOCRService.swift
struct ReceiptOCRService: Sendable {
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ReceiptOCRError.invalidImage }
        return try await Task.detached(priority: .userInitiated) {
            try Self.runVisionOCR(cgImage: cgImage)     // Heavy Vision framework work
        }.value
    }
}
```

`Task.detached` breaks `@MainActor` inheritance, running OCR on a background executor. The `Sendable` struct and `CGImage` (which is `Sendable`) ensure safe cross-isolation transfer.

## 7.5 Single-Flight Token Refresh

`APIClient` (an actor) implements a **single-flight pattern** to prevent concurrent token refreshes:

```swift
actor APIClient {
    private var refreshTask: Task<String, any Error>?

    private func refreshAccessToken() async throws -> String {
        // If a refresh is already in flight, await it instead of starting another
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, any Error> {
            try await handler()
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
```

When multiple requests hit 401 simultaneously, only one refresh call is made. Others await the same `Task.value`. The actor isolation guarantees `refreshTask` is read/written safely.

## 7.6 Session Refresh with Cancellation Safety

`SessionManager` tracks its active refresh task to support cancellation on logout:

```swift
@MainActor @Observable
public final class SessionManager {
    @ObservationIgnored
    private var activeRefreshTask: Task<RefreshTokenResponse, any Error>?

    public func refreshSession() async throws {
        activeRefreshTask?.cancel()          // Cancel previous
        let task = Task { try await authRepository.refreshToken() }
        activeRefreshTask = task

        let response = try await task.value

        // Safety: check cancellation AFTER await
        if Task.isCancelled || activeRefreshTask?.isCancelled == true {
            throw CancellationError()        // User logged out during refresh
        }
        // ... persist and update state
    }

    public func logout() async {
        activeRefreshTask?.cancel()          // Cancel any in-flight refresh
        activeRefreshTask = nil
        // ... clear session data
    }
}
```

**Key insight:** After `await task.value`, the code checks `Task.isCancelled` before updating state. If the user logged out while the refresh was in flight, the state update is aborted — preventing a race where logout → refresh success → re-authentication.

## 7.7 Observation-Based Reactivity (No Combine)

The project uses **Swift Observation** exclusively:

| Old (Combine) | FinFlow (Observation) |
|---|---|
| `@Published var items: [Item]` | `var items: [Item] = []` (inside `@Observable`) |
| `@StateObject var vm = VM()` | `let vm: VM` (injected) |
| `@ObservedObject var vm: VM` | `let vm: VM` (injected) |
| `sink { }` / `onReceive` | `withObservationTracking { }` |

### AppRouter's Observation Loop

The only explicit use of `withObservationTracking` is in `AppRouter`:

```swift
private func startSessionObservation() {
    withObservationTracking {
        self.handleStateChange(self.sessionManager.state)
    } onChange: { [weak self] in
        Task { @MainActor [weak self] in
            self?.startSessionObservation()    // Re-register
        }
    }
}
```

This creates a recursive observation loop: every time `sessionManager.state` changes, the `onChange` closure fires, which re-registers observation. This is the **non-SwiftUI** way to observe `@Observable` properties — SwiftUI views do it automatically.

### @ObservationIgnored

Properties that should not trigger view updates are marked `@ObservationIgnored`:

```swift
@ObservationIgnored
private var activeRefreshTask: Task<RefreshTokenResponse, any Error>?

@ObservationIgnored
private var hasCompletedInitialLoad = false
```

## 7.8 Sendable Compliance

Swift 6 strict concurrency requires values crossing actor boundaries to be `Sendable`:

| Type | Strategy |
|------|----------|
| Use cases | `struct` (value type) — automatically `Sendable` |
| Models (Codable) | `struct` — automatically `Sendable` |
| Repository protocols | `actor` conformance — inherently `Sendable` |
| Closures crossing actors | Annotated `@Sendable` |
| `UIImage` → background task | Extract `CGImage` (Sendable) before `Task.detached` |

Example of `@Sendable` closure annotation:

```swift
public func configureAuthHooks(
    refreshHandler: @escaping @Sendable () async throws -> String,
    onUnauthorized: (@Sendable () async -> Void)? = nil
) { ... }
```

## 7.9 Speech-to-Text: Multi-Actor Coordination

`SpeechToTextManager` demonstrates a complex multi-actor pattern:

```
┌────────────────────────┐
│  SpeechToTextManager   │  @MainActor — owns UI state (isListening, latestTranscript)
│  (Presentation layer)  │
└────────┬───────────────┘
         │ await
┌────────▼───────────────┐
│   SpeechAudioActor     │  private actor — owns AVAudioEngine + SFSpeechRecognizer
│   (Audio isolation)    │
└────────┬───────────────┘
         │ await
┌────────▼───────────────┐
│  AutoSubmitDebouncer   │  private actor — debounce timer for auto-submit
│   (Timer isolation)    │
└────────────────────────┘
```

- **SpeechToTextManager** (`@MainActor`) provides the public API and UI-bindable state.
- **SpeechAudioActor** (private `actor`) isolates audio engine setup, microphone permission, and speech recognition — keeping hardware state off the main thread.
- **AutoSubmitDebouncer** (private `actor`) manages a cancellable `Task.sleep` timer. When the user pauses speaking for 1.5 seconds, it fires the auto-submit callback.

Callbacks from `SpeechAudioActor` hop back to `@MainActor` via `Task { @MainActor in ... }`.

## 7.10 Concurrency Rules Summary

| Rule | Enforcement |
|------|-------------|
| All repositories are `actor` | Convention + code review |
| All ViewModels are `@MainActor @Observable` | SwiftLint `no_observable_object` + convention |
| No Combine (`@Published`, `ObservableObject`) | SwiftLint `no_combine_property_wrappers` |
| No raw `DispatchQueue` | Convention (not a single usage in codebase) |
| No `Task.detached` except for CPU-bound work | Convention — only `ReceiptOCRService` uses it |
| `@Sendable` on all closures crossing actor boundaries | Swift 6 compiler enforcement |
| Check `Task.isCancelled` after long `await` | Convention for session-critical paths |
| Single-flight token refresh | `APIClient.refreshTask` deduplication |

---

*Previous: [Chapter 6 — Data Flows](./06-data-flows.md)*
*Next: [Chapter 8 — API & Network](./08-api-network.md)*
