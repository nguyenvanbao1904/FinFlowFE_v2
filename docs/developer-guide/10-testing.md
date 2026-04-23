# Chapter 10 — Testing

FinFlow dùng **Swift Testing** (framework mới của Apple, `import Testing`) thay cho XCTest. Tests tập trung vào **tầng Domain (UseCases)** — nơi chứa business logic thuần — và mock Repository ở biên.

## 10.1 Testing Scope

Trạng thái hiện tại (snapshot tại thời điểm viết doc):

| Package | Test Target | Ghi chú |
|---------|-------------|---------|
| Identity | ✅ `IdentityTests` | 3 UseCases: Login, Register, ForgotPassword |
| Transaction | ✅ `TransactionTests` | 9 UseCases: Add, Update, Delete, Get*, Analyze, Chart, Summary, Insights, GetCategories |
| Dashboard | ❌ | — |
| Planning | ❌ | — |
| Wealth | ❌ | — |
| Investment | ❌ | — |
| Profile | ❌ | — |
| FinFlowCore | ❌ | — |

**Chỉ 2/8 package** có test. Những package còn lại là backlog; khi thêm test mới hãy tuân đúng pattern trong chương này.

**Không có UI test, không có integration/E2E test** — tất cả test hiện tại đều là unit test ở cấp UseCase.

## 10.2 Test Philosophy

1. **Test UseCase, không test Repository.** Repository chỉ là I/O wrapper (network / cache) — test sẽ trở thành integration test, dễ flaky. Test các **business rule** nằm trong UseCase (validate, trim, format, transform).
2. **Mock Repository bằng class handcrafted.** Không dùng mocking framework. Mock implement đầy đủ protocol + expose `callCount`, `lastXxxRequest`, `stubbedResponse`, `errorToThrow`.
3. **Không test ViewModel/View.** ViewModel là glue code (bind UseCase → state). Logic thật đã ở UseCase; test ViewModel vừa trùng lặp vừa đòi `@MainActor` harness phức tạp. Ưu tiên test UseCase + manual smoke test UI.
4. **Một `@Suite` cho một UseCase.** Một `struct` test, `makeSUT()` private helper, group bằng `// MARK: - <Scenario>`.

## 10.3 Thiết lập Test Target cho Package mới

Trong `Package.swift` của feature package, thêm `testTarget`:

```swift
targets: [
    .target(
        name: "Planning",
        dependencies: [.product(name: "FinFlowCore", package: "FinFlowCore")]
    ),
    .testTarget(
        name: "PlanningTests",
        dependencies: [
            "Planning",
            .product(name: "FinFlowCore", package: "FinFlowCore")
        ],
        path: "Tests/PlanningTests"
    )
]
```

Tạo cấu trúc thư mục:

```
Packages/Planning/Tests/PlanningTests/
├── Mocks/
│   └── MockBudgetRepository.swift
└── UseCases/
    ├── GetBudgetsUseCaseTests.swift
    └── AddBudgetUseCaseTests.swift
```

Chạy:

```bash
swift test --package-path Packages/Planning
```

## 10.4 Mock Repository Pattern

Dùng lại pattern từ `MockTransactionRepository` / `MockAuthRepository`. Quy ước:

- `final class` + `@unchecked Sendable` (vì mock không cần thread-safety thật — được gọi từ test).
- Implement **toàn bộ** protocol (kể cả method không test đến) để compile pass.
- 3 loại property:
  - **Stubs:** `stubbedXxxResult` — dữ liệu trả về.
  - **Error switch:** `var errorToThrow: Error?` — nếu set, mọi method throw error đó.
  - **Trackers:** `var xxxCallCount` + `var lastXxxRequest` — để `#expect` verify.

Ví dụ:

```swift
// Packages/Transaction/Tests/TransactionTests/Mocks/MockTransactionRepository.swift
final class MockTransactionRepository: TransactionRepositoryProtocol, @unchecked Sendable {

    // Stubs
    var stubbedTransactionResult: TransactionResponse = .mock()

    // Error
    var errorToThrow: Error?

    // Trackers
    var addTransactionCallCount = 0
    var lastAddTransactionRequest: AddTransactionRequest?

    func addTransaction(request: AddTransactionRequest) async throws -> TransactionResponse {
        if let error = errorToThrow { throw error }
        addTransactionCallCount += 1
        lastAddTransactionRequest = request
        return stubbedTransactionResult
    }
    // ... các method khác
}
```

### Test Fixtures (`.mock()` extensions)

Đặt cùng file mock, ở dưới class. Factory methods có default parameters để test viết ngắn:

```swift
extension TransactionResponse {
    static func mock(
        id: String = "txn-001",
        amount: Double = 100_000,
        type: TransactionType = .expense,
        categoryId: String = "cat-001",
        note: String? = nil,
        date: String = "2026-04-13T12:00:00"
    ) -> TransactionResponse {
        TransactionResponse(id: id, amount: amount, type: type, ...)
    }
}

extension PaginatedResponse where T == TransactionResponse {
    static func mockEmpty() -> Self { .init(items: [], page: 0, totalPages: 0, ...) }
}
```

> **Rule:** Mock/fixture chỉ sống trong thư mục `Tests/`. Không expose sang production code.

## 10.5 Swift Testing Syntax Cheat-sheet

```swift
import Testing
import Foundation
@testable import Transaction
import FinFlowCore

@Suite("AddTransactionUseCase")                       // ← đặt tên người đọc
struct AddTransactionUseCaseTests {

    // System Under Test helper — MỌI test file đều có
    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: AddTransactionUseCase, repository: MockTransactionRepository) {
        (AddTransactionUseCase(repository: repository), repository)
    }

    @Test("execute thành công trả về TransactionResponse từ repository")
    func execute_success() async throws {
        let (sut, repo) = makeSUT()
        repo.stubbedTransactionResult = .mock(amount: 150_000)

        let result = try await sut.execute(request: .init(amount: 150_000, ...))

        #expect(result.amount == 150_000)
    }

    @Test("execute throws AppError khi repository throws")
    func execute_whenRepositoryThrows_propagates() async {
        let (sut, repo) = makeSUT()
        repo.errorToThrow = AppError.networkError("offline")

        await #expect(throws: AppError.self) {
            _ = try await sut.execute(request: .init(...))
        }
    }
}
```

Các API cần nhớ:
- `@Suite("...")` — đặt tên suite.
- `@Test("...")` — một test case; viết mô tả **bằng tiếng Việt, có dấu**, mô tả scenario + expected.
- `#expect(condition)` — assert thường; test tiếp tục nếu fail (thu thập nhiều failure trong một test).
- `#require(value)` — unwrap Optional hoặc assert cứng; test **dừng** tại đây nếu fail.
- `#expect(throws: ErrorType.self) { ... }` — assert block throw error thuộc type.
- `#expect(throws: SpecificError.case) { ... }` — assert throw đúng case (nếu error `Equatable`).

## 10.6 Testing Patterns thường dùng

### A. Test "UseCase forward request"

Verify UseCase pass đúng data xuống repository.

```swift
@Test("execute trim whitespace username trước khi forward")
func execute_trimsUsername() async throws {
    let (sut, repo) = makeSUT()

    _ = try await sut.execute(username: "  admin  ", password: "pass")

    let captured = try #require(repo.lastLoginRequest)
    #expect(captured.username == "admin")
}
```

### B. Test "Validation fail không gọi repository"

```swift
@Test("execute username rỗng → throw validationError, không gọi repo")
func execute_emptyUsername() async {
    let (sut, repo) = makeSUT()

    await #expect(throws: AppError.self) {
        _ = try await sut.execute(username: "", password: "x")
    }
    #expect(repo.loginCallCount == 0)
}
```

### C. Test "Error propagation"

```swift
@Test("repo throw networkError → propagate")
func execute_propagatesNetworkError() async {
    let (sut, repo) = makeSUT()
    repo.errorToThrow = IdentityMockError.networkFailure

    await #expect(throws: IdentityMockError.networkFailure) {
        _ = try await sut.execute(username: "u", password: "p")
    }
}
```

### D. Test "Transform logic" (parse, format)

```swift
@Test("parseAmount với định dạng VN '1.500.000' → 1500000")
func parseAmount_vnFormat() throws {
    let value = try AddTransactionUseCase.parseAmount("1.500.000")
    #expect(value == 1_500_000)
}

@Test("parseAmount với chuỗi rỗng → throw validationError")
func parseAmount_empty_throws() {
    #expect(throws: AppError.self) {
        _ = try AddTransactionUseCase.parseAmount("")
    }
}
```

Để test helper static, expose `static func` ở UseCase bằng `internal` (không `public`) — `@testable import` sẽ vẫn thấy được.

## 10.7 Convention về Naming & Format

Quy ước đã áp dụng trong codebase:

| Vị trí | Quy ước | Ví dụ |
|--------|---------|-------|
| Suite name | Tên UseCase, không có "Tests" | `@Suite("LoginUseCase")` |
| Test function | `<method>_<scenario>_<expected>` (snake_case mix) | `execute_withEmptyUsername_throwsValidationError` |
| Test description (string) | Tiếng Việt, mô tả business behaviour | `"execute trim whitespace từ username trước khi gửi lên repository"` |
| MARK groups | `// MARK: - <Scenario Group>` | `// MARK: - Input Sanitization (Business Logic)` |
| SUT helper | `private func makeSUT(...) -> (sut: ..., repository: ...)` | Luôn return tuple để test có tên rõ ràng |

Thứ tự `// MARK:` sections được khuyến nghị:

1. `Success Path`
2. `Input Sanitization / Validation` (business logic)
3. `Error Propagation`
4. (Tuỳ UseCase) sub-methods như Google Login, refresh...

## 10.8 Chạy Tests

```bash
# Test một package
swift test --package-path Packages/Transaction

# Test filter theo suite
swift test --package-path Packages/Identity --filter LoginUseCase

# Test từ Xcode
# Mở FinFlowIos.xcodeproj, chọn scheme của package, ⌘U
```

> CI chưa được thiết lập — tests chạy thủ công trên máy dev trước khi PR.

## 10.9 Những gì **KHÔNG** nên test

Tránh phí effort vào những thứ sau:

- **Repository HTTP layer** — test với real server = flaky; test với mock URLProtocol = test lại `URLSession`. Nếu cần, viết integration test tách riêng, không gộp vào UseCase tests.
- **SwiftUI Views** — không có tool ổn định, và UI đang thay đổi nhanh.
- **ViewModel state transitions** — `@MainActor` + `@Observable` khó assert trực tiếp; hãy đảm bảo UseCase đã test, rồi dùng manual smoke.
- **DependencyContainer wiring** — compile-time đã check; test runtime chỉ lặp lại config.
- **Model Codable round-trip** — Swift's `Codable` đã reliable; chỉ test khi có custom `init(from:)` / `encode(to:)` phức tạp.

## 10.10 Checklist khi thêm UseCase mới

- [ ] Tạo file `<UseCase>Tests.swift` trong `Tests/<Package>Tests/UseCases/`.
- [ ] Dùng lại `Mock<Feature>Repository` có sẵn; nếu thêm method mới vào protocol → cập nhật mock trước, tránh build break.
- [ ] Có ít nhất 1 test cho: **success path**, **mỗi validation branch**, **error propagation**.
- [ ] Nếu UseCase có static helper (parse/format) → test riêng từng branch.
- [ ] Test description bằng tiếng Việt, nêu rõ scenario + expected.
- [ ] Chạy `swift test --package-path Packages/<Pkg>` → pass, không warning.

---

*End of Developer Guide. Back to [Chapter 1 — Project Overview](./01-project-overview.md).*
