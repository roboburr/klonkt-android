# Licenses & attribution

The released `klonkt.apk` is a **modified build of [Termux](https://github.com/termux/termux-app)**,
licensed under the **GNU General Public License v3.0** (see `LICENSE`).
All credit for the terminal app, its terminal emulator and its package
ecosystem goes to the Termux maintainers and contributors.

## How this build corresponds to its source

The APK is built by CI from:

- upstream `termux-app` (cloned at build time from
  https://github.com/termux/termux-app), plus
- [`termux-patch.diff`](termux-patch.diff) in this repository (the complete
  modification: the Klonkt bootstrap/kickstart hooks in `TermuxActivity`).

The exact upstream commit used for a given release is recorded in the
`BUILD-INFO.txt` asset published alongside the APK. Build recipe:
[`.github/workflows/build-termux.yml`](.github/workflows/build-termux.yml).

## Components bundled inside the APK

| Component | License |
|---|---|
| Termux app + bootstraps | GPLv3 (app); packages under their own licenses |
| Klonkt (`klonkt-node`, the actual server) | AGPL-3.0-or-later — source: https://github.com/roboburr/klonkt |
| Node.js (from the Termux package repo) | MIT |
| ffmpeg (from the Termux package repo) | GPL/LGPL |
| cloudflared (from the Termux package repo) | Apache-2.0 |
| Debian packages in the offline bundle | each under its own license (Termux main repo) |

## Trademarks / naming

"Klonkt" is the name of this distribution and of the bundled server
software. This project is not affiliated with or endorsed by the Termux
project; the app it modifies is and remains Termux, used under the GPLv3.
