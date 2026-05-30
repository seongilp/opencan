import Foundation

public struct KeychainTrust: Sendable {
    public init() {}

    /// Writes the CA certificate to a `.pem` file for installation; returns its URL.
    public func exportCACertificate(_ ca: CertificateAuthority, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("LocalPort-CA.pem")
        try ca.certificatePEM().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Installs and trusts the CA in the login keychain. Triggers a one-time auth dialog.
    /// Returns the process exit status (0 == success).
    @discardableResult
    public func installTrust(caFile: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["add-trusted-cert", "-r", "trustRoot",
                             "-k", "\(NSHomeDirectory())/Library/Keychains/login.keychain-db",
                             caFile.path]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
