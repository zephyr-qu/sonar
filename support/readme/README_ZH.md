<p align="center">
  <img src="../../sonar-site/assets/brand/sonar-lockup-horizontal-fullcolor-transparent.svg" alt="Sonar" width="240">
</p>

<p align="center">
  在局域网里传文件：不开账号，不经过云端，不限大小。
</p>

<p align="center">
  Apache-2.0 · Flutter + Rust · 协议 v2（兼容 LocalSend） · <a href="../../README.md">English</a>
</p>

---

Sonar 是 [LocalSend](https://localsend.org) 的个人 fork：网络部分沿用 LocalSend，外面的应用是重新设计的。
它实现 **LocalSend 协议 v2**，可以和同一网络里装了 LocalSend 的设备互传 —— 不必把所有设备都换成 Sonar。

| | |
|---|---|
| 仓库 | `zephyr-qu/sonar` —— issue 和 PR 可能不会及时处理，见[与 LocalSend 的关系](#与-localsend-的关系) |
| 当前版本 | `1.18.3+64`（[`app/pubspec.yaml`](../../app/pubspec.yaml)） |
| 安装包 | **还没有发布** —— 从源码构建，见[从源码构建](#从源码构建) |
| 许可 | Apache-2.0，署名见 [NOTICE](../../NOTICE) |

## 目录

- [特性](#特性)
- [平台](#平台)
- [工作原理](#工作原理)
- [这个 fork 改了什么](#这个-fork-改了什么)
- [仓库结构](#仓库结构)
- [从源码构建](#从源码构建)
- [字体不在 git 里](#字体不在-git-里)
- [开发](#开发)
- [故障排查](#故障排查)
- [与 LocalSend 的关系](#与-localsend-的关系)
- [许可与署名](#许可与署名)

## 特性

<img src="../../sonar-site/assets/shots/nearby.png" alt="Sonar 的附近页：设备排布在雷达上，下方是待发送的文件" height="380" align="right">

**不用输 IP 就能找到设备。** 同一网段的设备会自己出现：近处的排布在雷达上，其余收进下面的列表，并带搜索、筛选和重新扫描。

**对着谁就发给谁。** 把文件拖到设备上，或者先点设备再选文件。可以一次把多台设备排进队列，接收方各自确认一次。

**对方不用装这个应用。** 开启「链接接收」后给出一个网页地址，任何浏览器都能直接下载。

**传输是加密的。** 每台设备现场生成自己的证书，并且强制校验客户端证书，所以设备身份是证书的 SHA-256，而不是对方自报的名字。

**快速保存、收藏、历史。** 对指定设备自动接收，把常发的设备钉成收藏以便直连，收发记录合成一个列表。

**断网也能用。** 发现是局域网多播，传输是点对点 HTTP；没有中转服务器，没有账号。

## 平台

任意两个平台之间都能互传。

| 平台 | 要求 | 备注 |
|---|---|---|
| Windows | Windows 10 19041（2004）或更新 | MSIX 清单里写的是 `10.0.19041.0` |
| macOS | 11 Big Sur 或更新 | |
| Linux | 任意较新的桌面 | 文件选择框打不开时，需要 `xdg-desktop-portal` 加 GTK 或 KDE 后端 |
| Android | 由锁定的 Flutter SDK 决定 `minSdkVersion` | 本 fork 没有覆盖；见 [`app/android/app/build.gradle`](../../app/android/app/build.gradle) |
| iOS | 13.0（分享扩展需要 14.0） | |
| 任意浏览器 | — | 只能接收，走「链接接收」 |

端口 `53317`（TCP 与 UDP）需要在局域网内可达。

## 工作原理

HTTP 服务端与客户端是 Rust（`packages/core`），不是 Dart。服务端实现协议 v2，通过一串 `ServerEventV2`
事件与应答用 oneshot 和 app 通信；Flutter 侧只负责路由这些事件，从不在 UI isolate 上做网络。
发现是 UDP 多播、只广播不回应，每个网络接口一个 socket，这样每个接口都能广播；回应走 HTTP 单播回来。
TLS 证书按设备现场生成，并强制校验客户端证书。

隔离层（`packages/sonar_isolates`）把发现、上传和服务端都放在主 isolate 之外。另有一条可选的 WebRTC
路径和一个自托管的信令服务器（`server/`），用于直连 HTTP 走不通的网络。

协议细节见 [LocalSend 协议仓库](https://github.com/localsend/protocol)。模块地图和改动时真正要紧的不变量，
写在 [AGENTS.md](../../AGENTS.md) 里。

## 这个 fork 改了什么

相对上游 LocalSend，这是一个重新设计过的仓库，维护预算刻意压得很窄：

- **桌面优先的界面。** 主页拆成「附近 / 传输 / 设置」三个页签；附近页有雷达、卡片、列表三种排布，并记住你选的那一种。
  设置变成一个可搜索的分区索引，会标出哪些改动需要重启服务端。收发历史合成一个列表。
- **无障碍与动效。** 尊重「减少动态效果」开关，隐藏的页签停止动画，可点击区域补上了指针、焦点和标签。
- **没有命令行。** CLI 已删除，这个仓库只构建应用。
- **FOSS 构建路径。** [`support/scripts/remove_proprietary_dependencies.sh`](../../support/scripts/remove_proprietary_dependencies.sh)
  按源码里的 `[FOSS_REMOVE]` 标记剥掉内购和捐赠代码，用于 F-Droid 式构建。
- **字体二进制不入库。** 见[字体不在 git 里](#字体不在-git-里)；新克隆的仓库不补字体会构建失败。
- **`packages/core` 一次只跟一个上游提交**，上面叠一小组本地补丁。不要执行 `git checkout upstream -- packages/core`，
  命名和 DTO 已经分叉了。

## 仓库结构

多语言 monorepo：Flutter 应用架在 Rust 协议实现之上。

| 路径 | 是什么 |
|---|---|
| `app/` | Flutter 应用（`sonar`）：界面、provider、持久化、平台通道 |
| `packages/sonar_isolates/` | Dart 隔离层与 `flutter_rust_bridge` 绑定；自带插件 crate |
| `packages/core/` | Rust crate `localsend`：协议、HTTP 服务端与客户端、加密、多播、WebRTC |
| `packages/typed_isolates/` | 给 `Isolate` 套上类型化收发通道 |
| `server/` | WebRTC 用的 axum WebSocket 信令服务器（`/v1/ws`） |
| `support/scripts/` | 发布与打包脚本、FOSS 剥离 |
| `sonar-site/` | 落地页：静态 HTML/CSS/JS，含品牌 SVG 与字体子集 |
| `app/assets/i18n/` | 翻译，59 种语言 |

三个 Rust crate 组成仓库根部的单个 Cargo workspace（共用 `Cargo.lock` 与 `target/`，profile 只写在根清单里）。
三个 Dart 包组成单个 pub workspace，一次 `pub get` 全部解析。

依赖方向：`app` → `sonar_isolates` →（`typed_isolates`、插件 crate → `core`）。应用只依赖 `sonar_isolates`。

## 从源码构建

前置条件：

- Flutter，版本锁定在 [`.fvmrc`](../../.fvmrc)（3.41.9）。装 [fvm](https://fvm.app)，用 `fvm flutter` / `fvm dart`；
  系统里另一份 Flutter 一定对不上。
- Rust（stable，见 [`rust-toolchain.toml`](../../rust-toolchain.toml)）。
- [字体不在 git 里](#字体不在-git-里)说的那八个字体文件。

然后：

```bash
git clone https://github.com/zephyr-qu/sonar
cd sonar
fvm flutter pub get               # 一次调用解析整个 pub workspace
cd app
fvm dart run build_runner build   # dart_mappable、freezed、flutter_gen、mockito
fvm dart run slang                # i18n 代码生成，输出到 lib/gen
fvm flutter run
```

本地要出发布产物，在 `app/` 里直接 `fvm flutter build <目标>` 就可以。正式发布流程是
[`support/scripts/`](../../support/scripts) 里的一组脚本，CI 调用的就是它们：

| 目标 | 脚本 |
|---|---|
| Android APK（可复现，F-Droid 风格） | `compile_android_apk.sh` |
| Android App Bundle | `compile_android_appbundle.ps1` |
| iOS | `compile_ios.sh` |
| macOS DMG / App Store | `compile_mac_dmg.sh`、`compile_mac_appstore.sh` |
| Windows 安装包 / MSIX / 便携 ZIP | `compile_windows_exe.ps1`、`compile_windows_msix_*.ps1`、`compile_windows_zip.ps1` |
| Linux AppImage | `compile_linux_appimage.sh` |
| 把版本号改到 CI 检查的每个文件 | `fvm dart run support/scripts/release.dart 1.18.3+64` |

本地构建 Windows 安装包没有签名证书，给 `compile_windows_exe.ps1` 加 `-Unsigned`。

## 字体不在 git 里

`app/assets/fonts/*.ttf` 是刻意不入库的 —— 八个文件、约 6 MiB、压不动。只有旁边的 OFL 许可文本入库，
并且必须继续入库。`app/pubspec.yaml` 把这些 TTF 声明成资源，所以新克隆的仓库不补字体会构建失败：

```bash
cp /path/to/font-cache/*.ttf app/assets/fonts/
ls app/assets/fonts/*.ttf    # 应该是 8 个文件
```

需要的文件：`Archivo-{Regular,Medium,SemiBold,Bold}.ttf`、`JetBrainsMono-{Regular,Medium}.ttf`、
`NotoSansSC-{Regular,Bold}.ttf`。`NotoSansSC` 是手工裁的子集，没法从 Google Fonts 原样下载回来，
所以在仓库之外留一份。

## 开发

CI 跑的检查（在 `app/` 下，格式化为 150 列）：

```bash
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
```

Rust —— `packages/core` 把大部分模块都藏在 feature 后面，且 `default = []`，所以裸跑 `cargo check` 本来就会失败：

```bash
cd packages/core && cargo test --features full && cargo clippy --features full
cd server && cargo check
cd packages/sonar_isolates/rust && cargo check
```

代码生成：应用在 `app/` 里跑 `build_runner`；`packages/sonar_isolates/` 的模型变了要在它自己目录里再跑一次。
绑定代码在 `packages/sonar_isolates/` 里用 `flutter_rust_bridge_codegen generate` 重新生成；它习惯把
`app/test/mocks.mocks.dart` 按 80 列重写，这个文件出现在 diff 里就还原掉。

能省你时间的细节 —— 隔离层的规矩、事件流向、为什么必须在启动服务端之前推同步状态 —— 都在
[AGENTS.md](../../AGENTS.md)。

## 故障排查

| 现象 | 可能原因 |
|---|---|
| 看不到设备 | 路由器开了 AP 隔离、Windows 把网络当成「公用」，或者 VPN 拦了局域网流量。手动填对方 IP 仍然可用，成功后可以加成收藏。 |
| macOS、iOS 上看不到设备 | 「隐私」里的「本地网络」权限被拒绝了。 |
| 只有一对设备互不相通 | 端口 53317 的 TCP 或 UDP 被挡了。`ufw`：`sudo ufw allow 53317`；`firewalld`：`firewall-cmd --permanent --add-port=53317/{tcp,udp}` 再 `firewall-cmd --reload`。 |
| 传得很慢 | 换 5 GHz，并在两端关掉加密。Android 上走 SAF 写入慢是已知限制。 |
| 改了设置没反应 | 有些设置会重启 HTTP 服务端，设置页会标出来。 |

## 与 LocalSend 的关系

Sonar 是 fork，不是 LocalSend 的分发版：

- 上游的应用代码不合进来。`app/` 的重设计是一次性的，不跟着上游维护；翻译也是手工改的品牌名，从不从上游合并。
- `packages/core` 确实跟上游，一次一个提交，上面叠一小组本地补丁。
- 协议保持兼容，所以 Sonar 设备与 LocalSend 设备能互传；反过来把这些补丁推回上游不是目标。
- 这是个人项目。带上诊断的 bug 报告欢迎；功能请求和 PR 可能被谢绝，以压住维护成本。

## 许可与署名

以 [Apache License 2.0](../../LICENSE) 分发。

原始作品 © Tien Do Nam 与 [LocalSend 贡献者](https://github.com/localsend/localsend/graphs/contributors)。
界面重设计与修改 © 2026 [Zephyr](https://github.com/zephyr-qu)。

内置字体以 SIL Open Font License 授权，许可文本在 [`app/assets/fonts/`](../../app/assets/fonts)。
Apache 许可不授予商标权（§6），所以这个 fork 以「Sonar」名义发布 —— 见 [NOTICE](../../NOTICE)。
