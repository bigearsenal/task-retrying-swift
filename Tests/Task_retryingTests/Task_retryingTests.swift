import XCTest
import Task_retrying

var numberOfOperations = 0

final class Task_retryingTests: XCTestCase {
    private enum CustomError: Error, Equatable {
        case errorThatNeedToRetry
        case errorThatCanNotBeRetried
    }
    
    override func setUpWithError() throws {
        numberOfOperations = 0
    }
    
    func testSuccessTaskWithoutRetrying() async throws {
        try await Task.retrying(
            where: {_ in true},
            maxRetryCount: 0,
            retryDelay: 0,
            timeoutInSeconds: 3
        ) {
            try await Task.sleep(nanoseconds: self.nanoseconds(seconds: 1))
        }
            .value
    }
    
    func testSuccessTaskWithRetrying() async throws {
        let expectedNumberOfOperations = 2
        try await Task.retrying(
            where: {error in (error as? CustomError) == .errorThatNeedToRetry},
            maxRetryCount: expectedNumberOfOperations + 1,
            retryDelay: 1,
            timeoutInSeconds: 30
        ) {
            if numberOfOperations < expectedNumberOfOperations {
                numberOfOperations += 1
                throw CustomError.errorThatNeedToRetry
            }
            try await Task.sleep(nanoseconds: self.nanoseconds(seconds: 1))
        }
            .value
        
        XCTAssertEqual(numberOfOperations, expectedNumberOfOperations)
    }
    
    func testFailedTaskWithErrorThatCanNotBeRetried() async throws {
        let expectedNumberOfOperations = 2
        await XCTAssertThrowsError(
            try await Task.retrying(
                where: {error in (error as? CustomError) == .errorThatNeedToRetry},
                maxRetryCount: 3,
                retryDelay: 1,
                timeoutInSeconds: 30
            ) {
                if numberOfOperations < expectedNumberOfOperations {
                    numberOfOperations += 1
                    throw CustomError.errorThatNeedToRetry
                }
                if numberOfOperations == expectedNumberOfOperations {
                    throw CustomError.errorThatCanNotBeRetried
                }
                try await Task.sleep(nanoseconds: self.nanoseconds(seconds: 1))
            }
                .value
        ) { error in
            XCTAssertEqual(error as? CustomError, .errorThatCanNotBeRetried)
        }
        XCTAssertEqual(numberOfOperations, expectedNumberOfOperations)
    }
    
    func testFailedTaskAfterMaximumOfRetry() async throws {
        let maxRetryCount = 3
        await XCTAssertThrowsError(
            try await Task.retrying(
                where: {error in (error as? CustomError) == .errorThatNeedToRetry},
                maxRetryCount: maxRetryCount,
                retryDelay: 1,
                timeoutInSeconds: 30
            ) {
                numberOfOperations += 1
                throw CustomError.errorThatNeedToRetry
            }
                .value
        ) { error in
            XCTAssertEqual(error as? TaskRetryingError, .exceededMaxRetryCount)
        }
        XCTAssertEqual(numberOfOperations, maxRetryCount + 1) // first time and maxRetryCount times doing operation
    }
    
    func testFailedTaskExceededTimeout() async throws {
        let maxRetryCount = 3
        await XCTAssertThrowsError(
            try await Task.retrying(
                where: {error in (error as? CustomError) == .errorThatNeedToRetry},
                maxRetryCount: maxRetryCount,
                retryDelay: 1,
                timeoutInSeconds: 3
            ) {
                if numberOfOperations == 0 {
                    numberOfOperations += 1
                    sleep(3)
                    throw CustomError.errorThatNeedToRetry
                }
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: self.nanoseconds(seconds: 5))
            }
                .value
        ) { error in
            XCTAssertEqual(error as? TaskRetryingError, .timedOut)
        }
        XCTAssertEqual(numberOfOperations, 1)
    }
    
    func testPerpetualRetryCountWithIdentifyingError() async throws {
        let errors: [CustomError] = .init(repeating: .errorThatNeedToRetry, count: 3) + [.errorThatCanNotBeRetried]
        
        await XCTAssertThrowsError(
            try await Task.retrying(
                where: {error in (error as? CustomError) == .errorThatNeedToRetry},
                maxRetryCount: .max,
                retryDelay: 1
            ) {
                numberOfOperations += 1
                throw errors[numberOfOperations]
            }
                .value
        ) { error in
            XCTAssertEqual(error as? CustomError, .errorThatCanNotBeRetried)
        }
        XCTAssertEqual(numberOfOperations, 3)
    }
    
    // MARK: - Helpers
    private func nanoseconds(seconds: Int) -> UInt64 {
        1_000_000 * UInt64(seconds)
    }
}

extension XCTest {
    func XCTAssertThrowsError<T: Sendable>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
