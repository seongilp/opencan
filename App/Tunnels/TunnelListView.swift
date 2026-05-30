import SwiftUI
import OpenCanCore

struct TunnelListView: View {
    @Environment(AppModel.self) private var model
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(model.tunnels) { tunnel in
                row(for: tunnel)
            }
            .onDelete { indexSet in
                let targets = indexSet.map { model.tunnels[$0] }
                Task { for t in targets { await model.deleteTunnel(t) } }
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

    @ViewBuilder
    private func row(for tunnel: TunnelData) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tunnel.hostname).font(.body.monospaced())
                Text("→ \(tunnel.upstreamHost):\(tunnel.upstreamPort)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { open(tunnel) }

            Spacer()

            Button { open(tunnel) } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Open \(model.urlString(for: tunnel))")

            Button(role: .destructive) {
                Task { await model.deleteTunnel(tunnel) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete tunnel")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Open in Browser") { open(tunnel) }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.urlString(for: tunnel), forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await model.deleteTunnel(tunnel) }
            }
        }
    }

    private func open(_ tunnel: TunnelData) {
        if let url = model.url(for: tunnel) { NSWorkspace.shared.open(url) }
    }
}
