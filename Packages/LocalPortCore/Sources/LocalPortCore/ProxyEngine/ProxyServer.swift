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
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(ProxyHandler(resolver: resolver, recorder: recorder))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        let bound = try await bootstrap.bind(host: host, port: port).get()
        self.channel = bound
        return bound.localAddress?.port ?? port
    }

    /// Starts an HTTPS listener that terminates TLS with a single wildcard `*.localhost`
    /// certificate, then proxies exactly like the plain HTTP listener.
    @discardableResult
    public func startTLS(host: String = "127.0.0.1", port: Int, sni: SNIResolver,
                         wildcardHost: String = "*.localhost") async throws -> Int {
        let tlsContext = try await sni.context(for: wildcardHost)
        let resolver = self.resolver
        let recorder = self.recorder
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let sslHandler = NIOSSLServerHandler(context: tlsContext)
                return channel.pipeline.addHandler(sslHandler).flatMap {
                    channel.pipeline.configureHTTPServerPipeline()
                }.flatMap {
                    channel.pipeline.addHandler(ProxyHandler(resolver: resolver, recorder: recorder))
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
