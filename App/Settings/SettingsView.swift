import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("URLs") {
                Text("Tunnels are served on standard ports (80/443) via a small root helper, so URLs need no port suffix — e.g. https://myapp.local")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Remove Forwarding Helper") {
                    Task { await model.removeHelper() }
                }
            }
            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Start / stop proxy:", name: .toggleProxy)
                Text("Works system-wide, even when OpenCan is in the background.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Certificates") {
                Button("Trust Local CA in Keychain") {
                    model.installCertificateTrust()
                }
                Text("Removes browser warnings for https://*.local. Asks for authorization once.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 380)
    }
}
