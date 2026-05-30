import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOSSL

public actor ProxyServer {
    private let resolver: RouteResolver
    private let recorder: TrafficRecorder
    private let group: EventLoopGroup
    private let ownsGroup: Bool
    private var channel: Channel?
    private var tlsChannel: Channel?

    public init(resolver: RouteResolver, recorder: TrafficRecorder, group: EventLoopGroup? = nil) {
        self.resolver = resolver
        self.recorder = recorder
        if let group {
            self.group = group
            self.ownsGroup = false
        } else {
            self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.ownsGroup = true
        }
    }

    /// Starts the HTTP listener. Returns the bound port (useful when port == 0 for tests).
    @discardableResult
    public func start(host: String = "127.0.0.1", port: Int) async throws -> Int {
        let resolver = self.resolver
        let recorder = self.recorder
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                Self.configureProxyPipeline(channel, resolver: resolver, recorder: recorder)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        let bound = try await bootstrap.bind(host: host, port: port).get()
        self.channel = bound
        return bound.localAddress?.port ?? port
    }

    /// HTTP server pipeline that supports protocol upgrades: the request decoder forwards any
    /// leftover bytes when removed, so ProxyHandler can splice WebSocket connections raw.
    static func configureProxyPipeline(_ channel: Channel, resolver: RouteResolver,
                                       recorder: TrafficRecorder) -> EventLoopFuture<Void> {
        let encoder = HTTPResponseEncoder()
        let decoder = ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes))
        return channel.pipeline.addHandler(encoder).flatMap {
            channel.pipeline.addHandler(decoder)
        }.flatMap {
            channel.pipeline.addHandler(ProxyHandler(resolver: resolver, recorder: recorder,
                                                     httpEncoder: encoder, httpDecoder: decoder))
        }
    }

    /// Starts an HTTPS listener that terminates TLS with `tlsContext` (a leaf certificate
    /// covering all tunnel hostnames), then proxies exactly like the plain HTTP listener.
    @discardableResult
    public func startTLS(host: String = "127.0.0.1", port: Int,
                         tlsContext: NIOSSLContext) async throws -> Int {
        let resolver = self.resolver
        let recorder = self.recorder
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let sslHandler = NIOSSLServerHandler(context: tlsContext)
                return channel.pipeline.addHandler(sslHandler).flatMap {
                    Self.configureProxyPipeline(channel, resolver: resolver, recorder: recorder)
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        let bound = try await bootstrap.bind(host: host, port: port).get()
        self.tlsChannel = bound
        return bound.localAddress?.port ?? port
    }

    public func stop() async {
        try? await channel?.close().get()
        try? await tlsChannel?.close().get()
        channel = nil
        tlsChannel = nil
        if ownsGroup {
            try? await group.shutdownGracefully()
        }
    }
}
