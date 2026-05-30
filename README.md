# OpenCan

A native macOS reverse proxy for local development. Map friendly `*.local` hostnames to
local ports, get local HTTPS, and inspect HTTP traffic live. Local-only — no cloud relay.

Inspired by [LocalCan](https://www.localcan.com); built following the Swift/SwiftUI guidance
collected in [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills).

## Features

- **Reverse proxy** — `https://myapp.local` → `127.0.0.1:3000`, routed by Host/SNI on a single
  embedded SwiftNIO proxy.
- **Clean port-less URLs** — a small root LaunchDaemon binds 80/443 and forwards to the app's
  unprivileged listeners, so URLs need no port suffix.
- **`.local` domains** — friendly hostnames registered in `/etc/hosts` (one-time admin auth).
- **Local HTTPS** — a locally-issued wildcard `*.local` certificate; one-click trust install
  removes browser warnings.
- **Port auto-scan** — discover running dev servers (3000/4000/5000/8000 ranges) and register
  them as tunnels in one click.
- **Traffic inspector** — live request/response log (method, host, path, status).
- **Click to open** — click a tunnel to open it in your browser; visible delete button + swipe.
- **Global shortcut** — assign a system-wide hotkey (Settings) to start/stop the proxy.
- **Menu bar + window** — quick start/stop from the menu bar; manage tunnels and traffic.

No public relay. The app listens on unprivileged ports (48080/48443); on first Start it
registers `/etc/hosts` and installs a tiny `python3` forwarding LaunchDaemon for 80/443 via a
single administrator prompt.

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
xcodegen generate          # creates OpenCan.xcodeproj from project.yml
open OpenCan.xcodeproj    # then run the OpenCan scheme
```

## Usage

1. Start the proxy from the menu bar or the main window's **Start** button.
2. Add a tunnel: name `myapp`, upstream `127.0.0.1:3000`.
3. Run a local server (e.g. `python3 -m http.server 3000`).
4. Visit `https://myapp.local` (no port needed).
5. Optional: **Settings ▸ Trust Local CA** to remove browser certificate warnings.

## Architecture

- `Packages/OpenCanCore` — pure, fully-tested logic (no UI dependency): proxy engine,
  certificate authority, traffic recorder, persistence (repository pattern).
- `App/` — thin SwiftUI shell over a single `@Observable` `AppModel`.

Design and implementation notes:

- `docs/superpowers/specs/2026-05-30-opencan-design.md`
- `docs/superpowers/plans/2026-05-30-opencan.md`
