import Foundation
import Observation
import OpenCanCore

@Observable
@MainActor
final class InspectorModel {
    private(set) var events: [TrafficEvent] = []
    private var task: Task<Void, Never>?

    func subscribe(to recorder: TrafficRecorder) {
        guard task == nil else { return }
        task = Task { [weak self] in
            let history = await recorder.history()
            self?.events = history
            for await event in await recorder.events() {
                guard let self else { break }
                self.events.append(event)
                if self.events.count > 1000 {
                    self.events.removeFirst(self.events.count - 1000)
                }
            }
        }
    }

    func clear() { events.removeAll() }
}
