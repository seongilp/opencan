import Testing
import Foundation
@testable import OpenCanCore

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

@Test func renderManagedReplacesBlockAndPreservesUserLines() {
    let existing = """
    127.0.0.1\tlocalhost
    255.255.255.255\tbroadcasthost
    127.0.0.1\told.local # OpenCan
    """
    let result = HostsManager.renderManaged(existing: existing, hostnames: ["a.local", "b.local"])
    // user lines kept
    #expect(result.contains("127.0.0.1\tlocalhost"))
    #expect(result.contains("broadcasthost"))
    // stale managed entry removed, new ones present exactly once
    #expect(!result.contains("old.local"))
    #expect(result.components(separatedBy: "a.local").count - 1 == 1)
    #expect(result.contains("127.0.0.1\ta.local \(HostsManager.marker)"))
    #expect(result.contains("127.0.0.1\tb.local \(HostsManager.marker)"))
}

@Test func renderManagedEmptyClearsManagedLines() {
    let existing = "127.0.0.1\tlocalhost\n127.0.0.1\tx.local # OpenCan\n"
    let result = HostsManager.renderManaged(existing: existing, hostnames: [])
    #expect(!result.contains("x.local"))
    #expect(result.contains("localhost"))
}
