import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// A discovered local server: a port and the loopback host it's reachable on.
public struct ScanResult: Sendable, Hashable {
    public let port: Int
    public let host: String   // "127.0.0.1" (IPv4) or "::1" (IPv6)
    public init(port: Int, host: String) {
        self.port = port
        self.host = host
    }
}

/// Probes localhost ports to discover running dev servers, so they can be registered as tunnels.
public struct PortScanner: Sendable {
    public init() {}

    /// Common local development ports: the full 5000s range plus 3000s/4000s/8000s and named ports.
    public static let defaultPorts: [Int] = {
        var ports = Set<Int>()
        for p in 3000...3010 { ports.insert(p) }
        for p in 4000...4010 { ports.insert(p) }
        for p in 5000...5999 { ports.insert(p) }   // full 5000s range
        for p in 8000...8010 { ports.insert(p) }
        ports.formUnion([4200, 6006, 8080, 8081, 8443, 8888, 9000, 9090])
        return ports.sorted()
    }()

    /// Returns each port that accepts a TCP connection on IPv4 or IPv6 loopback, tagged with the
    /// host it was found on. Concurrency is bounded so a wide range never exhausts the fd limit.
    public func scan(ports: [Int] = PortScanner.defaultPorts,
                     timeout: TimeInterval = 0.25,
                     maxConcurrent: Int = 64) async -> [ScanResult] {
        var results: [ScanResult] = []
        var next = 0
        await withTaskGroup(of: ScanResult?.self) { group in
            func enqueue() {
                guard next < ports.count else { return }
                let port = ports[next]
                next += 1
                group.addTask {
                    if Self.isOpen(host: "127.0.0.1", port: port, timeout: timeout) {
                        return ScanResult(port: port, host: "127.0.0.1")
                    }
                    if Self.isOpen(host: "::1", port: port, timeout: timeout) {
                        return ScanResult(port: port, host: "::1")
                    }
                    return nil
                }
            }
            for _ in 0..<min(maxConcurrent, ports.count) { enqueue() }
            for await result in group {
                if let result { results.append(result) }
                enqueue()
            }
        }
        return results.sorted { $0.port < $1.port }
    }

    /// Non-blocking TCP connect with a timeout; true if something is listening. Uses
    /// `getaddrinfo`, so it works for IPv4 ("127.0.0.1"), IPv6 ("::1"), and names ("localhost").
    static func isOpen(host: String, port: Int, timeout: TimeInterval) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &res) == 0, let info = res else { return false }
        defer { freeaddrinfo(res) }

        let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let rc = connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen)
        if rc == 0 { return true }
        if errno != EINPROGRESS { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&pfd, 1, Int32(timeout * 1000)) > 0 else { return false }

        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
        return soError == 0
    }

    /// Async health check for a single upstream (used to show tunnel reachability).
    public func probe(host: String, port: Int, timeout: TimeInterval = 0.3) async -> Bool {
        await Task.detached { Self.isOpen(host: host, port: port, timeout: timeout) }.value
    }

    /// A DNS-safe default tunnel name for a discovered port, e.g. 3000 → "port3000".
    public static func suggestedName(forPort port: Int) -> String { "port\(port)" }
}
