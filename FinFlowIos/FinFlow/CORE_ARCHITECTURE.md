## FinFlow Core Architecture (App + FinFlowCore)

File này giúp nắm luồng “xương sống” giữa app iOS (`FinFlowIos`) và module core (`FinFlowCore`) trước khi đi sâu vào `Identity` và `Dashboard`.

---

### 1. Bức tranh tổng quát

- **`FinFlowIosApp` (entry point)**  
  - Tạo **`DependencyContainer.shared`** (DI container) và **`AppRouter`**.  
  - Khởi động app bằng `AppRootView(router: container, ...)`.  
  - Lần chạy đầu tiên gọi `sessionManager.restoreSession()` để quyết định user đang ở trạng thái nào.

- **`DependencyContainer` (DI + composition root)**  
  - Khởi tạo hạ tầng core (Keychain, TokenStore, Cache, APIClient, AuthRepository, OTP handler...).  
  - Tạo **`SessionManager`** từ `FinFlowCore`.  
  - Cung cấp factory cho ViewModel + View thông qua các extension:
    - `DependencyContainer+Identity`
    - `DependencyContainer+Dashboard`
    - `DependencyContainer+AppViews`

- **`SessionManager` (FinFlowCore)**  
  - Là **Single Source Of Truth** cho **trạng thái phiên** (`SessionState`) và user hiện tại.  
  - Xử lý: login, logout, refresh token, restore session, lock/unlock, PIN, v.v.  
  - Là class `@Observable`, nên thay đổi `state` sẽ được các observer (như `AppRouter`) nhìn thấy.

- **`AppRouter` (FinFlowIos)**  
  - Giữ `root: AppRoot` (màn chính hiện tại) và `path: NavigationPath` (stack SwiftUI).  
  - Dùng **Swift Observation** (`withObservationTracking`) để theo dõi `sessionManager.state` và map nó sang **root UI** tương ứng:
    - `.authentication` / `.welcomeBack` / `.dashboard` / `.locked` / `.splash`.

---

### 2. Dòng chảy khi app boot

1. **App khởi động**
   - `FinFlowIosApp` tạo:
     - `let container = DependencyContainer.shared`
     - `let router = AppRouter(sessionManager: container.sessionManager)`
   - Body hiển thị `AppRootView(router: router, container: container)`.

2. **Khôi phục phiên (restoreSession)**
   - Trong `.task` của `FinFlowIosApp`:
     - Nếu `isFirstLaunch == true` → `await container.sessionManager.restoreSession()`.
   - `SessionManager.restoreSession()` đọc:
     - Email / user info từ `UserDefaultsManager`
     - Token / refresh token từ `TokenStore`
     - Refresh token expiry cũng từ `UserDefaultsManager`.
   - Kết quả đặt **`state: SessionState`**:
     - `.unauthenticated` (chưa login)
     - `.sessionExpired(email, firstName, lastName)` (hết hạn, có user)
     - `.welcomeBack(email, ...)` (có refresh token, cần PIN)
     - `.authenticated(token, ...)` (đã login, token còn hạn)

3. **Router tự động phản ứng với state**
   - `AppRouter` được khởi tạo với `sessionManager`:
     - Gọi `startSessionObservation()` ngay trong `init`.
   - `startSessionObservation()`:
     - Dùng `withObservationTracking` để **đọc `sessionManager.state`** và gọi:
       - `handleStateChange(sessionManager.state)`
     - Đăng ký `onChange` để **gọi lại chính nó** khi `state` đổi (login, logout, refresh, lock, ...).

4. **`handleStateChange` map state → root UI**
   - Trong `AppRouter`:
     - `.authenticated` → `root = .dashboard`, `path = NavigationPath()`
     - `.welcomeBack` → `root = .welcomeBack`, `path = NavigationPath()`
     - `.unauthenticated` / `.sessionExpired` → `root = .authentication`, `path = NavigationPath()`
     - `.loading` / `.refreshing` → `root = .splash`
     - `.locked` → `root = .locked`
   - Mỗi lần đổi root, `AppRootView` sẽ render branch tương ứng.

---

### 3. `AppRootView` – nối Router với SwiftUI

- `AppRootView` là root SwiftUI view:

  - Bọc toàn bộ app trong:

    ```swift
    @Bindable var observableRouter = router

    NavigationStack(path: $observableRouter.path) {
        switch observableRouter.root {
        case .splash: ProgressView()
        case .authentication, .welcomeBack:
            container.makeAuthenticationView(router: router)
        case .dashboard:
            container.makeDashboardView(router: router)
        case .locked:
            if case .locked(let user, let bio) = container.sessionManager.state {
                container.makeLockScreenView(user: user, biometricAvailable: bio)
            } else {
                container.makeLoginView(router: router)
            }
        }
    }
    .navigationDestination(for: AppRoute.self) { route in
        makeDestination(for: route)
    }
    ```

- **Điểm chính:**
  - `root` quyết định **flow lớn** (auth vs dashboard vs lock vs splash).
  - `path` + `AppRoute` quyết định **màn con trong flow** (login, register, forgotPassword, ...).

---

### 4. `DependencyContainer` – DI và View factories

#### 4.1. Hạ tầng & Core services

- Trong `DependencyContainer.init()`:
  - Tạo:
    - `KeychainService`
    - `PINManager`
    - `UserDefaultsManager`
    - `AuthTokenStore` (access + refresh token)
    - `FileCacheService`
    - `APIClient` (cấu hình hook refresh token / unauthorized)
    - `AuthRepository`
    - `OTPInputHandler`
  - Tạo **`SessionManager`** với:
    - `tokenStore`, `authRepository`, `userDefaultsManager`, `pinManager`.

#### 4.2. ViewModel factories (trong các extension)

- `DependencyContainer+Identity`: tạo ViewModel cho Login, Register, ForgotPassword, WelcomeBack, LockScreen.
- `DependencyContainer+Dashboard`: tạo ViewModel cho dashboard container.

#### 4.3. View factories (trong `DependencyContainer+AppViews`)

- Để AppRootView không phải “biết” cách lắp ViewModel, container cung cấp:

  - `makeAuthenticationView(router:)`
    - Dựa trên `sessionManager.state`:
      - `welcomeBack` → `makeWelcomeBackView`
      - `sessionExpired` → `makeLoginView(prefillEmail:displayName:)`
      - mặc định → `makeLoginView()`

  - `makeLoginView(router:prefillEmail:userDisplayName:)`
    - Tạo `LoginViewModel` với router, sessionManager, userDefaults, v.v.
    - Nếu có `prefillEmail` (session expired) → prefill username + flag `isSessionExpired`.

  - `makeRegisterView(router:)`
    - Tạo `RegisterView` với `RegisterViewModel`:
      - `onSuccess` / `onNavigateToLogin` đều gọi `router.popToRoot()` (quay về Login root, không back stack).

  - `makeForgotPasswordView(router:)`
    - Tạo `ForgotPasswordView` với ViewModel:
      - `onSuccess(email)`:
        - Lưu email vào `UserDefaultsManager.saveEmailForPrefill(email)` (key `user_email`).
        - `router.popToRoot()` → quay về Login, LoginViewModel đọc lại email từ UserDefaults.

  - `makeWelcomeBackView(router:email:firstName:lastName:)`
    - Tạo WelcomeBackView + ViewModel với `onSwitchAccount`:
      - Gọi `sessionManager.logoutCompletely()` → state = `.unauthenticated` → quay về flow login.

  - `makeLockScreenView(user:biometricAvailable:)`
    - Tạo `LockScreenView` với `LockScreenViewModel`.

  - `makeDashboardView(router:)`
    - Tạo `DashboardView` với container ViewModel (`DashboardContainerViewModel`).

---

### 5. SessionManager – điều khiển state

- `SessionManager` là `@Observable`:
  - `state: SessionState` – trạng thái phiên:
    - `.loading`, `.refreshing`
    - `.unauthenticated`
    - `.authenticated(token:isRestored:)`
    - `.sessionExpired(email, firstName, lastName)`
    - `.welcomeBack(email, firstName, lastName)`
    - `.locked(user, biometricAvailable)`

- Các hành động chính:
  - `restoreSession()` – quyết định state ban đầu dựa trên UserDefaults + TokenStore.
  - `login(response:)` – lưu session (token + refresh token + expiry) rồi set `.authenticated`.
  - `logout()` – giữ refresh token + user info → `.welcomeBack`.
  - `logoutCompletely()` – xoá sạch → `.unauthenticated`.
  - `refreshSession()` / `refreshSessionSilently()` – refresh token, update state nếu thành công/thất bại.
  - `handleSessionExpired()` – set `.sessionExpired` với email/firstName/lastName từ UserDefaults.
  - `lockSession()` / `unlockSession()` – dùng cho privacy timeout → `.locked` → quay lại `.authenticated` sau unlock.

- Mỗi lần `state` thay đổi → `AppRouter` (observer) cập nhật root + path, kéo theo SwiftUI render lại flow tương ứng.

---

### 6. Kết nối tất cả lại (luồng chuẩn)

1. App start → `restoreSession()` → `state` (vd `.unauthenticated`).
2. `AppRouter` quan sát `state` → `root = .authentication`, path rỗng.
3. `AppRootView` thấy root `.authentication` → gọi `container.makeAuthenticationView(router:)` → trả về LoginView (hoặc WelcomeBackView, tuỳ state).
4. User login:
   - `LoginViewModel.login()` → `AuthRepository.login()` → `SessionManager.login(response)`.
   - `login` set `state = .authenticated(...)`.
5. `AppRouter` nhận state mới → `root = .dashboard`, clear path.
6. `AppRootView` render dashboard bằng `container.makeDashboardView(router:)`.

Với luồng quên mật khẩu, session expired, khoá bằng PIN, dashboard, v.v. tất cả đều quay lại 3 mảnh lõi:
- **SessionManager** quyết định `state`.
- **AppRouter** map `state` → `AppRoot` + `NavigationPath`.
- **DependencyContainer** lắp View/VM tương ứng với `root` + `AppRoute`.

