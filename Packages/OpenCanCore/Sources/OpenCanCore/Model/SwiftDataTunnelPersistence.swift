import Foundation
import SwiftData

/// SwiftData record backing a `TunnelData`. Used only inside the app (a real bundle);
/// SwiftData cannot run in bare SwiftPM test processes, so this type is exercised by the
/// app and SwiftUI previews, not unit tests.
@Model
public final class TunnelRecord {
    public var id: UUID
    public var name: String
    public var upstreamHost: String
    public var upstreamPort: Int
    public var createdAt: Date

    public init(id: UUID, name: String, upstreamHost: String, upstreamPort: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.upstreamHost = upstreamHost
        self.upstreamPort = upstreamPort
        self.createdAt = createdAt
    }

    convenience init(from data: TunnelData) {
        self.init(id: data.id, name: data.name, upstreamHost: data.upstreamHost,
                  upstreamPort: data.upstreamPort, createdAt: data.createdAt)
    }

    var asData: TunnelData {
        TunnelData(id: id, name: name, upstreamHost: upstreamHost,
                   upstreamPort: upstreamPort, createdAt: createdAt)
    }
}

@MainActor
public final class SwiftDataTunnelPersistence: TunnelPersisting {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [TunnelData] {
        try context.fetch(FetchDescriptor<TunnelRecord>()).map(\.asData)
    }

    public func insert(_ tunnel: TunnelData) throws {
        context.insert(TunnelRecord(from: tunnel))
        try context.save()
    }

    public func delete(id: UUID) throws {
        let target = id
        let matches = try context.fetch(FetchDescriptor<TunnelRecord>())
            .filter { $0.id == target }
        for record in matches {
            context.delete(record)
        }
        try context.save()
    }
}
