import Foundation

public actor APIClient: HTTPClientProtocol {
    private let config: any NetworkConfigProtocol
    private let tokenStore: (any TokenStoreProtocol)?
    private let apiVersion: String
    private let session: URLSession
    private var refreshHandler: (@Sendable () async throws -> String)?
    private var onUnauthorized: (@Sendable () async -> Void)?
    private var refreshTask: Task<String, any Error>?

    public init(
        config: any NetworkConfigProtocol,
        tokenStore: (any TokenStoreProtocol)? = nil,
        apiVersion: String = "1",
        session: URLSession? = nil,
        refreshHandler: (@Sendable () async throws -> String)? = nil,
        onUnauthorized: (@Sendable () async -> Void)? = nil
    ) {
        self.config = config
        self.tokenStore = tokenStore
        self.apiVersion = apiVersion
        self.refreshHandler = refreshHandler
        self.onUnauthorized = onUnauthorized
        self.session =
            session
            ?? {
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = 30
                configuration.timeoutIntervalForResource = 60
                configuration.waitsForConnectivity = true
                return URLSession(configuration: configuration)
            }()
    }

    // Entry point matching HTTPClientProtocol
    public func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?,
        version: String?
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: method,
            body: body,
            version: version,
            retryOn401: true
        )
    }

    // Internal entry with retry control
    public func request<T: Codable & Sendable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable & Sendable)? = nil,
        version: String? = nil,  // Override version cho request cụ thể
        retryOn401: Bool = true  // Cho phép tắt retry khi gọi refresh token
    ) async throws -> T {
        var retryAttempted = false

        func makeRequest(with tokenOverride: String? = nil) async throws -> URLRequest {
            guard let url = URL(string: config.baseURL + endpoint) else {
                throw AppError.networkError("URL không hợp lệ")
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(version ?? apiVersion, forHTTPHeaderField: "API-Version")

            // Đính kèm Authorization nếu có token (hoặc token override sau refresh)
            let bearer: String?
            if let override = tokenOverride {
                bearer = override
            } else {
                bearer = await tokenStore?.getToken()
            }
            if let token = bearer, !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            if let body = body {
                request.httpBody = try JSONEncoder().encode(body)
            }
            return request
        }

        while true {
            var request = try await makeRequest()
            logRequest(request, body: body)

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw AppError.networkError(error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkError("Phản hồi không hợp lệ")
            }

            logResponse(httpResponse, data: data)

            // Handle error responses (4xx, 5xx)
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401, retryOn401 {
                    do {
                        let token = try await refreshAccessToken()
                        if retryAttempted {
                            await onUnauthorized?()
                            throw AppError.unauthorized("Phiên đăng nhập hết hạn")
                        }
                        retryAttempted = true
                        request = try await makeRequest(with: token)
                        continue
                    } catch {
                        await onUnauthorized?()
                        throw AppError.unauthorized("Lỗi làm mới phiên đăng nhập")
                    }
                }

                // Prefer RFC 7807 ProblemDetail if backend returns it
                if let problem = try? JSONDecoder().decode(ProblemDetail.self, from: data) {
                    let message = problem.detail ?? problem.title ?? "Lỗi máy chủ"
                    let code = problem.code ?? problem.status ?? httpResponse.statusCode
                    Logger.error(
                        "Server error (ProblemDetail): Code \(code) - \(message)",
                        category: "Network")
                    throw AppError.serverError(code, message)
                }

                // Legacy ApiResponse fallback (if backend still wraps errors this way)
                if let errorResponse = try? JSONDecoder().decode(
                    ApiResponse<String>.self, from: data)
                {
                    let errorMessage = errorResponse.message ?? "Lỗi máy chủ"
                    Logger.error(
                        "Server error: Code \(errorResponse.code) - \(errorMessage)",
                        category: "Network")
                    throw AppError.serverError(errorResponse.code, errorMessage)
                }

                // Fallback to raw response body
                let serverMessage = String(data: data, encoding: .utf8) ?? "Lỗi máy chủ"
                throw AppError.serverError(httpResponse.statusCode, serverMessage)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                Logger.error("Decoding error: \(error)", category: "Network")
                throw AppError.decodingError
            }
        }
    }

    /// Cấu hình hook refresh sau khi khởi tạo (để tránh vòng phụ thuộc DI)
    public func configureAuthHooks(
        refreshHandler: @escaping @Sendable () async throws -> String,
        onUnauthorized: (@Sendable () async -> Void)? = nil
    ) {
        self.refreshHandler = refreshHandler
        self.onUnauthorized = onUnauthorized
    }

    private func logRequest(_ request: URLRequest, body: (any Encodable & Sendable)?) {
        let url = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"

        var bodyString: String? = nil
        if let body = body, let data = try? JSONEncoder().encode(body) {
            bodyString = String(data: data, encoding: .utf8)
        }

        Logger.logRequest(
            method,
            url: url,
            headers: request.allHTTPHeaderFields,
            body: bodyString
        )
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        let url = response.url?.absoluteString ?? ""
        let bodyString = String(data: data, encoding: .utf8)

        Logger.logResponse(
            response.statusCode,
            url: url,
            body: bodyString
        )
    }

    // MARK: - Token Refresh (single-flight)
    private func refreshAccessToken() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }
        guard let handler = refreshHandler else {
            throw AppError.unauthorized("Cấu hình xác thực không hợp lệ")
        }
        // capture handler in a nonisolated context-safe way
        let task = Task<String, any Error> {
            try await handler()
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
