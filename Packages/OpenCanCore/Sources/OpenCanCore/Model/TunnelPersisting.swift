import Foundation

/// Storage backend for tunnels. Implementations: SwiftData (app) and in-memory (tests/previews).
@MainActor
public protocol TunnelPersisting {
    func fetchAll() throws -> [TunnelData]
    func insert(_ tunnel: TunnelData) throws
    func update(_ tunnel: TunnelData) throws
    func delete(id: UUID) throws
}

/// Array-backed persistence for unit tests and SwiftUI previews.
@MainActor
public final class InMemoryTunnelPersistence: TunnelPersisting {
    private var storage: [TunnelData]

    public init(_ initial: [TunnelData] = []) {
        self.storage = initial
    }

    public func fetchAll() throws -> [TunnelData] { storage }

    public func insert(_ tunnel: TunnelData) throws { storage.append(tunnel) }

    public func update(_ tunnel: TunnelData) throws {
        if let i = storage.firstIndex(where: { $0.id == tunnel.id }) { storage[i] = tunnel }
    }

    public func delete(id: UUID) throws { storage.removeAll { $0.id == id } }
}
