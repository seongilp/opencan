import Testing
import Foundation
import NIOCore
import NIOPosix
@testable import OpenCanCore

@Test func detectsAnOpenPortAndIgnoresClosedOnes() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { _ in group.next().makeSucceededFuture(()) }
        .bind(host: "127.0.0.1", port: 0).get()
    let openPort = channel.localAddress!.port!

    let scanner = PortScanner()
    let found = await scanner.scan(ports: [openPort])
    #expect(found.contains { $0.port == openPort && $0.host == "127.0.0.1" })

    try await channel.close().get()
    try await group.shutdownGracefully()

    let afterClose = await scanner.scan(ports: [openPort])
    #expect(!afterClose.contains { $0.port == openPort })
}

@Test func detectsIPv6OnlyServer() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    // Bind on IPv6 loopback only (like Vite/Node default).
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { _ in group.next().makeSucceededFuture(()) }
        .bind(host: "::1", port: 0).get()
    let openPort = channel.localAddress!.port!

    let found = await PortScanner().scan(ports: [openPort])
    #expect(found.contains { $0.port == openPort && $0.host == "::1" })

    try await channel.close().get()
    try await group.shutdownGracefully()
}

@Test func boundedScanOverWideRangeStillFindsOpenPort() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { _ in group.next().makeSucceededFuture(()) }
        .bind(host: "127.0.0.1", port: 0).get()
    let openPort = channel.localAddress!.port!

    var ports = Array(20000..<20200)
    ports.append(openPort)
    let found = await PortScanner().scan(ports: ports, maxConcurrent: 16)
    #expect(found.contains { $0.port == openPort })

    try await channel.close().get()
    try await group.shutdownGracefully()
}

@Test func defaultPortsCoverFull5000sRange() {
    let ports = Set(PortScanner.defaultPorts)
    #expect(ports.contains(5000))
    #expect(ports.contains(5173))   // vite
    #expect(ports.contains(5500))
    #expect(ports.contains(5999))
}

@Test func suggestedNameIsDNSSafe() {
    #expect(PortScanner.suggestedName(forPort: 3000) == "port3000")
}
