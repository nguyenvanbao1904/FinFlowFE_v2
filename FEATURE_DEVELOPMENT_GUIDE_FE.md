# 📱 iOS Development Guide - The Holy Bible

**Purpose:** Hướng dẫn phát triển tính năng mới ĐÚNG CHUẨN  
**Status:** Living Document - Nguyên tắc bất biến

---

## 🎯 Core Philosophy

> **UseCase chỉ có giá trị khi nó chứa LOGIC NGHIỆP VỤ thực sự.**  
> **Không tạo wrapper vô nghĩa.**

---

## 🌳 Decision Tree

```
Feature mới
    ↓
Logic có phức tạp không?
├─ Kết hợp 2+ repositories?
├─ Business rules phức tạp?
├─ Side effects (analytics, local storage)?
└─ Transaction spanning?
    ↓ CÓ              ↓ KHÔNG
┌─────────┐      ┌──────────────┐
│ UseCase │      │ ViewModel +  │
│ Pattern │      │ Repository   │
└─────────┘      └──────────────┘
```

---

## 📋 Decision Matrix

| Tiêu chí | UseCase | Repository trực tiếp |
|----------|---------|---------------------|
| Simple fetch (get list, get detail) | ❌ | ✅ |
| Kết hợp 2+ repositories | ✅ | ❌ |
| Complex validation/business rules | ✅ | ❌ |
| Side effects (analytics, cache, storage) | ✅ | ❌ |
| Data transformation phức tạp | ✅ | ❌ |
| Local + Remote coordination | ✅ | ❌ |

---

## 🏗️ Architecture Patterns

### Pattern 1: Simple Fetch → NO UseCase

**Structure:**
```
View → ViewModel → Repository → API/Storage
```

**Example:**
```swift
// View
struct ProductListView: View {
    @StateObject var viewModel = ProductListViewModel()
    
    var body: some View {
        List(viewModel.products) { product in
            ProductRow(product: product)
        }
        .task {
            await viewModel.loadProducts()
        }
    }
}

// ViewModel - Gọi Repository trực tiếp
@MainActor
final class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: ProductRepository
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await repository.fetchProducts()
        } catch {
            self.error = error
        }
    }
}
```

**Lý do:** Chỉ 1 repository call, không có logic gì khác.

---

### Pattern 2: Complex Logic → UseCase

**Structure:**
```
View → ViewModel → UseCase → Repository(s) → API/Storage
```

**Example: Multi-Repository Orchestration**
```swift
protocol PlaceOrderUseCase {
    func execute(cart: Cart, paymentMethod: PaymentMethod) async throws -> Order
}

final class PlaceOrderUseCaseImpl: PlaceOrderUseCase {
    private let orderRepository: OrderRepository
    private let inventoryRepository: InventoryRepository
    private let paymentRepository: PaymentRepository
    private let analytics: AnalyticsService
    
    init(
        orderRepository: OrderRepository,
        inventoryRepository: InventoryRepository,
        paymentRepository: PaymentRepository,
        analytics: AnalyticsService
    ) {
        self.orderRepository = orderRepository
        self.inventoryRepository = inventoryRepository
        self.paymentRepository = paymentRepository
        self.analytics = analytics
    }
    
    func execute(
        cart: Cart,
        paymentMethod: PaymentMethod
    ) async throws -> Order {
        // 1. Validate inventory (business rule)
        for item in cart.items {
            let available = try await inventoryRepository
                .checkStock(productId: item.productId)
            guard available >= item.quantity else {
                throw OrderError.outOfStock(item.productName)
            }
        }
        
        // 2. Process payment
        let paymentResult = try await paymentRepository
            .processPayment(
                amount: cart.total,
                method: paymentMethod
            )
        
        guard paymentResult.isSuccess else {
            throw OrderError.paymentFailed(paymentResult.errorMessage)
        }
        
        // 3. Create order
        let order = Order(
            items: cart.items,
            total: cart.total,
            paymentId: paymentResult.transactionId,
            status: .confirmed
        )
        let savedOrder = try await orderRepository.createOrder(order)
        
        // 4. Update inventory
        for item in cart.items {
            try await inventoryRepository.decreaseStock(
                productId: item.productId,
                quantity: item.quantity
            )
        }
        
        // 5. Side effect: Track analytics
        analytics.track(.orderPlaced(
            orderId: savedOrder.id,
            amount: savedOrder.total
        ))
        
        return savedOrder
    }
}
```

**Giá trị UseCase:**
- ✅ Orchestrate 3 repositories
- ✅ Business validation (stock check)
- ✅ Transaction-like operation
- ✅ Side effect (analytics)

---

### Pattern 3: Infrastructure Service

**Khi nào dùng:**
- Scheduled tasks
- System integration
- Framework requirements
- Technical concerns (không phải business logic)

**Example: Cache Management**
```swift
final class CacheCleanupService {
    private let imageCache: ImageCache
    private let dataCache: DataCache
    
    init(imageCache: ImageCache, dataCache: DataCache) {
        self.imageCache = imageCache
        self.dataCache = dataCache
    }
    
    func scheduleCleanup() {
        // Schedule daily cleanup at 3 AM
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                await self.performCleanup()
            }
        }
    }
    
    private func performCleanup() async {
        // Remove old images
        let cutoffDate = Date().addingTimeInterval(-7 * 86400) // 7 days
        await imageCache.removeImagesOlderThan(cutoffDate)
        
        // Clear expired data
        await dataCache.removeExpiredEntries()
        
        print("Cache cleanup completed")
    }
}
```

**Lý do dùng Service:** Infrastructure concern, không phải use case của user.

---

### Pattern 4: Domain Service

**Khi nào dùng:**
- Logic phức tạp cần reuse ở nhiều UseCases
- Thuật toán calculation phức tạp
- Domain rules không thuộc về 1 entity cụ thể

**Example: Budget Calculation Engine**
```swift
protocol BudgetCalculationService {
    func calculateBudgetStatus(
        budget: Budget,
        transactions: [Transaction],
        recurringExpenses: [RecurringExpense]
    ) -> BudgetStatus
}

final class BudgetCalculationServiceImpl: BudgetCalculationService {
    
    func calculateBudgetStatus(
        budget: Budget,
        transactions: [Transaction],
        recurringExpenses: [RecurringExpense]
    ) -> BudgetStatus {
        // 1. Calculate spent amount
        let spent = calculateTotalSpent(
            transactions: transactions,
            category: budget.category
        )
        
        // 2. Project future expenses
        let projectedExpenses = projectRecurringExpenses(
            recurringExpenses: recurringExpenses,
            endDate: budget.endDate
        )
        
        // 3. Calculate available amount
        let available = budget.amount - spent - projectedExpenses
        
        // 4. Determine status based on complex rules
        let percentageUsed = (spent + projectedExpenses) / budget.amount
        
        let status: BudgetStatus.Level
        if percentageUsed >= 1.0 {
            status = .exceeded
        } else if percentageUsed >= 0.9 {
            status = .critical
        } else if percentageUsed >= 0.75 {
            status = .warning
        } else {
            status = .healthy
        }
        
        return BudgetStatus(
            level: status,
            spent: spent,
            projected: projectedExpenses,
            available: available,
            percentageUsed: percentageUsed
        )
    }
    
    private func calculateTotalSpent(
        transactions: [Transaction],
        category: Category
    ) -> Decimal {
        transactions
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func projectRecurringExpenses(
        recurringExpenses: [RecurringExpense],
        endDate: Date
    ) -> Decimal {
        // Complex projection logic
        var total: Decimal = 0
        let calendar = Calendar.current
        
        for expense in recurringExpenses {
            let occurrences = expense.frequency
                .occurrenceCount(from: Date(), to: endDate, calendar: calendar)
            total += expense.amount * Decimal(occurrences)
        }
        
        return total
    }
}
```

**Lý do dùng Service:**
- Logic calculation phức tạp, nhiều UseCases cần dùng
- Budget Overview, Budget Alert, Budget Forecast đều cần
- Domain logic không phải technical concern

---

## ⚠️ Anti-Patterns

### ❌ Wrapper Vô Nghĩa

```swift
// ❌ SAI - UseCase chỉ forward
protocol GetUserProfileUseCase {
    func execute() async throws -> UserProfile
}

final class GetUserProfileUseCaseImpl: GetUserProfileUseCase {
    private let repository: UserRepository
    
    func execute() async throws -> UserProfile {
        return try await repository.fetchUserProfile()
    }
}
```

**Vấn đề:** Không có giá trị gì! ViewModel có thể gọi trực tiếp Repository.

**Cách sửa:**
```swift
// ✅ ĐÚNG - ViewModel gọi Repository trực tiếp
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    private let repository: UserRepository
    
    func loadProfile() async throws {
        profile = try await repository.fetchUserProfile()
    }
}
```

---

### ❌ Business Logic trong ViewModel

```swift
// ❌ SAI - Logic nằm trong ViewModel
@MainActor
final class CheckoutViewModel: ObservableObject {
    func placeOrder() async throws {
        // Validate inventory
        // Process payment
        // Create order
        // Update inventory
        // Track analytics
        // All in ViewModel! ❌
    }
}
```

**Vấn đề:**
- ViewModel quá nặng
- Không test được business logic riêng
- Khó reuse

**Cách sửa:**
```swift
// ✅ ĐÚNG - Logic vào UseCase
@MainActor
final class CheckoutViewModel: ObservableObject {
    private let placeOrderUseCase: PlaceOrderUseCase
    
    func placeOrder(cart: Cart, payment: PaymentMethod) async throws {
        let order = try await placeOrderUseCase.execute(
            cart: cart,
            paymentMethod: payment
        )
        // Just handle UI state
    }
}
```

---

## 📚 Real-World Examples

### Example 1: Simple List

**Requirement:** Display list of categories

**Decision:**
- Kết hợp nhiều repo? ❌
- Business rules? ❌
- Side effects? ❌

**Solution:** Repository trực tiếp

```swift
@MainActor
final class CategoryListViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var isLoading = false
    
    private let repository: CategoryRepository
    
    init(repository: CategoryRepository) {
        self.repository = repository
    }
    
    func loadCategories() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            categories = try await repository.fetchCategories()
        } catch {
            print("Error loading categories: \(error)")
        }
    }
}
```

---

### Example 2: Create with Simple Validation

**Requirement:** Create budget với validation amount > 0, check duplicate

**Decision:**
- Logic đơn giản có thể xử lý trong ViewModel
- Chỉ 1 repository
- Không có side effects

**Solution:** ViewModel + Repository

```swift
@MainActor
final class CreateBudgetViewModel: ObservableObject {
    @Published var amount: Decimal = 0
    @Published var category: Category?
    @Published var error: String?
    
    private let repository: BudgetRepository
    
    func createBudget() async throws {
        // Simple validation
        guard amount > 0 else {
            error = "Amount must be greater than 0"
            return
        }
        
        guard let category = category else {
            error = "Please select a category"
            return
        }
        
        // Check duplicate
        let exists = try await repository
            .budgetExists(for: category)
        guard !exists else {
            error = "Budget for this category already exists"
            return
        }
        
        // Create budget
        let budget = Budget(
            amount: amount,
            category: category,
            startDate: Date()
        )
        try await repository.createBudget(budget)
    }
}
```

---

### Example 3: Complex Login Flow

**Requirement:** Login với:
- Authenticate với backend
- Save credentials to Keychain
- Fetch user profile
- Sync local data
- Track login event

**Decision:**
- Kết hợp nhiều repo? ✅ (Auth, User, Local Storage)
- Business rules? ✅ (credential validation)
- Side effects? ✅ (analytics, sync)

**Solution:** UseCase

```swift
protocol LoginUseCase {
    func execute(email: String, password: String) async throws -> User
}

final class LoginUseCaseImpl: LoginUseCase {
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let keychainService: KeychainService
    private let syncService: DataSyncService
    private let analytics: AnalyticsService
    
    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        keychainService: KeychainService,
        syncService: DataSyncService,
        analytics: AnalyticsService
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.keychainService = keychainService
        self.syncService = syncService
        self.analytics = analytics
    }
    
    func execute(email: String, password: String) async throws -> User {
        // 1. Validate credentials (business rule)
        guard email.isValidEmail else {
            throw LoginError.invalidEmail
        }
        
        guard password.count >= 8 else {
            throw LoginError.passwordTooShort
        }
        
        // 2. Authenticate with backend
        let authResult = try await authRepository.login(
            email: email,
            password: password
        )
        
        // 3. Save to Keychain
        try keychainService.saveToken(authResult.token)
        
        // 4. Fetch user profile
        let user = try await userRepository.fetchProfile(
            userId: authResult.userId
        )
        
        // 5. Sync local data
        Task {
            await syncService.syncUserData(for: user.id)
        }
        
        // 6. Side effect: Track analytics
        analytics.track(.userLoggedIn(
            userId: user.id,
            method: .email
        ))
        
        return user
    }
}
```

**Giá trị UseCase:**
- ✅ Orchestrate 3 repositories + 2 services
- ✅ Complex validation
- ✅ Multiple operations coordinated
- ✅ Side effects (analytics, sync)

---

## 🚀 Development Workflow

### Checklist khi develop feature mới:

1. **Phân tích requirement:**
   - Cần fetch data gì?
   - Có business rules phức tạp không?
   - Cần combine data từ nhiều sources?
   - Có side effects không?

2. **Chạy qua Decision Matrix:**
   - Đánh dấu ✅ các tiêu chí phù hợp
   - Nếu có >= 2 ✅ trong cột UseCase → Dùng UseCase
   - Nếu tất cả ❌ → Repository trực tiếp

3. **Implement:**
   - Simple → ViewModel + Repository
   - Complex → ViewModel + UseCase + Repository(s)

4. **Review:**
   - UseCase có logic thực sự không?
   - Có thể đơn giản hóa không?
   - Có duplicate code không?

5. **Refactor nếu cần:**
   - UseCase wrapper vô nghĩa → Xóa, gọi Repository trực tiếp
   - Logic phức tạp reuse → Extract Domain Service
   - Technical concerns → Extract Infrastructure Service

---

## 📖 Key Principles

### 1. KISS (Keep It Simple, Stupid)
- Default: Simple nhất có thể
- Chỉ thêm complexity khi CẦN THIẾT

### 2. YAGNI (You Aren't Gonna Need It)
- Không tạo UseCase "for future"
- Không tạo abstraction "just in case"

### 3. SwiftUI State Management
- @Published cho data changes
- @MainActor cho UI updates
- Task {} cho async operations

### 4. Single Responsibility
- 1 UseCase = 1 business operation
- 1 Repository = 1 data source
- 1 ViewModel = 1 screen/feature

---

## 🎯 Summary

| Scenario | Pattern | Example |
|----------|---------|---------|
| **Simple fetch** | Repository trực tiếp | `repository.fetchCategories()` |
| **Simple create với validation đơn giản** | ViewModel + Repository | Create budget |
| **Complex orchestration** | UseCase | Place order với inventory check |
| **Side effects** | UseCase | Login với analytics + sync |
| **Scheduled tasks** | Infrastructure Service | Cache cleanup |
| **Shared complex logic** | Domain Service | Budget calculation |

---

## 🛡️ Production-Ready Base (bổ sung bắt buộc)

### 1) Authentication Resilience
- API client phải có **silent refresh + retry 401** đúng 1 lần, single-flight (không spam server).
- Refresh endpoint gọi với `retryOn401: false` để tránh vòng lặp.
- Khi refresh thất bại → phát sự kiện session expired → router đưa user về Login.
- TokenStore + RefreshTokenStore là SSoT; không cache token ở ViewModel.

### 2) Session Single Source of Truth
- Dùng SessionManager (actor/ObservableObject) publish state: `.authenticated(token)`, `.unauthenticated`, `.refreshing`.
- Router subscribe state; khi `.unauthenticated` → reset path, show Login.
- Logout/refresh fail/clear token đều đi qua SessionManager để đồng bộ.

### 3) Design System & Components
- Design tokens tập trung: Colors (thêm semantic state: success/warn/error), Typography, Spacing, Radius, Shadow.
- Atomic components (GlassyTextField, PrimaryButton, SocialLoginButton, DividerWithText) phải `public`, stateless, dùng tokens.
- Ưu tiên style modifiers (vd: `.primaryButtonStyle()`, `.glassFieldStyle()`) để giảm lặp padding/background.
- Assets brand (Google/FB/Apple) cần fallback SF Symbols.

### 4) Independence & Navigation
- View chỉ biết `AppRouterProtocol` ở Core; không import App shell.
- Simple fetch → Repo trực tiếp; logic phức tạp → UseCase (theo Decision Tree).
- Không hardcode data trong View; mọi dữ liệu từ VM/Repo/UseCase.

### 5) Tooling & Quality Gate
- Bắt buộc unit test cho UseCase/Repo/VM với mocks (MockAPIClient, MockTokenStore, MockRouter).
- Preview/Snapshot: mỗi View có Preview với MockVM + MockRouter; không gọi network thật.
- CI: lint + test cho packages (FinFlowCore, Identity, Dashboard) trước khi merge.
- Instruments/Memory Graph: kiểm tra retain cycle khi thêm closures (router callbacks, VM → coordinator).

### 6) Checklist khi thêm feature
- [ ] Chọn pattern: Simple (Repo) hay Complex (UseCase) theo Decision Matrix.
- [ ] Wiring DI: inject qua init; chỉ singleton cho hạ tầng (Logger, SessionManager).
- [ ] UI dùng components/design tokens; không hardcode màu/spacing.
- [ ] Xử lý lỗi bằng ErrorHandler; không swallow error.
- [ ] Thêm preview/test tối thiểu cho ViewModel/UseCase.

---

## 🧭 Data-Driven Navigation (Router Protocol)

- Nguyên tắc: Cha (FinFlowIos) biết Con (Identity/Dashboard), nhưng Con **không** biết Cha → Không circular deps.
- Luật chơi đặt tại Core: `Packages/FinFlowCore/Sources/FinFlowCore/Navigation/NavigationTypes.swift` chứa `AppRoute` + `AppRouterProtocol` (extends `ObservableObject`).
- Module Con chỉ import `FinFlowCore` và nhận `any AppRouterProtocol` qua init. Không import FinFlowIos.
- App chính implement router thật (`FinFlowIos/Core/Navigation/AppRouter.swift`) và inject ở entry (`FinFlowIosApp`) qua DI container.
- Pattern: Navigation = State. `NavigationStack(path: $router.path)` + `navigationDestination(for: AppRoute.self)` map route → View.
- Unit test dễ: mock `AppRouterProtocol` để assert navigate/pop.

---

## 🔄 Coordinator Pattern Integration

### Simple Flow (No UseCase)
```
Coordinator → ViewModel → Repository → API
```

### Complex Flow (With UseCase)
```
Coordinator → ViewModel → UseCase → Repository(s) → API
```

**Coordinator responsibilities:**
- Navigation logic
- Dependency injection
- Flow coordination

**NOT for business logic!**

---

*"Simplicity is the ultimate sophistication." - Leonardo da Vinci*

---

## 7. Modular Clean Architecture Rules (BẮT BUỘC)

Để đảm bảo code clean và modular, các file phải được đặt đúng vị trí:

### 7.1 Domain Layer (`Sources/[Module]/Domain`)
- **CHỈ CHỨA**:
    - **Protocols** (Interfaces): `AuthRepositoryProtocol`, `LoginUseCaseProtocol`.
    - **Entities/Models**: `UserProfile`, `LoginRequest`.
    - **UseCases** (Implementation logic business thuần súy): `LoginUseCase`.
    - **Domain Errors**: `AuthError`.
- **KHÔNG CHỨA**:
    - Implementation của Repository (không gọi API/Database ở đây).
    - UI Code (SwiftUI).
    - Libraries (Alamofire, Realm).

### 7.2 Data Layer (`Sources/[Module]/Data`)
- **CHỨA**:
    - **Repository Implementations**: `AuthRepository` (implement `AuthRepositoryProtocol`).
    - **DTOs** (Data Transfer Objects): Mapping JSON <-> Domain Model.
    - **API Services**: Gọi Networking.
    - **Local Storage**: UserDefaults, FileManager helpers.

### 7.3 Presentation Layer (`Sources/[Module]/Presentation`)
- **CHỨA**:
    - **Views** (SwiftUI).
    - **ViewModels** (ObservableObject).
    - **Coordinators** (Navigation).

### 📝 Example Structure
```text
Packages/Identity/Sources/Identity/
├── Domain/                  # ✅ PURE SWIFT
│   ├── AuthRepositoryProtocol.swift
│   ├── LoginUseCase.swift
│   └── Models/
├── Data/                    # 🔌 IMPLEMENTATION
│   ├── AuthRepository.swift # (class AuthRepository: AuthRepositoryProtocol)
│   └── Network/
└── Presentation/            # 📱 UI
    ├── LoginViewModel.swift
    └── LoginView.swift
```

---

*Last updated: 28/12/2025*  
*Status: The Holy Bible - Follow strictly* 📖
