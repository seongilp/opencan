import Testing
import NIOSSL
@testable import LocalPortCore

@Test func buildsTLSContextForIssuedHost() async throws {
    let ca = try CertificateAuthority()
    let issuer = LeafIssuer(authority: ca)
    let sni = SNIResolver(issuer: issuer)
    _ = try await sni.context(for: "myapp.localhost")
    // Second lookup must reuse the cache without throwing.
    _ = try await sni.context(for: "myapp.localhost")
}

@Test func buildsWildcardContext() async throws {
    let ca = try CertificateAuthority()
    let sni = SNIResolver(issuer: LeafIssuer(authority: ca))
    _ = try await sni.context(for: "*.localhost")
}
