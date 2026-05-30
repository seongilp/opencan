import Testing
import NIOSSL
@testable import OpenCanCore

@Test func buildsContextForHostnames() throws {
    let ca = try CertificateAuthority()
    _ = try TLSContextFactory.makeContext(authority: ca, hostnames: ["myapp.local", "port5000.local"])
}

@Test func buildsContextForEmptyHostnames() throws {
    let ca = try CertificateAuthority()
    _ = try TLSContextFactory.makeContext(authority: ca, hostnames: [])
}

@Test func leafListsEveryHostAsExactSAN() throws {
    let ca = try CertificateAuthority()
    let bundle = try LeafIssuer(authority: ca).issue(hosts: ["a.local", "b.local"])
    let san = try #require(try bundle.certificate.extensions.subjectAlternativeNames)
    let names = san.map { String(describing: $0) }
    #expect(names.contains { $0.contains("a.local") })
    #expect(names.contains { $0.contains("b.local") })
    #expect(!names.contains { $0.contains("*") })  // no wildcards
}
