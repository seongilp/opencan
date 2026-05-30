import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
@testable import LocalPortCore

/// Test-only URLSession delegate that trusts any server certificate.
private final class InsecureTrust: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

private func startDummyUpstream(group: EventLoopGroup) async throws -> Int {
    final class Echo: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart
        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            guard case .end = unwrapInboundIn(data) else { return }
            var buf = context.channel.allocator.buffer(capacity: 16)
            buf.writeString("secure hello")
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

@Test func terminatesTLSAndRelaysOverHTTPS() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    let upstreamPort = try await startDummyUpstream(group: group)
    let resolver = RouteResolver()
    await resolver.upsert(host: "myapp.localhost",
                          upstream: Upstream(host: "127.0.0.1", port: upstreamPort))
    let recorder = TrafficRecorder()
    let ca = try CertificateAuthority()
    let sni = SNIResolver(issuer: LeafIssuer(authority: ca))

    let server = ProxyServer(resolver: resolver, recorder: recorder, group: group)
    let port = try await server.startTLS(host: "127.0.0.1", port: 0, sni: sni)

    let session = URLSession(configuration: .ephemeral, delegate: InsecureTrust(), delegateQueue: nil)
    var req = URLRequest(url: URL(string: "https://127.0.0.1:\(port)/secure")!)
    req.setValue("myapp.localhost", forHTTPHeaderField: "Host")
    let (data, response) = try await session.data(for: req)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == "secure hello")

    await server.stop()
    try await group.shutdownGracefully()
}
