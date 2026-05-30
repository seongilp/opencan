import SwiftUI
import OpenCanCore

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @State private var inspector = InspectorModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Traffic")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Clear") { inspector.clear() }
                    .disabled(inspector.events.isEmpty)
                    .tint(Theme.green)
            }
            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 18)

            if inspector.events.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .onAppear { inspector.subscribe(to: model.recorder) }
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(inspector.events.reversed())) { event in
                    HStack(spacing: 14) {
                        Text(event.method)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 56, alignment: .leading)
                        Text(event.host)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 160, alignment: .leading)
                        Text(event.path)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(event.statusCode.map(String.init) ?? "—")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(statusColor(event))
                    }
                    .padding(.horizontal, 24).padding(.vertical, 9)
                    Rectangle().fill(Theme.stroke).frame(height: 1)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36)).foregroundStyle(Theme.textTertiary)
            Text("No traffic yet").font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Requests through the proxy appear here.")
                .font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusColor(_ event: TrafficEvent) -> Color {
        switch event.kind {
        case .completed: return Theme.green
        case .failed: return .red
        case .started: return Theme.textTertiary
        }
    }
}
