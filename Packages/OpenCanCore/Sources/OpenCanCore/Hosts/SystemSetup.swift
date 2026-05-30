import Foundation

public enum SystemSetupError: Error, Equatable {
    case authorizationFailed(Int32)
}

/// Applies the system configuration that makes clean `https://name.local` URLs work, in a
/// single administrator-authorized step:
///   1. registers `*.local` hostnames in `/etc/hosts` (→ 127.0.0.1)
///   2. loads a pf `rdr` anchor that forwards :443→:httpsPort and :80→:httpPort on loopback,
///      so the app keeps binding unprivileged high ports while users connect on 80/443.
///
/// The pf anchor is named under `com.apple/*`, which `/etc/pf.conf` already evaluates, so no
/// edit to the main ruleset is required.
public struct SystemSetup: Sendable {
    public static let anchor = "com.apple/250.OpenCan"

    private let hostsFile: URL

    public init(hostsFile: URL = HostsManager.defaultHostsFile) {
        self.hostsFile = hostsFile
    }

    public struct PortMapping: Sendable {
        public let from: Int   // public port (e.g. 443)
        public let to: Int     // app's bind port (e.g. 8443)
        public init(from: Int, to: Int) {
            self.from = from
            self.to = to
        }
    }

    /// Builds the pf ruleset text for the given mappings (pure; unit-testable).
    public static func pfRules(_ mappings: [PortMapping]) -> String {
        mappings
            .map { "rdr pass on lo0 inet proto tcp from any to any port = \($0.from) -> 127.0.0.1 port \($0.to)" }
            .joined(separator: "\n") + "\n"
    }

    /// One admin prompt: update /etc/hosts and load the pf forwarding anchor.
    public func apply(hostnames: [String], mappings: [PortMapping]) throws {
        let existing = (try? String(contentsOf: hostsFile, encoding: .utf8)) ?? ""
        let hostsContent = HostsManager.renderManaged(existing: existing, hostnames: hostnames)

        let tmp = FileManager.default.temporaryDirectory
        let hostsTmp = tmp.appendingPathComponent("opencan-hosts-\(UUID().uuidString)")
        let pfTmp = tmp.appendingPathComponent("opencan-pf-\(UUID().uuidString)")
        try hostsContent.write(to: hostsTmp, atomically: true, encoding: .utf8)
        try Self.pfRules(mappings).write(to: pfTmp, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: hostsTmp)
            try? FileManager.default.removeItem(at: pfTmp)
        }

        let shell = [
            "cp '\(hostsTmp.path)' '\(hostsFile.path)'",
            "/sbin/pfctl -a '\(Self.anchor)' -f '\(pfTmp.path)'",
            "/sbin/pfctl -E",
        ].joined(separator: " ; ")
        try runAdmin(shell)
    }

    /// Removes the pf forwarding anchor (leaves /etc/hosts entries in place).
    public func teardownForwarding() throws {
        try runAdmin("/sbin/pfctl -a '\(Self.anchor)' -F all")
    }

    private func runAdmin(_ shell: String) throws {
        let script = "do shell script \"\(shell)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw SystemSetupError.authorizationFailed(process.terminationStatus)
        }
    }
}
