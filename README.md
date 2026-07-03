# Klonkt for Android <sup>alpha</sup>

Run a full [Klonkt](https://github.com/roboburr/klonkt) server on your Android
phone. **One APK, everything bundled** — Node.js, the Klonkt app, ffmpeg and a
Cloudflare tunnel. The first run installs completely offline in 1–2 minutes, and
your site gets a public HTTPS address through a free Cloudflare tunnel.

> **Status: alpha.** It works, but a phone is not a 24/7 server — Android may
> stop background processes, and heavy use makes your phone warm. Great for
> trying Klonkt, demos and small sites; for an always-on site use a
> [VPS install](https://klonkt.com/install).

## Download & install

**[⬇ klonkt.apk](https://github.com/roboburr/klonkt-android/releases/download/termux-latest/klonkt.apk)**
(~300 MB, always the latest build)

Full install guide, Cloudflare domain setup and troubleshooting:
**[klonkt.com/android](https://klonkt.com/android)**

Requirements: Android 7.0+, a 64-bit ARM phone (arm64 — practically everything
from ~2017 onward), ~2 GB free storage.

## How it works

The APK is a **modified build of [Termux](https://github.com/termux/termux-app)**
(the complete modification is [`termux-patch.diff`](termux-patch.diff) — hooks in
`TermuxActivity` that stage an offline bundle and start Klonkt). On first run it:

1. copies the bundled `.deb` packages (nodejs, ffmpeg, cloudflared + their full
   dependency closure) out of the APK and installs them with `dpkg` — no
   network needed;
2. unpacks a **prebuilt `klonkt-node`** (node_modules already compiled for
   aarch64, so phones never need compilers);
3. starts the server on `localhost:3020` and a Cloudflare tunnel, printing the
   public URL in the terminal.

Everything is (re)written idempotently on every app start, so a broken state
heals itself.

### Commands on the phone

| Command | What it does |
|---|---|
| `klonkt-token <token> [domain]` | Connect your own domain via a Cloudflare named tunnel (also sets Klonkt's public base URL). `klonkt-token clear` reverts to temporary trycloudflare URLs. |
| `klonkt-update` | Update Klonkt to the latest release build. Keeps `storage/` (database + uploads) and `.env`; the previous version stays as rollback in `~/klonkt-node.prev`. Also available as the update button on the in-app Updates page. |
| `bash ~/.klonkt-start.sh` | (Re)start everything manually — safe to run at any time. |

## How it's built (CI)

The [`Build Custom Termux APK`](.github/workflows/build-termux.yml) workflow:

1. **Prebake** (in `termux/termux-docker:aarch64` under QEMU,
   [`ci/prebake.sh`](ci/prebake.sh)): downloads the deb dependency closure,
   clones **klonkt @ the `stable` branch** (the same release channel
   self-hosted instances run), runs `npm install`, stubs `ffmpeg-static` to the
   system ffmpeg (its npm binary is glibc and can't run on Android), and
   **boot-tests the server inside the container** — the build fails hard if
   Klonkt doesn't actually start. Cached on the klonkt stable commit, so every
   new Klonkt release automatically produces a fresh bundle.
2. Clones upstream `termux-app`, applies `termux-patch.diff`, embeds the bundle
   in the APK assets and builds.
3. Publishes to the [`termux-latest`](../../releases/tag/termux-latest) release:
   `klonkt.apk`, `klonkt-node-arm64.tar.gz` (what `klonkt-update` downloads) and
   `BUILD-INFO.txt` (the exact upstream Termux and Klonkt commits of the build).

## Repository layout

| Path | Purpose |
|---|---|
| `termux-patch.diff` | The complete Termux modification (bootstrap + kickstart hooks) |
| `ci/prebake.sh` | Builds the offline bundle from klonkt@stable (runs in termux-docker) |
| `klonkt-update.sh` | The phone updater (fetched fresh by the `klonkt-update` command) |
| `.github/workflows/build-termux.yml` | The APK build + release pipeline |
| `app/src/main/assets/setup-termux-klonkt.sh` | Online fallback installer (used only if the bundled install is unavailable) |
| `app/` | A legacy WebView wrapper app (retired; kept for history) |

## Licenses

The released APK is a modified **Termux** build, distributed under the
**GPL-3.0** (see [`LICENSE`](LICENSE)) — all credit to the Termux maintainers.
The bundled Klonkt server is **AGPL-3.0-or-later**. Full attribution and the
per-component license table: [`NOTICE.md`](NOTICE.md). Each release ships a
`BUILD-INFO.txt` recording the exact source commits. This project is not
affiliated with or endorsed by the Termux project.
