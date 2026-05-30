import Testing
import Foundation
@testable import OpenCanCore

@Test func writesCAFileForInstall() throws {
    let ca = try CertificateAuthority()
    let trust = KeychainTrust()
    let url = try trust.exportCACertificate(ca, to: FileManager.default.temporaryDirectory)
    let pem = try String(contentsOf: url, encoding: .utf8)
    #expect(pem.contains("BEGIN CERTIFICATE"))
    try? FileManager.default.removeItem(at: url)
}
