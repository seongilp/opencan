import Foundation
import NIOSSL

/// Builds and caches a `NIOSSLContext` for a hostname using a locally-issued leaf certificate.
/// The proxy uses a single wildcard `*.local` context to serve all single-label subdomains.
public actor SNIResolver {
    private let issuer: LeafIssuer
    private var cache: [String: NIOSSLContext] = [:]

    public init(issuer: LeafIssuer) {
        self.issuer = issuer
    }

    public func context(for host: String) throws -> NIOSSLContext {
        let key = host.lowercased()
        if let cached = cache[key] { return cached }
        let bundle = try issuer.issue(host: key)
        let certs = try NIOSSLCertificate.fromPEMBytes(Array(bundle.certificatePEM.utf8))
        let privateKey = try NIOSSLPrivateKey(bytes: Array(bundle.privateKeyPEM.utf8), format: .pem)
        var config = TLSConfiguration.makeServerConfiguration(
            certificateChain: certs.map { .certificate($0) },
            privateKey: .privateKey(privateKey))
        config.applicationProtocols = ["http/1.1"]
        let context = try NIOSSLContext(configuration: config)
        cache[key] = context
        return context
    }
}
