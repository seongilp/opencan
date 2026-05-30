# OpenCan — Design Spec

**Date:** 2026-05-30
**Status:** Approved (brainstorming complete)
**Reference:** Inspired by [LocalCan](https://www.localcan.com); follows Swift/SwiftUI agent-skill guidance from [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills).

## 1. Summary

OpenCan is a native macOS app that exposes local development servers through friendly
hostnames over a local reverse proxy, terminates TLS with a locally-issued certificate,
and inspects HTTP traffic in real time. It is **local-only** — there is no public internet
relay server. Scope is intentionally constrained so the app is fully functional with no
backend infrastructure.

### Goals (v1)

- **Reverse proxy mapping** — map a friendly hostname (e.g. `myapp.localhost`) to a local
  upstream (e.g. `127.0.0.1:3000`). A single embedded proxy routes by Host header / SNI.
- **Local domain / DNS management** — default to `*.localhost` (auto-resolves to loopback on
  macOS, no configuration). Optionally register custom `.test` domains via `/etc/hosts`
  (one-time authorization prompt).
- **Local HTTPS (TLS certificates)** — generate a local root CA and per-host leaf
  certificates; offer one-click trust installation into the keychain (one auth dialog).
- **HTTP traffic inspector** — live request/response log: method, path, status, headers,
  timing, and bodies (bounded buffering).

### Non-Goals (v1)

- Public internet tunneling / cloud relay servers / custom public domains.
- Privileged port binding (80/443) and a persistent privileged helper. v1 uses fixed
  high ports (HTTP 8080, HTTPS 8443) requiring no elevation. A future version may add an
  opt-in privileged helper for 80/443.
- Mutating request/response (no rewrite/breakpoint tooling); inspector is read-only.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Core scope | Local tunneling / reverse proxy (no public relay) | Achievable with no infra |
| UI form factor | Menu bar + main window | Matches LocalCan UX |
| Privileged ports | No — fixed high ports 8080/8443 | No persistent privileged helper needed |
| Friendly domains | `*.localhost` default; optional `.test` via /etc/hosts | `*.localhost` needs no config on macOS |
| Proxy engine | SwiftNIO + NIOSSL | Production-grade TLS termination, SNI routing, streaming, WebSocket passthrough |
| Persistence | SwiftData | Native, testable with in-memory container |
| Tests | Swift Testing | Per swift-agent-skills guidance |

## 3. Architecture

```
SwiftUI App (OpenCanApp)
  MenuBarExtra (toggle, status)  +  Main Window (tunnels, inspector, settings)
        |  @Observable view models, async streams
ProxyEngine (SwiftNIO actor)
  - HTTPS listener :8443  /  HTTP listener :8080
  - SNI / Host header -> upstream (127.0.0.1:port) routing
  - TrafficRecorder channel handler
Supporting services:
  - CertificateAuthority (root CA + per-host leaf issuance)
  - HostsManager (optional /etc/hosts editing for .test)
  - TunnelStore (SwiftData persistence)
```

The proxy binds **two fixed ports** and multiplexes all hostnames over them, routing by the
request's Host header (and TLS SNI for certificate selection). Default addresses use
`*.localhost`, which macOS resolves to `127.0.0.1` with no DNS/hosts configuration.

## 4. Module / Package Layout

Core logic lives in an SPM package (`OpenCanCore`) with no SwiftUI/AppKit dependency so it
is unit-testable. The Xcode app target is a thin SwiftUI shell.

```
OpenCan/
  OpenCan.xcodeproj                 # app shell: menu bar + window, code signing
  App/                                # SwiftUI layer (app target)
    OpenCanApp.swift                # @main, MenuBarExtra + Window
    MenuBar/                          # menu bar views + toggle
    Tunnels/                          # tunnel list/edit views + view models
    Inspector/                        # traffic inspector views + view model
    Settings/                         # certificate / port / domain settings
  Packages/OpenCanCore/             # pure logic (no app deps, unit tested)
    Sources/
      ProxyEngine/
        ProxyServer.swift             # listener bootstrap (actor)
        RouteResolver.swift           # Host/SNI -> upstream mapping
        ProxyHandler.swift            # request relay channel handler
        SNIResolver.swift             # per-host certificate selection
      Certificates/
        CertificateAuthority.swift    # root CA create/load
        LeafIssuer.swift              # per-host leaf issuance
        KeychainTrust.swift           # trust install (one-time auth)
      Hosts/
        HostsManager.swift            # /etc/hosts read/write (optional)
      Traffic/
        TrafficRecorder.swift         # request/response capture
        TrafficEvent.swift            # capture model (value type)
      Model/
        Tunnel.swift                  # tunnel definition (SwiftData @Model)
        TunnelStore.swift             # CRUD + persistence
```

File guidance: single responsibility, target 200–400 lines, immutable value types across
concurrency boundaries.

## 5. Data Flow

### Tunnel creation -> activation
```
user input (myapp -> localhost:3000)
  -> TunnelStore.create(Tunnel)               [SwiftData persist]
  -> LeafIssuer issues leaf cert for myapp.localhost (signed by root CA)
  -> RouteResolver table updated: "myapp.localhost" -> 127.0.0.1:3000
  -> ProxyServer already listening on :8443/:8080 (no restart)
```

### Request relay (runtime)
```
browser -> https://myapp.localhost:8443/api/users
  -> NIO TLS handler: SNI "myapp.localhost" -> SNIResolver picks leaf -> TLS terminates
  -> ProxyHandler: Host header -> RouteResolver lookup -> upstream 127.0.0.1:3000
  -> TrafficRecorder captures request (method, path, headers, body) -> AsyncStream to UI
  -> connect upstream -> forward request -> stream response back
  -> TrafficRecorder captures response (status, headers, body, duration)
  -> response to browser
```

### UI update
`ProxyEngine` (actor) exposes `AsyncStream<TrafficEvent>`; the Inspector view model consumes
it via `for await` and publishes through `@Observable` for automatic SwiftUI refresh. Only
immutable value types (`TrafficEvent`) cross the boundary, keeping concurrency safe.

### Certificate trust (one-time)
On first run, generate the root CA. A "remove browser warnings" button invokes
`KeychainTrust` to install the root CA as trusted (one authorization dialog). Skipping it
leaves browser warnings but the proxy still functions.

## 6. Error Handling & Edge Cases

| Situation | Handling |
|---|---|
| Upstream unreachable / connection refused | Proxy returns 502 with a friendly HTML page; error event recorded in inspector |
| Fixed port (8443/8080) already in use | Detect at boot -> UI warning + change port in settings -> graceful ProxyServer restart |
| Duplicate hostname | Validate in TunnelStore, reject save with inline error |
| Root CA trust declined/cancelled | Non-fatal; show warning banner and continue |
| /etc/hosts write denied | `.test` registration fails -> fall back to `*.localhost` with guidance |
| Large / streaming body | Inspector buffers body up to a limit (e.g. 5 MB); beyond it, record metadata only while passthrough streams losslessly |
| WebSocket upgrade | On `Upgrade` header, bidirectional raw passthrough (inspector records handshake only) |

All errors handled explicitly; user-facing messages in the UI; structured logging
internally; no silently swallowed errors.

## 7. Testing Strategy

Core package tested with **Swift Testing**; target 80%+ coverage on `OpenCanCore`.

- **RouteResolver** — Host/SNI -> upstream mapping (wildcard, case-insensitivity, port split).
- **CertificateAuthority / LeafIssuer** — issued leaf verifies against root; SAN includes host.
- **HostsManager** — fake file path for read/write/idempotent add+remove (never touches real /etc/hosts).
- **ProxyServer integration** — spin up a dummy NIO upstream -> request through proxy ->
  assert response + traffic events; assert 502 fallback.
- **TunnelStore** — in-memory SwiftData container for CRUD + duplicate validation.

UI is tested at the view-model level (views themselves excluded).

## 8. Open Questions / Future Work

- Opt-in privileged helper (SMAppService) to bind 80/443 for portless URLs.
- Request/response rewrite & breakpoints in the inspector.
- Export captured traffic (HAR).
- Public tunneling via a relay (out of scope for v1).
