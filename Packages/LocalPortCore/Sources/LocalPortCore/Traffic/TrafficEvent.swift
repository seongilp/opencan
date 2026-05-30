import Foundation

public struct TrafficEvent: Sendable, Identifiable, Hashable {
    public enum Kind: Sendable, Hashable {
        case started      // request received
        case completed    // response sent
        case failed       // upstream error (502)
    }

    public let id: UUID
    public let host: String
    public let method: String
    public let path: String
    public let statusCode: Int?
    public let kind: Kind
    public let timestamp: Date

    public init(id: UUID, host: String, method: String, path: String,
                statusCode: Int?, kind: Kind, timestamp: Date) {
        self.id = id
        self.host = host
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.kind = kind
        self.timestamp = timestamp
    }
}
