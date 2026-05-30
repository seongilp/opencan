import Foundation

public struct Upstream: Sendable, Hashable {
    public let host: String
    public let port: Int
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

/// Immutable representation of a tunnel used by business logic, the proxy, and the UI.
/// Persistence-agnostic — see `TunnelPersisting` for storage.
public struct TunnelData: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var upstreamHost: String
    public var upstreamPort: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, upstreamHost: String,
                upstreamPort: Int, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.upstreamHost = upstreamHost
        self.upstreamPort = upstreamPort
        self.createdAt = createdAt
    }

    /// Friendly local hostname, e.g. "myapp.localhost".
    public var hostname: String { "\(name).localhost" }

    public var upstream: Upstream { Upstream(host: upstreamHost, port: upstreamPort) }
}
