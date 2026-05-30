import Testing
import Foundation
@testable import LocalPortCore

private func tempFile(_ contents: String = "") throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".hosts")
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Test func addsHostIdempotently() throws {
    let url = try tempFile("127.0.0.1 localhost\n")
    let mgr = HostsManager(hostsFile: url)
    try mgr.add(hostname: "myapp.test")
    try mgr.add(hostname: "myapp.test") // idempotent
    let text = try String(contentsOf: url, encoding: .utf8)
    let occurrences = text.components(separatedBy: "myapp.test").count - 1
    #expect(occurrences == 1)
    #expect(text.contains("127.0.0.1\tmyapp.test"))
}

@Test func removesOnlyManagedHost() throws {
    let url = try tempFile("127.0.0.1 localhost\n")
    let mgr = HostsManager(hostsFile: url)
    try mgr.add(hostname: "a.test")
    try mgr.remove(hostname: "a.test")
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(!text.contains("a.test"))
    #expect(text.contains("localhost")) // untouched
}
