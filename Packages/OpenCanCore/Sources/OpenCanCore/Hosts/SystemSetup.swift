import Foundation

public enum SystemSetupError: Error, Equatable {
    case authorizationFailed(Int32)
}

/// Applies everything needed for clean `https://name.local` URLs in a single administrator
/// prompt: registers `*.local` in `/etc/hosts`, and installs a root LaunchDaemon that binds
/// ports 80/443 and forwards them to the app's unprivileged listeners.
public struct SystemSetup: Sendable {
    private let hostsFile: URL

    public init(hostsFile: URL = HostsManager.defaultHostsFile) {
        self.hostsFile = hostsFile
    }

    /// Updates /etc/hosts and (re)installs the forwarding LaunchDaemon — but only prompts for
    /// administrator authorization when something actually needs to change. Returns true if an
    /// admin action was performed. Safe to call on every launch: a no-op when already set up.
    @discardableResult
    public func apply(hostnames: [String], mappings: [RootHelper.Mapping]) throws -> Bool {
        let existing = (try? String(contentsOf: hostsFile, encoding: .utf8)) ?? ""
        let hostsContent = HostsManager.renderManaged(existing: existing, hostnames: hostnames)

        let hostsNeedsUpdate = hostsContent != existing
        let helperMissing = !isHelperInstalled()
        guard hostsNeedsUpdate || helperMissing else { return false }

        let tmp = FileManager.default.temporaryDirectory
        let hostsTmp = tmp.appendingPathComponent("opencan-hosts-\(UUID().uuidString)")
        let fwdTmp = tmp.appendingPathComponent("opencan-fwd-\(UUID().uuidString).py")
        let plistTmp = tmp.appendingPathComponent("opencan-plist-\(UUID().uuidString).plist")
        try hostsContent.write(to: hostsTmp, atomically: true, encoding: .utf8)
        try RootHelper.forwarderScript.write(to: fwdTmp, atomically: true, encoding: .utf8)
        try RootHelper.launchdPlist(mappings).write(to: plistTmp, atomically: true, encoding: .utf8)
        defer {
            for url in [hostsTmp, fwdTmp, plistTmp] { try? FileManager.default.removeItem(at: url) }
        }

        let shell = [
            "cp '\(hostsTmp.path)' '\(hostsFile.path)'",
            "mkdir -p '\(RootHelper.supportDir)'",
            "cp '\(fwdTmp.path)' '\(RootHelper.forwarderPath)'",
            "cp '\(plistTmp.path)' '\(RootHelper.plistPath)'",
            "chown root:wheel '\(RootHelper.plistPath)'",
            "chmod 644 '\(RootHelper.plistPath)'",
            "launchctl bootout system/\(RootHelper.label) 2>/dev/null || true",
            "launchctl bootstrap system '\(RootHelper.plistPath)'",
        ].joined(separator: " ; ")
        try runAdmin(shell)
        return true
    }

    /// Installs the root CA into the System keychain as a trusted root (admin prompt).
    /// Safari's sandboxed networking only honors the admin trust domain, so login-keychain
    /// trust is not enough — this is what makes `https://name.local` work in Safari.
    public func trustRootInSystemKeychain(certificatePEM: String) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencan-ca-\(UUID().uuidString).pem")
        try certificatePEM.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let shell = "security add-trusted-cert -d -r trustRoot "
            + "-k /Library/Keychains/System.keychain '\(tmp.path)'"
        try runAdmin(shell)
    }

    /// Removes the forwarding LaunchDaemon (leaves /etc/hosts entries in place).
    public func removeHelper() throws {
        let shell = [
            "launchctl bootout system/\(RootHelper.label) 2>/dev/null || true",
            "rm -f '\(RootHelper.plistPath)'",
        ].joined(separator: " ; ")
        try runAdmin(shell)
    }

    /// Whether the helper LaunchDaemon plist is already installed (no admin needed to check).
    public func isHelperInstalled() -> Bool {
        FileManager.default.fileExists(atPath: RootHelper.plistPath)
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
