import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - GetTransactionSummaryUseCase Tests

@Suite("GetTransactionSummaryUseCase")
struct GetTransactionSummaryUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: GetTransactionSummaryUseCase, repository: MockTransactionRepository) {
        let sut = GetTransactionSummaryUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Success Path

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryOnce() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute()

        #expect(repository.getTransactionSummaryCallCount == 1)
    }

    @Test("execute trả về đúng summary từ repository")
    func execute_returnsSummaryFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedSummary = TransactionSummaryResponse(
            totalBalance: 1_200_000,
            totalIncome: 5_000_000,
            totalExpense: 3_800_000
        )

        let result = try await sut.execute()

        #expect(result.totalBalance == 1_200_000)
        #expect(result.totalIncome == 5_000_000)
        #expect(result.totalExpense == 3_800_000)
    }

    @Test("execute khi balance âm → trả về đúng giá trị âm")
    func execute_whenNegativeBalance_returnsCorrectNegativeValue() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedSummary = TransactionSummaryResponse(
            totalBalance: -500_000,
            totalIncome: 1_000_000,
            totalExpense: 1_500_000
        )

        let result = try await sut.execute()

        #expect(result.totalBalance == -500_000)
        #expect(result.totalExpense > result.totalIncome)
    }

    @Test("execute khi balance = 0 (thu = chi)")
    func execute_whenBalanceIsZero_returnsZeroBalance() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedSummary = TransactionSummaryResponse(
            totalBalance: 0,
            totalIncome: 2_000_000,
            totalExpense: 2_000_000
        )

        let result = try await sut.execute()

        #expect(result.totalBalance == 0)
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

    @Test("execute khi repository throw unauthorized → propagate error")
    func execute_whenRepositoryThrowsUnauthorized_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.unauthorized

        await #expect(throws: MockError.unauthorized) {
            _ = try await sut.execute()
        }
    }

    @Test("execute khi lỗi → không gọi repository lần thứ 2 (không tự retry)")
    func execute_onError_doesNotRetry() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.serverError(code: 500)

        _ = try? await sut.execute()

        #expect(repository.getTransactionSummaryCallCount == 1)
    }
}
