import Foundation

public struct HostsManager: Sendable {
    public static let defaultHostsFile = URL(fileURLWithPath: "/etc/hosts")
    private static let marker = "# OpenCan"

    private let hostsFile: URL

    public init(hostsFile: URL = HostsManager.defaultHostsFile) {
        self.hostsFile = hostsFile
    }

    public func add(hostname: String) throws {
        var lines = try readLines()
        let entry = "127.0.0.1\t\(hostname) \(Self.marker)"
        guard !lines.contains(where: { isManaged($0, hostname: hostname) }) else {
            return
        }
        lines.append(entry)
        try write(lines)
    }

    public func remove(hostname: String) throws {
        let lines = try readLines().filter { !isManaged($0, hostname: hostname) }
        try write(lines)
    }

    private func isManaged(_ line: String, hostname: String) -> Bool {
        guard line.contains(Self.marker) else { return false }
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        return tokens.contains(hostname)
    }

    private func readLines() throws -> [String] {
        let text = try String(contentsOf: hostsFile, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func write(_ lines: [String]) throws {
        let text = lines.joined(separator: "\n")
        try text.write(to: hostsFile, atomically: true, encoding: .utf8)
    }
}
