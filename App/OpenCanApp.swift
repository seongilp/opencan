import SwiftUI

enum SidebarSelection: Hashable {
    case all
    case traffic
    case tunnel(UUID)
}

@main
struct OpenCanApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("OpenCan", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("OpenCan", systemImage: model.isRunning ? "bolt.fill" : "bolt.slash") {
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

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarSelection = .all
    @State private var showingAdd = false
    @State private var showingScan = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, showingAdd: $showingAdd, showingScan: $showingScan)
                .frame(width: Theme.sidebarWidth)
                .background(Theme.sidebar)

            Rectangle().fill(Theme.stroke).frame(width: 1)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) {
            TunnelEditView { name, host, port in
                Task { await model.addTunnel(name: name, host: host, port: port) }
            }
        }
        .sheet(isPresented: $showingScan) {
            ScanView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .traffic:
            InspectorView()
        case .all:
            DomainsView(tunnels: model.tunnels, showingAdd: $showingAdd)
        case .tunnel(let id):
            DomainsView(tunnels: model.tunnels.filter { $0.id == id }, showingAdd: $showingAdd)
        }
    }
}
