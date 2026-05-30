import Foundation
import NIOCore
import NIOHTTP1

/// Bridges an inbound HTTP request to an upstream and streams the response back.
/// One instance per inbound connection. Only the Sendable `Channel` is captured into the
/// async relay task — never the non-Sendable `ChannelHandlerContext`.
final class ProxyHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let resolver: RouteResolver
    private let recorder: TrafficRecorder
    private let allocator = ByteBufferAllocator()

    private var requestHead: HTTPRequestHead?
    private var bodyBuffer = ByteBuffer()

    init(resolver: RouteResolver, recorder: TrafficRecorder) {
        self.resolver = resolver
        self.recorder = recorder
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            requestHead = head
            bodyBuffer = context.channel.allocator.buffer(capacity: 0)
        case .body(var chunk):
            bodyBuffer.writeBuffer(&chunk)
        case .end:
            guard let head = requestHead else { return }
            forward(channel: context.channel, head: head, body: bodyBuffer)
            requestHead = nil
        }
    }

    private func forward(channel: Channel, head: HTTPRequestHead, body: ByteBuffer) {
        let hostHeader = head.headers.first(name: "host") ?? ""
        let method = head.method.rawValue
        let path = head.uri
        let eventID = UUID()
        let group = channel.eventLoop
        let resolver = self.resolver
        let recorder = self.recorder

        Task { [allocator] in
            await recorder.record(TrafficEvent(
                id: eventID, host: hostHeader, method: method, path: path,
                statusCode: nil, kind: .started, timestamp: Date()))

            guard let upstream = await resolver.upstream(forHostHeader: hostHeader) else {
                Self.write502(on: channel, allocator: allocator,
                              message: "No tunnel for host \(hostHeader)")
                await recorder.record(TrafficEvent(
                    id: eventID, host: hostHeader, method: method, path: path,
                    statusCode: 502, kind: .failed, timestamp: Date()))
                return
            }

            do {
                let response = try await UpstreamClient.send(
                    on: group, head: head, body: body, upstream: upstream)
                Self.writeResponse(on: channel, response: response)
                await recorder.record(TrafficEvent(
                    id: eventID, host: hostHeader, method: method, path: path,
                    statusCode: response.status, kind: .completed, timestamp: Date()))
            } catch {
                Self.write502(on: channel, allocator: allocator, message: "Upstream unavailable")
                await recorder.record(TrafficEvent(
                    id: eventID, host: hostHeader, method: method, path: path,
                    statusCode: 502, kind: .failed, timestamp: Date()))
            }
        }
    }

    private static func writeResponse(on channel: Channel, response: UpstreamResponse) {
        var headers = response.headers
        headers.replaceOrAdd(name: "content-length", value: String(response.body.readableBytes))
        let head = HTTPResponseHead(version: .http1_1,
                                    status: HTTPResponseStatus(statusCode: response.status),
                                    headers: headers)
        channel.write(HTTPServerResponsePart.head(head), promise: nil)
        channel.write(HTTPServerResponsePart.body(.byteBuffer(response.body)), promise: nil)
        channel.writeAndFlush(HTTPServerResponsePart.end(nil), promise: nil)
    }

    private static func write502(on channel: Channel, allocator: ByteBufferAllocator, message: String) {
        let html = """
        <html><body style="font-family: -apple-system; padding: 2rem;">
        <h2>502 — Bad Gateway</h2><p>\(message)</p>
        <p>Is your local server running?</p></body></html>
        """
        var buffer = allocator.buffer(capacity: html.utf8.count)
        buffer.writeString(html)
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "text/html; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))
        let head = HTTPResponseHead(version: .http1_1, status: .badGateway, headers: headers)
        channel.write(HTTPServerResponsePart.head(head), promise: nil)
        channel.write(HTTPServerResponsePart.body(.byteBuffer(buffer)), promise: nil)
        channel.writeAndFlush(HTTPServerResponsePart.end(nil), promise: nil)
    }
}
