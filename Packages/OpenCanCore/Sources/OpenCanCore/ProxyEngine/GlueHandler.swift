import NIOCore

/// Forwards raw bytes from this channel to a peer channel. Two of these (client↔upstream)
/// form a transparent byte tunnel, used for WebSocket / protocol-upgrade passthrough.
final class GlueHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var peer: Channel?

    init(peer: Channel) {
        self.peer = peer
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        peer?.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        peer?.close(promise: nil)
        peer = nil
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
