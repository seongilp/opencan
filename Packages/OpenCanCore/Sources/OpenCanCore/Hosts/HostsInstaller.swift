import Foundation

public enum HostsInstallerError: Error, Equatable {
    case authorizationFailed(Int32)
}

/// Writes `/etc/hosts` with one-time administrator authorization via osascript.
/// Used by the app to make `*.local` tunnel hostnames resolve to 127.0.0.1.
public struct HostsInstaller: Sendable {
    private let hostsFile: URL

    public init(hostsFile: URL = HostsManager.defaultHostsFile) {
        self.hostsFile = hostsFile
    }

    /// Ensures `/etc/hosts` maps exactly `hostnames` (each → 127.0.0.1) under OpenCan's
    /// managed marker. Reads the current file (no privilege), computes the new content, then
    /// copies it into place with administrator privileges (one auth dialog, cached briefly).
    public func sync(hostnames: [String]) throws {
        let existing = (try? String(contentsOf: hostsFile, encoding: .utf8)) ?? ""
        let desired = HostsManager.renderManaged(existing: existing, hostnames: hostnames)
        if desired == existing { return }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencan-hosts-\(UUID().uuidString)")
        try desired.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let script = "do shell script \"cp '\(temp.path)' '\(hostsFile.path)'\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw HostsInstallerError.authorizationFailed(process.terminationStatus)
        }
    }
}
