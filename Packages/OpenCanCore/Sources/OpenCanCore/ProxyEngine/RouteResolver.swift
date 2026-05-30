public actor RouteResolver {
    private var table: [String: Upstream] = [:]

    public init() {}

    public func upsert(host: String, upstream: Upstream) {
        table[Self.normalize(host)] = upstream
    }

    public func remove(host: String) {
        table[Self.normalize(host)] = nil
    }

    public func upstream(forHostHeader header: String) -> Upstream? {
        table[Self.normalize(header)]
    }

    public func allHosts() -> [String] { Array(table.keys) }

    static func normalize(_ host: String) -> String {
        let withoutPort = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? host
        return withoutPort.lowercased()
    }
}
