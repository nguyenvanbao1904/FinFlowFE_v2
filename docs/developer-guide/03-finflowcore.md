# Chapter 3 — FinFlowCore Deep-Dive

## 3.1 Package Manifest

```swift
// swift-tools-version: 6.2
let package = Package(
    name: "FinFlowCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FinFlowCore", targets: ["FinFlowCore"]),
    ],
    targets: [
        .target(
            name: "FinFlowCore",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
    ]
)
```

Key points:
- **Swift 6.2** with Strict Concurrency enabled by default
- **`ExistentialAny`** upcoming feature — requires `any` keyword for existential types (e.g., `any AppRouterProtocol`)
- **Zero external dependencies** — FinFlowCore is self-contained
- Single target, single library product

## 3.2 Directory Structure

```
Sources/FinFlowCore/
├── DesignSystem/
│   ├── Components/
│   │   ├── Primitives/
│   │   │   ├── ButtonStyles.swift       # Primary, Text button styles + View extensions
│   │   │   ├── ProgressBar.swift        # Custom progress bar
│   │   │   ├── SheetContainer.swift     # Generic sheet wrapper (title + detents)
│   │   │   └── TypeOptionButton.swift   # Income/Expense toggle
│   │   ├── BalanceLabel.swift           # Currency formatting label
│   │   ├── CategorySelectionSheet.swift # Category picker sheet
│   │   ├── ChartSelectionPopover.swift  # Chart type/range selection popover
│   │   ├── CompactMetricCard.swift      # Dashboard snapshot grid card
│   │   ├── DateRangeFilterSheet.swift   # Date picker sheet
│   │   ├── EmptyStateView.swift         # Reusable empty state (icon + text + CTA)
│   │   ├── FinancialHeroCard.swift      # Dark hero card for financial summaries
│   │   ├── GlassField.swift             # Glassmorphism text field
│   │   ├── IconTitleTrailingRow.swift   # Generic list row
│   │   ├── LoadingOverlay.swift         # Full-screen loading overlay modifier
│   │   ├── PasswordConfirmationSheet.swift # Password confirm sheet
│   │   ├── PINEntry.swift               # Consolidated PIN input (sheet + view + digits)
│   │   └── SelectionSheet.swift         # Generic selection sheet
│   ├── Extensions/
│   │   ├── Color+Extensions.swift       # Color(hex:) + .toHex
│   │   └── View+Alert.swift             # .alertHandler() modifier
│   └── Tokens/
│       ├── Assets.swift                 # SF Symbol + image asset names
│       ├── Colors.swift                 # AppColors (~40 semantic color tokens)
│       ├── Spacing.swift                # Spacing, CornerRadius, BorderWidth, OpacityLevel, etc.
│       ├── Typography.swift             # AppTypography (~20 font tokens)
│       └── UILayout.swift               # Fixed dimensions (icons, PIN dots, buttons)
├── Domain/
│   ├── GetBudgetsUseCase.swift          # Cross-module use case for Home
│   ├── GetCategoriesUseCaseProtocol.swift
│   ├── GetPortfolioAssetsUseCase.swift
│   ├── GetPortfoliosUseCase.swift
│   ├── GetWealthAccountsUseCase.swift
│   └── RepositoryProtocols.swift        # All repository protocols (ISP)
├── Error/
│   ├── AppAlert.swift                   # AppAlert protocol
│   ├── AppErrorAlert.swift              # 7-case alert enum with AlertType
│   ├── Error+AppErrorAlert.swift        # Error → AppErrorAlert mapping
│   ├── Error+AppErrorHandler.swift      # Error → handled alert (with 401 auto-clear)
│   └── Logger.swift                     # Static Logger (wraps os.Logger)
├── Models/
│   ├── AccountModels.swift
│   ├── ApiResponse.swift                # Generic ApiResponse<T>
│   ├── AppError.swift                   # 6-case error enum
│   ├── AuthModels.swift                 # Login/Register/OTP/Password DTOs
│   ├── BudgetModels.swift
│   ├── ChatModels.swift
│   ├── CompanySuggestionModels.swift
│   ├── CurrencyFormatter.swift          # VND formatting, input parsing
│   ├── DomainModels.swift               # UserProfile, OtpPurpose
│   ├── HomeDashboardSnapshot.swift      # Aggregated home data
│   ├── PortfolioModels.swift
│   ├── ProblemDetail.swift              # RFC 7807 error format
│   └── TransactionModels.swift
├── Network/
│   ├── APIClient.swift                  # Actor — HTTP engine with 401 retry
│   ├── HTTPClientProtocol.swift         # Protocol with convenience overloads
│   └── NetworkConfig.swift              # Base URL + API version protocol
├── Security/
│   ├── BiometricAuthHandler.swift       # Face ID / Touch ID
│   ├── OTPInputHandler.swift            # Actor — OTP validation + send/verify
│   ├── PINManager.swift                 # Actor — SHA-256 hashed PIN + lockout
│   └── PINManagerProtocol.swift
├── State/
│   ├── NavigationTypes.swift            # AppRoot, AppTab, AppRoute, AppRouterProtocol
│   ├── SessionManager.swift             # @MainActor @Observable — auth state machine
│   ├── SessionManagerProtocol.swift
│   └── SessionState.swift               # 7-case state enum
├── Storage/
│   ├── AuthTokenStore.swift             # Actor — token storage via Keychain
│   ├── CacheService.swift               # Actor — file-based cache (Library/Caches)
│   ├── KeychainService.swift            # Actor — Security framework wrapper
│   ├── TokenStore.swift                 # TokenStoreProtocol
│   ├── UserDefaultsManager.swift        # Actor — non-sensitive user data
│   └── UserDefaultsManagerProtocol.swift
```

**Total: 65 Swift files** — the largest package in the project.

## 3.3 Models & DTOs

### Generic API Wrapper

All API responses are wrapped in a standard envelope:

```swift
public struct ApiResponse<T: Codable & Sendable>: Codable, Sendable {
    public let code: Int
    public let message: String?
    public let result: T?
}

public struct EmptyResponse: Codable, Sendable {}
```

For paginated endpoints (Spring Boot `Page<T>` responses):

```swift
public struct PageResponse<T: Codable & Sendable>: Codable, Sendable {
    public let content: [T]
    public let totalElements: Int
    public let totalPages: Int
    public let number: Int
    public let size: Int
    public let first: Bool
    public let last: Bool
}
```

Used by `ChatRepository` to decode paginated thread/message lists from the backend.

### RFC 7807 Error Model

Server errors follow the RFC 7807 Problem Detail format:

```swift
public struct ProblemDetail: Decodable, Sendable {
    public let type: String?
    public let title: String?
    public let status: Int?
    public let detail: String?
    public let instance: String?
}
```

### AppError

Six-case enum used throughout the app:

```swift
public enum AppError: Error, Sendable {
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case unauthorized
    case validationError(String)
    case unknown(String)
}
```

### Domain Models

| File | Key Types | Purpose |
|------|-----------|---------|
| `DomainModels.swift` | `UserProfile`, `OtpPurpose` | Core user identity |
| `AuthModels.swift` | Login/Register/OTP/Password request & response DTOs | Authentication flows |
| `TransactionModels.swift` | `TransactionType`, `TransactionResponse`, `CategoryResponse`, `PaginatedResponse<T>`, `ChartRange`, chart data models, `AnalyzeTransactionRequest/Response` | Transaction CRUD + analytics |
| `AccountModels.swift` | `AccountTypeOptionResponse`, `WealthAccountResponse`, create/update requests | Wealth accounts |
| `BudgetModels.swift` | `BudgetResponse`, `BudgetWithSpending`, create/update requests | Budget management |
| `ChatModels.swift` | Thread/message request & response DTOs, `SendChatMessageResponse`, `FinFlowBotChatMessage`, `FinFlowBotSendResult`, `FinFlowBotCitation` | AI chat (multi-thread) |
| `PortfolioModels.swift` | `PortfolioResponse`, `PortfolioAssetResponse`, `TradeType`, trade/import/health/benchmark DTOs | Investment portfolio |
| `CompanySuggestionModels.swift` | `CompanySuggestionResponse`, `CompanyIndustryResponse` | Stock search |
| `HomeDashboardSnapshot.swift` | `HomeDashboardSnapshot`, `HomeDashboardService` protocol | Home screen aggregation |

All models conform to `Codable`, `Sendable`, and where needed `Hashable` / `Identifiable`.

### Cross-Module Notifications

Two `Notification.Name` constants for cross-module communication:

```swift
// In TransactionModels.swift
extension Notification.Name {
    public static let transactionDidSave = Notification.Name("transactionDidSave")
}

// In BudgetModels.swift
extension Notification.Name {
    public static let budgetDidSave = Notification.Name("budgetDidSave")
}
```

These allow the Home screen to refresh when data changes in other modules without importing them.

## 3.4 Repository Protocols (Interface Segregation)

All repository protocols live in `FinFlowCore/Domain/RepositoryProtocols.swift`. They follow the **Interface Segregation Principle** — each protocol covers a single responsibility:

```swift
public protocol AuthenticationRepositoryProtocol: Sendable { ... }
public protocol ProfileRepositoryProtocol: Sendable { ... }
public protocol OTPRepositoryProtocol: Sendable { ... }
public protocol AccountRepositoryProtocol: Sendable { ... }
public protocol TransactionRepositoryProtocol: Sendable { ... }
public protocol WealthAccountRepositoryProtocol: Sendable { ... }
public protocol BudgetRepositoryProtocol: Sendable { ... }
public protocol PortfolioRepositoryProtocol: Sendable { ... }
public protocol ChatRepositoryProtocol: Sendable { ... }
```

A **composite protocol** combines auth-related protocols for convenience:

```swift
public protocol AuthRepositoryProtocol:
    AuthenticationRepositoryProtocol,
    ProfileRepositoryProtocol,
    OTPRepositoryProtocol,
    AccountRepositoryProtocol,
    Sendable { }
```

**Why protocols live in Core:** This is Inversion of Control — feature packages provide concrete implementations (e.g., `AuthRepository: AuthRepositoryProtocol`) while only depending on the protocol defined here. The App Target's `DependencyContainer` wires concrete to abstract.

## 3.5 Network Layer

### HTTPClientProtocol

```swift
public protocol HTTPClientProtocol: Sendable {
    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?,
        headers: [String: String]?,
        version: String?,
        retryOn401: Bool,
        extendedTimeout: Bool
    ) async throws -> T
}
```

Convenience overloads default `body` to `nil`, `headers` to `nil`, `version` to `nil`, `retryOn401` to `true`, and `extendedTimeout` to `false`. The overload chain: 2-param → 3-param → 5-param → 6-param → 7-param (full).

### APIClient Actor

The `APIClient` is the **sole HTTP engine** in the app (enforced by the `no_url_session` lint rule). Key behaviors:

```
Request Flow:
┌──────────┐     ┌───────────┐     ┌──────────────┐     ┌──────────┐
│  Caller  │ ──▶ │ APIClient │ ──▶ │  URLSession  │ ──▶ │  Server  │
└──────────┘     └─────┬─────┘     └──────────────┘     └──────────┘
                       │
                 ┌─────▼─────┐
                 │ On 401:   │
                 │ Refresh   │──▶ Single-flight token refresh
                 │ & Retry   │    (concurrent 401s share one refresh)
                 └───────────┘
```

1. **Auth injection** — Reads access token from `TokenStoreProtocol`, adds `Authorization: Bearer` header
2. **401 retry** — On unauthorized response, triggers a single-flight token refresh (via `refreshTask` deduplication), then retries the original request exactly once
3. **Extended timeout** — AI chat endpoints use 120s timeout instead of the default 30s
4. **Error parsing** — Tries `ProblemDetail` first, falls back to `ApiResponse<EmptyResponse>`, then raw status code
5. **Empty body handling** — Uses `AnyOptional` protocol to detect `Optional<T>` return types and skip decoding for 204/empty responses

### ChatRepository

Actor implementing `ChatRepositoryProtocol` via `HTTPClientProtocol`. Lives in the **App Target** (`FinFlowIos/Core/DI/ChatRepository.swift`) — not in FinFlowCore — following the same pattern as all other concrete repositories (e.g., `TransactionRepository` in `Transaction/Data/`, `BudgetRepository` in `Planning/Data/`). FinFlowCore only contains the `ChatRepositoryProtocol` (in `Domain/RepositoryProtocols.swift`). Provides full CRUD for chat threads: `createThread`, `listThreads`, `listMessages`, `sendMessage`, and `deleteThread`. Uses `PageResponse<T>` to decode Spring Boot paginated responses for thread/message lists.

## 3.6 State Management

### SessionState

Seven-case enum representing the authentication state machine:

```swift
public enum SessionState: Equatable, Sendable {
    case loading                                                          // App launch, checking stored tokens
    case authenticated(token: String, isRestored: Bool = false)           // Valid session, show dashboard
    case unauthenticated                                                  // No session, show login
    case welcomeBack(email: String, firstName: String?, lastName: String?) // Returning user with expired session
    case refreshing                                                       // Token refresh in progress
    case sessionExpired(email: String, firstName: String?, lastName: String?) // Refresh failed, must re-authenticate
    case locked(user: UserProfile, biometricAvailable: Bool)              // PIN/biometric lock active
}
```

### SessionManager

`@MainActor @Observable` class — the central auth state machine. Key responsibilities:

| Method | Behavior |
|--------|----------|
| `restoreSession()` | On app launch: check stored tokens → try refresh → set state |
| `login(response:)` | Store tokens + user profile → `.authenticated` |
| `logout()` | Soft logout → `.unauthenticated` (keeps some data) |
| `completeLogout()` | Full logout → clear all keychain + defaults |
| `refreshSession()` | Refresh access token; cancels any in-flight refresh first |
| `lockSession()` | → `.locked` |
| `unlockSession()` | → `.authenticated` |
| `authenticateWithPIN(pin:)` | Verify PIN via `PINManager` → unlock or increment failure |

The `AppRouter` (in the App Target) observes `SessionManager.state` via `withObservationTracking` and automatically transitions the root view.

## 3.7 Storage Layer

### Storage Strategy

| Data | Store | Why |
|------|-------|-----|
| Access token | Keychain | Sensitive credential |
| Refresh token | Keychain | Sensitive credential |
| PIN hash | Keychain | Security-critical |
| PIN fail count | Keychain | Tamper-resistant counter |
| User profile | UserDefaults | Non-sensitive, fast read |
| Refresh token expiry | UserDefaults | Used for welcomeBack detection |
| API response cache | File system (Library/Caches) | Large, purgeable by OS |

### KeychainService

Actor wrapping the Security framework. All items use `kSecAttrAccessibleWhenUnlocked` — data is only available when the device is unlocked.

```swift
actor KeychainService {
    func save(_ data: Data, forKey key: String) throws
    func load(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
}
```

### AuthTokenStore

Actor implementing `TokenStoreProtocol`. Bridges typed token operations to `KeychainService`:

```swift
public protocol TokenStoreProtocol: Sendable {
    func getAccessToken() async -> String?
    func getRefreshToken() async -> String?
    func saveTokens(accessToken: String, refreshToken: String) async throws
    func clearTokens() async throws
}
```

Uses `KeychainKey` enum for type-safe key management: `.accessToken`, `.refreshToken`, `.pinHash`, `.pinFailCount`.

### UserDefaultsManager

Actor for non-sensitive data. Stores:
- User profile (JSON encoded)
- Refresh token expiry date (for `welcomeBack` state detection)

### FileCacheService

Actor implementing `CacheServiceProtocol`. Caches API responses to `Library/Caches/` (automatically purged by iOS under storage pressure). Uses `CacheKey` enum for type-safe cache identifiers.

## 3.8 Security

### PINManager

Actor managing PIN lifecycle:

```swift
actor PINManager: PINManagerProtocol {
    func setPIN(_ pin: String) async throws       // SHA-256 hash → Keychain
    func verifyPIN(_ pin: String) async throws -> Bool
    func hasPIN() async -> Bool
    func removePIN() async throws
    func getFailedAttempts() async -> Int
    func incrementFailedAttempts() async throws
    func resetFailedAttempts() async throws
}
```

- **Hashing:** SHA-256 via CryptoKit (never stores plaintext)
- **Lockout:** After 5 failed attempts, clears all tokens (forces full re-authentication)

### BiometricAuthHandler

Wraps `LAContext` from LocalAuthentication:

```swift
public protocol BiometricVerifying: Sendable {
    func canUseBiometrics() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
```

### OTPInputHandler

Actor handling OTP entry validation and server communication:
- Validates 6-digit format
- Sends OTP via `OTPRepositoryProtocol`
- Verifies OTP via `OTPRepositoryProtocol`

## 3.9 Navigation Types

All navigation types live in `NavigationTypes.swift`:

### AppRoot (5 cases)

```swift
public enum AppRoot: Sendable {
    case splash
    case authentication
    case welcomeBack
    case dashboard
    case locked
}
```

### AppTab (5 cases)

```swift
public enum AppTab: Int, CaseIterable, Sendable {
    case home = 0
    case transaction
    case planning
    case wealth
    case investment
}
```

### AppRoute (17 cases)

```swift
public enum AppRoute: Hashable, Sendable {
    // MARK: - Authentication Flow
    case login
    case register
    case forgotPassword

    // MARK: - Main Flow
    case dashboard
    case profile
    case settings
    case transactionDetail(id: String)
    case updateProfile(UserProfile)
    case changePassword(hasPassword: Bool)
    case createPIN(email: String)
    case addTransaction
    case editTransaction(TransactionResponse)
    case categoryList
    case addBudget
    case editBudget(BudgetResponse)

    /// Thread list — shows all chat conversations.
    case chatThreadList

    /// Chat with FinFlow Bot. threadId nil = auto-create new thread.
    case finFlowBotChat(threadId: String? = nil, initialPrompt: String? = nil)
}
```

`AppRoute` also conforms to `Identifiable` via an extension that returns a stable, human-readable `id` string for each case — safe for SwiftUI `sheet(item:)` and `List` diffing.

### AppRouterProtocol

```swift
@MainActor
public protocol AppRouterProtocol: AnyObject {
    var activeTab: AppTab { get set }
    var homePath: [AppRoute] { get set }
    var transactionPath: [AppRoute] { get set }
    var planningPath: [AppRoute] { get set }
    var wealthPath: [AppRoute] { get set }
    var investmentPath: [AppRoute] { get set }
    var authPath: [AppRoute] { get set }

    var root: AppRoot { get }
    var presentedSheet: AppRoute? { get set }

    func navigate(to route: AppRoute)
    func pop()
    func popToRoot()
    func replacePath(with routes: [AppRoute])
    func navigateToDeepLink(_ routes: [AppRoute])
    func presentSheet(_ route: AppRoute)
    func dismissSheet()
    func selectTab(_ tab: AppTab)
}
```

## 3.10 Design System Tokens

### Spacing & Layout

| Token | Value | Usage |
|-------|-------|-------|
| `Spacing.xs` | 8pt | Tight spacing, icon gaps |
| `Spacing.sm` | 16pt | Standard padding |
| `Spacing.md` | 20pt | Section padding |
| `Spacing.lg` | 32pt | Section separators |
| `Spacing.xl` | 40pt | Hero spacing |
| `Spacing.iconSmall` | 24pt | Small icon frames |
| `Spacing.iconMedium` | 32pt | Medium icon frames |
| `Spacing.touchTarget` | 44pt | iOS minimum touch target |

Also in `Spacing.swift`:

| Enum | Tokens |
|------|--------|
| `CornerRadius` | `.micro` (6), `.small` (12), `.medium` (16), `.large` (20), `.pill` (100) |
| `BorderWidth` | `.hairline` (0.5), `.thin` (1), `.medium` (2), `.thick` (3) |
| `OpacityLevel` | `.ultraLight` (0.1) through `.high` (0.8) — 6 levels |
| `AnimationTiming` | `.fast`, `.normal`, `.slow` — standard durations |
| `ShadowStyle` | `.subtle`, `.medium`, `.strong` — shadow configurations |

### AppColors (~40 tokens)

| Category | Tokens |
|----------|--------|
| **Brand** | `primary` |
| **Semantic** | `success`, `error`, `accent`, `disabled`, `textInverted` |
| **Social** | `google`, `apple`, `expense`, `destructive` |
| **UI** | `overlayBackground`, `inputBorderDefault`, `glassBorder`, `glassBorderFocused`, `errorBorder`, `buttonDisabled`, `settingsCardBackground` |
| **Backgrounds** | `appBackground`, `cardBackground` |
| **Charts** | `chartGridLine`, `chartRevenue`, `chartProfit`, 9× `chartAsset*`, 7× `chartCapital*`, etc. |

### AppTypography (~20 tokens)

| Category | Tokens |
|----------|--------|
| **Display** | `displayXL`, `largeTitle`, `displayLarge`, `displayMedium`, `title`, `displaySmall`, `displayCaption`, `iconMedium` |
| **System Scaled** | `headline`, `subheadline`, `body`, `caption`, `caption2`, `buttonTitle` |
| **Specialty** | `icon`, `pinDigit`, `profileStat`, `labelSmall` |

### UILayout

Fixed dimensions used across the app:

```swift
public enum UILayout {
    public static let smallIcon: CGFloat = 20
    public static let mediumIcon: CGFloat = 28
    public static let profileImageSize: CGFloat = 80
    public static let pinDotSize: CGFloat = 14
    // ... ~15 constants
}
```

### AppAssets

Centralized SF Symbol names and image asset references:

```swift
public enum AppAssets {
    // SF Symbols
    public static let home = "house.fill"
    public static let transaction = "arrow.left.arrow.right"
    // ... tab icons, action icons, category icons

    // Image assets
    public static let appLogo = "app_logo"
    // ...
}
```

## 3.11 Design System Components

### Button Styles

Two button styles with consistent behavior:

| Style | Appearance | Loading State |
|-------|-----------|---------------|
| `PrimaryButtonStyle` | Gradient fill, full width, rounded | Built-in `ProgressView` |
| `TextButtonStyle` | Plain text, accent color | — |

Usage via View extensions:

```swift
Button("Sign In") { ... }
    .primaryButton(isLoading: viewModel.isLoading)

Button("Cancel") { ... }
    .textButton()
```

### GlassField

Glassmorphism text field with:
- Leading icon (SF Symbol)
- Focus state animation (border color transition)
- Secure mode toggle (password visibility)
- Error state display

### EmptyStateView

Reusable empty state with:
- SF Symbol icon
- Title + subtitle
- Optional CTA button

### FinancialHeroCard

Generic `<Content: View>` card with dark brand-colored background, ultra-thin material overlay for glass effect, and gradient border highlight. Used as the focal point in Budget and Transaction screens.

### LoadingOverlay

`.loadingOverlay(isLoading:)` — full-screen semi-transparent overlay with centered `ProgressView`.

## 3.12 Error Handling Pipeline

The error handling system is a four-stage pipeline:

```
Error (any Swift Error)
    │
    ▼
AppError (6 cases — normalized domain error)
    │  Error.toAppAlert()
    ▼
AppErrorAlert (7 cases — UI-ready alert model)
    │  Error.toHandledAlert(sessionManager:)
    ▼
Handled alert (auto-ignores CancellationError, auto-clears on 401)
    │  .alertHandler() modifier
    ▼
SwiftUI Alert (with haptic feedback + logging)
```

### Stage 1: AppError

Raw errors are caught and wrapped into `AppError` cases by the network layer or use cases.

### Stage 2: AppErrorAlert

Maps `AppError` to a UI-ready alert with title, message, and button configuration:

```swift
public enum AppErrorAlert: AppAlert, Equatable, Sendable, Identifiable {
    case network(onRetry: @Sendable () -> Void)
    case general(title: String, message: String)
    case auth(message: String)
    case authWithAction(message: String, onOK: @Sendable () -> Void)
    case data(message: String)
    case validation(message: String)
    case success(message: String, onOK: @Sendable () -> Void)
}
```

Each case provides a `title`, `subtitle`, and `buttons` (action buttons for the alert). The `alertType` property (`.error`, `.warning`, `.info`, `.success`) determines the haptic feedback pattern. The `isUnauthorized` property returns `true` for `.auth` and `.authWithAction` cases, allowing callers to reset loading state before displaying session-expired alerts.

### Stage 3: Handled Alert

`Error.toHandledAlert(sessionManager:)` adds smart behavior:
- **Ignores `CancellationError`** — no alert for cancelled tasks
- **Auto-clears session on 401** — calls `sessionManager.clearSessionDueToUnauthorized()`

### Stage 4: View Modifier

`.alertHandler()` renders the alert and triggers appropriate haptic feedback:

```swift
SomeView()
    .alertHandler()
```

## 3.13 Shared Use Cases

FinFlowCore contains a few use cases that exist for **cross-module data aggregation** on the Home screen:

| Use Case | Repository Protocol | Purpose |
|----------|-------------------|---------|
| `GetWealthAccountsUseCase` | `WealthAccountRepositoryProtocol` | Home: net worth summary |
| `GetBudgetsUseCase` | `BudgetRepositoryProtocol` | Home: budget overview |
| `GetPortfoliosUseCase` | `PortfolioRepositoryProtocol` | Home: portfolio summary |
| `GetPortfolioAssetsUseCase` | `PortfolioRepositoryProtocol` | Home: asset breakdown |

These are simple passthrough structs:

```swift
public struct GetBudgetsUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [BudgetWithSpending] {
        try await repository.getBudgets()
    }
}
```

Additionally, `GetCategoriesUseCaseProtocol` is defined here as a protocol (implemented by the Transaction package) so other modules can access transaction categories.

## 3.14 Utilities

### CurrencyFormatter

Static enum for Vietnamese Dong (₫) formatting:

| Method | Example Input | Example Output |
|--------|--------------|----------------|
| `format(_:)` | `150000.0` | `"150.000 ₫"` |
| `formatWithSign(_:isIncome:)` | `150000.0, true` | `"+ 150.000 ₫"` |
| `formatBalance(_:)` | `-50000.0` | `"- 50.000 ₫"` |
| `formatInput(_:)` | `"150000"` | `"150.000"` |
| `parseCurrencyInput(_:)` | `"1.500.000"` | `1500000.0` |
| `formatAxisValue(_:)` | `1500000` | `"1.5M"` |
| `formatQuantity(_:)` | `12345.0` | `"12.345"` |

Uses `.` as grouping separator (Vietnamese locale convention).

### Logger

Static enum wrapping `os.Logger`, active only in `DEBUG` builds:

```swift
Logger.info("User authenticated", category: "Auth")
Logger.debug("Cache hit for key: \(key)", category: "Cache")
Logger.error("Failed to fetch: \(error)", category: "Network")
```

Also provides `logAPIRequest` and `logAPIResponse` for network debugging.

## 3.15 Configuration

### NetworkConfig

```swift
public protocol NetworkConfigProtocol: Sendable {
    var baseURL: String { get }
    var apiVersion: String { get }
}

public struct NetworkConfig: NetworkConfigProtocol, Sendable {
    public let baseURL: String
    public let apiVersion: String
}
```

The App Target's `AppConfig` provides the concrete values (dev vs prod base URL).

---

*Previous: [Chapter 2 — Architecture Rules](./02-architecture-rules.md)*
*Next: [Chapter 4 — App Target Composition](./04-app-target.md)*
