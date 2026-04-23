# Chapter 8 — API & Network

## 8.1 Network Architecture Overview

FinFlow uses a **single, centralized HTTP client** — no third-party networking libraries (no Alamofire, no Moya). The entire stack is built on `URLSession`:

```
Feature Repository (actor)
    └─▶ HTTPClientProtocol
            └─▶ APIClient (actor)
                    └─▶ URLSession
                            └─▶ Backend REST API
```

All networking types live in `FinFlowCore/Network/`:

| File | Type | Role |
|------|------|------|
| `HTTPClientProtocol.swift` | Protocol | Abstraction for all HTTP requests |
| `APIClient.swift` | Actor | Concrete implementation with auth, retry, logging |
| `NetworkConfig.swift` | Struct + Protocol | Base URL configuration |
| `ChatRepository.swift` | Actor | AI chat (lives in Core, not a feature package) |

## 8.2 HTTPClientProtocol

The protocol defines a single generic method with convenience overloads:

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

**Default parameter overloads** (via protocol extension) simplify call sites:

```swift
// Full form:
try await client.request(endpoint: "/budgets", method: "GET", body: nil, headers: nil, version: nil, retryOn401: true, extendedTimeout: false)

// Minimal form:
try await client.request(endpoint: "/budgets", method: "GET")
```

The overload chain: 2-param → 3-param → 5-param → 7-param (full).

## 8.3 APIClient

`APIClient` is a Swift `actor` — thread-safe without manual locking.

### Initialization

```swift
public actor APIClient: HTTPClientProtocol {
    private let config: any NetworkConfigProtocol     // base URL
    private let tokenStore: (any TokenStoreProtocol)? // Keychain access
    private let apiVersion: String                    // default "1"
    private let session: URLSession                   // 30s request / 60s resource
    private let longRunningSession: URLSession        // 120s request / 300s resource
    private var refreshHandler: (@Sendable () async throws -> String)?
    private var onUnauthorized: (@Sendable () async -> Void)?
    private var refreshTask: Task<String, any Error>? // single-flight dedup
}
```

**Two URLSessions:**

| Session | Request Timeout | Resource Timeout | Used For |
|---------|----------------|-----------------|----------|
| Default | 30s | 60s | All standard API calls |
| Long-running | 120s | 300s | AI chat (`extendedTimeout: true`) |

### Request Lifecycle

```
1. Build URL:  config.baseURL + endpoint
2. Set headers:
   - Content-Type: application/json
   - API-Version: "1" (or override)
   - Authorization: Bearer <token> (if available)
   - Custom headers (if provided)
3. Encode body as JSON
4. Send via URLSession.data(for:)
5. Handle response:
   - 200-299 → decode JSON as T
   - 401 → refresh token + retry (once)
   - 4xx/5xx → parse ProblemDetail or ApiResponse error
   - Empty body / 204 → return EmptyResponse or nil
```

### Error Response Parsing

The backend may return errors in two formats. APIClient tries both:

**1. RFC 7807 ProblemDetail (preferred):**
```json
{
    "type": "https://api.finflow.com/errors/duplicate-email",
    "title": "Conflict",
    "status": 409,
    "detail": "Email already exists",
    "code": 1003
}
```

**2. Legacy ApiResponse (fallback):**
```json
{
    "code": 1003,
    "message": "Email already exists",
    "result": null
}
```

Parsing order: ProblemDetail first → ApiResponse fallback → raw string.

### Empty Response Handling

For endpoints that return no body (DELETE, logout):

```swift
if data.isEmpty || httpResponse.statusCode == 204 {
    if T.self == EmptyResponse.self { return EmptyResponse() as! T }
    if let optionalType = T.self as? any AnyOptional.Type {
        return optionalType.validNil as! T   // returns nil for Optional<T>
    }
    throw AppError.decodingError             // mandatory T but no data
}
```

Repositories use `let _: EmptyResponse = try await client.request(...)` for void endpoints.

### Auth Hook Configuration

To break the circular dependency (APIClient needs AuthRepository for refresh, AuthRepository needs APIClient for HTTP), auth hooks are configured **after** init:

```swift
// In DependencyContainer:
Task {
    await apiClient.configureAuthHooks(
        refreshHandler: {
            let response = try await authRepository.refreshToken()
            return response.token
        },
        onUnauthorized: {
            await tokenStore.clearToken()
        }
    )
}
```

### Request & Response Logging

Every request/response is logged via `Logger`:

```
[Network] → GET https://api.finflow.com/api/transactions?page=0&size=20
[Network] ← 200 https://api.finflow.com/api/transactions?page=0&size=20
```

Headers and body content are included in debug builds. Token values are truncated for security.

## 8.4 Environment Configuration

```swift
struct AppConfig {
    enum Environment {
        case development
        case production
    }

    var networkConfig: NetworkConfig {
        switch environment {
        case .development:
            return NetworkConfig(baseURL: "http://192.168.1.8:8080/api")
        case .production:
            return NetworkConfig(baseURL: "https://api.finflow.com/api")
        }
    }

    let apiVersion: String = "1"   // sent as API-Version header
}
```

Environment is selected at compile time via `#if DEBUG`.

## 8.5 API Versioning

All requests include an `API-Version` header:

```swift
request.setValue(version ?? apiVersion, forHTTPHeaderField: "API-Version")
```

- Default version: `"1"` (set in `AppConfig`)
- Per-request override: `version` parameter in `request()`
- Backend default: `"1"` if header not present

## 8.6 API Endpoint Catalog

### Authentication (`/auth/`)

| Method | Endpoint | Request Body | Response | Notes |
|--------|----------|-------------|----------|-------|
| POST | `/auth/login` | `LoginRequest` | `LoginResponse` | `retryOn401: false` |
| POST | `/auth/google` | `GoogleLoginRequest` | `LoginResponse` | `retryOn401: false` |
| POST | `/auth/register` | `RegisterRequest` | `RegisterResponse` | `X-Registration-Token` header |
| POST | `/auth/refresh` | `RefreshTokenRequest` | `RefreshTokenResponse` | `retryOn401: false` |
| POST | `/auth/logout` | — | `EmptyResponse` | Invalidates token server-side |
| POST | `/auth/send-otp` | `SendOtpRequest` | `[String: String]` | |
| POST | `/auth/verify-otp` | `VerifyOtpRequest` | `VerifyOtpResponse` | |
| POST | `/auth/reset-password` | `ResetPasswordRequest` | `[String: String]` | `X-Reset-Token` header |
| POST | `/auth/change-password` | `ChangePasswordRequest` | `[String: String]` | |
| POST | `/auth/check-user-existence` | `CheckUserExistenceRequest` | `CheckUserExistenceResponse` | |
| POST | `/auth/toggle-biometric` | `{ enabled: Bool }` | `[String: String]` | |
| DELETE | `/auth/delete-account` | `DeleteAccountRequest` | `EmptyResponse` | |

### User Profile (`/users/`)

| Method | Endpoint | Request Body | Response |
|--------|----------|-------------|----------|
| GET | `/users/my-profile` | — | `UserProfile` |
| PUT | `/users/my-profile` | `UpdateProfileRequest` | `UserProfile` |

### Transactions (`/transactions/`)

| Method | Endpoint | Request Body | Response |
|--------|----------|-------------|----------|
| GET | `/transactions?page=&size=&startDate=&endDate=&keyword=` | — | `PaginatedResponse<TransactionResponse>` |
| POST | `/transactions` | `AddTransactionRequest` | `TransactionResponse` |
| PUT | `/transactions/{id}` | `AddTransactionRequest` | `TransactionResponse` |
| DELETE | `/transactions/{id}` | — | `EmptyResponse` |
| GET | `/transactions/summary` | — | `TransactionSummaryResponse` |
| POST | `/transactions/analyze` | `AnalyzeTransactionRequest` | `AnalyzeTransactionResponse` |
| GET | `/transactions/analytics-insights` | — | `TransactionAnalyticsInsightsResponse` |
| GET | `/transactions/chart?range=&referenceDate=` | — | `TransactionChartResponse` |
| GET | `/transactions/categories` | — | `[CategoryResponse]` |
| POST | `/transactions/categories` | `CreateCategoryRequest` | `CategoryResponse` |
| PUT | `/transactions/categories/{id}` | `UpdateCategoryRequest` | `CategoryResponse` |
| DELETE | `/transactions/categories/{id}` | — | `EmptyResponse` |

### Wealth Accounts (`/wealth/`)

| Method | Endpoint | Request Body | Response |
|--------|----------|-------------|----------|
| GET | `/wealth/accounts/types` | — | `[AccountTypeOptionResponse]` |
| GET | `/wealth/accounts` | — | `[WealthAccountResponse]` |
| POST | `/wealth/accounts` | `CreateWealthAccountRequest` | `WealthAccountResponse` |
| PUT | `/wealth/accounts/{id}` | `UpdateWealthAccountRequest` | `WealthAccountResponse` |
| DELETE | `/wealth/accounts/{id}` | — | `EmptyResponse` |

### Budgets (`/budgets/`)

| Method | Endpoint | Request Body | Response |
|--------|----------|-------------|----------|
| GET | `/budgets` | — | `[BudgetResponse]` |
| POST | `/budgets` | `CreateBudgetRequest` | `BudgetResponse` |
| PUT | `/budgets/{id}` | `UpdateBudgetRequest` | `BudgetResponse` |
| DELETE | `/budgets/{id}` | — | `EmptyResponse` |

### Investments (`/investments/`)

**Company Analysis:**

| Method | Endpoint | Query Params | Response |
|--------|----------|-------------|----------|
| GET | `/investments/companies/{symbol}/analysis` | `annualLimit`, `quarterlyLimit` | `InvestmentAnalysisDTO` → `InvestmentAnalysisBundle` |
| GET | `/investments/companies/{symbol}/analysis/financials` | `annualLimit`, `quarterlyLimit` | `FinancialSeriesDTO` → `FinancialDataSeries` |
| GET | `/investments/companies/{symbol}/analysis/valuations` | `annualLimit`, `startDate`, `endDate`, `showQuarterly` | `[ValuationDTO]` → `[ValuationDataPoint]` |
| GET | `/investments/companies/{symbol}/analysis/valuations/daily` | `startDate`, `endDate` | `[DailyValuationDTO]` → `[DailyValuationDataPoint]` |
| GET | `/investments/companies/{symbol}/analysis/dividends` | `annualLimit` | `[DividendDTO]` → `[DividendDataPoint]` |
| GET | `/investments/companies/suggest?q=&limit=` | — | `[CompanySuggestionResponse]` |
| GET | `/investments/companies/industries?symbols=` | — | `[CompanyIndustryResponse]` |

**Portfolios:**

| Method | Endpoint | Request Body | Response |
|--------|----------|-------------|----------|
| GET | `/investments/portfolios` | — | `[PortfolioResponse]` |
| POST | `/investments/portfolios` | `CreatePortfolioRequest` | `PortfolioResponse` |
| GET | `/investments/portfolios/{id}/assets` | — | `[PortfolioAssetResponse]` |
| POST | `/investments/portfolios/{id}/assets` | `CreatePortfolioAssetRequest` | `PortfolioAssetResponse` |
| POST | `/investments/portfolios/{id}/transactions` | `CreateTradeTransactionRequest` | `EmptyResponse` |
| POST | `/investments/portfolios/{id}/import-snapshot` | `ImportPortfolioSnapshotRequest` | `EmptyResponse` |
| GET | `/investments/portfolios/{id}/health?quarters=` | — | `PortfolioHealthResponse` |
| GET | `/investments/portfolios/{id}/benchmark?code=` | — | `PortfolioMarketBenchmarkResponse` |

### AI Chat (`/chat/`)

| Method | Endpoint | Request Body | Response | Notes |
|--------|----------|-------------|----------|-------|
| POST | `/chat/threads` | `CreateChatThreadRequest` | `ChatThreadResponse` | |
| GET | `/chat/threads` | — | `[ChatThreadResponse]` | |
| GET | `/chat/threads/{id}/messages` | — | `[ChatMessageResponse]` | |
| POST | `/chat/threads/{id}/messages` | `SendChatMessageRequest` | `SendChatMessageResponse` | `extendedTimeout: true` |

## 8.7 DTO-to-Domain Mapping

Most features return API response models directly to the ViewModel. **Investment** is the exception — it maps private DTOs to public domain models:

```swift
// InvestmentRepository.swift (private DTOs)
private struct InvestmentAnalysisDTO: Codable, Sendable { ... }
private struct OverviewDTO: Codable, Sendable { ... }
private struct ValuationDTO: Codable, Sendable { ... }

// Mapped to public domain models:
public struct InvestmentAnalysisBundle { ... }
public struct StockOverview { ... }
public struct ValuationDataPoint { ... }
```

**Why Investment is different:** The backend response structure doesn't match what the UI needs. The repository performs:
- **Percent normalization** — Backend returns 0.18 (ratio) or 18 (percent); repository normalizes to always-percent
- **Share count normalization** — Converts absolute shares to billions for UI display
- **Bank vs. non-bank branching** — Maps to `FinancialDataSeries.bank([...])` or `.nonBank([...])`
- **Null coalescing** — Backend sends nullable fields; domain models use defaults

## 8.8 Query String Building

Repositories build query strings manually (no shared utility):

**Simple pattern** (BudgetRepository):
```swift
endpoint: "/budgets/\(id)"
```

**URLComponents pattern** (TransactionRepository):
```swift
private func buildEndpoint(path: String, queryItems: [URLQueryItem]) -> String {
    var components = URLComponents()
    components.path = path
    components.queryItems = queryItems
    return components.string ?? path
}
```

**String concatenation pattern** (InvestmentRepository):
```swift
let query = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
return "/investments/companies/\(symbol)/\(pathSuffix)\(query)"
```

## 8.9 Date Formatting Conventions

Different features use different date formats based on backend API contracts:

| Feature | Format | Example | Formatter |
|---------|--------|---------|-----------|
| Transaction (add/edit) | ISO8601 fractional | `2026-04-16T10:30:00.000Z` | `ISO8601DateFormatter` |
| Transaction (query) | `yyyy-MM-dd` | `2026-04-16` | `DateFormatter` |
| Investment | `yyyy-MM-dd` | `2026-04-16` | `DateFormatter` (UTC) |
| Budget | `yyyy-MM-dd` | `2026-04-16` | `DateFormatter` |

## 8.10 Network Patterns Summary

| Pattern | Implementation | Where |
|---------|---------------|-------|
| Single HTTP client | `APIClient` actor | `FinFlowCore/Network/` |
| Auto token injection | Bearer header from `TokenStoreProtocol` | `APIClient.request()` |
| 401 auto-retry | Single-flight refresh + one retry | `APIClient.request()` |
| Error parsing | ProblemDetail → ApiResponse → raw string | `APIClient.request()` |
| Empty response | `EmptyResponse` type + Optional handling | `APIClient.request()` |
| Extended timeout | Separate `URLSession` for AI chat | `APIClient.longRunningSession` |
| DTO mapping | Private DTOs → public domain models | `InvestmentRepository` only |
| No third-party deps | Pure `URLSession` | Entire network stack |
| API versioning | `API-Version` header on every request | `APIClient` + `AppConfig` |

---

*Previous: [Chapter 7 — Concurrency Model](./07-concurrency.md)*
*Next: [Chapter 9 — Adding New Features](./09-adding-features.md)*
