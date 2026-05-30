import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Ports") {
                LabeledContent("HTTP", value: ":\(model.httpPort)")
                LabeledContent("HTTPS", value: ":\(model.httpsPort)")
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
        .frame(width: 440, height: 320)
    }
}
