import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Ports") {
                LabeledContent("HTTP", value: ":\(model.httpPort)")
                LabeledContent("HTTPS", value: ":\(model.httpsPort)")
            }
            Section("Certificates") {
                Button("Trust Local CA in Keychain") {
                    model.installCertificateTrust()
                }
                Text("Removes browser warnings for https://*.localhost. Asks for authorization once.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 260)
    }
}
