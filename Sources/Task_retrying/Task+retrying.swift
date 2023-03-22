import Foundation

public struct TaskRetryingError: Error {
    public enum ErrorType: String, Equatable {
        case timedOut
        case exceededMaxRetryCount
    }
    
    public let type: ErrorType
    public let lastError: Error?
}

extension Task where Failure == Error {
    @discardableResult
    /// Create a retriable Task with deadline and max retry count
    /// - Parameters:
    ///   - condition: Condition that indicates where to retry
    ///   - priority: (Optional) Priority of the task
    ///   - maxRetryCount: max number of retries, default is 3
    ///   - retryDelay: delay after each retries, default is 1 seconds
    ///   - timeoutInSeconds: timeout in seconds
    ///   - operation: operation that needs to do
    /// - Returns: Retriable task
    public static func retrying(
        where condition: @escaping (Error) -> Bool,
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1,
        timeoutInSeconds: Int? = nil,
        operation: @Sendable @escaping () async throws -> Success
    ) -> Task {
        retrying(
            where: condition,
            priority: priority,
            maxRetryCount: maxRetryCount,
            retryDelay: retryDelay,
            timeoutInSeconds: timeoutInSeconds,
            operation: { _ in
                try await operation()
            }
        )
    }
    
    @discardableResult
    /// Create a retriable Task with deadline and max retry count
    /// - Parameters:
    ///   - condition: Condition that indicates where to retry
    ///   - priority: (Optional) Priority of the task
    ///   - maxRetryCount: max number of retries, default is 3
    ///   - retryDelay: delay after each retries, default is 1 seconds
    ///   - timeoutInSeconds: timeout in seconds
    ///   - operation: operation that needs to do which receive a `numberOfRetried` as it parameters
    /// - Returns: Retriable task
    public static func retrying(
        where condition: @escaping (Error) -> Bool,
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1,
        timeoutInSeconds: Int? = nil,
        operation: @Sendable @escaping (Int) async throws -> Success
    ) -> Task {
        // set delay time
        let oneSecond = TimeInterval(1_000_000_000)
        let delay = UInt64(oneSecond * retryDelay)
        
        // get deadline
        let startAt = Date()
        let deadline: Date?
        if let timeoutInSeconds = timeoutInSeconds {
            deadline = Calendar.current.date(byAdding: .second, value: Int(timeoutInSeconds), to: startAt)
        } else {
            deadline = nil
        }
        
        // execute task
        return Task(priority: priority) {
            
            // cache last error
            var lastError: Error?
            
            // run for maxRetryCount times
            for i in 0...maxRetryCount {
                do {
                    // assert deadline is not exceeded
                    if let deadline = deadline, Date() >= deadline {
                        throw TaskRetryingError(
                            type: .timedOut,
                            lastError: lastError
                        )
                    }
                    
                    // perform action
                    do {
                        return try await operation(i)
                    }
                    
                    // cache lastError and re throw
                    catch {
                        lastError = error
                        throw error
                    }
                } catch {
                    guard condition(error) else {throw error}
                    
                    try await Task<Never, Never>.sleep(nanoseconds: delay)
                    continue
                }
            }

            throw TaskRetryingError(
                type: .exceededMaxRetryCount,
                lastError: lastError
            )
        }
    }
}
