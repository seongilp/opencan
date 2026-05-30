import Foundation

public enum SystemSetupError: Error, Equatable {
    case authorizationFailed(Int32)
}

/// Registers `*.local` tunnel hostnames in `/etc/hosts` (→ 127.0.0.1) using a single
/// administrator-authorized step, so the names resolve on this machine.
///
/// Note: clean port-less URLs (`https://name.local`) would require binding ports 80/443,
/// which needs root. Unprivileged pf `rdr` forwarding does not work for locally-originated
/// loopback traffic on macOS, so the app serves on high ports (`:8080` / `:8443`).
public struct SystemSetup: Sendable {
    private let hostsFile: URL

    public init(hostsFile: URL = HostsManager.defaultHostsFile) {
        self.hostsFile = hostsFile
    }

    /// One admin prompt: rewrite OpenCan's managed `/etc/hosts` block to exactly `hostnames`.
    public func registerHosts(_ hostnames: [String]) throws {
        let existing = (try? String(contentsOf: hostsFile, encoding: .utf8)) ?? ""
        let desired = HostsManager.renderManaged(existing: existing, hostnames: hostnames)
        if desired == existing { return }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencan-hosts-\(UUID().uuidString)")
        try desired.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try runAdmin("cp '\(tmp.path)' '\(hostsFile.path)'")
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
