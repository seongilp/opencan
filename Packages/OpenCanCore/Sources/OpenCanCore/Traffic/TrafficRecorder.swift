import Foundation

public actor TrafficRecorder {
    private let historyLimit: Int
    private var buffer: [TrafficEvent] = []
    private var continuations: [UUID: AsyncStream<TrafficEvent>.Continuation] = [:]

    public init(historyLimit: Int = 500) {
        self.historyLimit = historyLimit
    }

    public func record(_ event: TrafficEvent) {
        buffer.append(event)
        if buffer.count > historyLimit {
            buffer.removeFirst(buffer.count - historyLimit)
        }
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    public func history() -> [TrafficEvent] { buffer }

    /// A live stream of events. The subscriber is dropped when the stream terminates.
    public func events() -> AsyncStream<TrafficEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
