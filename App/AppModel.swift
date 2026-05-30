import Foundation
import Observation
import SwiftData
import OpenCanCore
import KeyboardShortcuts

@Observable
@MainActor
final class AppModel {
    enum ProxyState: Equatable { case stopped, running }

    private(set) var state: ProxyState = .stopped
    private(set) var statusMessage = "Stopped"
    private(set) var tunnels: [TunnelData] = []

    let httpPort = 8080
    let httpsPort = 8443

    let recorder = TrafficRecorder()

    private let container: ModelContainer
    private let store: TunnelStore
    private let resolver = RouteResolver()
    private let authority: CertificateAuthority
    private let sni: SNIResolver
    private let hostsInstaller = HostsInstaller()
    private var server: ProxyServer?

    init() {
        self.container = try! ModelContainer(for: TunnelRecord.self)
        self.store = TunnelStore(persistence: SwiftDataTunnelPersistence(context: container.mainContext))
        self.authority = try! CertificateAuthority()
        self.sni = SNIResolver(issuer: LeafIssuer(authority: authority))
        reload()
        registerGlobalShortcut()
    }

    var isRunning: Bool { state == .running }

    /// URL to open a tunnel in the browser (HTTPS).
    func url(for tunnel: TunnelData) -> URL? {
        URL(string: "https://\(tunnel.hostname):\(httpsPort)")
    }

    func toggle() async {
        isRunning ? await stop() : await start()
    }

    func reload() {
        tunnels = (try? store.all()) ?? []
    }

    func start() async {
        guard !isRunning else { return }
        await syncHosts()
        do {
            for tunnel in tunnels {
                await resolver.upsert(host: tunnel.hostname, upstream: tunnel.upstream)
            }
            let server = ProxyServer(resolver: resolver, recorder: recorder)
            _ = try await server.start(host: "127.0.0.1", port: httpPort)
            _ = try await server.startTLS(host: "127.0.0.1", port: httpsPort, sni: sni)
            self.server = server
            state = .running
            statusMessage = "Running on :\(httpPort) / :\(httpsPort)"
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }

    func stop() async {
        await server?.stop()
        server = nil
        state = .stopped
        statusMessage = "Stopped"
    }

    func addTunnel(name: String, host: String, port: Int) async {
        do {
            let tunnel = try store.create(name: name, upstreamHost: host, upstreamPort: port)
            await resolver.upsert(host: tunnel.hostname, upstream: tunnel.upstream)
            reload()
            if isRunning { await syncHosts() }
        } catch {
            statusMessage = "Could not add tunnel: \(error)"
        }
    }

    func deleteTunnel(_ tunnel: TunnelData) async {
        await resolver.remove(host: tunnel.hostname)
        try? store.delete(tunnel)
        reload()
        if isRunning { await syncHosts() }
    }

    func installCertificateTrust() {
        let trust = KeychainTrust()
        guard let url = try? trust.exportCACertificate(authority, to: FileManager.default.temporaryDirectory) else {
            statusMessage = "Could not export CA certificate"
            return
        }
        let status = (try? trust.installTrust(caFile: url)) ?? -1
        statusMessage = status == 0 ? "Local CA trusted" : "CA trust install cancelled"
    }

    /// Registers `*.local` hostnames in /etc/hosts (admin auth) so they resolve to loopback.
    func syncHosts() async {
        let names = tunnels.map(\.hostname)
        let installer = hostsInstaller
        do {
            try await Task.detached { try installer.sync(hostnames: names) }.value
        } catch {
            statusMessage = "Hosts update needs admin permission"
        }
    }

    private func registerGlobalShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleProxy) { [weak self] in
            guard let self else { return }
            Task { await self.toggle() }
        }
    }
}
