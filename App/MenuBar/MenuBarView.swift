import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.statusMessage).font(.headline)
            Text("\(model.tunnels.count) tunnel(s)")
                .font(.caption).foregroundStyle(.secondary)

            Button(model.isRunning ? "Stop Proxy" : "Start Proxy") {
                Task { model.isRunning ? await model.stop() : await model.start() }
            }

            Divider()

            Button("Open OpenCan") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(12)
        .frame(width: 240)
    }
}
