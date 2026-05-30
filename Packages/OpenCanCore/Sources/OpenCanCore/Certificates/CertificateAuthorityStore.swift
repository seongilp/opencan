import Foundation

/// Loads a persisted root CA from disk, or creates and saves one on first use, so the same CA
/// (and therefore the same trust decision) survives app relaunches.
public struct CertificateAuthorityStore: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var keyURL: URL { directory.appendingPathComponent("ca-key.pem") }
    private var certURL: URL { directory.appendingPathComponent("ca-cert.pem") }

    public func loadOrCreate() throws -> CertificateAuthority {
        if let keyPEM = try? String(contentsOf: keyURL, encoding: .utf8),
           let certPEM = try? String(contentsOf: certURL, encoding: .utf8),
           let ca = try? CertificateAuthority(privateKeyPEM: keyPEM, certificatePEM: certPEM) {
            return ca
        }
        let ca = try CertificateAuthority()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ca.privateKeyPEM().write(to: keyURL, atomically: true, encoding: .utf8)
        try ca.certificatePEM().write(to: certURL, atomically: true, encoding: .utf8)
        // Restrict the private key to the current user.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return ca
    }
}
