import Testing
import Foundation
@testable import LocalPortCore

@Test func broadcastsRecordedEvents() async {
    let recorder = TrafficRecorder(historyLimit: 10)
    let stream = await recorder.events()

    let event = TrafficEvent(
        id: UUID(),
        host: "myapp.localhost",
        method: "GET",
        path: "/health",
        statusCode: 200,
        kind: .completed,
        timestamp: Date()
    )
    await recorder.record(event)

    var iterator = stream.makeAsyncIterator()
    let received = await iterator.next()
    #expect(received?.path == "/health")
}

@Test func keepsBoundedHistory() async {
    let recorder = TrafficRecorder(historyLimit: 2)
    for i in 0..<5 {
        await recorder.record(TrafficEvent(
            id: UUID(), host: "h", method: "GET", path: "/\(i)",
            statusCode: nil, kind: .started, timestamp: Date()))
    }
    let history = await recorder.history()
    #expect(history.count == 2)
    #expect(history.last?.path == "/4")
}
