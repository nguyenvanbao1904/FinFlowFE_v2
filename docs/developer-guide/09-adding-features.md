# Chapter 9 — Adding New Features

Chương này là **playbook** để thêm một màn hình mới hoặc một tính năng mới vào FinFlow. Nó không mô tả lại kiến trúc (xem Ch.2) mà chỉ liệt kê **thứ tự các bước** đúng quy ước của dự án, kèm vị trí file và ví dụ cụ thể.

## 9.1 Ba kịch bản thường gặp

| Kịch bản | Ví dụ | Work scope |
|----------|-------|------------|
| **A. Thêm screen mới trong package có sẵn** | Thêm `RecurringTransaction` vào Transaction package | Chỉ chỉnh trong 1 package + DI + Route |
| **B. Thêm feature package mới** | Thêm package `Notification` | Tạo package mới + update App target + Core |
| **C. Thêm API endpoint vào service có sẵn** | Thêm `GET /transactions/{id}` | Chỉ chỉnh Repository + Core nếu cần model mới |

---

## 9.2 Kịch bản A — Thêm Screen mới trong package có sẵn

Ví dụ: thêm màn hình **"Edit Category"** vào Transaction package.

### Bước 1 — Domain model (nếu thiếu)

Kiểm tra `Packages/FinFlowCore/Sources/FinFlowCore/Models/` xem đã có model/DTO phù hợp chưa. Nếu thiếu:

```swift
// Packages/FinFlowCore/Sources/FinFlowCore/Models/Category.swift
public struct UpdateCategoryRequest: Codable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String?
    // ...
    public init(id: String, name: String, iconName: String?) { ... }
}
```

> **Rule:** Mọi DTO, domain model, protocol dùng chung phải nằm trong `FinFlowCore`. Feature package **không** định nghĩa model dùng chung riêng.

### Bước 2 — Repository protocol (Core) & implementation (Feature)

Nếu endpoint chưa có, thêm vào protocol trong `FinFlowCore`:

```swift
// Packages/FinFlowCore/.../TransactionRepositoryProtocol.swift
public protocol TransactionRepositoryProtocol: Sendable {
    // ... existing methods
    func updateCategory(request: UpdateCategoryRequest) async throws -> CategoryResponse
}
```

Implement trong `Packages/Transaction/Sources/Transaction/Data/TransactionRepository.swift`:

```swift
actor TransactionRepository: TransactionRepositoryProtocol {
    func updateCategory(request: UpdateCategoryRequest) async throws -> CategoryResponse {
        try await client.request(
            endpoint: "/categories/\(request.id)",
            method: .put,
            body: request
        )
    }
}
```

> Xem Ch.8 để chọn `method`, path, và cách decode response.

### Bước 3 — UseCase

Tạo `Packages/Transaction/Sources/Transaction/Domain/UseCases/UpdateCategoryUseCase.swift`:

```swift
import Foundation
import FinFlowCore

public struct UpdateCategoryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        id: String,
        name: String,
        iconName: String?
    ) async throws -> CategoryResponse {
        // Business rules go here: trim, validate, format...
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw AppError.validationError("Tên danh mục không được rỗng")
        }
        return try await repository.updateCategory(
            request: UpdateCategoryRequest(id: id, name: trimmed, iconName: iconName)
        )
    }
}
```

> **Rule:** UseCase chỉ import `Foundation` + `FinFlowCore`. **KHÔNG** import SwiftUI, UIKit, Combine.
> **Rule:** UseCase có `Sendable`, repository là `any <Protocol>` để giữ constructor injection rõ ràng.

### Bước 4 — ViewModel

`Packages/Transaction/Sources/Transaction/Presentation/ViewModels/EditCategoryViewModel.swift`:

```swift
import Foundation
import FinFlowCore
import Observation

@MainActor
@Observable
public final class EditCategoryViewModel {
    // Input state
    public var name: String = ""
    public var iconName: String?

    // Output state
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let categoryId: String
    private let updateCategoryUseCase: UpdateCategoryUseCase
    private let router: any AppRouterProtocol
    private let onSuccess: (CategoryResponse) -> Void

    public init(
        categoryId: String,
        initialName: String,
        updateCategoryUseCase: UpdateCategoryUseCase,
        router: any AppRouterProtocol,
        onSuccess: @escaping (CategoryResponse) -> Void
    ) {
        self.categoryId = categoryId
        self.name = initialName
        self.updateCategoryUseCase = updateCategoryUseCase
        self.router = router
        self.onSuccess = onSuccess
    }

    public func save() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await updateCategoryUseCase.execute(
                id: categoryId, name: name, iconName: iconName
            )
            onSuccess(updated)
            router.pop()
        } catch let error as AppError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

> **Rule:** ViewModel gắn `@MainActor` + `@Observable`. Không dùng `@Published`, `ObservableObject`, `@StateObject` — đã bị SwiftLint cấm (xem Ch.11).
> **Rule:** ViewModel nhận UseCase + Router qua `init`; **không** self-resolve từ `DependencyContainer`.

### Bước 5 — View

`Packages/Transaction/Sources/Transaction/Presentation/Views/EditCategoryView.swift`:

```swift
import SwiftUI
import FinFlowCore

public struct EditCategoryView: View {
    @Bindable var viewModel: EditCategoryViewModel

    public init(viewModel: EditCategoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                TextField("Tên danh mục", text: $viewModel.name)
            }
            if let err = viewModel.errorMessage {
                Text(err).foregroundStyle(.red)
            }
        }
        .navigationTitle("Sửa danh mục")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lưu") { Task { await viewModel.save() } }
                    .disabled(viewModel.isLoading)
            }
        }
    }
}
```

### Bước 6 — Route trong `FinFlowCore`

Thêm case mới vào enum `AppRoute` (file `Packages/FinFlowCore/Sources/FinFlowCore/Navigation/NavigationTypes.swift`):

```swift
public enum AppRoute: Hashable, Sendable {
    // ... existing cases
    case editCategory(CategoryResponse)
}

// Cập nhật computed "id" (nếu có) để route hashable ổn định:
extension AppRoute {
    var id: String {
        switch self {
        // ...
        case .editCategory(let c): return "editCategory-\(c.id)"
        }
    }
}
```

> **Rule:** Tất cả route đều khai báo trong `FinFlowCore/Navigation/NavigationTypes.swift`. Feature package **không** định nghĩa route riêng.

### Bước 7 — DI Factory trong App target

Mở rộng `DependencyContainer+AppViews.swift` (hoặc tạo file partial mới, ví dụ `DependencyContainer+Transaction.swift`):

```swift
// FinFlowIos/FinFlow/Core/DI/DependencyContainer+AppViews.swift
extension DependencyContainer {
    @MainActor
    func makeEditCategoryView(
        router: any AppRouterProtocol,
        category: CategoryResponse
    ) -> some View {
        let useCase = UpdateCategoryUseCase(repository: transactionRepository)
        let vm = EditCategoryViewModel(
            categoryId: category.id,
            initialName: category.name,
            updateCategoryUseCase: useCase,
            router: router,
            onSuccess: { _ in /* broadcast refresh if needed */ }
        )
        return EditCategoryView(viewModel: vm)
    }
}
```

> **Rule:** UseCase được khởi tạo **transient** (ngay trong factory), không giữ property trên `DependencyContainer` (xem Ch.4 §4.3).

### Bước 8 — Đăng ký route trong `AppRouter`

Trong `AppRouter` (hoặc nơi `NavigationStack`'s `.navigationDestination` được vẽ), thêm nhánh mới cho case vừa tạo:

```swift
.navigationDestination(for: AppRoute.self) { route in
    switch route {
    // ... existing
    case .editCategory(let category):
        container.makeEditCategoryView(router: router, category: category)
    }
}
```

### Bước 9 — Gọi từ call-site

Từ ViewModel khác (ví dụ `CategoryListViewModel`):

```swift
func onTapEdit(_ category: CategoryResponse) {
    router.navigate(to: .editCategory(category))
}
```

### Bước 10 — Lint & test

```bash
swiftlint lint --config .swiftlint.yml
swift test --package-path Packages/Transaction
```

Nếu test target chưa tồn tại cho package, xem Ch.10 §10.3 để tạo.

---

## 9.3 Kịch bản B — Thêm Feature Package mới

Ví dụ: tạo package **Notification**.

### Bước 1 — Tạo thư mục package

```
Packages/Notification/
├── Package.swift
├── Sources/Notification/
│   ├── Data/NotificationRepository.swift
│   ├── Domain/UseCases/
│   └── Presentation/
│       ├── ViewModels/
│       └── Views/
└── Tests/NotificationTests/           # optional
```

### Bước 2 — Package.swift

Dán template ở Ch.5 §5.2, chỉ đổi tên:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Notification",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Notification", targets: ["Notification"])
    ],
    dependencies: [
        .package(path: "../FinFlowCore")
    ],
    targets: [
        .target(
            name: "Notification",
            dependencies: [
                .product(name: "FinFlowCore", package: "FinFlowCore")
            ]
        )
    ]
)
```

> **Rule:** Package mới **chỉ** phụ thuộc vào `FinFlowCore`. Nếu bạn thấy mình cần import package khác thì thiết kế đang sai — tách phần chung lên `FinFlowCore`.

### Bước 3 — Thêm vào Xcode App target

1. Mở `FinFlowIos/FinFlow.xcodeproj`.
2. **File → Add Package Dependencies → Add Local** → chọn `Packages/Notification`.
3. Link `Notification` vào target `FinFlowIos` (TARGETS → General → Frameworks, Libraries, and Embedded Content).

### Bước 4 — Cập nhật `DependencyContainer`

```swift
// DependencyContainer.swift
import Notification

@MainActor
public class DependencyContainer {
    // ...
    let notificationRepository: NotificationRepositoryProtocol

    private init() {
        // ...
        self.notificationRepository = NotificationRepository(client: apiClient, cacheService: cacheService)
    }
}
```

Thêm factory methods trong `DependencyContainer+AppViews.swift` như Kịch bản A.

### Bước 5 — Route & Tab (nếu có tab mới)

- Thêm case trong `AppRoute`.
- Nếu là tab: thêm vào `MainTab` enum của `Dashboard` package và render trong `MainTabView`.

### Bước 6 — SwiftLint whitelist

Không cần chỉnh `.swiftlint.yml` — rule `included: [Packages]` tự cover package mới. Nhưng nhớ:

- File đầu tiên bạn commit **không được chứa** `print`, `@Published`, `ObservableObject`, `Combine`, `UIKit` (xem Ch.11 §11.2 cho full list).

---

## 9.4 Kịch bản C — Thêm Endpoint vào Service có sẵn

Ví dụ: thêm `GET /transactions/{id}` → `TransactionResponse`.

### Bước 1 — Model

Nếu `TransactionResponse` đã có, bỏ qua. Nếu thiếu field: thêm field (giữ nguyên tương thích với response hiện tại — thường dùng `Optional`).

### Bước 2 — Protocol

`FinFlowCore/.../TransactionRepositoryProtocol.swift`:

```swift
public protocol TransactionRepositoryProtocol: Sendable {
    // ... existing
    func getTransaction(id: String) async throws -> TransactionResponse
}
```

### Bước 3 — Implementation

`Packages/Transaction/.../TransactionRepository.swift`:

```swift
actor TransactionRepository: TransactionRepositoryProtocol {
    func getTransaction(id: String) async throws -> TransactionResponse {
        try await client.request(endpoint: "/transactions/\(id)", method: .get)
    }
}
```

### Bước 4 — UseCase + consumer (nếu cần)

Chỉ thêm UseCase nếu có business logic (validate, transform). Nếu chỉ pass-through thì có thể để ViewModel gọi thẳng use case đã có, hoặc tạo `GetTransactionUseCase` mỏng để giữ consistency.

---

## 9.5 Checklist "Definition of Done" cho một feature

Trước khi mở PR, xác nhận đầy đủ các mục:

- [ ] Đặt file đúng layer (`Data/`, `Domain/UseCases/`, `Presentation/ViewModels/`, `Presentation/Views/`).
- [ ] ViewModel có `@MainActor` + `@Observable`, không dùng Combine / `ObservableObject`.
- [ ] UseCase `Sendable`, chỉ import `Foundation` + `FinFlowCore`.
- [ ] Repository là `actor`, conform protocol trong `FinFlowCore`.
- [ ] Không `print()` — dùng `Logger.info/debug/error(_:category:)`.
- [ ] Route mới khai báo ở `FinFlowCore/Navigation/NavigationTypes.swift`.
- [ ] Factory method nằm ở `DependencyContainer+*.swift`, UseCase được khởi tạo transient.
- [ ] Feature package **không import** package khác (chỉ `FinFlowCore`).
- [ ] Thêm/cập nhật test cho UseCase có business logic (Ch.10).
- [ ] Chạy `swiftlint lint` không có warning/error mới.
- [ ] Build Debug (`#if DEBUG`) dùng `http://192.168.1.8:8080/api`; Release dùng `https://api.finflow.com/api` — không hardcode URL trong feature.
- [ ] String hiển thị bằng tiếng Việt (nhất quán với phần còn lại của app).

---

## 9.6 Những lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách sửa |
|-------------|-------------|----------|
| `Cannot find type 'AppRoute' in scope` | Quên `import FinFlowCore` trong ViewModel/Router | Thêm import |
| `Actor-isolated property ... can not be referenced from a non-isolated context` | Gọi repository (actor) từ nơi không `await` | Wrap trong `Task { await ... }` hoặc đổi hàm thành `async` |
| SwiftLint báo `no_cross_module_import` | Feature package import feature khác | Tách phần dùng chung lên `FinFlowCore` |
| SwiftLint báo `no_observable_object` | Dùng `ObservableObject`/`@Published` | Đổi sang `@Observable` + property thường (xem Ch.11) |
| Navigation không hoạt động | Thiếu `.navigationDestination` cho case mới, hoặc route `id` trùng | Thêm nhánh trong `AppRouter`; đảm bảo `id` khác biệt (dùng payload) |
| ViewModel không cập nhật UI | Dùng class thường thay vì `@Observable`, hoặc view quên `@Bindable` | Thêm `@Observable` + `@Bindable var viewModel` |

---

*Next: [Chapter 10 — Testing](./10-testing.md)*
