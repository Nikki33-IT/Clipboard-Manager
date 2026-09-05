<div align="center">

<img src="docs/logo.png" width="96" alt="ClipVault logo"/>

# ClipVault

**Local, private clipboard history manager for Windows.**

Everything you copy (Ctrl+C) — one keypress away from getting it back.

[![Release](https://img.shields.io/github/v/release/allynIT/Clipboard-Manager?label=release&color=green)](https://github.com/allynIT/Clipboard-Manager/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)](https://github.com/allynIT/Clipboard-Manager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-passing-green)](#tests)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#license)

[⬇ Download latest](https://github.com/allynIT/Clipboard-Manager/releases/latest) · [Report a bug](https://github.com/allynIT/Clipboard-Manager/issues) · [How it works](#how-it-works)

</div>

---

## Why ClipVault

| | ClipVault | Plain Windows clipboard |
|---|---|---|
| Long-term history | Yes (SQLite, up to 1000+ items) | Only last 25, wiped on reboot |
| Search & filters | Yes (text, links, emails, pinned) | No |
| Pins & usage counter | Yes | No |
| Global hotkey | Yes (`Ctrl+Shift+V`, toggles window) | Yes (`Win+V`), but no long-term history |
| Password & token detection | Yes (skipped by default) | No |
| Telemetry / account / cloud | None — 100% local | Microsoft account, cloud sync |

## Features

- **Clipboard history** — every copied text saved automatically, deduplication (re-copying moves the entry to the top), pins, usage counter and relative time ("5 min ago").
- **Screenshots & images** — PrintScreen and copied images land in history with thumbnails (converted to lightweight PNG), one click puts them back on the clipboard. Copied **files** too.
- **Blazing search** — debounced, with phrase highlighting and filters: All / Pinned / Links / Emails / Text. Enter copies the first result.
- **Day groups & entrance animations** — pinned section on top, then Today / Yesterday / dates; new entries slide in, scrolling stays smooth.
- **A real Windows citizen** — tray icon with menu (left-click opens, right-click shows options), X minimizes instead of quitting, global toggle hotkey `Ctrl+Shift+V`, optional autostart.
- **Privacy guard** — detects GitHub tokens, API keys, JWTs, private keys, card numbers and random passwords — and **does not save them** by default.
- **One-click updates** — Settings → About → Check for updates. Zero network traffic without your consent.
- **Looks** — light / dark / system themes + 8 accent colors, English & Polish UI. Shortcuts: `Ctrl+F` (search), `Esc` (close settings).

## Installation

1. Download **`ClipVault-Windows-Portable.zip`** from [Releases](https://github.com/allynIT/Clipboard-Manager/releases/latest).
2. Unpack anywhere.
3. Run **`clipvault.exe`** — no installer, no admin rights needed.

> Copy something (Ctrl+C) and press `Ctrl+Shift+V` — the entry appears in the list. Press the hotkey again to hide the window.

## Settings at a glance

History (50–1000 limit, 1/7/30-day retention, auto-clean, images & files) · Autostart (also minimized) · Monitoring · X closes or minimizes · Always on top · Custom global hotkey · Theme + accent + language · Secrets saving (OFF by default) · Editable excluded-app list · Copy toast · JSON export/import · Reset to defaults · Update check.

## Privacy

- **Local-first:** history (`clipboard_history.db`) and settings (`settings.json`) live only in `%APPDATA%\com.example\ClipVault`. No cloud, no telemetry, no accounts.
- **The only network traffic** is your explicit "Check for updates" click (a GitHub API query for the latest release).
- Settings export shows a warning first — the file may hold sensitive data.

## How it works

```
Windows clipboard ──500ms poll──▶ Secret detector ──▶ Type classifier
      (skips our own writes)      (blocks passwords)   (text/link/email)
                                                              │
                                                              ▼
                                            SQLite ◀── HistoryController (Riverpod)
```

State: Flutter + `flutter_riverpod` · Database: SQLite via `sqflite_common_ffi` (parameterized queries) · Platform: `window_manager`, `tray_manager`, `hotkey_manager`, `launch_at_startup` · Images: `pasteboard` + `image` (BMP → resized PNG).

## For developers

```powershell
flutter pub get        # dependencies
flutter test           # unit tests
flutter run -d windows # dev mode
build_windows_portable.bat  # package: build\releases\ClipVault-Windows-Portable.zip
```

```
lib/
  domain/       - ClipItem, classifier, interfaces, localization (EN/PL)
  data/         - SQLite repository
  application/  - Riverpod controllers (history, settings)
  platform/     - clipboard, tray, global hotkey, autostart
  security/     - heuristic secret detector
  settings/     - AppSettings + JSON repository
  services/     - update checker (GitHub Releases), log file
  presentation/ - screens, widgets, Material 3 theme
test/           - unit tests
```

New release: bump `kAppVersion` (`lib/app_version.dart`) and `version` (`pubspec.yaml`) → build the package → create a Release tagged `vX.Y.Z` with the ZIP attached (name must contain `portable` and end with `.zip`).

## Author

Made by **[allynIT](https://github.com/allynIT)** — bug reports and ideas welcome in [Issues](https://github.com/allynIT/Clipboard-Manager/issues).

## License

MIT — see [LICENSE](LICENSE).
