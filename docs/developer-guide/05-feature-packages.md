# Chapter 5 — Feature Packages

## 5.1 Package Inventory

FinFlow ships **7 feature packages** under `Packages/`. Each is a standalone Swift Package with its own `Package.swift`, depending only on `FinFlowCore` (and optionally on third-party SDKs — never on another feature package).

| Package | Screens | External Deps | Tests |
|---------|---------|---------------|-------|
| **Identity** | Login, Register, ForgotPassword, WelcomeBack, LockScreen, ChangePassword, UpdateProfile | GoogleSignIn | ✅ |
| **Dashboard** | MainTabView, HomeView | — | ❌ |
| **Transaction** | TransactionList, AddTransaction, CategoryList, TransactionAnalytics | — | ✅ |
| **Planning** | PlanningView, BudgetList, AddBudget | — | ❌ |
| **Investment** | InvestmentView, StockAnalysis, PortfolioView, CreatePortfolio, AddStockTrade, ImportSnapshot | — | ❌ |
| **Wealth** | WealthList, AddWealthAccount | — | ❌ |
| **Profile** | ProfileView, CreatePIN, AccountManagement, SecuritySettings | — | ❌ |

> Only **Identity** and **Transaction** have unit tests (UseCase-level).

## 5.2 Package Manifest Pattern

Every feature package follows the same `Package.swift` template:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Transaction",          // ← feature name
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Transaction", targets: ["Transaction"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")   // ← always relative path
    ],
    targets: [
        .target(
            name: "Transaction",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        ),
        .testTarget(                        // ← optional
            name: "TransactionTests",
            dependencies: [
                "Transaction",
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ],
            path: "Tests/TransactionTests"
        )
    ]
)
```

**Rule:** Feature packages depend **only** on `FinFlowCore`. The sole exception is Identity, which additionally depends on `GoogleSignIn-iOS` for Google OAuth.

## 5.3 Internal Directory Structure

All feature packages follow a three-layer Clean Architecture layout:

```
Sources/<PackageName>/
├── Data/
│   └── <Feature>Repository.swift       ← actor, conforms to FinFlowCore protocol
├── Domain/
│   └── UseCases/
│       ├── Get<Entity>UseCase.swift     ← query use cases
│       ├── Create<Entity>UseCase.swift  ← command use cases
│       ├── Update<Entity>UseCase.swift
│       └── Delete<Entity>UseCase.swift
└── Presentation/
    ├── Components/                      ← reusable sub-views within the feature
    ├── Extensions/                      ← feature-specific extensions (rare)
    ├── Services/                        ← platform bridges (camera, speech, etc.)
    ├── Utils/                           ← feature-specific utilities
    ├── ViewModels/
    │   └── <Screen>ViewModel.swift      ← @MainActor @Observable
    └── Views/
        └── <Screen>View.swift           ← SwiftUI View with @Bindable
```

**Not every package uses every folder.** Dashboard has no `Data/` or `Domain/` layers — its `HomeViewModel` receives a pre-built service from the app target's DI container. Investment adds a `Domain/` level for local models and protocols that don't belong in FinFlowCore.

## 5.4 Data Layer — Actor-Based Repositories

Repositories are the **only** types that touch the network. Most are implemented as Swift `actor`s for thread safety (exception: `AuthRepository` is a `final class: Sendable`):

```swift
public actor TransactionRepository: TransactionRepositoryProtocol {
    private let client: any HTTPClientProtocol

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getTransactions(
        page: Int, pageSize: Int,
        startDate: Date?, endDate: Date?,
        keyword: String?
    ) async throws -> PaginatedResponse<TransactionItem> {
        let endpoint = buildEndpoint(page: page, pageSize: pageSize, ...)
        return try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }
}
```

Key patterns:
- **Protocol lives in FinFlowCore** (`RepositoryProtocols.swift`) — the feature package provides the concrete implementation
- **`HTTPClientProtocol`** is the sole network dependency, injected via init
- **Generic `client.request<T: Decodable>()`** for all API calls — no manual `URLSession` usage
- **Query building** via `URLComponents` for endpoints with filters/pagination
- Some repositories (e.g., `AuthRepository`) add **caching** via `CacheServiceProtocol`

### Repository Inventory

| Package | Repository | Isolation |
|---------|-----------|-----------|
| Identity | `AuthRepository` | `final class: Sendable` (+ optional cache + token store) |
| Transaction | `TransactionRepository` | `actor` |
| Planning | `BudgetRepository` | `actor` |
| Investment | `InvestmentRepository`, `PortfolioRepository` | `actor` |
| Wealth | `WealthAccountRepository` | `actor` |
| Dashboard | — (uses `HomeDashboardServiceImpl` from app target) | — |
| Profile | — (uses `AuthRepository` from Identity via protocol) | — |

## 5.5 Domain Layer — Use Cases

Use cases are **struct**s conforming to `Sendable`. Each use case represents a single business operation:

```swift
public protocol AddTransactionUseCaseProtocol: Sendable {
    func execute(
        type: String, amount: String, categoryId: Int,
        description: String, date: Date, wealthAccountId: Int?
    ) async throws -> TransactionItem
}

public struct AddTransactionUseCase: AddTransactionUseCaseProtocol {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(...) async throws -> TransactionItem {
        // 1. Validate + sanitize input
        guard let parsedAmount = CurrencyFormatter.parseCurrencyInput(amount),
              parsedAmount > 0 else {
            throw AppError.validationError("Invalid amount")
        }
        // 2. Format data for API
        let isoDate = ISO8601DateFormatter.fractional.string(from: date)
        // 3. Delegate to repository
        return try await repository.addTransaction(...)
    }
}
```

**Responsibilities:**
- **Input validation** — empty checks, format parsing, range validation
- **Data transformation** — currency parsing via `CurrencyFormatter`, date formatting
- **No UI concerns** — use cases know nothing about views or navigation

### Use Case Count by Package

| Package | Use Cases | Examples |
|---------|-----------|---------|
| Identity | 5 | Login, Register, ForgotPassword, ChangePassword, UpdateProfile |
| Transaction | 12 | AddTransaction, GetTransactions, GetSummary, GetChart, AnalyzeText, CRUD categories, … |
| Planning | 3 | CreateBudget, UpdateBudget, DeleteBudget |
| Investment | 8 | GetStockAnalysis, CreatePortfolio, CreateTradeTransaction, GetPortfolioHealth, … |
| Wealth | 4 | CreateWealthAccount, UpdateWealthAccount, DeleteWealthAccount, GetWealthAccountTypes |
| Profile | 2 | GetProfile, AccountManagement |
| Dashboard | 0 | (data aggregation handled by app-target service) |

## 5.6 Presentation Layer — ViewModels

Every ViewModel follows the same formula:

```swift
@MainActor
@Observable
final class BudgetListViewModel {
    // — Dependencies (injected via init) —
    private let router: any AppRouterProtocol
    private let deleteBudgetUseCase: any DeleteBudgetUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol

    // — Published state —
    var budgets: [BudgetItem] = []
    var isLoading = false
    var alert: AppErrorAlert?

    // — Load guard —
    private var hasRequestedInitialLoad = false

    func loadBudgets() async {
        guard !hasRequestedInitialLoad else { return }
        hasRequestedInitialLoad = true
        isLoading = true
        do {
            budgets = try await getBudgetsUseCase.execute()
        } catch {
            alert = error.toHandledAlert(sessionManager: sessionManager)
        }
        isLoading = false
    }
}
```

### Common ViewModel Patterns

| Pattern | Description |
|---------|-------------|
| **`@MainActor @Observable`** | All ViewModels — Swift Observation, not Combine |
| **`hasRequestedInitialLoad`** | Guard against duplicate `.task` calls on view reappear |
| **`isLoading` + concurrent guard** | Prevents parallel loads: `guard !isLoading else { return }` |
| **`AppErrorAlert?`** | Unified error alert state, consumed by `.alertHandler()` modifier |
| **`error.toHandledAlert(sessionManager:)`** | Auto-maps errors; 401 triggers session clear |
| **Router navigation** | `router.navigate(to:)`, `router.presentSheet()`, `router.dismissSheet()` |
| **`NotificationCenter` for cross-module** | e.g., `.transactionDidSave` triggers reload in other features |

### Advanced Patterns

**Pagination** (TransactionListViewModel):
```swift
func loadMore() async {
    guard !isLoadingMore, hasMorePages else { return }
    isLoadingMore = true
    currentPage += 1
    let result = try await getTransactionsUseCase.execute(page: currentPage, ...)
    transactions.append(contentsOf: result.items)
    hasMorePages = result.hasNextPage
    isLoadingMore = false
}
```

**Search debounce** (TransactionListViewModel):
```swift
// 500ms debounce on search text changes
private var searchTask: Task<Void, Never>?

func onSearchTextChanged(_ text: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        await performSearch(keyword: text)
    }
}
```

**Race condition protection** (chart loading):
```swift
private var currentRequestId = UUID()

func loadChart() async {
    let requestId = UUID()
    currentRequestId = requestId
    let data = try await getChartUseCase.execute(...)
    guard currentRequestId == requestId else { return }  // ← stale response
    chartData = data
}
```

## 5.7 Presentation Layer — Views

Views are thin SwiftUI structs that bind to ViewModels via `@Bindable`:

```swift
public struct TransactionListView: View {
    @Bindable var viewModel: TransactionListViewModel

    public var body: some View {
        List { ... }
            .task { await viewModel.loadTransactions() }
            .searchable(text: $viewModel.searchText)
            .alertHandler(alert: $viewModel.alert)
            .loadingOverlay(isLoading: viewModel.isLoading)
    }
}
```

### View Conventions

| Convention | Example |
|-----------|---------|
| **`@Bindable var viewModel`** | View never creates its own ViewModel — always injected |
| **`.task { }`** | Async data loading on appear |
| **`.alertHandler()`** | FinFlowCore modifier for unified error alerts |
| **`.loadingOverlay()`** | FinFlowCore modifier for full-screen loading |
| **`.onReceive(NotificationCenter...)`** | Cross-module event handling |
| **Design tokens only** | `AppColors.primary`, `Spacing.md`, `AppTypography.bodyMedium` — no magic numbers |
| **No business logic** | Views call ViewModel methods, never repositories/use cases directly |

## 5.8 Package Deep-Dives

### Identity

The most complex package — handles the full authentication lifecycle:

```
Identity/
├── Data/
│   └── AuthRepository.swift              ← login, register, OAuth, OTP, biometric, token refresh
├── Domain/UseCases/
│   ├── LoginUseCase.swift                ← email/password + Google OAuth
│   ├── RegisterUseCase.swift
│   ├── ForgotPasswordUseCase.swift       ← OTP-based password reset
│   ├── ChangePasswordUseCase.swift
│   ├── UpdateProfileUseCase.swift
│   └── DOBFormatter.swift                ← date-of-birth formatting utility
├── Presentation/
│   ├── Components/
│   │   ├── AppLogoHeader.swift           ← shared branding header
│   │   ├── BiometricAuthService.swift    ← SessionBiometricAuthCoordinator
│   │   ├── EmailFieldWithOTP.swift       ← email input + OTP trigger
│   │   ├── SocialLoginButton.swift       ← Google sign-in button
│   │   └── WelcomeHeaderView.swift
│   ├── ViewModels/
│   │   ├── LoginViewModel.swift          ← biometric login, Google OAuth, PIN check
│   │   ├── RegisterViewModel.swift
│   │   ├── ForgotPasswordViewModel.swift
│   │   ├── WelcomeBackViewModel.swift    ← PIN entry, biometric, forgot-PIN flow
│   │   ├── LockScreenViewModel.swift     ← simplified PIN/biometric unlock
│   │   ├── ChangePasswordViewModel.swift
│   │   └── UpdateProfileViewModel.swift
│   └── Views/ (mirrors ViewModels 1:1, plus RegisterFormSection helper view)
```

**Unique patterns in Identity:**
- **`SessionBiometricAuthCoordinator`** (in `BiometricAuthService.swift`) — coordinator pattern: (1) check device support → (2) check user setting → (3) verify biometrics → (4) refresh token silently → (5) finalize session
- **PIN fail counter** — increments on wrong PIN, calls `logoutCompletely()` on max attempts
- **Biometric attempt cap** — 3 failed attempts → fallback to PIN entry
- **Forgot-PIN branching** — password users verify password; social-login users verify via OTP
- **Google Sign-In bridging** — View handles `GIDSignIn` UIKit presentation, extracts `idToken`, passes to ViewModel

### Dashboard

The thinnest package — primarily a **shell for tab navigation**:

```
Dashboard/
└── Presentation/
    ├── ViewModels/
    │   └── HomeViewModel.swift           ← single service dependency, 20s timeout
    └── Views/
        ├── Home/
        │   ├── HomeView.swift            ← error/content/loading states
        │   ├── HomeDashboardContentView.swift
        │   └── HomeErrorStateView.swift
        └── Main/
            └── MainTabView.swift         ← generic over 5 tab content views
```

**Why no Data/Domain layers?** Dashboard aggregates data from multiple features (transactions, budgets, wealth accounts, portfolios). The aggregation service (`HomeDashboardServiceImpl`) lives in the **app target** because it crosses feature boundaries. Dashboard only receives the pre-built result.

**`MainTabView`** is generic over its tab content views — the app target injects concrete views at composition time. Each tab wraps content in its own `NavigationStack(path:)` with a shared `destinationFactory`.

### Transaction

The feature-richest package with 12 use cases:

```
Transaction/
├── Data/
│   └── TransactionRepository.swift       ← CRUD + summary + analytics + charts
├── Domain/
│   ├── TransactionDateParser.swift       ← date parsing utility
│   └── UseCases/                         ← 12 use cases (CRUD, categories, analytics, charts, AnalyzeText)
├── Presentation/
│   ├── Components/
│   │   ├── AISmartInputBar.swift         ← AI-powered transaction input (moved from FinFlowCore)
│   │   └── AccountSelectionSheet.swift   ← wealth account picker (moved from FinFlowCore)
│   ├── Services/
│   │   ├── CameraImagePicker.swift       ← UIKit camera bridge for receipt scanning
│   │   ├── ReceiptOCRService.swift       ← Vision framework OCR
│   │   └── SpeechToTextManager.swift     ← Speech recognition for voice input
│   ├── ViewModels/
│   │   ├── TransactionListViewModel.swift ← pagination, search debounce, chart nav, race protection
│   │   ├── AddTransactionViewModel.swift  ← multi-input (manual, camera, voice)
│   │   ├── CategoryListViewModel.swift
│   │   └── TransactionInputAssistant.swift ← AI text analysis helper
│   └── Views/                             ← list, add/edit, analytics with charts
└── Tests/ ← 9 use-case test files + 1 mock repository
```

**Unique patterns:**
- **Platform services** — `CameraImagePicker` (UIKit bridge), `ReceiptOCRService` (Vision OCR), `SpeechToTextManager` (Speech framework)
- **Vietnamese locale grouping** — transactions grouped by date with "Hôm nay", "Hôm qua" labels
- **Cross-module notifications** — posts `.transactionDidSave` for other features to react
- **AI analytics fallback** — local insight generation when server-side AI analytics fails

### Investment

The largest package by file count (57 files), heavily focused on **financial charting**:

```
Investment/
├── Data/
│   ├── InvestmentRepository.swift        ← stock analysis, financial series, suggestions
│   └── PortfolioRepository.swift         ← portfolio CRUD, health, benchmark
├── Domain/
│   ├── Models/
│   │   ├── InvestmentModels.swift        ← local domain models (not in FinFlowCore)
│   │   └── InvestmentAnalysisBundle.swift ← aggregated analysis data
│   ├── InvestmentRepositoryProtocol.swift ← local protocol (complex enough to warrant isolation)
│   └── UseCases/                          ← 8 use cases
├── Presentation/
│   ├── Components/
│   │   ├── Charts/                       ← 22 chart files (bar, donut, line, stacked, valuation)
│   │   │   ├── FinancialCharts*.swift    ← modular chart builders (bank vs non-bank)
│   │   │   ├── Interactive*Chart.swift   ← interactive chart variants
│   │   │   ├── Valuation*.swift          ← P/E, P/B valuation charts
│   │   │   └── ProportionDonutChart.swift
│   │   ├── CompanyInfoCard.swift
│   │   ├── DividendHistoryTable.swift
│   │   ├── MobileInsightSnapshot.swift
│   │   └── SymbolSuggestionsList.swift
│   ├── ViewModels/
│   │   ├── StockAnalysisViewModel.swift  ← multi-tab analysis (overview, financials, valuation)
│   │   ├── InvestmentPortfolioViewModel.swift
│   │   ├── AddTradeViewModel.swift       ← stock trade entry
│   │   ├── ImportSnapshotViewModel.swift  ← portfolio snapshot import
│   │   └── ValuationChartGroupViewModel.swift ← valuation chart state
│   └── Views/                             ← analysis, portfolio, trade sheets
```

**Unique patterns:**
- **Local domain models** — `InvestmentModels.swift` and `InvestmentRepositoryProtocol.swift` live inside the package (too complex/specific for FinFlowCore)
- **DTO-to-domain mapping** — `InvestmentRepository` maps `InvestmentAnalysisDTO` → `InvestmentAnalysisBundle` internally
- **Bank vs. non-bank branching** — chart builders split into separate files by company type
- **Chart component architecture** — 22 specialized chart files in `Charts/` subfolder using Swift Charts, with shared helpers for formatting and interaction. Non-chart components (CompanyInfoCard, DividendHistoryTable, etc.) remain in `Components/`

### Planning

A straightforward CRUD package for budget management:

```
Planning/
├── Data/
│   └── BudgetRepository.swift            ← CRUD (getBudgets, create, update, delete)
├── Domain/UseCases/
│   ├── CreateBudgetUseCase.swift          ← currency parse + date format (yyyy-MM-dd)
│   ├── UpdateBudgetUseCase.swift
│   └── DeleteBudgetUseCase.swift
└── Presentation/
    ├── ViewModels/
    │   ├── BudgetListViewModel.swift      ← computed totals (totalBudget, totalSpent, progress)
    │   └── AddBudgetViewModel.swift
    └── Views/
        ├── PlanningView.swift             ← entry point
        ├── BudgetListView.swift
        └── AddBudgetView.swift
```

**Note:** Date format is `yyyy-MM-dd` (not ISO8601 with fractional seconds like Transaction). This matches the backend API contract for budgets.

### Wealth

Manages financial account tracking (bank accounts, e-wallets, cash):

```
Wealth/
├── Data/
│   └── WealthAccountRepository.swift     ← CRUD + account types lookup
├── Domain/UseCases/
│   ├── CreateWealthAccountUseCase.swift
│   ├── UpdateWealthAccountUseCase.swift
│   ├── DeleteWealthAccountUseCase.swift
│   └── GetWealthAccountTypesUseCase.swift
└── Presentation/
    ├── ViewModels/
    │   ├── AddWealthAccountViewModel.swift
    │   └── WealthListViewModel.swift     ← wealth account list state
    └── Views/
        ├── WealthListView.swift
        ├── WealthAccountSectionList.swift
        └── AddWealthAccountView.swift
```

### Profile

User settings, PIN management, and account security:

```
Profile/
├── Domain/UseCases/
│   ├── GetProfileUseCase.swift           ← fetches user profile
│   └── AccountManagementUseCase.swift    ← account deletion
└── Presentation/
    ├── Components/
    │   ├── SettingsRowIcon.swift
    │   └── CreatePINWelcomeView.swift
    ├── ViewModels/
    │   ├── ProfileViewModel.swift        ← profile display + settings navigation
    │   ├── CreatePINViewModel.swift      ← PIN creation/update flow
    │   ├── SecuritySettingsViewModel.swift ← biometric toggle, PIN management
    │   └── AccountManagementViewModel.swift ← account deletion
    └── Views/
        ├── ProfileView.swift
        ├── ProfileSettingsListContent.swift
        ├── ProfileLoadStateViews.swift
        └── CreatePINView.swift
```

**Note:** Profile has **no Data layer** — it reuses `AuthRepository` from Identity via the `AuthRepositoryProtocol` defined in FinFlowCore. The protocol is injected by the app target's DI container.

## 5.9 Cross-Cutting Patterns Summary

| Layer | Type | Concurrency | Key Pattern |
|-------|------|-------------|-------------|
| Data | `actor` or `final class: Sendable` | Actor isolation / Sendable | `HTTPClientProtocol.request<T>()` |
| Domain | `struct` | `Sendable` | Protocol + concrete struct, input validation |
| ViewModel | `final class` | `@MainActor @Observable` | Load guard, error-to-alert mapping, router navigation |
| View | `struct` | `@MainActor` (implicit) | `@Bindable`, `.task {}`, `.alertHandler()`, design tokens |

### Dependency Flow

```
View (@Bindable) → ViewModel (@Observable)
    ViewModel → UseCase (protocol)
        UseCase → Repository (protocol)
            Repository → HTTPClient (FinFlowCore)
```

**All protocols live in FinFlowCore. All concrete implementations live in feature packages (or the app target for cross-feature services).** This is what enables feature isolation — packages never import each other.

## 5.10 Testing Strategy

Only **Identity** and **Transaction** have tests, both at the **UseCase level**:

```
Tests/
└── <Feature>Tests/
    ├── Mocks/
    │   └── Mock<Feature>Repository.swift   ← hand-written mock conforming to protocol
    └── UseCases/
        └── <UseCase>Tests.swift            ← async test methods
```

```swift
// Example: LoginUseCaseTests
@Test func loginSuccess() async throws {
    let mockRepo = MockAuthRepository()
    mockRepo.loginResult = .success(LoginResponse(...))
    let useCase = LoginUseCase(repository: mockRepo)

    let result = try await useCase.execute(username: "test@email.com", password: "pass123")
    #expect(result.accessToken == "mock-token")
}
```

**Pattern:** Mock repositories are hand-written structs/classes conforming to the FinFlowCore protocol. Tests verify validation logic, error propagation, and data transformation — not network calls.

| Package | Test Files | Coverage |
|---------|-----------|----------|
| Identity | 3 | Login, Register, ForgotPassword use cases |
| Transaction | 9 | 9 use-case tests (Add, Update, Delete, GetTransactions, GetSummary, GetChart, GetAnalyticsInsights, GetCategories, AnalyzeText) + 1 mock repository |
| Others | 0 | No tests yet |

---

*Previous: [Chapter 4 — App Target Composition](./04-app-target.md)*
*Next: [Chapter 6 — Data Flows](./06-data-flows.md)*
