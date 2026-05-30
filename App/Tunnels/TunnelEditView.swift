import SwiftUI

struct TunnelEditView: View {
    var onSave: (String, String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var host = "127.0.0.1"
    @State private var port = "3000"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Tunnel").font(.title2.bold())
            Form {
                TextField("Name", text: $name, prompt: Text("myapp"))
                TextField("Upstream host", text: $host)
                TextField("Upstream port", text: $port)
            }
            if !name.isEmpty {
                Text("→ https://\(name).localhost")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Add") {
                    if let p = Int(port), !name.isEmpty {
                        onSave(name, host, p)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || Int(port) == nil)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
