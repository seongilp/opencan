import Foundation
import Crypto
import X509
import SwiftASN1

public struct CertificateAuthority: Sendable {
    public let certificate: Certificate
    public let privateKey: Certificate.PrivateKey
    private let signingKey: P256.Signing.PrivateKey

    /// Generates a fresh self-signed root CA valid for 10 years.
    public init(commonName: String = "OpenCan Local CA",
                notValidBefore: Date = Date(timeIntervalSinceNow: -3600),
                lifetime: TimeInterval = 60 * 60 * 24 * 365 * 10) throws {
        let key = P256.Signing.PrivateKey()
        let caKey = Certificate.PrivateKey(key)
        let name = try DistinguishedName { CommonName(commonName) }
        let cert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: caKey.publicKey,
            notValidBefore: notValidBefore,
            notValidAfter: notValidBefore.addingTimeInterval(lifetime),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
                Critical(KeyUsage(keyCertSign: true, cRLSign: true))
            },
            issuerPrivateKey: caKey
        )
        self.signingKey = key
        self.privateKey = caKey
        self.certificate = cert
    }

    /// Reconstructs a persisted CA from its private key + certificate PEM.
    public init(privateKeyPEM: String, certificatePEM: String) throws {
        let key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        self.signingKey = key
        self.privateKey = Certificate.PrivateKey(key)
        self.certificate = try Certificate(pemEncoded: certificatePEM)
    }

    /// PEM of the root CA certificate (for keychain trust install).
    public func certificatePEM() throws -> String {
        try certificate.serializeAsPEM().pemString
    }

    /// PEM of the CA private key (for persistence). Keep this file private.
    public func privateKeyPEM() -> String {
        signingKey.pemRepresentation
    }
}
