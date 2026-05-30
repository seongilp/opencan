import Foundation

public struct KeychainTrust: Sendable {
    public init() {}

    /// Writes the CA certificate to a `.pem` file (e.g. to reveal in Finder); returns its URL.
    public func exportCACertificate(_ ca: CertificateAuthority, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("OpenCan-CA.pem")
        try ca.certificatePEM().write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
