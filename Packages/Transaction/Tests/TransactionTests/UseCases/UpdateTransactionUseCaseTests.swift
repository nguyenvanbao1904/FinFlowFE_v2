import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - UpdateTransactionUseCase Tests

@Suite("UpdateTransactionUseCase")
struct UpdateTransactionUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: UpdateTransactionUseCase, repository: MockTransactionRepository) {
        let sut = UpdateTransactionUseCase(repository: repository)
        return (sut, repository)
    }

    private func makeRequest(
        amount: Double = 200_000,
        type: TransactionType = .expense,
        categoryId: String = "cat-001",
        accountId: String = "acc-001",
        note: String? = "Sửa ghi chú",
        transactionDate: String = "2026-04-13T12:00:00"
    ) -> AddTransactionRequest {
        AddTransactionRequest(
            amount: amount, type: type, categoryId: categoryId,
            accountId: accountId, note: note, transactionDate: transactionDate
        )
    }

    // MARK: - Success Path

    @Test("execute thành công trả về TransactionResponse từ repository")
    func execute_success_returnsUpdatedTransactionFromRepository() async throws {
        let (sut, repository) = makeSUT()
        let expected = TransactionResponse.mock(id: "txn-001", amount: 200_000)
        repository.stubbedTransactionResult = expected

        let result = try await sut.execute(id: "txn-001", request: makeRequest(amount: 200_000))

        #expect(result.id == "txn-001")
        #expect(result.amount == 200_000)
    }

    @Test("execute truyền đúng id và request xuống repository")
    func execute_forwardsIdAndRequestToRepository() async throws {
        let trackingRepository = TrackingUpdateRepository()
        let sut = UpdateTransactionUseCase(repository: trackingRepository)
        let request = makeRequest(amount: 350_000, type: .income, categoryId: "cat-inc", accountId: "acc-bank", note: "Tiền thưởng")

        _ = try await sut.execute(id: "txn-xyz", request: request)

        #expect(trackingRepository.lastUpdatedId == "txn-xyz")
        let captured = try #require(trackingRepository.lastUpdatedRequest)
        #expect(captured.amount == 350_000)
        #expect(captured.type == .income)
        #expect(captured.note == "Tiền thưởng")
    }

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryExactlyOnce() async throws {
        let trackingRepository = TrackingUpdateRepository()
        let sut = UpdateTransactionUseCase(repository: trackingRepository)

        _ = try await sut.execute(id: "txn-001", request: makeRequest())

        #expect(trackingRepository.updateCallCount == 1)
    }

    @Test("execute cho phép note = nil (xóa ghi chú)")
    func execute_withNilNote_forwardsNilNoteToRepository() async throws {
        let trackingRepository = TrackingUpdateRepository()
        let sut = UpdateTransactionUseCase(repository: trackingRepository)

        _ = try await sut.execute(id: "txn-001", request: makeRequest(note: nil))

        let captured = try #require(trackingRepository.lastUpdatedRequest)
        #expect(captured.note == nil)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw → propagate error")
    func execute_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute(id: "txn-001", request: makeRequest())
        }
    }

    @Test("execute khi lỗi → không retry tự động")
    func execute_onError_doesNotRetry() async {
        let trackingRepository = TrackingUpdateRepository()
        trackingRepository.errorToThrow = MockError.networkFailure
        let sut = UpdateTransactionUseCase(repository: trackingRepository)

        _ = try? await sut.execute(id: "txn-001", request: makeRequest())

        #expect(trackingRepository.updateCallCount == 1)
    }
}

// MARK: - Tracking Mock

private final class TrackingUpdateRepository: MockTransactionRepository {
    var updateCallCount = 0
    var lastUpdatedId: String?
    var lastUpdatedRequest: AddTransactionRequest?

    override func updateTransaction(id: String, request: AddTransactionRequest) async throws -> TransactionResponse {
        if let error = errorToThrow { throw error }
        updateCallCount += 1
        lastUpdatedId = id
        lastUpdatedRequest = request
        return stubbedTransactionResult
    }
}
