//
//  DashboardRepository.swift
//  Dashboard
//
//  Created by Nguyễn Văn Bảo on 27/12/25.
//

import Foundation

/// Protocol định nghĩa các hành động mà Dashboard có thể thực hiện
/// Dashboard sử dụng các use cases từ Identity module
public protocol DashboardRepositoryProtocol {
    // Hiện tại Dashboard sử dụng trực tiếp GetProfileUseCase và LogoutUseCase từ Identity
    // Protocol này để dành cho các tính năng Dashboard riêng trong tương lai
}
