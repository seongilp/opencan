import SwiftUI

@main
struct LocalPortApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("LocalPort", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("LocalPort", systemImage: model.isRunning ? "bolt.fill" : "bolt.slash") {
            MenuBarView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            TunnelListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            InspectorView()
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(model.statusMessage).foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(model.isRunning ? "Stop" : "Start") {
                    Task { model.isRunning ? await model.stop() : await model.start() }
                }
            }
        }
    }
}
