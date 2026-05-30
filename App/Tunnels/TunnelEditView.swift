import SwiftUI
import OpenCanCore

struct TunnelEditView: View {
    var initial: TunnelData? = nil
    var onSave: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var host: String
    @State private var port: String

    init(initial: TunnelData? = nil, onSave: @escaping (String, String, Int) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial?.name ?? "")
        _host = State(initialValue: initial?.upstreamHost ?? "127.0.0.1")
        _port = State(initialValue: initial.map { String($0.upstreamPort) } ?? "3000")
    }

    private var isEditing: Bool { initial != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Domain" : "New Domain").font(.title2.bold())
            Form {
                TextField("Name", text: $name, prompt: Text("myapp"))
                TextField("Upstream host", text: $host)
                TextField("Upstream port", text: $port)
            }
            if !name.isEmpty {
                Text("→ https://\(name).local")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button(isEditing ? "Save" : "Add") {
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
