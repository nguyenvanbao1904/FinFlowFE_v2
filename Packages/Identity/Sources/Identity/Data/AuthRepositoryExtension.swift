import Foundation
import FinFlowCore

/// Extension để thêm các helper methods cho Repository
extension AuthRepository {
    /// Lấy cached profile (không cần network)
    /// Uses user-scoped cache key to avoid cross-account leakage.
    public func getCachedProfile() async -> UserProfile? {
        guard let cacheKey = await currentUserCacheKey() else { return nil }
        return try? await cacheService?.retrieve(
            forKey: cacheKey,
            as: UserProfile.self
        )
    }
    
    /// Load profile với offline support thông minh
    /// - Returns: Profile từ server (hoặc cached nếu offline)
    public func getMyProfileWithCache() async throws -> UserProfile {
        // 1. Trả về cached data ngay (nếu có) để UI responsive
        let cachedProfile = await getCachedProfile()
        
        // 2. Thử fetch từ server
        do {
            let freshProfile = try await getMyProfile()
            
            // Lưu lại cache theo userId sau khi fetch thành công
            if let cacheKey = await currentUserCacheKey(for: freshProfile.id) {
                try? await cacheService?.save(freshProfile, forKey: cacheKey)
            }
            return freshProfile
        } catch {
            // 3. Nếu lỗi network và có cache → dùng cache
            if let cached = cachedProfile {
                Logger.warning("Dùng cached profile do lỗi network", category: "Auth")
                return cached
            }
            
            // 4. Không có cache và lỗi network → throw error
            throw error
        }
    }
}
