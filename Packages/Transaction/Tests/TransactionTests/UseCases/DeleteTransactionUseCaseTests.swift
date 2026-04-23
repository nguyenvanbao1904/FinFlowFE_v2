import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - DeleteTransactionUseCase Tests

@Suite("DeleteTransactionUseCase")
struct DeleteTransactionUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: DeleteTransactionUseCase, repository: MockTransactionRepository) {
        let sut = DeleteTransactionUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Success Path

    @Test("execute thành công không throw error")
    func execute_success_doesNotThrow() async throws {
        let (sut, _) = makeSUT()
        try await sut.execute(id: "txn-001")
    }

    @Test("execute truyền đúng ID xuống repository")
    func execute_forwardsCorrectIdToRepository() async throws {
        let trackingRepository = TrackingDeleteRepository()
        let sut = DeleteTransactionUseCase(repository: trackingRepository)

        try await sut.execute(id: "txn-abc-123")

        #expect(trackingRepository.lastDeletedId == "txn-abc-123")
    }

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryExactlyOnce() async throws {
        let trackingRepository = TrackingDeleteRepository()
        let sut = DeleteTransactionUseCase(repository: trackingRepository)

        try await sut.execute(id: "txn-001")

        #expect(trackingRepository.deleteTransactionCallCount == 1)
    }

    @Test("execute với nhiều ID khác nhau → mỗi lần forward đúng ID")
    func execute_withDifferentIds_forwardsCorrectId() async throws {
        let trackingRepository = TrackingDeleteRepository()
        let sut = DeleteTransactionUseCase(repository: trackingRepository)

        try await sut.execute(id: "txn-first")
        #expect(trackingRepository.lastDeletedId == "txn-first")

        try await sut.execute(id: "txn-second")
        #expect(trackingRepository.lastDeletedId == "txn-second")
        #expect(trackingRepository.deleteTransactionCallCount == 2)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw networkFailure → propagate error")
    func execute_whenRepositoryThrowsNetworkError_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            try await sut.execute(id: "txn-001")
        }
    }

    @Test("execute khi repository throw serverError 404 → propagate error")
    func execute_whenTransactionNotFound_propagatesNotFoundError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.serverError(code: 404)

        await #expect(throws: MockError.serverError(code: 404)) {
            try await sut.execute(id: "txn-not-found")
        }
    }
}

// MARK: - Tracking Mock

private final class TrackingDeleteRepository: MockTransactionRepository {
    var deleteTransactionCallCount = 0
    var lastDeletedId: String?

    override func deleteTransaction(id: String) async throws {
        if let error = errorToThrow { throw error }
        deleteTransactionCallCount += 1
        lastDeletedId = id
    }
}
