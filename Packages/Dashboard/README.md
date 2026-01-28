# Dashboard Module

Module Dashboard cho ứng dụng FinFlow iOS, theo kiến trúc Clean Architecture.

## 📁 Cấu trúc

```
Dashboard/
├── Package.swift              # Package definition
└── Sources/Dashboard/
    ├── Dashboard.swift        # Entry point
    ├── Data/                  # Models
    │   └── DashboardModels.swift
    ├── Domain/                # Business logic
    │   ├── DashboardRepository.swift
    │   └── UseCases/
    │       └── DashboardUseCases.swift
    └── Presentation/          # UI layer
        ├── DashboardView.swift
        └── DashboardViewModel.swift
```

## 🎯 Chức năng

- Hiển thị thông tin profile người dùng
- Xử lý đăng xuất
- Refresh profile data
- Error handling và loading states

## 🔗 Dependencies

- **FinFlowCore**: Core functionalities (Network, Logger, Error handling)
- **Identity**: Authentication và User profile models

## 🏗️ Architecture

Module tuân theo **Clean Architecture** với 3 layers:

1. **Data Layer**: Models và data structures
2. **Domain Layer**: Business logic, UseCases, Repository protocols
3. **Presentation Layer**: SwiftUI Views và ViewModels

## 📝 Usage

```swift
import Dashboard

// Khởi tạo ViewModel với dependencies
let viewModel = DashboardViewModel(
    getProfileUseCase: getProfileUseCase,
    logoutUseCase: logoutUseCase
)

// Sử dụng trong SwiftUI
DashboardView(viewModel: viewModel)
```

## ✅ Benefits

- ✅ Tách biệt rõ ràng giữa các concerns
- ✅ Dễ test và maintain
- ✅ Có thể tái sử dụng cho nhiều apps
- ✅ Dependencies rõ ràng qua Package.swift
- ✅ Build time nhanh hơn với modular architecture
