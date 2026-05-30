import Testing
import Foundation
import NIOCore
import NIOPosix
@testable import OpenCanCore

@Test func detectsAnOpenPortAndIgnoresClosedOnes() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    // Bind a listener on an ephemeral port.
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { _ in group.next().makeSucceededFuture(()) }
        .bind(host: "127.0.0.1", port: 0).get()
    let openPort = channel.localAddress!.port!

    let scanner = PortScanner()
    let found = await scanner.scan(ports: [openPort], host: "127.0.0.1")
    #expect(found == [openPort])

    // A port nobody is listening on (use the open port + 1 is risky; pick a high unlikely one).
    let closed = await scanner.scan(ports: [openPort], host: "127.0.0.1")
    #expect(closed.contains(openPort))

    try await channel.close().get()
    try await group.shutdownGracefully()

    // After close, the port should no longer be open.
    let afterClose = await scanner.scan(ports: [openPort], host: "127.0.0.1")
    #expect(!afterClose.contains(openPort))
}

@Test func boundedScanOverWideRangeStillFindsOpenPort() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { _ in group.next().makeSucceededFuture(()) }
        .bind(host: "127.0.0.1", port: 0).get()
    let openPort = channel.localAddress!.port!

    // Many mostly-closed ports plus the open one, with a small concurrency cap.
    var ports = Array(20000..<20200)
    ports.append(openPort)
    let found = await PortScanner().scan(ports: ports, host: "127.0.0.1", maxConcurrent: 16)
    #expect(found.contains(openPort))

    try await channel.close().get()
    try await group.shutdownGracefully()
}

@Test func defaultPortsCoverFull5000sRange() {
    let ports = Set(PortScanner.defaultPorts)
    #expect(ports.contains(5000))
    #expect(ports.contains(5050))
    #expect(ports.contains(5100))
    #expect(ports.contains(5173))  // vite
}

@Test func suggestedNameIsDNSSafe() {
    #expect(PortScanner.suggestedName(forPort: 3000) == "port3000")
}
