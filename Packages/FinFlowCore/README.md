# FinFlowCore Module

Module Core cho ứng dụng FinFlow iOS, cung cấp các chức năng nền tảng được chia sẻ cho toàn bộ ứng dụng.

## 📁 Cấu trúc

```
FinFlowCore/
├── Package.swift              # Package definition
└── Sources/FinFlowCore/
    ├── Configuration/         # App configuration
    │   └── NetworkConfig.swift
    ├── Error/                 # Error handling
    │   └── ErrorHandler.swift
    ├── Logging/               # Logging system
    │   └── Logger.swift
    ├── Models/                # Shared models
    │   ├── ApiResponse.swift
    │   └── AppError.swift
    ├── Network/               # Network layer
    │   ├── APIClient.swift
    │   └── HTTPClientProtocol.swift
    └── Storage/               # Data persistence
        ├── CacheService.swift
        ├── KeychainTokenStore.swift
        ├── RefreshTokenStore.swift
        └── TokenStore.swift
```

## 🎯 Chức năng chính

### 1. **Network Layer**

- `APIClient`: HTTP client với auto token refresh
- `HTTPClientProtocol`: Protocol cho network requests
- Tự động inject access token vào headers
- Tự động refresh token khi expired

### 2. **Storage Layer**

- `TokenStore`: Protocol cho token management
- `KeychainTokenStore`: Lưu tokens an toàn trong Keychain
- `CacheService`: Cache responses để offline support
- `RefreshTokenStore`: Quản lý refresh token logic

### 3. **Error Handling**

- `AppError`: Enum định nghĩa tất cả error types
- `ErrorHandler`: Centralized error handling
- Hỗ trợ error logging và user-friendly messages

### 4. **Logging System**

- `Logger`: Structured logging với categories
- Support multiple log levels (debug, info, warning, error)
- Timestamp và category cho mỗi log

### 5. **Configuration**

- `NetworkConfig`: Centralized network configuration
- `NetworkConfigProtocol`: Protocol để inject configuration

## 🔗 Dependencies

**Không có external dependencies** - module này là foundation layer

## 📝 Usage

### Network Client

```swift
import FinFlowCore

// Khởi tạo config
let config = NetworkConfig(baseURL: "https://api.example.com")

// Khởi tạo token store
let tokenStore = KeychainTokenStore()

// Tạo API client
let apiClient = APIClient(config: config, tokenStore: tokenStore)

// Thực hiện request
let response: MyModel = try await apiClient.request(
    endpoint: "/users/profile",
    method: .get
)
```

### Logger

```swift
import FinFlowCore

// Log messages
Logger.info("User logged in", category: "Auth")
Logger.error("Failed to load data", category: "Network")
Logger.debug("Token: \(token)", category: "Debug")
```

### Token Storage

```swift
import FinFlowCore

let tokenStore = KeychainTokenStore()

// Lưu tokens
await tokenStore.saveAccessToken("access_token_here")
await tokenStore.saveRefreshToken("refresh_token_here")

// Đọc tokens
if let token = await tokenStore.getAccessToken() {
    print("Current token: \(token)")
}

// Xóa tokens
await tokenStore.clearTokens()
```

### Cache Service

```swift
import FinFlowCore

let cacheService = try FileCacheService()

// Cache data
try await cacheService.save(data, forKey: "user_profile")

// Load cached data
if let cached = try await cacheService.load(forKey: "user_profile") {
    print("Loaded from cache")
}
```

## ✅ Features

- ✅ **Thread-safe**: Tất cả operations đều thread-safe với actors
- ✅ **Async/await**: Modern concurrency với Swift 6
- ✅ **Protocol-oriented**: Dễ test và mock
- ✅ **Type-safe**: Strongly typed với Codable
- ✅ **Error handling**: Comprehensive error types
- ✅ **Offline support**: Cache responses cho offline mode
- ✅ **Security**: Tokens được lưu an toàn trong Keychain

## 🏗️ Architecture

Module tuân theo **Protocol-Oriented Programming**:

- Định nghĩa protocols cho tất cả services
- Implement cụ thể có thể swap được
- Dễ dàng mock cho testing

## 🔒 Security

- Access tokens lưu trong **Keychain** với encryption
- Refresh tokens được bảo vệ
- Automatic token cleanup khi logout
- Secure network communication

## 📊 Logging Categories

- `App`: Application lifecycle events
- `Network`: Network requests và responses
- `Auth`: Authentication events
- `Cache`: Cache operations
- `Error`: Error events
- `Debug`: Debug information

## 🧪 Testing

Module được thiết kế để dễ test:

```swift
// Mock token store cho testing
class MockTokenStore: TokenStoreProtocol {
    var accessToken: String?
    var refreshToken: String?

    func saveAccessToken(_ token: String) async {
        accessToken = token
    }
    // ... implement other methods
}
```

## 📦 Export

Module này được các module khác sử dụng:

- **Identity**: Dùng APIClient, TokenStore, Logger
- **Dashboard**: Dùng Logger, ErrorHandler
- **FinFlowIos**: App configuration

## 🎯 Best Practices

1. **Luôn dùng Logger** thay vì print()
2. **Handle errors properly** với ErrorHandler
3. **Cache data** khi có thể để support offline
4. **Clear tokens** khi logout
5. **Use protocols** để dễ test và mock
