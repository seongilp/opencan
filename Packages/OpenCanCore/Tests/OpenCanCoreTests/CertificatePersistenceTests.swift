import Testing
import Foundation
@testable import OpenCanCore

@Test func caRoundTripsThroughPEM() throws {
    let original = try CertificateAuthority()
    let keyPEM = original.privateKeyPEM()
    let certPEM = try original.certificatePEM()

    let restored = try CertificateAuthority(privateKeyPEM: keyPEM, certificatePEM: certPEM)
    #expect(restored.certificate == original.certificate)

    // A leaf issued by the restored CA still chains to the same subject.
    let bundle = try LeafIssuer(authority: restored).issue(host: "myapp.local")
    #expect(bundle.certificate.issuer == original.certificate.subject)
}

@Test func storeLoadsSameCAOnSecondCall() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("opencan-ca-\(UUID().uuidString)")
    let store = CertificateAuthorityStore(directory: dir)
    let first = try store.loadOrCreate()
    let second = try store.loadOrCreate()
    #expect(first.certificate == second.certificate)
    try? FileManager.default.removeItem(at: dir)
}
