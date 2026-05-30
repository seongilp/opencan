# LocalPort

A native macOS reverse proxy for local development. Map friendly `*.localhost` hostnames to
local ports, get local HTTPS, and inspect HTTP traffic live. Local-only — no cloud relay.

Inspired by [LocalCan](https://www.localcan.com); built following the Swift/SwiftUI guidance
collected in [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills).

## Features

- **Reverse proxy** — `myapp.localhost:8443` → `127.0.0.1:3000`, routed by Host/SNI on a single
  embedded SwiftNIO proxy.
- **Local HTTPS** — a locally-issued wildcard `*.localhost` certificate; one-click trust install
  removes browser warnings.
- **Traffic inspector** — live request/response log (method, host, path, status).
- **Menu bar + window** — quick start/stop from the menu bar; manage tunnels and traffic in the
  main window.

No privileged helper and no public relay: the proxy uses fixed high ports (HTTP 8080,
HTTPS 8443), and `*.localhost` resolves to loopback on macOS with zero configuration.

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to generate the app
  project from `project.yml`.

## Build & Run

Core library + tests (uses the Xcode toolchain for Swift Testing):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

The macOS app:

```sh
xcodegen generate          # creates LocalPort.xcodeproj from project.yml
open LocalPort.xcodeproj    # then run the LocalPort scheme
```

## Usage

1. Start the proxy from the menu bar or the main window's **Start** button.
2. Add a tunnel: name `myapp`, upstream `127.0.0.1:3000`.
3. Run a local server (e.g. `python3 -m http.server 3000`).
4. Visit `https://myapp.localhost:8443` (or `http://myapp.localhost:8080`).
5. Optional: **Settings ▸ Trust Local CA** to remove browser certificate warnings.

## Architecture

- `Packages/LocalPortCore` — pure, fully-tested logic (no UI dependency): proxy engine,
  certificate authority, traffic recorder, persistence (repository pattern).
- `App/` — thin SwiftUI shell over a single `@Observable` `AppModel`.

Design and implementation notes:

- `docs/superpowers/specs/2026-05-30-localport-design.md`
- `docs/superpowers/plans/2026-05-30-localport.md`
