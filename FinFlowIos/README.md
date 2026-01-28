# FinFlow iOS – kiến trúc và luồng đăng nhập

## Kiến trúc tổng quan
- **App shell**: `FinFlowIos/App/FinFlowIosApp.swift` khởi tạo DI container, router và dựng `NavigationStack`.
- **DI & hạ tầng**: `Core/DI/DependencyContainer.swift` ghép cấu hình (`AppConfig`), lưu trữ token (`KeychainTokenStore`), cache file (`FileCacheService`), HTTP client (`APIClient`), repository (`AuthRepository`) và các use case (`Login/GetProfile/Logout`).
- **Điều hướng**: `Core/Navigation/AppRouter.swift` giữ `NavigationPath`, điều hướng theo enum `Screen`.
- **Tính năng**: `Features/DashboardView.swift` + `DashboardViewModel.swift` cho màn dashboard. Màn đăng nhập nằm trong package `Identity` (`Presentation/LoginView`, `LoginViewModel`).
- **Packages chia lớp**:
  - `Packages/FinFlowCore`: logging, error, network, storage/token, cache, cấu hình mạng.
  - `Packages/Identity`: domain/auth (model, repository, use case), UI đăng nhập, lỗi xác thực.

## Cấu hình môi trường
- `Core/Configuration/AppConfig.swift` chọn baseURL theo build:
  - Debug: `http://192.168.1.8:8080/api`
  - Release: `https://api.finflow.com/api`
- `FinFlowCore/Configuration/NetworkConfig.swift` giữ `baseURL`. Thay đổi endpoint chỉ cần cập nhật `AppConfig`.

## Luồng khởi động ứng dụng
1. `@main FinFlowIosApp` tạo `DependencyContainer.shared` và `router`.
2. Dựng `NavigationStack(path: $router.path)` với màn đầu là `LoginView(viewModel: makeLoginViewModel())`.
3. `navigationDestination` map `Screen.login` → `LoginView`, `Screen.dashboard` → `DashboardView`.

## Luồng đăng nhập (UI → domain → network)
1. Người dùng nhập username/password ở `Identity/Presentation/LoginView`. Nhấn nút gọi `Task { await viewModel.login() }`.
2. `LoginViewModel.login()`:
   - Kiểm tra rỗng, hiển thị thông báo tại chỗ nếu thiếu.
   - Đặt trạng thái loading, xoá message cũ.
   - Gọi `LoginUseCase.execute(username, password)`.
3. `LoginUseCase.execute`:
   - Trim, minimal validation (không rỗng).
   - Tạo `LoginRequest` và gọi `AuthRepository.login(req)`.
4. `AuthRepository.login`:
   - POST `/auth/login` qua `APIClient`.
   - Lưu `token` vào `KeychainTokenStore`; lưu `refreshToken` (nếu có) vào `RefreshTokenStore`.
   - Trả về `LoginResponse`.
   - Nếu server trả lỗi → throw `AppError.serverError(code, message)` từ backend.
5. Trở lại `LoginViewModel`, khi thành công:
   - `message = "Đăng nhập thành công"`.
   - Gọi `onLoginSuccess` (được `FinFlowIosApp` gắn) → `router.navigate(to: .dashboard)` đẩy màn Dashboard.
6. Khi lỗi:
   - Log qua `Logger`.
   - `ErrorHandler` nhận lỗi (dùng chung toàn app) và `message` hiển thị ngay dưới form (màu đỏ).
   - Token/refresh token không bị ghi đè nếu login fail.

## Luồng vào Dashboard & tải profile
1. `FinFlowIosApp` tạo `DashboardViewModel` với `GetProfileUseCase` và `LogoutUseCase`, gắn `onLogout` để reset router.
2. `DashboardView`:
   - `.task { await viewModel.loadProfile() }` khi render lần đầu.
   - `.refreshable` gọi `refresh()` (đặt `isRefreshing = true` rồi `loadProfile`).
3. `DashboardViewModel.loadProfile()`:
   - Bật `isLoading` (trừ khi đang refresh), xoá lỗi cũ.
   - Gọi `GetProfileUseCase.execute()` → `AuthRepository.getMyProfile()`.
4. `AuthRepository.getMyProfile()`:
   - GET `/users/my-profile` qua `APIClient`.
   - Thành công: cache profile vào `FileCacheService` (`CacheKey.userProfile`), trả về `UserProfile`.
   - Nếu 401: Token hết hạn → throw `AppError.unauthorized`.
   - Lỗi khác: throw `AppError.serverError` với message từ backend.
5. UI hiển thị:
   - Đang tải → `ProgressView`.
   - Lỗi (và chưa có profile) → text lỗi + nút “Thử lại”.
   - Thành công → chào mừng, email, vai trò, nút “Đăng xuất”.
6. `DashboardViewModel.logout()`:
   - Gọi `LogoutUseCase.execute()` → `AuthRepository.logout()` xoá access token, refresh token, cache.
   - Gọi `onLogout` → `router.reset()` quay về stack trống (Login).

## Hành vi khi lỗi/ngoại tuyến
- **Sai username/password hoặc thiếu input**: Backend trả 401 → `AppError.serverError(1011, "Invalid username or password")`.
- **Mất kết nối**:
  - Login: `AppError.networkError` → hiển thị lỗi localized từ `AppError`.
  - Profile: nếu chưa có dữ liệu, lỗi được show; nếu đã có profile và lỗi khi refresh, UI chỉ log warning và giữ dữ liệu hiện tại.
- **Token hết hạn**: 401 ở profile → throw `AppError.unauthorized` → DashboardCoordinator.onLogout() → quay về login.

## Ghi chú triển khai
- APIClient gắn header `Authorization: Bearer <token>` nếu token tồn tại trong Keychain.
- Logging bật trong DEBUG, có phân cấp level và log request/response.
- Cache profile lưu ở Documents/Cache; bị xoá khi logout hoặc khi đọc cache lỗi.
- `AppConfig` là điểm duy nhất cần chỉnh để trỏ môi trường khác.


