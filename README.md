<p align="center">
  <img src="sonar-site/assets/brand/sonar-lockup-horizontal-fullcolor-transparent.svg" alt="Sonar" width="240">
</p>

<p align="center">
  <strong>Send files across your own network.</strong><br>
  No account, no cloud, no size limit.
</p>

<p align="center">
  <a href="https://www.zephyrqu.top/sonar/"><strong>Download</strong></a> ·
  Apache-2.0 · Flutter + Rust · protocol v2 (LocalSend compatible) ·
  <a href="support/readme/README_ZH.md">中文</a>
</p>

---

Sonar is a personal fork of [LocalSend](https://localsend.org): we kept its networking layer and rebuilt the app. It still speaks protocol v2, so it works with LocalSend devices on the same LAN.

<p align="center">
  <img src="sonar-site/assets/shots/nearby.png" alt="Sonar's nearby page: devices arranged on a radar, with the send tray below" height="320">
</p>

## Features

- Devices on your LAN show up automatically: nearby ones on a radar, the rest in a searchable list.
- Drop files onto a device, or pick the device first; you can queue several receivers.
- The other side has no app? Enable *receive via link* and share a browser URL.
- Every transfer uses TLS with mutual certificate checks; a device is identified by its certificate SHA-256.
- Set auto-accept per device, pin favourites for quick dialling, and see every transfer in one history.

## Platforms

Official builds: Windows and Android. For macOS, Linux and iOS, build it yourself.
Any two installed apps can talk; browsers can only receive through *receive via link*. 

Port `53317`(TCP and UDP) must be reachable on the LAN.

## Troubleshooting

- **No devices listed:** check AP isolation, Windows' "Public" profile, VPNs, and Local Network permission on macOS/iOS. You can still type the peer's IP.
- **One pair fails:** port 53317 is blocked, e.g. `sudo ufw allow 53317`.
- **Slow transfers:** use 5 GHz and turn encryption off on both ends.

## About this fork

This is a personal, one-off redesign: desktop-first UI, accessibility fixes, no CLI, F-Droid-style builds. The networking crate (`packages/core`) still tracks upstream commit by commit; the app (`app/`) doesn't. The protocol stays compatible. Issues and PRs may go unanswered.

## License

Apache-2.0. Original work © Tien Do Nam and the [LocalSend contributors](https://github.com/localsend/localsend/graphs/contributors);
redesign and modifications © 2026 [Zephyr](https://github.com/zephyr-qu). 
Bundled fonts are under the SIL Open Font License; see [NOTICE](NOTICE).
