import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
@testable import LocalPortCore

/// Minimal upstream that replies 200 "hello from upstream" to any request.
private func startDummyUpstream(group: EventLoopGroup) async throws -> Int {
    final class Echo: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart
        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            guard case .end = unwrapInboundIn(data) else { return }
            var buf = context.channel.allocator.buffer(capacity: 32)
            buf.writeString("hello from upstream")
            var headers = HTTPHeaders()
            headers.add(name: "content-length", value: String(buf.readableBytes))
            context.write(wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: .ok, headers: headers))), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
    let channel = try await ServerBootstrap(group: group)
        .childChannelInitializer { ch in
            ch.pipeline.configureHTTPServerPipeline().flatMap { ch.pipeline.addHandler(Echo()) }
        }
        .bind(host: "127.0.0.1", port: 0).get()
    return channel.localAddress!.port!
}

@Test func relaysRequestToUpstreamAndRecords() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    let upstreamPort = try await startDummyUpstream(group: group)
    let resolver = RouteResolver()
    await resolver.upsert(host: "myapp.localhost",
                          upstream: Upstream(host: "127.0.0.1", port: upstreamPort))
    let recorder = TrafficRecorder()

    let server = ProxyServer(resolver: resolver, recorder: recorder, group: group)
    let port = try await server.start(host: "127.0.0.1", port: 0)

    var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/health")!)
    req.setValue("myapp.localhost", forHTTPHeaderField: "Host")
    let (data, response) = try await URLSession.shared.data(for: req)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == "hello from upstream")

    try await Task.sleep(for: .milliseconds(100))
    let history = await recorder.history()
    #expect(history.contains { $0.kind == .completed && $0.statusCode == 200 })

    await server.stop()
    try await group.shutdownGracefully()
}

@Test func returns502ForUnknownHost() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    let server = ProxyServer(resolver: RouteResolver(), recorder: TrafficRecorder(), group: group)
    let port = try await server.start(host: "127.0.0.1", port: 0)

    var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
    req.setValue("nope.localhost", forHTTPHeaderField: "Host")
    let (_, response) = try await URLSession.shared.data(for: req)
    #expect((response as? HTTPURLResponse)?.statusCode == 502)

    await server.stop()
    try await group.shutdownGracefully()
}
