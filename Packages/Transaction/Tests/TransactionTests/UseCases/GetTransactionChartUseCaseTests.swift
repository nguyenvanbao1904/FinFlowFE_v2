import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - GetTransactionChartUseCase Tests

@Suite("GetTransactionChartUseCase")
struct GetTransactionChartUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: GetTransactionChartUseCase, repository: MockTransactionRepository) {
        let sut = GetTransactionChartUseCase(repository: repository)
        return (sut, repository)
    }

    private let referenceDate = Date(timeIntervalSince1970: 1_744_502_400)

    // MARK: - Success Path

    @Test("execute thành công trả về TransactionChartResponse từ repository")
    func execute_success_returnsChartFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedChart = TransactionChartResponse(
            dataPoints: [
                .init(label: "T2", income: 500_000, expense: 300_000),
                .init(label: "T3", income: 0, expense: 200_000)
            ],
            periodLabel: "Tuần 15/2026",
            hasNext: true
        )

        let result = try await sut.execute(range: .week, referenceDate: referenceDate)

        #expect(result.dataPoints.count == 2)
        #expect(result.periodLabel == "Tuần 15/2026")
        #expect(result.hasNext == true)
    }

    @Test("execute truyền đúng range xuống repository")
    func execute_forwardsRangeToRepository() async throws {
        let trackingRepository = TrackingChartRepository()
        let sut = GetTransactionChartUseCase(repository: trackingRepository)

        _ = try await sut.execute(range: .month, referenceDate: referenceDate)

        #expect(trackingRepository.lastRange == .month)
    }

    @Test("execute truyền đúng referenceDate xuống repository")
    func execute_forwardsReferenceDateToRepository() async throws {
        let trackingRepository = TrackingChartRepository()
        let sut = GetTransactionChartUseCase(repository: trackingRepository)

        _ = try await sut.execute(range: .week, referenceDate: referenceDate)

        #expect(trackingRepository.lastReferenceDate == referenceDate)
    }

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryOnce() async throws {
        let trackingRepository = TrackingChartRepository()
        let sut = GetTransactionChartUseCase(repository: trackingRepository)

        _ = try await sut.execute(range: .year, referenceDate: referenceDate)

        #expect(trackingRepository.chartCallCount == 1)
    }

    @Test("execute với mỗi ChartRange đều forward đúng range", arguments: ChartRange.allCases)
    func execute_withEachRange_forwardsCorrectRange(range: ChartRange) async throws {
        let trackingRepository = TrackingChartRepository()
        let sut = GetTransactionChartUseCase(repository: trackingRepository)

        _ = try await sut.execute(range: range, referenceDate: referenceDate)

        #expect(trackingRepository.lastRange == range)
    }

    @Test("execute khi không có data → trả về empty dataPoints")
    func execute_whenNoData_returnsEmptyDataPoints() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedChart = TransactionChartResponse.mockEmpty()

        let result = try await sut.execute(range: .week, referenceDate: referenceDate)

        #expect(result.dataPoints.isEmpty)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw → propagate error")
    func execute_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute(range: .week, referenceDate: referenceDate)
        }
    }

    @Test("execute khi lỗi → không retry tự động")
    func execute_onError_doesNotRetry() async {
        let trackingRepository = TrackingChartRepository()
        trackingRepository.errorToThrow = MockError.networkFailure
        let sut = GetTransactionChartUseCase(repository: trackingRepository)

        _ = try? await sut.execute(range: .week, referenceDate: referenceDate)

        #expect(trackingRepository.chartCallCount == 1)
    }
}

// MARK: - Tracking Mock

private final class TrackingChartRepository: MockTransactionRepository {
    var chartCallCount = 0
    var lastRange: ChartRange?
    var lastReferenceDate: Date?

    override func getChart(range: ChartRange, referenceDate: Date) async throws -> TransactionChartResponse {
        if let error = errorToThrow { throw error }
        chartCallCount += 1
        lastRange = range
        lastReferenceDate = referenceDate
        return stubbedChart
    }
}
