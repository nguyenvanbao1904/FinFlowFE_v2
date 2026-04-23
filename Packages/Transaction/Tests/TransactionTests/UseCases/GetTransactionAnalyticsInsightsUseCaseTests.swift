import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - GetTransactionAnalyticsInsightsUseCase Tests

@Suite("GetTransactionAnalyticsInsightsUseCase")
struct GetTransactionAnalyticsInsightsUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: GetTransactionAnalyticsInsightsUseCase, repository: MockTransactionRepository) {
        let sut = GetTransactionAnalyticsInsightsUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Success Path

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryOnce() async throws {
        let trackingRepository = TrackingInsightsRepository()
        let sut = GetTransactionAnalyticsInsightsUseCase(repository: trackingRepository)

        _ = try await sut.execute()

        #expect(trackingRepository.insightsCallCount == 1)
    }

    @Test("execute khi không có insights → trả về empty insights array")
    func execute_whenNoInsights_returnsEmptyInsights() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedInsights = TransactionAnalyticsInsightsResponse.mockEmpty()

        let result = try await sut.execute()

        #expect(result.insights.isEmpty)
    }

    @Test("execute trả về cached = true khi dữ liệu từ cache")
    func execute_whenDataIsCached_returnsCachedTrue() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedInsights = TransactionAnalyticsInsightsResponse(insights: [], cached: true)

        let result = try await sut.execute()

        #expect(result.cached == true)
    }

    @Test("execute trả về cached = false khi dữ liệu fresh từ server")
    func execute_whenDataIsFresh_returnsCachedFalse() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedInsights = TransactionAnalyticsInsightsResponse(insights: [], cached: false)

        let result = try await sut.execute()

        #expect(result.cached == false)
    }

    @Test("execute gọi 2 lần liên tiếp → repository cũng được gọi 2 lần (không cache trong UseCase)")
    func execute_calledTwice_callsRepositoryTwice() async throws {
        let trackingRepository = TrackingInsightsRepository()
        let sut = GetTransactionAnalyticsInsightsUseCase(repository: trackingRepository)

        _ = try await sut.execute()
        _ = try await sut.execute()

        #expect(trackingRepository.insightsCallCount == 2)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw networkFailure → propagate error")
    func execute_whenRepositoryThrowsNetworkError_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute()
        }
    }

    @Test("execute khi lỗi → không retry tự động")
    func execute_onError_doesNotRetry() async {
        let trackingRepository = TrackingInsightsRepository()
        trackingRepository.errorToThrow = MockError.serverError(code: 500)
        let sut = GetTransactionAnalyticsInsightsUseCase(repository: trackingRepository)

        _ = try? await sut.execute()

        #expect(trackingRepository.insightsCallCount == 1)
    }
}

// MARK: - Tracking Mock

private final class TrackingInsightsRepository: MockTransactionRepository {
    var insightsCallCount = 0

    override func getAnalyticsInsights() async throws -> TransactionAnalyticsInsightsResponse {
        if let error = errorToThrow { throw error }
        insightsCallCount += 1
        return stubbedInsights
    }
}
