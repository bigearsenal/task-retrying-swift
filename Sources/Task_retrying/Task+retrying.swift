import Foundation

public enum TaskRetryingError: Error {
    case timedOut
    case exceededMaxRetryCount
}

extension Task where Failure == Error {
    @discardableResult
    public static func retrying(
        where condition: @escaping (Error) -> Bool,
        priority: TaskPriority? = nil,
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1,
        timeoutInSeconds: Int? = nil,
        operation: @Sendable @escaping () async throws -> Success
    ) -> Task {
        let oneSecond = TimeInterval(1_000_000_000)
        let delay = UInt64(oneSecond * retryDelay)
        
        let startAt = Date()
        let deadline: Date?
        if let timeoutInSeconds = timeoutInSeconds {
            deadline = Calendar.current.date(byAdding: .second, value: Int(timeoutInSeconds), to: startAt)
        } else {
            deadline = nil
        }
        return Task(priority: priority) {
            for _ in 0...maxRetryCount {
                do {
                    if let deadline = deadline, Date() >= deadline {
                        throw TaskRetryingError.timedOut
                    }
                    return try await operation()
                } catch {
                    guard condition(error) else {throw error}
                    
                    try await Task<Never, Never>.sleep(nanoseconds: delay)
                    continue
                }
            }

            throw TaskRetryingError.exceededMaxRetryCount
        }
    }
}
