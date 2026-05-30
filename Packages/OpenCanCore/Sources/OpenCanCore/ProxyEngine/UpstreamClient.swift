import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

struct UpstreamResponse: Sendable {
    let status: Int
    let headers: HTTPHeaders
    let body: ByteBuffer
}

/// Minimal one-shot HTTP/1.1 client used to relay a request to a local upstream.
enum UpstreamClient {
    static func send(on group: EventLoopGroup, head: HTTPRequestHead, body: ByteBuffer,
                     upstream: Upstream) async throws -> UpstreamResponse {
        try await withCheckedThrowingContinuation { continuation in
            let collector = ResponseCollector(continuation: continuation)
            let bootstrap = ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHTTPClientHandlers().flatMap {
                        channel.pipeline.addHandler(collector)
                    }
                }
            bootstrap.connect(host: upstream.host, port: upstream.port).whenComplete { result in
                switch result {
                case .failure(let error):
                    collector.fail(error)
                case .success(let channel):
                    var requestHead = head
                    // Bracket IPv6 literals in the Host header (e.g. [::1]:5173).
                    let hostValue = upstream.host.contains(":")
                        ? "[\(upstream.host)]:\(upstream.port)"
                        : "\(upstream.host):\(upstream.port)"
                    requestHead.headers.replaceOrAdd(name: "host", value: hostValue)
                    channel.write(HTTPClientRequestPart.head(requestHead), promise: nil)
                    if body.readableBytes > 0 {
                        channel.write(HTTPClientRequestPart.body(.byteBuffer(body)), promise: nil)
                    }
                    channel.writeAndFlush(HTTPClientRequestPart.end(nil), promise: nil)
                }
            }
        }
    }
}

private final class ResponseCollector: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPClientResponsePart

    private var status = 502
    private var headers = HTTPHeaders()
    private var body = ByteBuffer()
    private var continuation: CheckedContinuation<UpstreamResponse, Error>?

    init(continuation: CheckedContinuation<UpstreamResponse, Error>) {
        self.continuation = continuation
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            status = Int(head.status.code)
            headers = head.headers
        case .body(var chunk):
            body.writeBuffer(&chunk)
        case .end:
            finish(context: context)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        fail(error)
        context.close(promise: nil)
    }

    private func finish(context: ChannelHandlerContext) {
        continuation?.resume(returning: UpstreamResponse(status: status, headers: headers, body: body))
        continuation = nil
        context.close(promise: nil)
    }

    func fail(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
