# OpenCan

A native macOS reverse proxy for local development. Map friendly `*.local` hostnames to
local ports, get local HTTPS, and inspect HTTP traffic live. Local-only — no cloud relay.

Inspired by [LocalCan](https://www.localcan.com); built following the Swift/SwiftUI guidance
collected in [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills).

## Features

- **Reverse proxy** — `myapp.local:8443` → `127.0.0.1:3000`, routed by Host/SNI on a single
  embedded SwiftNIO proxy.
- **`.local` domains** — friendly hostnames registered in `/etc/hosts` (one-time admin auth)
  so they resolve to loopback.
- **Local HTTPS** — a locally-issued wildcard `*.local` certificate; one-click trust install
  removes browser warnings.
- **Traffic inspector** — live request/response log (method, host, path, status).
- **Click to open** — click a tunnel in the list to open it in your browser.
- **Global shortcut** — assign a system-wide hotkey (Settings) to start/stop the proxy.
- **Menu bar + window** — quick start/stop from the menu bar; manage tunnels and traffic in the
  main window.

No public relay and no persistent privileged helper: the proxy uses fixed high ports
(HTTP 8080, HTTPS 8443). The app updates `/etc/hosts` for `.local` names via a one-time
administrator authorization prompt.

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
4. Visit `https://myapp.local:8443` (or `http://myapp.local:8080`).
5. Optional: **Settings ▸ Trust Local CA** to remove browser certificate warnings.

## Architecture

- `Packages/OpenCanCore` — pure, fully-tested logic (no UI dependency): proxy engine,
  certificate authority, traffic recorder, persistence (repository pattern).
- `App/` — thin SwiftUI shell over a single `@Observable` `AppModel`.

Design and implementation notes:

- `docs/superpowers/specs/2026-05-30-opencan-design.md`
- `docs/superpowers/plans/2026-05-30-opencan.md`
