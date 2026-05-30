import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Probes localhost ports to discover running dev servers, so they can be registered as tunnels.
public struct PortScanner: Sendable {
    public init() {}

    /// Common local development ports plus the 3000/4000/5000/8000 ranges.
    public static let defaultPorts: [Int] = {
        var ports = Set<Int>()
        for p in 3000...3010 { ports.insert(p) }
        for p in 4000...4010 { ports.insert(p) }
        for p in 5000...5100 { ports.insert(p) }   // full 5000s range
        for p in 8000...8010 { ports.insert(p) }
        // popular named dev ports (vite, angular, storybook, postgres, etc.)
        ports.formUnion([4200, 5173, 5174, 5432, 5500, 5555, 6006, 8080, 8081, 8443, 8888, 9000, 9090])
        return ports.sorted()
    }()

    /// Returns the subset of `ports` that currently accept TCP connections on `host`.
    /// Concurrency is bounded so a wide range never exhausts the process file-descriptor limit.
    public func scan(ports: [Int] = PortScanner.defaultPorts,
                     host: String = "127.0.0.1",
                     timeout: TimeInterval = 0.25,
                     maxConcurrent: Int = 64) async -> [Int] {
        var open: [Int] = []
        var next = 0
        await withTaskGroup(of: Int?.self) { group in
            func enqueue() {
                guard next < ports.count else { return }
                let port = ports[next]
                next += 1
                group.addTask { Self.isOpen(host: host, port: port, timeout: timeout) ? port : nil }
            }
            for _ in 0..<min(maxConcurrent, ports.count) { enqueue() }
            for await result in group {
                if let port = result { open.append(port) }
                enqueue()
            }
        }
        return open.sorted()
    }

    /// Non-blocking TCP connect with a timeout; true if something is listening.
    static func isOpen(host: String, port: Int, timeout: TimeInterval) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else { return false }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if rc == 0 { return true }
        if errno != EINPROGRESS { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let ready = poll(&pfd, 1, Int32(timeout * 1000))
        guard ready > 0 else { return false }

        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
        return soError == 0
    }

    /// A DNS-safe default tunnel name for a discovered port, e.g. 3000 → "port3000".
    public static func suggestedName(forPort port: Int) -> String { "port\(port)" }
}
