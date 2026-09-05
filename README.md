<div align="center">

<img src="docs/logo.png" width="96" alt="ClipVault logo"/>

# ClipVault

**Lokalny, prywatny menedzer historii schowka na Windows.**

Wszystko co kopiujesz (Ctrl+C) — jedno wcisniecie przycisku dzieli Cie od odzyskania tego.

[![Release](https://img.shields.io/github/v/release/allynIT/Clipboard-Manager?label=release&color=green)](https://github.com/allynIT/Clipboard-Manager/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)](https://github.com/allynIT/Clipboard-Manager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-12%20passed-green)](#testy)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#licencja)

[⬇ Pobierz najnowsza wersje](https://github.com/allynIT/Clipboard-Manager/releases/latest) · [Zglos blad](https://github.com/allynIT/Clipboard-Manager/issues) · [Jak to dziala](#jak-to-dziala)

</div>

---

## Dlaczego ClipVault

| | ClipVault | Zwykly schowek Windows |
|---|---|---|
| Historia bez limitu czasu | Tak (SQLite, limit do 1000+) | Tylko 25 ostatnich, czyszczone po restarcie |
| Wyszukiwanie i filtry | Tak (tekst, linki, e-maile, przypiete) | Nie |
| Pinezki i licznik uzyc | Tak | Nie |
| Globalny skrot | Tak (`Ctrl+Shift+V`) | Tak (`Win+V`), ale bez historii dlugoterminowej |
| Wykrywanie haseł i tokenow | Tak (domyslnie nie zapisuje) | Nie |
| Telemetria / konto / chmura | Brak — 100% lokalnie | Konto Microsoft, synchronizacja z chmura |

## Funkcje

- **Historia schowka** — automatyczny zapis kazdego skopiowanego tekstu, deduplikacja (ponowne kopiowanie przenosi wpis na gore), przypinanie, licznik uzyc i czas wzgledny ("5 min temu").
- **Blyskawiczne wyszukiwanie** — z debounce, podswietlaniem frazy i filtrami: Wszystko / Przypiete / Linki / E-maile / Tekst. Enter kopiuje pierwszy wynik, po skopiowaniu dostajesz dyskretny toast.
- **Praca w tle jak na Windows przystalo** — ikona w trayu z menu, X minimalizuje zamiast zamykac, globalny skrot `Ctrl+Shift+V`, opcjonalny autostart.
- **Stroz prywatnosci** — wykrywa tokeny GitHub, klucze API, JWT, klucze prywatne, numery kart i losowe hasla — i domyslnie ich **nie zapisuje**.
- **Aktualizacje jednym klikiem** — Ustawienia → O aplikacji → Sprawdz aktualizacje. Zero ruchu sieciowego bez Twojej zgody.
- **Motywy** — jasny, ciemny, systemowy + wybor koloru akcentu (8 kolorow). Skroty: `Ctrl+F` (szukaj), `Esc` (zamknij ustawienia).

## Instalacja

1. Pobierz **`ClipVault-Windows-Portable.zip`** ze strony [Releases](https://github.com/allynIT/Clipboard-Manager/releases/latest).
2. Rozpakuj w dowolnym miejscu.
3. Uruchom **`clipvault.exe`** — bez instalatora, bez uprawnien administratora.

> Skopiuj cos (Ctrl+C) i wcisnij `Ctrl+Shift+V` — wpis pojawi sie na liscie.

## Ustawienia w skrocie

Historia (limit 50–1000, retencja 1/7/30 dni, auto-czyszczenie) · Autostart (tez zminimalizowany) · Monitorowanie · X zamyka lub minimalizuje · Okno zawsze na wierzchu · Wlasny skrot globalny · Motyw + akcent · Zapisywanie sekretow (domyslnie OFF) · Edytowalna lista wykluczonych aplikacji · Toast kopiowania · Eksport/import JSON · Reset do domyslnych · Sprawdzanie aktualizacji.

## Prywatnosc

- **Local-first:** historia (`clipboard_history.db`) i ustawienia (`settings.json`) leza tylko w `%APPDATA%\com.example\ClipVault`. Zadnej chmury, zadnej telemetrii, zadnych kont.
- **Jedyny ruch sieciowy** to Twoje jawne klikniecie "Sprawdz aktualizacje" (zapytanie do GitHub API o najnowszy Release).
- Eksport ustawien wczesniej pokazuje ostrzezenie — plik moze zawierac wrazliwe dane.

## Jak to dziala

```
Schowek Windows ──polling 500ms──▶ Detektor sekretow ──▶ Klasyfikator typu
        (pomija wlasne wklejenia)      (blokuje hasla)      (tekst/link/e-mail)
                                                              │
                                                              ▼
                                            SQLite ◀── HistoryController (Riverpod)
```

Stan: Flutter + `flutter_riverpod` · Baza: SQLite przez `sqflite_common_ffi` (zapytania parametryzowane) · Platforma: `window_manager`, `tray_manager`, `hotkey_manager`, `launch_at_startup`.

## Dla deweloperow

```powershell
flutter pub get        # zaleznosci
flutter test           # 12 testow jednostkowych
flutter run -d windows # tryb deweloperski
build_windows_portable.bat  # paczka: build\releases\ClipVault-Windows-Portable.zip
```

```
lib/
  domain/       - ClipItem, klasyfikator, interfejsy
  data/         - repozytorium SQLite
  application/  - kontrolery Riverpod (historia, ustawienia)
  platform/     - schowek, tray, skrot globalny, autostart
  security/     - heurystyczny detektor sekretow
  settings/     - AppSettings + repozytorium JSON
  services/     - sprawdzanie aktualizacji (GitHub Releases), log diagnostyczny
  presentation/ - ekrany, widgety, motyw Material 3
test/           - testy jednostkowe
```

Nowe wydanie: podbij `kAppVersion` (`lib/app_version.dart`) i `version` (`pubspec.yaml`) → zbuduj paczke → utworz Release z tagiem `vX.Y.Z` i zalacz ZIP (nazwa musi zawierac `portable` i konczyc sie na `.zip`).

## Licencja

MIT — zobacz [LICENSE](LICENSE).
