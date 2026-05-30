import SwiftUI
import OpenCanCore

/// Sheet that scans local ports and lets the user register discovered servers as tunnels.
struct ScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var scanning = true
    @State private var ports: [Int] = []
    @State private var names: [Int: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Local Ports").font(.title2.bold())

            if scanning {
                HStack { ProgressView().controlSize(.small); Text("Scanning 3000 / 4000 / 5000 / 8000 ranges…") }
                    .foregroundStyle(.secondary)
            } else if ports.isEmpty {
                ContentUnavailableView("No New Servers",
                    systemImage: "magnifyingglass",
                    description: Text("No local servers found that aren't already tunneled."))
                    .frame(height: 160)
            } else {
                List {
                    ForEach(ports, id: \.self) { port in
                        HStack(spacing: 8) {
                            Text("127.0.0.1:\(String(port))").font(.body.monospaced())
                            Spacer()
                            TextField("name", text: name(port)).frame(width: 110)
                            Text(".local").font(.caption).foregroundStyle(.secondary)
                            Button("Add") { add(port) }
                                .disabled((names[port] ?? "").isEmpty)
                        }
                    }
                }
                .frame(height: 240)
                if ports.count > 1 {
                    Button("Add All") { for p in ports { add(p) } }
                }
            }

            HStack {
                Button("Rescan") { Task { await runScan() } }.disabled(scanning)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .task { await runScan() }
    }

    private func name(_ port: Int) -> Binding<String> {
        Binding(get: { names[port] ?? "" }, set: { names[port] = $0 })
    }

    private func runScan() async {
        scanning = true
        let found = await model.scanForServices()
        names = Dictionary(uniqueKeysWithValues: found.map { ($0, PortScanner.suggestedName(forPort: $0)) })
        ports = found
        scanning = false
    }

    private func add(_ port: Int) {
        let chosen = names[port] ?? PortScanner.suggestedName(forPort: port)
        Task {
            await model.addTunnel(name: chosen, host: "127.0.0.1", port: port)
            ports.removeAll { $0 == port }
        }
    }
}
