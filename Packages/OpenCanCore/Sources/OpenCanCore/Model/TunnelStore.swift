import Foundation

public enum TunnelStoreError: Error, Equatable {
    case duplicateHostname
    case invalidName
}

/// Validates and manages tunnels over an injected persistence backend.
@MainActor
public final class TunnelStore {
    private let persistence: any TunnelPersisting

    public init(persistence: any TunnelPersisting) {
        self.persistence = persistence
    }

    public func all() throws -> [TunnelData] {
        try persistence.fetchAll().sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    public func create(name: String, upstreamHost: String, upstreamPort: Int) throws -> TunnelData {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
            throw TunnelStoreError.invalidName
        }
        if try all().contains(where: { $0.name == trimmed }) {
            throw TunnelStoreError.duplicateHostname
        }
        let tunnel = TunnelData(name: trimmed, upstreamHost: upstreamHost, upstreamPort: upstreamPort)
        try persistence.insert(tunnel)
        return tunnel
    }

    @discardableResult
    public func setEnabled(_ tunnel: TunnelData, _ enabled: Bool) throws -> TunnelData {
        var updated = tunnel
        updated.enabled = enabled
        try persistence.update(updated)
        return updated
    }

    public func delete(_ tunnel: TunnelData) throws {
        try persistence.delete(id: tunnel.id)
    }
}
