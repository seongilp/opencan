import SwiftUI
import LocalPortCore

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @State private var inspector = InspectorModel()

    var body: some View {
        Group {
            if inspector.events.isEmpty {
                ContentUnavailableView("No Traffic Yet",
                    systemImage: "waveform.path.ecg",
                    description: Text("Requests through the proxy appear here."))
            } else {
                Table(inspector.events.reversed()) {
                    TableColumn("Method") { Text($0.method).font(.body.monospaced()) }
                        .width(70)
                    TableColumn("Host") { Text($0.host) }
                    TableColumn("Path") { Text($0.path).font(.body.monospaced()) }
                    TableColumn("Status") { event in
                        Text(event.statusCode.map(String.init) ?? "—")
                            .foregroundStyle(statusColor(event))
                    }
                    .width(60)
                }
            }
        }
        .navigationTitle("Traffic")
        .toolbar {
            Button("Clear") { inspector.clear() }
                .disabled(inspector.events.isEmpty)
        }
        .onAppear { inspector.subscribe(to: model.recorder) }
    }

    private func statusColor(_ event: TrafficEvent) -> Color {
        switch event.kind {
        case .completed: return .green
        case .failed: return .red
        case .started: return .secondary
        }
    }
}
