import Foundation

/// Builds the privileged TCP-forwarder daemon that binds ports 80/443 (root-only) and forwards
/// to the app's unprivileged listeners, enabling clean port-less URLs like `https://name.local`.
///
/// The daemon is a tiny Python forwarder run by a LaunchDaemon. Pure builders here are
/// unit-testable; installation happens via `SystemSetup` (one administrator prompt).
public enum RootHelper {
    public static let label = "com.opencan.helper"
    public static let supportDir = "/Library/Application Support/OpenCan"
    public static let forwarderPath = "\(supportDir)/forwarder.py"
    public static let plistPath = "/Library/LaunchDaemons/\(label).plist"

    public struct Mapping: Sendable, Hashable {
        public let publicPort: Int   // e.g. 443 (root binds this)
        public let bindPort: Int     // e.g. 48443 (app listens here)
        public init(publicPort: Int, bindPort: Int) {
            self.publicPort = publicPort
            self.bindPort = bindPort
        }
    }

    /// Threaded loopback TCP forwarder. Each `pub:bind` arg forwards 127.0.0.1:pub → 127.0.0.1:bind.
    public static let forwarderScript = """
    #!/usr/bin/env python3
    import socket, sys, threading, select

    def pump(client, target):
        try:
            upstream = socket.create_connection(target)
        except OSError:
            client.close(); return
        socks = [client, upstream]
        try:
            while True:
                r, _, _ = select.select(socks, [], [], 300)
                if not r:
                    break
                for s in r:
                    data = s.recv(65536)
                    if not data:
                        return
                    (upstream if s is client else client).sendall(data)
        except OSError:
            pass
        finally:
            try: client.close()
            except OSError: pass
            try: upstream.close()
            except OSError: pass

    def serve(public_port, target):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("127.0.0.1", public_port))
        srv.listen(128)
        while True:
            client, _ = srv.accept()
            threading.Thread(target=pump, args=(client, target), daemon=True).start()

    def main():
        threads = []
        for arg in sys.argv[1:]:
            pub, bind = arg.split(":")
            t = threading.Thread(target=serve, args=(int(pub), ("127.0.0.1", int(bind))), daemon=True)
            t.start(); threads.append(t)
        for t in threads:
            t.join()

    main()
    """

    /// LaunchDaemon plist that runs the forwarder for the given mappings.
    public static func launchdPlist(_ mappings: [Mapping]) -> String {
        let args = ["/usr/bin/python3", forwarderPath]
            + mappings.map { "\($0.publicPort):\($0.bindPort)" }
        let argXML = args.map { "        <string>\($0)</string>" }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
        \(argXML)
            </array>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
        </dict>
        </plist>
        """
    }
}
