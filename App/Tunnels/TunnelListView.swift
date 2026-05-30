import SwiftUI
import OpenCanCore

struct TunnelListView: View {
    @Environment(AppModel.self) private var model
    @State private var showingAdd = false

    var body: some View {
        List(model.tunnels) { tunnel in
            VStack(alignment: .leading, spacing: 2) {
                Text(tunnel.hostname).font(.body.monospaced())
                Text("→ \(tunnel.upstreamHost):\(tunnel.upstreamPort)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .contextMenu {
                Button("Copy HTTPS URL") {
                    let url = "https://\(tunnel.hostname):\(model.httpsPort)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                }
                Button("Delete", role: .destructive) {
                    Task { await model.deleteTunnel(tunnel) }
                }
            }
        }
        .navigationTitle("Tunnels")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            TunnelEditView { name, host, port in
                Task { await model.addTunnel(name: name, host: host, port: port) }
            }
        }
        .overlay {
            if model.tunnels.isEmpty {
                ContentUnavailableView("No Tunnels",
                    systemImage: "arrow.triangle.branch",
                    description: Text("Add a tunnel to map a local port to a friendly hostname."))
            }
        }
    }
}
