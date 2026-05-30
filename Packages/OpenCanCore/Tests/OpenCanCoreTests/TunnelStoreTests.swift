import Testing
@testable import OpenCanCore

@MainActor
private func makeStore() -> TunnelStore {
    TunnelStore(persistence: InMemoryTunnelPersistence())
}

@Test @MainActor func createsAndLists() throws {
    let store = makeStore()
    try store.create(name: "myapp", upstreamHost: "127.0.0.1", upstreamPort: 3000)
    let all = try store.all()
    #expect(all.count == 1)
    #expect(all.first?.hostname == "myapp.localhost")
}

@Test @MainActor func rejectsDuplicateHostname() throws {
    let store = makeStore()
    try store.create(name: "dup", upstreamHost: "127.0.0.1", upstreamPort: 1)
    #expect(throws: TunnelStoreError.duplicateHostname) {
        try store.create(name: "dup", upstreamHost: "127.0.0.1", upstreamPort: 2)
    }
}

@Test @MainActor func rejectsInvalidName() throws {
    let store = makeStore()
    #expect(throws: TunnelStoreError.invalidName) {
        try store.create(name: "has space", upstreamHost: "127.0.0.1", upstreamPort: 1)
    }
}

@Test @MainActor func deletesTunnel() throws {
    let store = makeStore()
    try store.create(name: "gone", upstreamHost: "127.0.0.1", upstreamPort: 1)
    let t = try store.all().first!
    try store.delete(t)
    #expect(try store.all().isEmpty)
}
