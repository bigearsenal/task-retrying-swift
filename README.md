# Task_retrying

The extension that allows you to make a retriable Task using Swift concurrency.

## Installation
### Cocoapods
`pod install Task_retrying`
### SPM
`.package(url: "https://github.com/bigearsenal/task-retrying-swift.git", from: "1.0.1"),`

## Interface
```swift
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
) -> Task
```

## How to use
```swift
try await Task.retrying(
    where: {error in error == .errorThatNeedToRetry},
    maxRetryCount: 3,
    retryDelay: 1,
    timeoutInSeconds: 30
) {
    try await doSomething()
}
    .value
```

## Throwing errors

In case of exceeded max retry count or timed out, there would be errors:

```swift
public enum TaskRetryingError: Error {
    case timedOut
    case exceededMaxRetryCount
}
```
