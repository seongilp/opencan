import SwiftUI
import OpenCanCore

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection
    @Binding var showingAdd: Bool
    @Binding var showingScan: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // window traffic-light spacer
            Color.clear.frame(height: 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    domainsSection
                    toolsSection
                    reverseProxySection
                    certificateSection
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)
            addButton
        }
    }

    // MARK: Sections

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Domains")
            SidebarRow(title: "All", systemImage: nil, dot: model.isRunning,
                       count: model.tunnels.count,
                       selected: selection == .all) { selection = .all }
            ForEach(model.tunnels) { tunnel in
                SidebarRow(title: tunnel.name.capitalized, systemImage: nil,
                           dot: tunnel.enabled && model.isRunning, count: nil,
                           selected: selection == .tunnel(tunnel.id)) {
                    selection = .tunnel(tunnel.id)
                }
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Tools")
            SidebarRow(title: "Inspect traffic", systemImage: "list.bullet.rectangle",
                       dot: false, count: nil, selected: selection == .traffic) {
                selection = .traffic
            }
            SidebarRow(title: "Scan ports", systemImage: "magnifyingglass",
                       dot: false, count: nil, selected: false) {
                showingScan = true
            }
        }
    }

    private var reverseProxySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Reverse proxy")
            proxyToggleRow(label: "http", systemImage: "square.stack.3d.up")
            proxyToggleRow(label: "https", systemImage: "square.stack.3d.up.fill")
        }
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Root certificate")
            Menu {
                Button("Trust in Keychain") { model.installCertificateTrust() }
                Button("Reveal RootCA.pem in Finder") { model.revealRootCertificate() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text").frame(width: 16)
                        .foregroundStyle(Theme.textSecondary)
                    Text("RootCA.pem").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(Theme.textTertiary)
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private var addButton: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add domain")
                Spacer()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
    }

    // MARK: Pieces

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 10).padding(.bottom, 4)
    }

    private func proxyToggleRow(label: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).frame(width: 16).foregroundStyle(Theme.textSecondary)
            Text(label).foregroundStyle(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.isRunning },
                set: { _ in Task { await model.toggle() } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.green)
            .controlSize(.small)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10).padding(.vertical, 5)
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String?
    let dot: Bool
    let count: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage).frame(width: 16)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Circle()
                        .fill(dot ? Theme.green : Theme.textTertiary)
                        .frame(width: 7, height: 7)
                        .frame(width: 16)
                }
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                if let count {
                    Text("\(count)").foregroundStyle(Theme.textTertiary)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.07) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
