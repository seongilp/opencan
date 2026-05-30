import Foundation
import Crypto
import X509

public struct CertificateBundle: Sendable {
    public let certificate: Certificate
    public let certificatePEM: String
    public let privateKeyPEM: String
}

public struct LeafIssuer: Sendable {
    private let authority: CertificateAuthority

    public init(authority: CertificateAuthority) {
        self.authority = authority
    }

    /// Issues a leaf certificate for a single host (convenience).
    public func issue(host: String,
                      notValidBefore: Date = Date(timeIntervalSinceNow: -3600),
                      lifetime: TimeInterval = 60 * 60 * 24 * 397) throws -> CertificateBundle {
        try issue(hosts: [host], notValidBefore: notValidBefore, lifetime: lifetime)
    }

    /// Issues a leaf certificate listing every host in `hosts` as an exact DNS SAN, valid
    /// ~13 months. Exact SANs (no wildcards) keep browsers like Safari happy for `.local`.
    public func issue(hosts: [String],
                      notValidBefore: Date = Date(timeIntervalSinceNow: -3600),
                      lifetime: TimeInterval = 60 * 60 * 24 * 397) throws -> CertificateBundle {
        let names = hosts.isEmpty ? ["localhost"] : hosts
        let leafKey = P256.Signing.PrivateKey()
        let leafPub = Certificate.PublicKey(leafKey.publicKey)
        let subject = try DistinguishedName { CommonName(names[0]) }
        let leaf = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: leafPub,
            notValidBefore: notValidBefore,
            notValidAfter: notValidBefore.addingTimeInterval(lifetime),
            issuer: authority.certificate.subject,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                KeyUsage(digitalSignature: true, keyEncipherment: true)
                try ExtendedKeyUsage([.serverAuth])
                SubjectAlternativeNames(names.map { .dnsName($0) })
            },
            issuerPrivateKey: authority.privateKey
        )
        return CertificateBundle(
            certificate: leaf,
            certificatePEM: try leaf.serializeAsPEM().pemString,
            privateKeyPEM: leafKey.pemRepresentation
        )
    }
}
