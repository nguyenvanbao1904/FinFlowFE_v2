import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - GetCategoriesUseCase Tests

@Suite("GetCategoriesUseCase")
struct GetCategoriesUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: GetCategoriesUseCase, repository: MockTransactionRepository) {
        let sut = GetCategoriesUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Success Path

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryOnce() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute()

        #expect(repository.getCategoriesCallCount == 1)
    }

    @Test("execute trả về đúng danh sách categories từ repository")
    func execute_returnsCategoriesFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCategories = [
            CategoryResponse.mock(id: "cat-001", name: "Ăn uống", type: .expense),
            CategoryResponse.mock(id: "cat-002", name: "Di chuyển", type: .expense),
            CategoryResponse.mock(id: "cat-003", name: "Lương", type: .income)
        ]

        let result = try await sut.execute()

        #expect(result.count == 3)
        #expect(result[0].id == "cat-001")
        #expect(result[2].id == "cat-003")
    }

    @Test("execute khi danh sách trống → trả về empty array")
    func execute_whenNoCategoriesExist_returnsEmptyArray() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCategories = []

        let result = try await sut.execute()

        #expect(result.isEmpty)
    }

    @Test("execute trả về đúng type của từng category")
    func execute_preservesCategoryTypes() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedCategories = [
            CategoryResponse.mock(id: "exp", type: .expense),
            CategoryResponse.mock(id: "inc", type: .income)
        ]

        let result = try await sut.execute()

        #expect(result.filter { $0.type == .expense }.count == 1)
        #expect(result.filter { $0.type == .income }.count == 1)
    }

    @Test("execute gọi 2 lần → repository cũng được gọi 2 lần (không cache trong UseCase)")
    func execute_calledTwice_callsRepositoryTwice() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute()
        _ = try await sut.execute()

        #expect(repository.getCategoriesCallCount == 2)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw networkFailure → propagate error")
    func execute_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute()
        }
    }

    @Test("execute khi lỗi → không retry tự động")
    func execute_onError_doesNotRetry() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.serverError(code: 500)

        _ = try? await sut.execute()

        #expect(repository.getCategoriesCallCount == 1)
    }
}
