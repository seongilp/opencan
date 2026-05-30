import Foundation
import AppKit
import Observation
import SwiftData
import OpenCanCore
import KeyboardShortcuts

@Observable
@MainActor
final class AppModel {
    enum ProxyState: Equatable { case stopped, running }

    enum Reachability: Equatable { case unknown, live, unreachable }

    private(set) var state: ProxyState = .stopped
    private(set) var statusMessage = "Stopped"
    private(set) var tunnels: [TunnelData] = []
    private(set) var reachability: [UUID: Reachability] = [:]
    private var reachabilityTask: Task<Void, Never>?

    // App listens on uncommon high ports (avoids conflicts); the root helper binds 80/443
    // and forwards onto these, so URLs need no port suffix.
    let httpPort = 48080
    let httpsPort = 48443
    let publicHTTPPort = 80
    let publicHTTPSPort = 443

    let recorder = TrafficRecorder()

    private let container: ModelContainer
    private let store: TunnelStore
    private let resolver = RouteResolver()
    private let authority: CertificateAuthority
    private let systemSetup = SystemSetup()
    private var server: ProxyServer?

    init() {
        self.container = try! ModelContainer(for: TunnelRecord.self)
        self.store = TunnelStore(persistence: SwiftDataTunnelPersistence(context: container.mainContext))
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpenCan", isDirectory: true)
        self.authority = (try? CertificateAuthorityStore(directory: appSupport).loadOrCreate())
            ?? (try! CertificateAuthority())
        reload()
        registerGlobalShortcut()
        startReachabilityMonitor()
    }

    var isRunning: Bool { state == .running }

    func reachability(for tunnel: TunnelData) -> Reachability {
        reachability[tunnel.id] ?? .unknown
    }

    /// Periodically probes each tunnel's upstream so the UI can show Live / Unreachable.
    private func startReachabilityMonitor() {
        reachabilityTask?.cancel()
        reachabilityTask = Task { [weak self] in
            let scanner = PortScanner()
            while !Task.isCancelled {
                guard let self else { return }
                let current = self.tunnels
                var next: [UUID: Reachability] = [:]
                for tunnel in current {
                    let up = await scanner.probe(host: tunnel.upstreamHost, port: tunnel.upstreamPort)
                    next[tunnel.id] = up ? .live : .unreachable
                }
                self.reachability = next
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// Clean HTTPS URL for a tunnel (no port — the root helper forwards 443 → bind port).
    func urlString(for tunnel: TunnelData) -> String {
        "https://\(tunnel.hostname)"
    }

    /// URL to open a tunnel in the browser.
    func url(for tunnel: TunnelData) -> URL? {
        URL(string: urlString(for: tunnel))
    }

    enum Browser: String {
        case `default`, chrome, safari
        var bundleID: String? {
            switch self {
            case .default: return nil
            case .chrome: return "com.google.Chrome"
            case .safari: return "com.apple.Safari"
            }
        }
    }

    /// Whether a specific browser is installed (to show/hide its menu item).
    func isInstalled(_ browser: Browser) -> Bool {
        guard let id = browser.bundleID else { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }

    /// Opens a tunnel in a specific browser (falls back to the default browser).
    func open(_ tunnel: TunnelData, in browser: Browser = .default) {
        guard let url = url(for: tunnel) else { return }
        if let id = browser.bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func toggle() async {
        isRunning ? await stop() : await start()
    }

    /// Auto-start on launch. Re-prompts for admin only if hosts/helper need changes.
    func bootstrap() async {
        await start()
    }

    func reload() {
        tunnels = (try? store.all()) ?? []
    }

    /// Scans common local dev ports (IPv4 + IPv6) and returns open ones not already tunneled.
    func scanForServices() async -> [ScanResult] {
        let mine: Set<Int> = [httpPort, httpsPort]
        let existing = Set(tunnels.map(\.upstreamPort))
        let found = await PortScanner().scan()
        return found.filter { !mine.contains($0.port) && !existing.contains($0.port) }
    }

    func start() async {
        guard !isRunning else { return }
        await applySystemSetup()
        do {
            for tunnel in tunnels where tunnel.enabled {
                await resolver.upsert(host: tunnel.hostname, upstream: tunnel.upstream)
            }
            let hostnames = tunnels.filter(\.enabled).map(\.hostname)
            let tlsContext = try TLSContextFactory.makeContext(authority: authority, hostnames: hostnames)
            let server = ProxyServer(resolver: resolver, recorder: recorder)
            _ = try await server.start(host: "127.0.0.1", port: httpPort)
            _ = try await server.startTLS(host: "127.0.0.1", port: httpsPort, tlsContext: tlsContext)
            self.server = server
            state = .running
            statusMessage = "Running — https://*.test"
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }

    /// Rebuilds the HTTPS certificate to cover the current hostnames (after add/edit/delete).
    private func refreshCertificate() async {
        guard isRunning else { return }
        await stop()
        await start()
    }

    func stop() async {
        await server?.stop()
        server = nil
        state = .stopped
        statusMessage = "Stopped"
    }

    func addTunnel(name: String, host: String, port: Int) async {
        do {
            try store.create(name: name, upstreamHost: host, upstreamPort: port)
            reload()
            await refreshCertificate()
        } catch TunnelStoreError.duplicateHostname {
            statusMessage = "A domain with that name already exists"
        } catch TunnelStoreError.invalidName {
            statusMessage = "Invalid name (letters, numbers, hyphen only)"
        } catch {
            statusMessage = "Could not add domain"
        }
    }

    func updateTunnel(_ tunnel: TunnelData, name: String, host: String, port: Int) async {
        do {
            try store.update(tunnel, name: name, upstreamHost: host, upstreamPort: port)
            reload()
            await refreshCertificate()
        } catch TunnelStoreError.duplicateHostname {
            statusMessage = "A domain with that name already exists"
        } catch TunnelStoreError.invalidName {
            statusMessage = "Invalid name (letters, numbers, hyphen only)"
        } catch {
            statusMessage = "Could not update domain"
        }
    }

    func setEnabled(_ tunnel: TunnelData, _ enabled: Bool) async {
        try? store.setEnabled(tunnel, enabled)
        reload()
        await refreshCertificate()
    }

    func deleteTunnel(_ tunnel: TunnelData) async {
        await resolver.remove(host: tunnel.hostname)
        try? store.delete(tunnel)
        reload()
        await refreshCertificate()
    }

    func installCertificateTrust() {
        guard let pem = try? authority.certificatePEM() else {
            statusMessage = "Could not export CA certificate"
            return
        }
        let setup = systemSetup
        Task {
            do {
                try await Task.detached { try setup.trustRootInSystemKeychain(certificatePEM: pem) }.value
                statusMessage = "Local CA trusted (Safari & Chrome)"
            } catch {
                statusMessage = "CA trust install cancelled"
            }
        }
    }

    /// Writes the root CA to Downloads and reveals it in Finder.
    func revealRootCertificate() {
        let trust = KeychainTrust()
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        if let url = try? trust.exportCACertificate(authority, to: dir) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Registers `*.test` in /etc/hosts and installs the 80/443 forwarding helper
    /// (one admin prompt) so clean URLs resolve and connect.
    func applySystemSetup() async {
        let names = tunnels.map(\.hostname)
        let setup = systemSetup
        let mappings = [
            RootHelper.Mapping(publicPort: publicHTTPSPort, bindPort: httpsPort),
            RootHelper.Mapping(publicPort: publicHTTPPort, bindPort: httpPort),
        ]
        do {
            try await Task.detached { try setup.apply(hostnames: names, mappings: mappings) }.value
        } catch {
            statusMessage = "System setup needs admin permission"
        }
    }

    /// Removes the root forwarding helper (Settings).
    func removeHelper() async {
        let setup = systemSetup
        do {
            try await Task.detached { try setup.removeHelper() }.value
            statusMessage = "Helper removed"
        } catch {
            statusMessage = "Could not remove helper"
        }
    }

    private func registerGlobalShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleProxy) { [weak self] in
            guard let self else { return }
            Task { await self.toggle() }
        }
    }
}
