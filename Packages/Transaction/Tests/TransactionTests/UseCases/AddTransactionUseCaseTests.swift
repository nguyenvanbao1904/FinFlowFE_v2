import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - AddTransactionUseCase Tests
// Kiểm tra Business Rule: UseCase forward đúng request đến Repository,
// và propagate error khi Repository throw.

@Suite("AddTransactionUseCase")
struct AddTransactionUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: AddTransactionUseCase, repository: MockTransactionRepository) {
        let sut = AddTransactionUseCase(repository: repository)
        return (sut, repository)
    }

    private func makeRequest(
        amount: Double = 150_000,
        type: TransactionType = .expense,
        categoryId: String = "cat-001",
        accountId: String = "acc-001",
        note: String? = "Cơm trưa",
        transactionDate: String = "2026-04-13T12:00:00"
    ) -> AddTransactionRequest {
        AddTransactionRequest(
            amount: amount,
            type: type,
            categoryId: categoryId,
            accountId: accountId,
            note: note,
            transactionDate: transactionDate
        )
    }

    // MARK: - Success Path

    @Test("execute thành công trả về TransactionResponse từ repository")
    func execute_success_returnsTransactionFromRepository() async throws {
        let (sut, repository) = makeSUT()
        let expectedTransaction = TransactionResponse.mock(id: "txn-999", amount: 150_000)
        repository.stubbedTransactionResult = expectedTransaction
        let request = makeRequest(amount: 150_000)

        let result = try await sut.execute(request: request)

        #expect(result.id == "txn-999")
        #expect(result.amount == 150_000)
    }

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryExactlyOnce() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(request: makeRequest())

        #expect(repository.addTransactionCallCount == 1)
    }

    @Test("execute truyền đúng request xuống repository")
    func execute_forwardsRequestToRepository() async throws {
        let (sut, repository) = makeSUT()
        let request = makeRequest(
            amount: 500_000,
            type: .income,
            categoryId: "cat-income-001",
            accountId: "acc-wallet",
            note: "Lương tháng 4",
            transactionDate: "2026-04-01T08:00:00"
        )

        _ = try await sut.execute(request: request)

        let captured = try #require(repository.lastAddTransactionRequest)
        #expect(captured.amount == 500_000)
        #expect(captured.type == .income)
        #expect(captured.categoryId == "cat-income-001")
        #expect(captured.accountId == "acc-wallet")
        #expect(captured.note == "Lương tháng 4")
        #expect(captured.transactionDate == "2026-04-01T08:00:00")
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw networkFailure → propagate lên caller")
    func execute_whenRepositoryThrowsNetworkError_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute(request: makeRequest())
        }
    }

    @Test("execute khi repository throw unauthorized → propagate lên caller")
    func execute_whenRepositoryThrowsUnauthorized_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.unauthorized

        await #expect(throws: MockError.unauthorized) {
            _ = try await sut.execute(request: makeRequest())
        }
    }

    @Test("execute khi lỗi → repository chỉ được gọi 1 lần (không retry tự động)")
    func execute_onError_doesNotRetry() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        _ = try? await sut.execute(request: makeRequest())

        // UseCase không tự retry — gọi đúng 1 lần, lỗi để caller xử lý
        #expect(repository.addTransactionCallCount == 1)
    }
}
