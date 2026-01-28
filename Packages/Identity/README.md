# Identity Module

Module Identity cho ứng dụng FinFlow iOS, xử lý authentication và user management theo kiến trúc Clean Architecture.

## 📁 Cấu trúc

```
Identity/
├── Package.swift              # Package definition
└── Sources/Identity/
    ├── Identity.swift         # Entry point
    ├── Data/                  # Data layer
    │   └── DashboardModels.swift
    ├── Domain/                # Business logic
    │   ├── AuthRepository.swift
    │   └── UseCases/
    │       └── AuthUseCases.swift
    └── Presentation/          # UI layer
        ├── LoginView.swift
        ├── LoginViewModel.swift
        └── Coordinator/
            └── AuthCoordinator.swift
```

## 🎯 Chức năng chính

### 1. **Authentication**

- Login với email/password
- Automatic token management
- Token refresh tự động
- Logout và clear session

### 2. **User Profile Management**

- Get user profile
- Cache profile data
- Offline support
- Auto refresh profile

### 3. **Session Management**

- Token persistence trong Keychain
- Auto-login khi app khởi động
- Session validation
- Secure logout

## 🔗 Dependencies

- **FinFlowCore**: Core functionalities (Network, Storage, Logger, Error handling)

## 📝 Models

### LoginRequest & LoginResponse

```swift
// Login request
public struct LoginRequest: Codable {
    let username: String
    let password: String
}

// Login response
public struct LoginResponse: Codable {
    let token: String
    let type: String  // "Bearer"
    let username: String
    let email: String
}

// User profile
public struct UserProfile: Codable, Identifiable {
    public let id: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let roles: [String]
}
```

⚠️ **Error Handling:**
- Không còn `AuthError.swift` (deprecated & deleted)
- Sử dụng `AppError` từ FinFlowCore
- Frontend hiển thị trực tiếp backend messages

## 🏗️ Architecture - Clean Architecture

### Data Layer

- **Models**: Request/Response DTOs (LoginRequest, LoginResponse, UserProfile)
- **Errors**: Sử dụng `AppError` từ FinFlowCore (không còn AuthError)

### Domain Layer

- **Repository Protocol**: `AuthRepositoryProtocol`
- **Repository Implementation**: `AuthRepository`
- **Use Cases**:
  - `LoginUseCaseProtocol` / `LoginUseCase`
  - `GetProfileUseCaseProtocol` / `GetProfileUseCase`
  - `LogoutUseCaseProtocol` / `LogoutUseCase`

### Presentation Layer

- **Views**: `LoginView.swift` (SwiftUI)
- **ViewModels**: `LoginViewModel.swift` (ObservableObject)

## 📝 Usage

### Login Flow

```swift
import Identity

// 1. Khởi tạo dependencies
let apiClient = APIClient(config: networkConfig, tokenStore: tokenStore)
let cacheService = try FileCacheService()
let repository = AuthRepository(
    apiClient: apiClient,
    tokenStore: tokenStore,
    cacheService: cacheService
)

// 2. Tạo use case
let loginUseCase = LoginUseCase(repository: repository)

// 3. Tạo ViewModel
let viewModel = LoginViewModel(loginUseCase: loginUseCase)
viewModel.onLoginSuccess = {
    // Navigate to dashboard
}

// 4. Sử dụng trong SwiftUI
LoginView(viewModel: viewModel)
```

### Get Profile

```swift
let getProfileUseCase = GetProfileUseCase(repository: repository)

do {
    let profile = try await getProfileUseCase.execute()
    print("Welcome \(profile.firstName)!")
} catch {
    print("Failed to load profile: \(error)")
}
```

### Logout

```swift
let logoutUseCase = LogoutUseCase(repository: repository)

await logoutUseCase.execute()
// Tokens cleared, cache cleared
```

## 🎨 UI Components

### LoginView

```swift
public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        // Email/Password form
        // Login button
        // Loading state
        // Error messages
    }
}
```

### LoginViewModel

```swift
@MainActor
public class LoginViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public var onLoginSuccess: (() -> Void)?

    public func login() async {
        // Validate input
        // Call login use case
        // Handle success/error
        // Trigger onLoginSuccess callback
    }
}
```

## ✅ Features

- ✅ **Clean Architecture**: Separation of concerns rõ ràng
- ✅ **Use Cases**: Business logic được encapsulate
- ✅ **Protocol-oriented**: Dễ test và mock
- ✅ **Async/await**: Modern Swift concurrency
- ✅ **Error handling**: Comprehensive error types
- ✅ **Caching**: Profile data được cache
- ✅ **Offline support**: Hiển thị cached profile khi offline
- ✅ **SwiftUI**: Modern declarative UI
- ✅ **MVVM**: Clear separation giữa UI và logic
- ✅ **Dependency Injection**: Dependencies được inject qua constructor

## 🔒 Security

- **Tokens** được lưu an toàn trong Keychain
- **Password** không được cache
- **Automatic token refresh** khi expired
- **Secure logout** xóa tất cả sensitive data

## 🧪 Testing

Module được thiết kế để dễ test:

```swift
// Mock Repository
class MockAuthRepository: AuthRepositoryProtocol {
    var shouldSucceed = true
    var mockProfile: UserProfile?

    func login(email: String, password: String) async throws -> LoginResponse {
        if shouldSucceed {
            return LoginResponse(/* mock data */)
        } else {
            throw AppError.serverError(1011, "Invalid username or password")
        }
    }
    // ... implement other methods
}

// Test ViewModel
@MainActor
func testLoginSuccess() async {
    let mockRepo = MockAuthRepository()
    let useCase = LoginUseCase(repository: mockRepo)
    let viewModel = LoginViewModel(loginUseCase: useCase)

    viewModel.email = "test@example.com"
    viewModel.password = "password"

    await viewModel.login()

    XCTAssertNil(viewModel.errorMessage)
}
```

## 📊 Use Cases Flow

```
LoginView
    ↓
LoginViewModel
    ↓
LoginUseCase
    ↓
AuthRepository
    ↓
APIClient → Backend
    ↓
TokenStore → Keychain
    ↓
CacheService → File System
```

## 🎯 Best Practices

1. **Sử dụng Use Cases** thay vì gọi Repository trực tiếp
2. **Inject dependencies** qua constructor
3. **Handle errors** ở ViewModel layer
4. **Cache profile data** để support offline
5. **Clear sensitive data** khi logout
6. **Use protocols** để dễ test và swap implementations
7. **Validate input** trước khi call use cases
8. **Show loading states** khi async operations
9. **Display user-friendly errors** trong UI

## 📦 Public APIs

Module export các public APIs sau:

### Models

- `LoginRequest`, `LoginResponse`
- `UserProfile`
- ⚠️ `AuthError` - DEPRECATED & DELETED (use `AppError` from FinFlowCore)

### Protocols

- `AuthRepositoryProtocol`
- `LoginUseCaseProtocol`, `GetProfileUseCaseProtocol`, `LogoutUseCaseProtocol`

### Implementations

- `AuthRepository`
- `LoginUseCase`, `GetProfileUseCase`, `LogoutUseCase`

### Views

- `LoginView`
- `LoginViewModel`

### Coordinators

- `AuthCoordinator` - Quản lý authentication navigation flow

## 🔄 State Management

ViewModel sử dụng `@Published` properties để reactive UI updates:

```swift
@Published public var isLoading: Bool
@Published public var errorMessage: String?
@Published public var email: String
@Published public var password: String
```

## 🚀 Future Enhancements

- [ ] Social login (Google, Apple)
- [ ] Two-factor authentication
- [ ] Password reset flow
- [ ] Email verification
- [ ] Biometric authentication
- [ ] Remember me functionality
- [ ] User registration
