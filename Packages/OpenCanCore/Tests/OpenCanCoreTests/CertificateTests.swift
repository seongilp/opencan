import Testing
import Foundation
import X509
@testable import OpenCanCore

@Test func issuesLeafChainingToCA() throws {
    let ca = try CertificateAuthority()
    let issuer = LeafIssuer(authority: ca)
    let bundle = try issuer.issue(host: "myapp.localhost")

    #expect(bundle.certificatePEM.contains("BEGIN CERTIFICATE"))
    #expect(bundle.privateKeyPEM.contains("BEGIN PRIVATE KEY"))
    #expect(bundle.certificate.publicKey != ca.certificate.publicKey)
    #expect(bundle.certificate.issuer == ca.certificate.subject)
}

@Test func leafIncludesHostInSAN() throws {
    let ca = try CertificateAuthority()
    let bundle = try LeafIssuer(authority: ca).issue(host: "alpha.localhost")
    let san = try #require(try bundle.certificate.extensions.subjectAlternativeNames)
    let names = san.map { String(describing: $0) }
    #expect(names.contains { $0.contains("alpha.localhost") })
}

@Test func caCertificateIsCA() throws {
    let ca = try CertificateAuthority()
    let bc = try #require(try ca.certificate.extensions.basicConstraints)
    if case .isCertificateAuthority = bc {} else {
        Issue.record("CA cert must have isCertificateAuthority basic constraint")
    }
}
