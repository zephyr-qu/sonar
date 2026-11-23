<p align="center">
  <img src="sonar-site/assets/brand/sonar-lockup-horizontal-fullcolor-transparent.svg" alt="Sonar" width="240">
</p>

<p align="center">
  <strong>Send files across your own network.</strong><br>
  No account, no cloud, no size limit.
</p>

<p align="center">
  Apache-2.0 · Flutter + Rust · protocol v2 (LocalSend compatible) · <a href="support/readme/README_ZH.md">中文</a>
</p>

---

Sonar is a personal fork of [LocalSend](https://localsend.org): the networking layer is LocalSend's, the
app around it was redesigned from scratch. It speaks **LocalSend protocol v2**, so it exchanges files
with LocalSend devices on the same network — you do not have to switch every device.

| | |
|---|---|
| Repository | `zephyr-qu/sonar` — issues and pull requests may go unanswered, see [Relationship to LocalSend](#relationship-to-localsend) |
| Current version | `1.18.3+64` ([`app/pubspec.yaml`](app/pubspec.yaml)) |
| Binaries | **none published yet** — build from source, see [Build from source](#build-from-source) |
| License | Apache-2.0, see [NOTICE](NOTICE) for attribution |

## Contents

- [Features](#features)
- [Platforms](#platforms)
- [How it works](#how-it-works)
- [What this fork changes](#what-this-fork-changes)
- [Repository layout](#repository-layout)
- [Build from source](#build-from-source)
- [Fonts are not in git](#fonts-are-not-in-git)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Relationship to LocalSend](#relationship-to-localsend)
- [License and attribution](#license-and-attribution)

## Features

<img src="sonar-site/assets/shots/nearby.png" alt="Sonar's nearby page: devices arranged on a radar, with the send tray below" height="380" align="right">

**Discovery without typing an IP.** Devices on your subnet show up on their own — close ones arranged
on a radar, the rest in a list below, with search, filters and a rescan button.

**Send to whoever you are looking at.** Drop files onto a device, or pick a device first and then
choose files. Several devices can be queued in one go; each receiver confirms once.

**The other side may not have the app.** Turn on *receive via link* and share a web address instead:
any browser can download from it, no install.

**Encrypted transfers.** Every device generates its own certificate on the fly, and client
certificates are mandatory, so a device's identity is the SHA-256 of its certificate rather than the
name it claims.

**Quick save, favourites, history.** Auto-accept from chosen devices, pin devices for direct dialling,
and one history list mixing what you sent with what you received.

**Runs without an internet connection.** Discovery is multicast on the local network, transfers are
peer-to-peer HTTP; there is no relay and no account.

## Platforms

Any two of these can talk to each other.

| Platform | Requirement | Note |
|---|---|---|
| Windows | Windows 10 build 19041 (2004) or newer | MSIX manifest declares `10.0.19041.0` |
| macOS | 11 Big Sur or newer | |
| Linux | any recent desktop | `xdg-desktop-portal` plus a GTK or KDE backend if the file picker does not open |
| Android | whatever the pinned Flutter SDK sets as `minSdkVersion` | this fork sets no override; see [`app/android/app/build.gradle`](app/android/app/build.gradle) |
| iOS | 13.0 (14.0 for the share extension) | |
| Any browser | — | receive only, through *receive via link* |

Port `53317`, TCP and UDP, must be reachable on your local network.

## How it works

The HTTP server and client are Rust (`packages/core`), not Dart. The server implements protocol v2 and
speaks to the app over a channel of `ServerEventV2` events with responder oneshots; the Flutter side
only routes those events and never does networking on the UI isolate. Discovery is UDP multicast,
announce-only, with one socket per interface so every interface can announce; answers come back as
unicast HTTP. TLS certificates are generated per device with mandatory client certificates.

The isolate layer (`packages/sonar_isolates`) keeps discovery, upload and the server off the main
isolate. An optional WebRTC path and a self-hosted signalling server (`server/`) exist for networks
where direct HTTP is not possible.

Protocol details live in the [LocalSend protocol repository](https://github.com/localsend/protocol).
For the module map and the invariants that matter when editing, read [AGENTS.md](AGENTS.md).

## What this fork changes

Compared with upstream LocalSend, this repository is a redesign with a deliberately narrow maintenance
budget:

- **Desktop-first UI.** The home page is split into nearby / transfer / settings tabs; the nearby tab
  has radar, tile and list layouts and remembers which one you chose. Settings became a searchable
  section index that tells you when a change needs the server restarted. Receive and send history are
  one list.
- **Accessibility and motion.** The reduced-motion setting is honoured, hidden tabs stop animating,
  and the clickable surfaces have pointer, focus and label fixes.
- **No CLI.** The command line client is gone; this repository builds the app only.
- **FOSS build path.** [`support/scripts/remove_proprietary_dependencies.sh`](support/scripts/remove_proprietary_dependencies.sh)
  strips the in-app purchase and donation code for F-Droid-style builds, driven by `[FOSS_REMOVE]`
  markers in the sources.
- **Untracked font binaries.** See [Fonts are not in git](#fonts-are-not-in-git); a fresh clone cannot
  build until you put the TTFs back.
- **`packages/core` follows upstream one commit at a time** on top of a small patch stack. Never
  `git checkout upstream -- packages/core`; names and DTOs have diverged.

## Repository layout

A multi-language monorepo: a Flutter app on top of a Rust protocol implementation.

| Path | What it is |
|---|---|
| `app/` | the Flutter app (`sonar`): UI, providers, persistence, platform channels |
| `packages/sonar_isolates/` | Dart isolate layer and the `flutter_rust_bridge` bindings; owns the plugin crate |
| `packages/core/` | Rust crate `localsend`: protocol, HTTP server and client, crypto, multicast, WebRTC |
| `packages/typed_isolates/` | typed send/receive channels over `Isolate` |
| `server/` | axum WebSocket signalling server for WebRTC (`/v1/ws`) |
| `support/scripts/` | release and packaging scripts, FOSS stripping |
| `sonar-site/` | the landing page: static HTML/CSS/JS, brand SVGs and font subsets |
| `app/assets/i18n/` | translations, 59 locales |

The three Rust crates form one Cargo workspace at the repository root (shared `Cargo.lock` and
`target/`, profiles only in the root manifest). The three Dart packages form one pub workspace, so a
single `pub get` resolves all of them.

Dependency direction: `app` → `sonar_isolates` → (`typed_isolates`, plugin crate → `core`). The app
depends on `sonar_isolates` only.

## Build from source

Prerequisites:

- Flutter, pinned in [`.fvmrc`](.fvmrc) (3.41.9). Install [fvm](https://fvm.app) and use
  `fvm flutter` / `fvm dart`; a system-wide Flutter of another version will not match.
- Rust (stable, see [`rust-toolchain.toml`](rust-toolchain.toml)).
- The eight font files described in [Fonts are not in git](#fonts-are-not-in-git).

Then:

```bash
git clone https://github.com/zephyr-qu/sonar
cd sonar
fvm flutter pub get            # one call resolves the whole pub workspace
cd app
fvm dart run build_runner build   # dart_mappable, freezed, flutter_gen, mockito
fvm dart run slang                # i18n codegen, output goes to lib/gen
fvm flutter run
```

For a local build of a release artifact, plain `fvm flutter build <target>` from `app/` works. The
release pipeline is a set of scripts in [`support/scripts/`](support/scripts); it is what CI calls:

| Target | Script |
|---|---|
| Android APK (reproducible, F-Droid style) | `compile_android_apk.sh` |
| Android App Bundle | `compile_android_appbundle.ps1` |
| iOS | `compile_ios.sh` |
| macOS DMG / App Store | `compile_mac_dmg.sh`, `compile_mac_appstore.sh` |
| Windows installer / MSIX / portable ZIP | `compile_windows_exe.ps1`, `compile_windows_msix_*.ps1`, `compile_windows_zip.ps1` |
| Linux AppImage | `compile_linux_appimage.sh` |
| Version bump in every file CI checks | `fvm dart run support/scripts/release.dart 1.18.3+64` |

A local Windows installer build has no signing certificate; pass `-Unsigned` to
`compile_windows_exe.ps1`.

## Fonts are not in git

`app/assets/fonts/*.ttf` is deliberately untracked — eight files, ~6 MiB, incompressible. Only the
OFL licence texts next to them are tracked and must stay tracked. `app/pubspec.yaml` declares the TTFs
as assets, so a fresh clone fails to build until they are restored:

```bash
cp /path/to/font-cache/*.ttf app/assets/fonts/
ls app/assets/fonts/*.ttf    # expect 8 files
```

Required: `Archivo-{Regular,Medium,SemiBold,Bold}.ttf`, `JetBrainsMono-{Regular,Medium}.ttf`,
`NotoSansSC-{Regular,Bold}.ttf`. `NotoSansSC` is a hand-built subset that cannot be re-downloaded from
Google Fonts verbatim, so keep a copy outside the repository.

## Development

What CI runs (from `app/`, formatting at 150 columns):

```bash
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
```

Rust — `packages/core` gates most modules behind features, and `default = []`, so a bare
`cargo check` fails by design:

```bash
cd packages/core && cargo test --features full && cargo clippy --features full
cd server && cargo check
cd packages/sonar_isolates/rust && cargo check
```

Generated code: `build_runner` from `app/` for the app, and a separate run in
`packages/sonar_isolates/` when its models change. Binding code is regenerated with
`flutter_rust_bridge_codegen generate` from `packages/sonar_isolates/`; it has a habit of rewriting
`app/test/mocks.mocks.dart` at 80 columns, so drop that file from the diff if it changes.

Details that will save you time — isolate rules, event flow, why sync state must be pushed before the
server starts — are in [AGENTS.md](AGENTS.md).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Devices do not appear | AP isolation on the router, a "public" network profile on Windows, or a VPN blocking local traffic. Manual entry of the peer's IP still works and can be turned into a favourite. |
| Devices do not appear on macOS or iOS | The "Local Network" permission under Privacy was denied. |
| Nothing works across one specific pair | Port 53317 TCP or UDP is blocked. With `ufw`: `sudo ufw allow 53317`. With `firewalld`: `firewall-cmd --permanent --add-port=53317/{tcp,udp}` then `firewall-cmd --reload`. |
| Transfers are slow | 5 GHz instead of 2.4 GHz, and turn encryption off on both ends. On Android, slow writes through SAF are a known limitation. |
| A change in settings did nothing | Some settings restart the HTTP server; the settings page marks them. |

## Relationship to LocalSend

Sonar is a fork, not a distribution of LocalSend:

- Upstream's app is not merged here. The `app/` redesign is a one-off and is not maintained against
  upstream; translations are rebranded by hand and are never merged from upstream either.
- `packages/core` does follow upstream, one commit at a time, with a small local patch stack on top.
- The protocol stays compatible, so a Sonar device and a LocalSend device interoperate; the reverse —
  taking this repository's patches upstream — is not a goal.
- This is a personal project. Bug reports that come with a diagnosis are welcome; feature requests and
  pull requests may be declined to keep the maintenance budget small.

## License and attribution

Distributed under the [Apache License 2.0](LICENSE).

Original work © Tien Do Nam and the [LocalSend contributors](https://github.com/localsend/localsend/graphs/contributors).
UI redesign and modifications © 2026 [Zephyr](https://github.com/zephyr-qu).

Bundled fonts are licensed under the SIL Open Font License; the licence texts are in
[`app/assets/fonts/`](app/assets/fonts). The Apache License does not grant trademark rights (§6), which
is why this fork ships as "Sonar" — see [NOTICE](NOTICE).
