import SwiftUI
import OpenCanCore

/// Sheet that scans local ports and lets the user register discovered servers as tunnels.
struct ScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var scanning = true
    @State private var results: [ScanResult] = []
    @State private var names: [Int: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Local Ports").font(.title2.bold())

            if scanning {
                HStack { ProgressView().controlSize(.small); Text("Scanning 3000 / 4000 / 5000 / 8000 ranges (IPv4 + IPv6)…") }
                    .foregroundStyle(.secondary)
            } else if results.isEmpty {
                ContentUnavailableView("No New Servers",
                    systemImage: "magnifyingglass",
                    description: Text("No local servers found that aren't already tunneled."))
                    .frame(height: 160)
            } else {
                List {
                    ForEach(results, id: \.port) { result in
                        HStack(spacing: 8) {
                            Text(displayAddress(result)).font(.body.monospaced())
                            Spacer()
                            TextField("name", text: name(result.port)).frame(width: 110)
                            Text(".test").font(.caption).foregroundStyle(.secondary)
                            Button("Add") { add(result) }
                                .disabled((names[result.port] ?? "").isEmpty)
                        }
                    }
                }
                .frame(height: 240)
                if results.count > 1 {
                    Button("Add All") { for r in results { add(r) } }
                }
            }

            HStack {
                Button("Rescan") { Task { await runScan() } }.disabled(scanning)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .task { await runScan() }
    }

    private func displayAddress(_ result: ScanResult) -> String {
        result.host.contains(":") ? "[\(result.host)]:\(String(result.port))" : "\(result.host):\(String(result.port))"
    }

    private func name(_ port: Int) -> Binding<String> {
        Binding(get: { names[port] ?? "" }, set: { names[port] = $0 })
    }

    private func runScan() async {
        scanning = true
        let found = await model.scanForServices()
        names = Dictionary(uniqueKeysWithValues: found.map { ($0.port, PortScanner.suggestedName(forPort: $0.port)) })
        results = found
        scanning = false
    }

    private func add(_ result: ScanResult) {
        let chosen = names[result.port] ?? PortScanner.suggestedName(forPort: result.port)
        Task {
            await model.addTunnel(name: chosen, host: result.host, port: result.port)
            results.removeAll { $0.port == result.port }
        }
    }
}
