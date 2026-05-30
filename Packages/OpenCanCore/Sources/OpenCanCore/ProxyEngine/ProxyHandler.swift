import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

/// Bridges an inbound HTTP request to an upstream and streams the response back.
/// One instance per inbound connection. Only the Sendable `Channel` is captured into the
/// async relay task — never the non-Sendable `ChannelHandlerContext`.
final class ProxyHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let resolver: RouteResolver
    private let recorder: TrafficRecorder
    private let httpEncoder: RemovableChannelHandler
    private let httpDecoder: RemovableChannelHandler
    private let allocator = ByteBufferAllocator()

    private var requestHead: HTTPRequestHead?
    private var bodyBuffer = ByteBuffer()

    init(resolver: RouteResolver, recorder: TrafficRecorder,
         httpEncoder: RemovableChannelHandler, httpDecoder: RemovableChannelHandler) {
        self.resolver = resolver
        self.recorder = recorder
        self.httpEncoder = httpEncoder
        self.httpDecoder = httpDecoder
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
            requestHead = nil
            if Self.isUpgrade(head) {
                handleUpgrade(clientChannel: context.channel, head: head)
            } else {
                forward(channel: context.channel, head: head, body: bodyBuffer)
            }
        }
    }

    // MARK: WebSocket / protocol upgrade passthrough

    private static func isUpgrade(_ head: HTTPRequestHead) -> Bool {
        let connectionTokens = head.headers[canonicalForm: "connection"].map { $0.lowercased() }
        return connectionTokens.contains("upgrade") && head.headers.contains(name: "upgrade")
    }

    private func handleUpgrade(clientChannel: Channel, head: HTTPRequestHead) {
        let hostHeader = head.headers.first(name: "host") ?? ""
        let loop = clientChannel.eventLoop
        let resolver = self.resolver
        let allocator = self.allocator
        Task { [weak self] in
            guard let upstream = await resolver.upstream(forHostHeader: hostHeader) else {
                loop.execute { clientChannel.close(promise: nil) }
                return
            }
            let bytes = Self.serializeRequest(head, upstream: upstream, allocator: allocator)
            loop.execute { self?.splice(clientChannel: clientChannel, upstream: upstream, requestBytes: bytes) }
        }
    }

    private func splice(clientChannel: Channel, upstream: Upstream, requestBytes: ByteBuffer) {
        let loop = clientChannel.eventLoop
        let encoder = httpEncoder
        let decoder = httpDecoder
        let bootstrap = ClientBootstrap(group: loop)
            .channelInitializer { $0.eventLoop.makeSucceededFuture(()) }
        bootstrap.connect(host: upstream.host, port: upstream.port).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                clientChannel.close(promise: nil)
            case .success(let upstreamChannel):
                // 1. upstream -> client glue, so the 101 + frames route back.
                // 2. make the client pipeline raw (remove HTTP handlers; decoder forwards
                //    any leftover bytes to the new glue).
                // 3. only THEN send the upgrade request upstream — by now both sides are raw,
                //    so the response can't reach the (removed) HTTP encoder.
                upstreamChannel.pipeline.addHandler(GlueHandler(peer: clientChannel))
                    .flatMap { clientChannel.pipeline.addHandler(GlueHandler(peer: upstreamChannel)) }
                    .flatMap { clientChannel.pipeline.removeHandler(self) }
                    .flatMap { clientChannel.pipeline.removeHandler(encoder) }
                    .flatMap { clientChannel.pipeline.removeHandler(decoder) }
                    .whenComplete { result in
                        switch result {
                        case .success:
                            upstreamChannel.writeAndFlush(requestBytes, promise: nil)
                        case .failure:
                            clientChannel.close(promise: nil)
                            upstreamChannel.close(promise: nil)
                        }
                    }
            }
        }
    }

    private static func serializeRequest(_ head: HTTPRequestHead, upstream: Upstream,
                                         allocator: ByteBufferAllocator) -> ByteBuffer {
        var headers = head.headers
        let hostValue = upstream.host.contains(":")
            ? "[\(upstream.host)]:\(upstream.port)"
            : "\(upstream.host):\(upstream.port)"
        headers.replaceOrAdd(name: "host", value: hostValue)
        var buffer = allocator.buffer(capacity: 256)
        buffer.writeString("\(head.method.rawValue) \(head.uri) HTTP/1.1\r\n")
        for header in headers {
            buffer.writeString("\(header.name): \(header.value)\r\n")
        }
        buffer.writeString("\r\n")
        return buffer
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
