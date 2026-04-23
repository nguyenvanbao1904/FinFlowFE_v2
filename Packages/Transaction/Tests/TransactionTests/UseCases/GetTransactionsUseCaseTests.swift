import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - GetTransactionsUseCase Tests

@Suite("GetTransactionsUseCase")
struct GetTransactionsUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: GetTransactionsUseCase, repository: MockTransactionRepository) {
        let sut = GetTransactionsUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Default Params

    @Test("execute với default params gọi repository đúng 1 lần")
    func execute_withDefaultParams_callsRepositoryOnce() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 0)

        #expect(repository.getTransactionsCallCount == 1)
    }

    @Test("execute truyền đúng page number xuống repository")
    func execute_withPageNumber_forwardsPageToRepository() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 3)

        #expect(repository.lastGetTransactionsPage == 3)
    }

    @Test("execute với size tùy chỉnh truyền đúng size xuống repository")
    func execute_withCustomSize_forwardsSizeToRepository() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 0, size: 50)

        #expect(repository.lastGetTransactionsSize == 50)
    }

    // MARK: - Search Keyword

    @Test("execute với keyword truyền đúng keyword xuống repository")
    func execute_withSearchKeyword_forwardsKeywordToRepository() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 0, keyword: "cà phê")

        #expect(repository.lastGetTransactionsKeyword == "cà phê")
    }

    @Test("execute không có keyword → repository nhận nil")
    func execute_withoutKeyword_passesNilToRepository() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 0, keyword: nil)

        #expect(repository.lastGetTransactionsKeyword == nil)
    }

    // MARK: - Date Filter

    @Test("execute với date range truyền đúng startDate và endDate xuống repository")
    func execute_withDateFilter_forwardsDateRangeToRepository() async throws {
        let (sut, repository) = makeSUT()
        let start = Date(timeIntervalSince1970: 1_743_465_600)
        let end   = Date(timeIntervalSince1970: 1_746_057_600)

        _ = try await sut.execute(page: 0, startDate: start, endDate: end)

        #expect(repository.lastGetTransactionsStartDate == start)
        #expect(repository.lastGetTransactionsEndDate == end)
    }

    @Test("execute không có date filter → repository nhận nil cho cả hai")
    func execute_withoutDateFilter_passesNilDatesToRepository() async throws {
        let (sut, repository) = makeSUT()

        _ = try await sut.execute(page: 0)

        #expect(repository.lastGetTransactionsStartDate == nil)
        #expect(repository.lastGetTransactionsEndDate == nil)
    }

    // MARK: - Response Mapping

    @Test("execute trả về đúng dữ liệu từ repository")
    func execute_returnsDataFromRepository() async throws {
        let (sut, repository) = makeSUT()
        let mockItems = [TransactionResponse.mock(id: "t1"), TransactionResponse.mock(id: "t2")]
        repository.stubbedPaginatedTransactions = .mock(items: mockItems)

        let result = try await sut.execute(page: 0)

        #expect(result.content.count == 2)
        #expect(result.content[0].id == "t1")
        #expect(result.content[1].id == "t2")
    }

    @Test("execute khi danh sách rỗng → trả về empty content")
    func execute_whenEmpty_returnsEmptyContent() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedPaginatedTransactions = .mockEmpty()

        let result = try await sut.execute(page: 0)

        #expect(result.content.isEmpty)
        #expect(result.totalElements == 0)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw → error được propagate lên caller")
    func execute_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute(page: 0)
        }
    }
}
