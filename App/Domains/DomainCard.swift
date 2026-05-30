import SwiftUI
import OpenCanCore

struct DomainCard: View {
    @Environment(AppModel.self) private var model
    let tunnel: TunnelData

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.stroke).frame(height: 1)
            row
        }
        .cardSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cylinder.split.1x2")
                .foregroundStyle(Theme.textSecondary)
            Text(tunnel.name.capitalized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Menu {
                Button("Trust in Keychain") { model.installCertificateTrust() }
                Button("Reveal RootCA.pem") { model.revealRootCertificate() }
            } label: {
                HStack(spacing: 4) {
                    Text("Certificate")
                    Image(systemName: "arrow.down")
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            cardMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var row: some View {
        HStack(spacing: 14) {
            Text("https")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)

            Button { open() } label: {
                HStack(spacing: 0) {
                    Text(tunnel.name).foregroundStyle(Theme.textPrimary)
                    Text(".local").foregroundStyle(Theme.textSecondary)
                }
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Open \(model.urlString(for: tunnel))")

            Button { open() } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Open in browser")

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                Text("http://\(tunnel.upstreamHost)").foregroundStyle(Theme.textSecondary)
                + Text(":\(String(tunnel.upstreamPort))").foregroundStyle(Theme.textPrimary)
            }
            .font(.system(size: 13, design: .monospaced))

            Text(tunnel.enabled ? "Published" : "Disabled")
                .font(.system(size: 12))
                .foregroundStyle(tunnel.enabled ? Theme.textSecondary : Theme.textTertiary)
                .frame(width: 70, alignment: .trailing)

            Toggle("", isOn: Binding(
                get: { tunnel.enabled },
                set: { newValue in Task { await model.setEnabled(tunnel, newValue) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.green)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var cardMenu: some View {
        Menu {
            Button("Open in Browser") { open() }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.urlString(for: tunnel), forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await model.deleteTunnel(tunnel) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func open() {
        if let url = model.url(for: tunnel) { NSWorkspace.shared.open(url) }
    }
}
