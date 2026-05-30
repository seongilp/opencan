import Foundation
import NIOSSL

/// Builds the server `NIOSSLContext` for the proxy's HTTPS listener using a single leaf
/// certificate that lists every tunnel hostname as an exact DNS SAN (no wildcards), so
/// browsers accept `.local` names once the root CA is trusted.
public enum TLSContextFactory {
    public static func makeContext(authority: CertificateAuthority,
                                   hostnames: [String]) throws -> NIOSSLContext {
        let bundle = try LeafIssuer(authority: authority).issue(hosts: hostnames)
        let certs = try NIOSSLCertificate.fromPEMBytes(Array(bundle.certificatePEM.utf8))
        let privateKey = try NIOSSLPrivateKey(bytes: Array(bundle.privateKeyPEM.utf8), format: .pem)
        var config = TLSConfiguration.makeServerConfiguration(
            certificateChain: certs.map { .certificate($0) },
            privateKey: .privateKey(privateKey))
        config.applicationProtocols = ["http/1.1"]
        return try NIOSSLContext(configuration: config)
    }
}
