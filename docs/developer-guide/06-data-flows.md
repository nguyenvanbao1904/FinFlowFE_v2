# Chapter 6 — Data Flows

## 6.1 The Canonical Data Path

Every user-initiated action in FinFlow follows the same four-layer pipeline:

```
View  ──▶  ViewModel  ──▶  UseCase  ──▶  Repository  ──▶  APIClient  ──▶  Backend
                                                              │
                                                        URLSession
```

**Direction is always one-way:** Views call ViewModel methods, ViewModels call UseCases, UseCases call Repositories, Repositories call `HTTPClientProtocol`. No layer ever reaches upward.

## 6.2 Query Flow (Read)

A typical query — e.g., loading the transaction list — flows through four steps:

```
TransactionListView (.task)
    └─▶ TransactionListViewModel.fetchData()
            └─▶ GetTransactionsUseCase.execute(page:size:startDate:endDate:keyword:)
                    └─▶ TransactionRepository.getTransactions(...)
                            └─▶ client.request<PaginatedResponse<TransactionResponse>>(
                                    endpoint: "/transactions?page=0&size=20",
                                    method: "GET"
                                )
```

**Step-by-step:**

1. **View** — `.task { await viewModel.fetchInitialDataIfNeeded() }` triggers on appear
2. **ViewModel** — Guards with `hasRequestedInitialLoad` to prevent duplicate loads, sets `isLoading = true`, calls use case
3. **UseCase** — Passes parameters directly to repository (query use cases rarely add business logic)
4. **Repository** — Builds the endpoint string, calls `client.request<T>()`, returns decoded `T`
5. **APIClient** — Constructs `URLRequest`, attaches Bearer token, sends via `URLSession`, decodes JSON response

**Data flows back** through return values (`async throws -> T`). The ViewModel stores results in `@Observable` properties, and SwiftUI automatically re-renders.

## 6.3 Command Flow (Write)

A write operation — e.g., adding a transaction — involves validation at the UseCase layer:

```
AddTransactionView (button tap)
    └─▶ AddTransactionViewModel.saveTransaction()
            └─▶ AddTransactionUseCase.execute(amount:type:categoryId:accountId:note:date:)
                    ├── parseAmount("1.500.000") → 1500000.0   ← validation
                    ├── formatDate(date) → "2026-04-16T..."    ← transformation
                    └─▶ TransactionRepository.addTransaction(request:)
                            └─▶ client.request<TransactionResponse>(
                                    endpoint: "/transactions",
                                    method: "POST",
                                    body: AddTransactionRequest(...)
                                )
```

**UseCase responsibilities in command flows:**
- **Input validation** — `parseAmount()` throws `AppError.validationError` if amount is invalid or <= 0
- **Data transformation** — Currency string parsing (`CurrencyFormatter`), date formatting (ISO8601 with fractional seconds)
- **Request construction** — Builds the typed request struct from raw ViewModel inputs

**After success**, the ViewModel typically:
1. Dismisses the sheet via `router.dismissSheet()`
2. Posts a `NotificationCenter` notification for cross-module reactivity

## 6.4 Error Flow

Errors propagate upward through `async throws`:

```
APIClient throws AppError
    └─▶ Repository re-throws
            └─▶ UseCase re-throws (or wraps in AppError.validationError)
                    └─▶ ViewModel catches → error.toHandledAlert(sessionManager:)
                            └─▶ View displays via .alertHandler(alert:)
```

### Error Types (AppError)

| Case | Source | Example |
|------|--------|---------|
| `networkError(String)` | `URLSession` failure | No internet, timeout |
| `serverError(Int, String)` | HTTP 4xx/5xx | "Email already exists" |
| `decodingError` | JSON decode failure | Schema mismatch |
| `unauthorized(String)` | HTTP 401 | Token expired |
| `validationError(String)` | UseCase validation | "Invalid amount" |

### Centralized Error Handling

Every ViewModel uses the same pattern:

```swift
do {
    result = try await someUseCase.execute(...)
} catch {
    alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Loi")
}
```

`toHandledAlert()` (defined in `Error+AppErrorHandler.swift`) provides centralized logic:
- **`CancellationError`** → returns `nil` (ignored silently)
- **`AppError.unauthorized` or `httpStatusCode == 401`** → triggers `sessionManager.clearExpiredSession()`, shows session-expired alert
- **All other errors** → generic alert with localized message

## 6.5 Authentication & Token Flow

### Token Storage

```
Keychain (via KeychainService)
├── auth_token      ← JWT access token
└── refresh_token   ← long-lived refresh token

UserDefaults (via UserDefaultsManager)
├── email, firstName, lastName   ← display data
└── refreshTokenExpiryTime       ← expiry tracking
```

### Automatic Token Injection

Every API request goes through `APIClient.request()`, which automatically:
1. Reads the current token from `TokenStoreProtocol`
2. Attaches `Authorization: Bearer <token>` header
3. No manual token handling in repositories or use cases

### 401 Retry & Token Refresh

```
APIClient.request()
    └─▶ HTTP 401 received
            └─▶ refreshAccessToken() (single-flight via Task dedup)
                    └─▶ AuthRepository.refreshToken()
                            └─▶ POST /auth/refresh { refreshToken: "..." }
                    └─▶ Save new tokens to Keychain
                    └─▶ Retry original request with new token
                            └─▶ If 2nd 401 → onUnauthorized() → clear token
```

**Single-flight guarantee:** If multiple requests hit 401 simultaneously, only one refresh task runs. Others await the same `Task<String, Error>`:

```swift
private func refreshAccessToken() async throws -> String {
    if let existing = refreshTask {
        return try await existing.value   // ← reuse in-flight refresh
    }
    let task = Task { try await handler() }
    refreshTask = task
    defer { refreshTask = nil }
    return try await task.value
}
```

### Session State Machine

`SessionManager` is the **single source of truth** for auth state:

```
                    ┌──────────────┐
          ┌────────│   .loading   │────────┐
          │        └──────────────┘        │
          ▼                                ▼
┌──────────────────┐              ┌────────────────┐
│ .unauthenticated │◀─────────── │ .sessionExpired │
└──────────────────┘  logoutFull  └────────────────┘
          │                                ▲
          │ login()                        │ refresh fail
          ▼                                │
┌──────────────────┐              ┌────────────────┐
│  .authenticated  │─────────────▶│  .refreshing   │
└──────────────────┘  refreshToken └────────────────┘
          │
          │ logout() (soft)
          ▼
┌──────────────────┐
│  .welcomeBack    │──── PIN/biometric ───▶ .authenticated
└──────────────────┘

          │ lockSession()
          ▼
┌──────────────────┐
│    .locked       │──── PIN/biometric ───▶ .authenticated
└──────────────────┘
```

**Soft logout** keeps refresh token + user data (enables "Welcome Back" quick re-login).
**Full logout** clears everything (token, refresh token, user info).

### Session Persistence (SSOT)

All token persistence goes through a single private method:

```swift
private func persistSession(token: String, refreshToken: String?, expiresIn: Int?) async {
    await tokenStore.setToken(token)
    if let refreshToken = refreshToken {
        await tokenStore.setRefreshToken(refreshToken)
        let lifetime = expiresIn.map { TimeInterval($0) } ?? 7 * 24 * 3600
        await userDefaultsManager.saveRefreshTokenExpiryTime(Date() + lifetime)
    }
}
```

This is called from `login()`, `refreshSession()`, `refreshSessionSilently()`, and `authenticateWithPIN()` — never duplicated.

## 6.6 Cross-Feature Data Flow

Feature packages cannot import each other. Cross-feature communication uses two mechanisms:

### 1. NotificationCenter (Event Bus)

```swift
// Transaction package posts:
NotificationCenter.default.post(name: .transactionDidSave, object: nil)

// Planning package listens (in BudgetListView):
.onReceive(NotificationCenter.default.publisher(for: .transactionDidSave)) { _ in
    Task { await viewModel.loadBudgets() }
}
```

| Notification | Posted by | Listened by |
|-------------|-----------|-------------|
| `.transactionDidSave` | AddTransactionVM, TransactionListVM (delete) | BudgetListView (refresh spent amounts) |
| `.budgetDidSave` | AddBudgetVM | (currently unused) |

### 2. App Target Aggregation Service

For the Home dashboard, the app target owns `HomeDashboardServiceImpl` which crosses feature boundaries:

```swift
struct HomeDashboardServiceImpl: HomeDashboardService {
    private let getTransactionSummary: GetTransactionSummaryUseCase   // from Transaction
    private let getBudgets: GetBudgetsUseCase                         // from FinFlowCore
    private let getPortfolios: GetPortfoliosUseCase                   // from FinFlowCore
    private let getPortfolioAssets: GetPortfolioAssetsUseCase          // from FinFlowCore
    private let getPortfolioHealth: GetPortfolioHealthUseCase          // from FinFlowCore

    func loadSnapshot() async throws -> HomeDashboardSnapshot {
        async let summary = getTransactionSummary.execute()
        async let budgets = getBudgets.execute()
        async let portfolios = getPortfolios.execute()

        // ← 3 concurrent API calls, aggregated into a single snapshot
    }
}
```

**Why this lives in the app target:** It imports `Transaction`, `Investment`, and `FinFlowCore` — a feature package is not allowed to depend on other feature packages.

## 6.7 Caching

Caching is minimal and targeted:

### File-based Cache (CacheServiceProtocol)

Only `AuthRepository` uses caching — specifically for `UserProfile`:

```swift
// After fetching profile from API:
if let cacheKey = await currentUserCacheKey(for: profile.id) {
    try? await cacheService?.save(profile, forKey: cacheKey)
}
```

- Cache keys are **user-scoped** (`user_profile_<userId>`) to prevent cross-account data leakage
- Stored in `Library/Caches/FinFlowCache/` (iOS-standard, excluded from iCloud backup)
- No TTL enforcement — cache is overwritten on every successful fetch

### ViewModel-level Caching

`DependencyContainer` caches two frequently-rebuilt ViewModels:

```swift
var cachedHomeViewModel: HomeViewModel?
var cachedTransactionListViewModel: TransactionListViewModel?
```

**Why:** SwiftUI body rebuilds (e.g., when presenting sheets) would otherwise create fresh ViewModels, triggering redundant API calls and losing scroll position.

## 6.8 Pagination

Only `TransactionListViewModel` implements pagination:

```swift
func loadMoreIfNeeded(currentItem: TransactionResponse) async {
    guard let lastItem = transactions.last,
          currentItem.id == lastItem.id,    // ← triggered by last visible item
          hasMorePages, !isLoading else { return }
    currentPage += 1
    await fetchData(isInitial: false)       // ← appends to existing array
}
```

The backend returns `PaginatedResponse<T>`:

```swift
public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let content: [T]
    public let totalElements: Int
    public let totalPages: Int
    public let size: Int
    public let number: Int      // ← current page (0-based)
}
```

Page exhaustion check: `hasMorePages = response.number < response.totalPages - 1`

## 6.9 Search Debounce

`TransactionListViewModel` implements 500ms debounce for search:

```swift
public var searchText: String = "" {
    didSet {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await fetchData(isInitial: true, triggeredBySearch: true,
                           refreshSummaryAndChart: false)
        }
    }
}
```

**`triggeredBySearch: true`** skips the loading skeleton to avoid UI jitter during rapid typing.

## 6.10 Race Condition Protection

Chart loading uses a **request ID pattern** to discard stale responses:

```swift
private var latestChartRequestID = UUID()

func fetchChartData() async {
    let requestID = UUID()
    latestChartRequestID = requestID
    // ...
    let response = try await getChartUseCase.execute(...)
    guard latestChartRequestID == requestID else { return }  // discard stale
    chartData = response
}
```

**When this matters:** User rapidly switches chart range (week → month → quarter). Without this guard, an earlier slow response could overwrite a later fast response.

## 6.11 Data Flow Summary Table

| Flow Type | Layers Involved | Error Handling | Example |
|-----------|----------------|----------------|---------|
| Simple query | View → VM → UC → Repo → API | `toHandledAlert()` | Get budgets |
| Query + pagination | View → VM → UC → Repo → API | `toHandledAlert()` + page guard | Get transactions |
| Command + validation | View → VM → UC (validate) → Repo → API | Validation error before network | Add transaction |
| Cross-feature query | View → VM → AggregationService → multiple UCs → multiple Repos | `toHandledAlert()` + `async let` | Home dashboard |
| Auth flow | View → VM → SessionManager → AuthRepo → API → TokenStore | Session state machine | Login, refresh |
| Cross-feature event | Source VM → NotificationCenter → Listener View → Target VM | Independent per listener | Transaction → Budget refresh |

---

*Previous: [Chapter 5 — Feature Packages](./05-feature-packages.md)*
*Next: [Chapter 7 — Concurrency Model](./07-concurrency.md)*
