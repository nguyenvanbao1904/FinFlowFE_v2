import Foundation

/// Protocol cho caching service
public protocol CacheServiceProtocol: Sendable {
    func save<T: Codable & Sendable>(_ data: T, forKey key: String) async throws
    func retrieve<T: Codable & Sendable>(forKey key: String, as type: T.Type) async throws -> T?
    func remove(forKey key: String) async throws
    func clear() async throws
}

/// File-based cache service - Lưu data vào file system
public actor FileCacheService: CacheServiceProtocol {
    private let fileManager: FileManager
    private let cacheDirectory: URL
    
    public init() throws {
        self.fileManager = FileManager.default
        
        // Tạo cache directory trong Library/Caches (đúng chuẩn iOS, tránh backup iCloud)
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesPath.appendingPathComponent("FinFlowCache", isDirectory: true)
        
        // Tạo directory nếu chưa có
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        Logger.info("Cache directory: \(cacheDirectory.path)", category: "Cache")
    }
    
    public func save<T: Codable & Sendable>(_ data: T, forKey key: String) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
            Logger.debug("Cached data for key: \(key)", category: "Cache")
        } catch {
            Logger.error("Failed to cache data for key \(key): \(error)", category: "Cache")
            throw AppError.unknown
        }
    }
    
    public func retrieve<T: Codable & Sendable>(forKey key: String, as type: T.Type) async throws -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        // Kiểm tra file có tồn tại không
        guard fileManager.fileExists(atPath: fileURL.path) else {
            Logger.debug("No cache found for key: \(key)", category: "Cache")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            Logger.debug("Retrieved cached data for key: \(key)", category: "Cache")
            return decoded
        } catch {
            Logger.error("Failed to retrieve cache for key \(key): \(error)", category: "Cache")
            // Xóa cache bị corrupt
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    public func remove(forKey key: String) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            Logger.debug("Removed cache for key: \(key)", category: "Cache")
        }
    }
    
    public func clear() async throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
        
        Logger.info("Cleared all cache", category: "Cache")
    }
}

/// Cache keys constants
public enum CacheKey {
    public static let userProfile = "user_profile"
    public static let transactions = "transactions"
    // Thêm keys khác khi cần
    
    /// User-scoped profile cache key to avoid cross-account leakage
    public static func userProfile(for userId: String) -> String {
        return "user_profile_\(userId)"
    }
    
    public static func transaction(id: String) -> String {
        return "transaction_\(id)"
    }
}
