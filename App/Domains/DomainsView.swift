import SwiftUI
import OpenCanCore

struct DomainsView: View {
    @Environment(AppModel.self) private var model
    let tunnels: [TunnelData]
    @Binding var showingAdd: Bool
    @State private var editing: TunnelData?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if tunnels.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(tunnels) { tunnel in
                            DomainCard(tunnel: tunnel) { editing = tunnel }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(item: $editing) { tunnel in
            TunnelEditView(initial: tunnel) { name, host, port in
                Task { await model.updateTunnel(tunnel, name: name, host: host, port: port) }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Domains")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(model.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Button(model.isRunning ? "Stop" : "Start") {
                Task { await model.toggle() }
            }
            .controlSize(.large)
            .tint(Theme.green)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("No domains yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Add a domain to map a friendly .test hostname to a local port.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("Add domain") { showingAdd = true }
                .tint(Theme.green)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
