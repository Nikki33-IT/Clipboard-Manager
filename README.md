# ClipVault

[![Flutter](https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows-blue)](https://www.microsoft.com/windows)
[![Version](https://img.shields.io/badge/version-0.1.0-green)](lib/app_version.dart)
[![Tests](https://img.shields.io/badge/tests-12_passed-green)](#testy)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#licencja)

Lokalny, prywatny menedzer historii schowka na Windows. Dziala w tle, zapamietuje wszystko co kopiujesz (Ctrl+C) i pozwala wrocic do dowolnego wczesniejszego wpisu jednym kliknieciem lub globalnym skrotem.

Zero chmury, zero telemetrii, zero kont. Wszystkie dane zostaja na Twoim dysku.

---

## Spis tresci

- [Co potrafi aplikacja](#co-potrafi-aplikacja)
- [Jak to dziala](#jak-to-dziala)
- [Prywatnosc](#prywatnosc)
- [Wymagania](#wymagania)
- [Instalacja (gotowy .exe)](#instalacja-gotowy-exe)
- [Uruchomienie z kodu zrodlowego](#uruchomienie-z-kodu-zrodlowego)
- [Obsluga na co dzien](#obsluga-na-co-dzien)
- [Ustawienia](#ustawienia)
- [Aktualizacje](#aktualizacje)
- [Struktura projektu](#struktura-projektu)
- [Testy](#testy)
- [Budowanie paczki portable](#budowanie-paczki-portable)
- [Ograniczenia i plan rozwoju](#ograniczenia-i-plan-rozwoju)
- [Licencja](#licencja)

---

## Co potrafi aplikacja

**Historia schowka**
- Automatycznie zapisuje kazdy skopiowany tekst (lekki polling schowka co ~500 ms).
- Deduplikacja: ponowne skopiowanie tego samego tekstu przenosi wpis na gore zamiast tworzyc duplikat.
- Wpisy przycinane do 200 000 znakow, zeby nie rozdac bazy.
- Licznik uzyc (`useCount`) i znacznik ostatniego uzycia (`lastUsedAt`) przy kazdym wpisie.
- Pinezki: przypiete wpisy przetrwaja czyszczenie historii (`Wyczysc historie` domyslnie zostawia przypiete).

**Wyszukiwanie i klasyfikacja**
- Biezace filtrowanie po frazie z pola wyszukiwania.
- Automatyczne rozpoznawanie typu tresci: zwykly tekst, tekst wieloliniowy, link, e-mail (z wlasna ikona na liscie).
- Architektura gotowa na obraz/HTML/RTF (`ClipContentType`), na razie obslugiwany jest tekst.

**Praca w tle jak przystalo na Windows**
- Ikona w zasobniku systemowym (tray) z menu: Otworz historie, Wstrzymaj/Wznow monitorowanie, Wyczysc historie, Ustawienia, Wyjscie.
- Zamykanie okna (X) minimalizuje do traya zamiast wylaczac aplikacje.
- Globalny skrot systemowy (domyslnie `Ctrl+Shift+V`) przywracajacy okno z dowolnego miejsca. Skrot mozna zmienic w ustawieniach.
- Opcjonalny autostart z systemem.
- Motywy: jasny, ciemny, systemowy.

**Limity i porzadek**
- Limit liczby wpisow (50 / 100 / 500 / 1000 / bez limitu, domyslnie 500) egzekwowany w SQLite.
- Opcjonalne automatyczne czyszczenie starych elementow.
- Ręczne czyszczenie jednym klikiem (z traya lub z poziomu aplikacji).

**Ustawienia przenosne**
- Eksport i import ustawien do JSON (z ostrzezeniem o poufnosci przed eksportem).
- Przywracanie ustawien domyslnych jednym przyciskiem.
- Ustawienia trzymane lokalnie w `settings.json` (patrz [Jak to dziala](#jak-to-dziala)).

**Aktualizacje na zadanie**
- Przycisk `Ustawienia -> O aplikacji -> Sprawdz aktualizacje` sprawdza najnowszy Release na GitHubie.
- Tylko na Twoje klikniecie — aplikacja nigdy sama nie dzwoni do internetu.
- Jesli jest nowsza wersja, jednym przyciskiem pobiera paczke portable i podmienia pliki (`update.ps1` robi backup, podmiane i restart).

---

## Jak to dziala

```
Schowek Windows
      |  polling co 500 ms (PollingClipboardMonitor)
      v
HeuristicSecretDetector  --->  podejrzany sekret? + saveSecrets=false -> odrzuc
      |
      v
ContentTypeClassifier (tekst / link / e-mail / wieloliniowy)
      |
      v
SqliteHistoryRepository (clipboard_history.db przez sqflite_ffi)
      |
      v
HistoryController (Riverpod StateNotifier) -> Historia / wyszukiwarka w UI
```

- **Stan:** Flutter + `flutter_riverpod`. `HistoryController` laczy monitor schowka, detektor sekretow i repozytorium; `SettingsController` trzyma `AppSettings` i zapisuje kazda zmiane na dysk.
- **Baza:** SQLite (`sqflite_common_ffi`, bo zwykly `sqflite` jest mobilny). Plik `clipboard_history.db` w katalogu support aplikacji, tabela `clip_items` z indeksem po `copiedAt`. Zapytania parametryzowane, bez interpolacji SQL.
- **Monitor:** Flutter na desktopie nie ma zdarzenia "schowek sie zmienil", wiec jest polling `Clipboard.getData` z flaga `suppressNextChange()` — wklejenie z historii nie tworzy petli ani duplikatu.
- **Warstwy:** `domain` (encje `ClipItem`, interfejsy, klasyfikator) -> `data` (SQLite) -> `application` (providery Riverpod) -> `platform` (tray, skrot, autostart) -> `security` / `settings` / `services` -> `presentation` (ekrany, widgety, motyw).

---

## Prywatnosc

- **Local-first:** historia (`clipboard_history.db`) i ustawienia (`settings.json`) leza w lokalnym katalogu aplikacji. Nic nie jest wysylane nigdzie automatycznie.
- **Jedyny ruch sieciowy** to jawne klikniecie `Sprawdz aktualizacje` (zapytanie do `api.github.com/repos/<owner>/<repo>/releases/latest`).
- **Detektor sekretow** (`HeuristicSecretDetector`) rozpoznaje m.in. tokeny GitHub (`ghp_...`), klucze w stylu `sk-...`, AWS Access Key ID (`AKIA...`), JWT, klucze prywatne (`-----BEGIN ... PRIVATE KEY-----`), numery kart oraz krotkie losowe ciagi o wysokiej entropii Shannona (> 3.5) z mieszanymi klasami znakow. Wykryte sekrety domyslnie **nie sa zapisywane** (przelacznik `Zapisuj potencjalne sekrety`).
- **Lista wykluczonych aplikacji** (domyslnie m.in. menedzery hasel) jest przechowywana w ustawieniach.
- Eksport ustawien pokazuje wczesniej ostrzezenie, bo plik moze zawierac wrazliwe dane.

---

## Wymagania

- Windows 10/11 x64.
- Do uruchamiania gotowej paczki: nic wiecej (portable, bez instalatora).
- Do budowania z kodu: [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (testowane na 3.47 / Dart 3.13) + Visual Studio 2022 z komponentem `Desktop development with C++`.

---

## Instalacja (gotowy .exe)

1. Wejdz w **Releases** tego repozytorium.
2. Pobierz `ClipVault-Windows-Portable.zip` z najnowszego wydania.
3. Rozpakuj w dowolnym miejscu.
4. Uruchom `clipvault.exe`.

Aplikacja osiądzie w trayu. Skopiuj cos (Ctrl+C) i otworz historie globalnym skrotem `Ctrl+Shift+V`.

---

## Uruchomienie z kodu zrodlowego

```powershell
flutter pub get
flutter test
flutter run -d windows
```

---

## Obsluga na co dzien

| Akcja | Jak |
|---|---|
| Otworz historie | Klik w ikone traya albo globalny skrot `Ctrl+Shift+V` |
| Wklej starszy wpis | Kliknij wpis na liscie (jedno- lub dwuklik) — wraca do schowka, potem Ctrl+V tam gdzie chcesz |
| Przypnij / odepnij | Ikona pinezki przy wpisie |
| Usun wpis | Ikona kosza przy wpisie |
| Szukaj | Pole `Szukaj w historii…` (Enter wkleja pierwszy wynik) |
| Pauza monitorowania | Tray -> `Wstrzymaj monitorowanie` albo przelacznik w ustawieniach |
| Calkowite wyjscie | Tray -> `Wyjscie` (sam X tylko chowa do traya) |
| Zamknij ustawienia | Klawisz `Esc` |

---

## Ustawienia

- **Historia:** limit elementow (50/100/500/1000/bez limitu), automatyczne czyszczenie starych.
- **Ogolne:** autostart z systemem, wlaczenie monitorowania, globalny skrot (edytor lapie kombinacje klawiszy).
- **Wyglad:** motyw jasny / ciemny / systemowy.
- **Prywatnosc:** zapisywanie sekretow (domyslnie wylaczone), podglad listy wykluczonych aplikacji.
- **Dane:** eksport / import JSON, reset do domyslnych.
- **O aplikacji:** numer wersji + reczne sprawdzanie aktualizacji.

---

## Aktualizacje

Obsluga znajduje sie w `Ustawienia -> O aplikacji -> Sprawdz aktualizacje`.

Jak wydac nowa wersje (dla opiekuna repo):

1. Podbij `kAppVersion` w `lib/app_version.dart` i `version:` w `pubspec.yaml`.
2. Zbuduj paczke portable (patrz nizej).
3. Na GitHubie: **Releases -> Draft a new release**, tag np. `v0.2.0`, zalacz `ClipVault-Windows-Portable.zip` (nazwa musi zawierac `portable` i konczyc sie na `.zip`).
4. Opublikuj. Uzytkownicy ze starsza wersja zobacza aktualizacje po kliknieciu przycisku.

> `kGithubRepo` w `lib/app_version.dart` musi miec format `wlasciciel/nazwa-repo` (np. `allynIT/Clipboard-Manager`), bo na jego podstawie budowany jest URL GitHub API.

---

## Struktura projektu

```
lib/
  app_version.dart     - wersja aplikacji + id repo GitHub (owner/repo)
  domain/              - ClipItem, ContentTypeClassifier, interfejsy repozytoriow
  data/                - SqliteHistoryRepository (sqflite_ffi)
  application/         - providery Riverpod (HistoryController, SettingsController)
  platform/            - polling schowka, tray, globalny skrot, autostart
  security/            - HeuristicSecretDetector
  settings/            - AppSettings (niemutowalny, copyWith) + SettingsRepository (JSON)
  services/            - UpdateChecker (GitHub Releases, tylko na zadanie)
  presentation/        - MaterialApp, ekrany historii/ustawien, widgety, motyw
test/                  - testy jednostkowe (settings, classifier, secret detector)
windows/               - runner desktopowy (generowany przez flutter create)
windows_update_script/ - update.ps1 dolaczany do paczki portable
assets/                - tray_icon.ico
```

---

## Testy

```powershell
flutter analyze
flutter test
```

Zakres: round-trip JSON ustawien (w tym `historyLimit: null`), klasyfikator tresci (link / e-mail / wielolinijkowiec / tekst), detektor sekretow (GitHub token, JWT, karta, zdania negatywne).

---

## Budowanie paczki portable

Najprosciej gotowym skryptem (zależności, testy, build release, dolaczenie `update.ps1`, pakowanie do ZIP):

```powershell
build_windows_portable.bat
```

Wynik: `build\releases\ClipVault-Windows-Portable.zip` (w srodku `.exe`, DLL-e, `data/`, `update.ps1`).

Recznie:

```powershell
flutter pub get
flutter build windows --release
Copy-Item windows_update_script\update.ps1 build\windows\x64\runner\Release\
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath build\releases\ClipVault-Windows-Portable.zip -Force
```

---

## Ograniczenia i plan rozwoju

- Monitoring to polling (~500 ms) — swiadomy wybor: najbardziej niezawodne podejscie z poziomu Fluttera na desktopie, kosztem ulamka sekundy opoznienia.
- W tej wersji obslugiwany jest tekst. Obrazy, HTML i RTF maja gotowe typy w `ClipContentType`, ale nie sa jeszcze zapisywane.
- Szyfrowanie zawartosci (AES-GCM + systemowy keystore, `flutter_secure_storage` jest juz w zaleznosciach) jest przygotowane architektonicznie, ale nie wlaczone produkcyjnie.
- Naturalni kandydaci na kolejne wersje: pelna lista wykluczonych aplikacji z wykrywaniem aktywnego okna, edycja wpisow, ulubione, synchronizacja opcjonalna.

---

## Licencja

Projekt prywatny. Jesli planujesz go upublicznic lub oddac innym, dodaj tu wybrana licencje (np. MIT) w pliku `LICENSE`.
