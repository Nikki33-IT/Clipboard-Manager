# CopyPaste Clone

Lokalny, prywatny menedżer historii schowka dla Windows (Flutter Desktop).
Wszystkie dane trzymane są na dysku użytkownika — brak telemetrii, brak
komunikacji z internetem, brak logowania zawartości schowka.

## Najszybsza droga do gotowego pliku .exe (bez instalowania czegokolwiek)

Nie musisz instalować Fluttera ani Visual Studio na swoim komputerze —
GitHub w chmurze zbuduje to za Ciebie, za darmo.

### Krok po kroku

1. **Załóż konto na [github.com](https://github.com)** (jeśli jeszcze nie masz) —
   wystarczy e-mail i hasło, karta płatnicza nie jest potrzebna.

2. **Utwórz nowe repozytorium**:
   - Kliknij zielony przycisk **"New"** na stronie głównej GitHub.
   - Nadaj nazwę np. `copypaste-clone`.
   - Zostaw ustawienie **Private** (prywatne) lub Public — oba działają.
   - Kliknij **"Create repository"**.

3. **Wgraj pliki projektu** (ten folder, który dostałeś ode mnie):
   - Na stronie nowego, pustego repozytorium kliknij link
     **"uploading an existing file"**.
   - Przeciągnij tam **całą zawartość** tego folderu (wszystkie pliki
     i podfoldery, zachowując strukturę — możesz przeciągnąć cały
     rozpakowany folder na raz w większości przeglądarek, albo dodawać
     podfoldery jeden po drugim, jeśli przeglądarka tego wymaga).
   - Na dole kliknij **"Commit changes"**.

4. **Uruchom budowanie**:
   - Wejdź w zakładkę **"Actions"** na górze repozytorium.
   - Po lewej wybierz **"Build Windows Portable"**.
   - Kliknij przycisk **"Run workflow"** (po prawej) → **"Run workflow"**
     jeszcze raz, żeby potwierdzić.

5. **Poczekaj ok. 5–10 minut** — GitHub w tym czasie w swojej chmurze,
   na prawdziwym Windows, instaluje Flutter, buduje aplikację i pakuje ją
   do ZIP-a. Odświeżaj stronę Actions, aż zobaczysz zielony ✅ przy
   uruchomieniu.

6. **Pobierz gotową paczkę**:
   - Kliknij w zakończone uruchomienie (z zielonym ✅).
   - Na dole strony, w sekcji **"Artifacts"**, znajdziesz
     `CopyPaste-Windows-Portable` — kliknij, żeby pobrać ZIP.

7. **Rozpakuj i uruchom**:
   - Rozpakuj pobrany plik ZIP w dowolnym miejscu.
   - Uruchom `copypaste_clone.exe` (lub podobnie nazwany plik `.exe`
     w środku) — gotowe, aplikacja działa bez instalatora.

## Alternatywa: budowanie lokalnie

Jeśli w przyszłości zdecydujesz się zainstalować
[Flutter SDK](https://docs.flutter.dev/get-started/install/windows) oraz
Visual Studio 2022 (komponent "Desktop development with C++"), możesz
zbudować projekt lokalnie:

```
build_windows_portable.bat
```

Skrypt sam sprawdzi zależności, uruchomi testy, zbuduje wersję release
i spakuje ją do `build\releases\CopyPaste-Windows-Portable.zip`.

## Konfiguracja przycisku "Sprawdź aktualizacje"

Aplikacja ma przycisk w Ustawieniach → "O aplikacji" → "Sprawdź aktualizacje",
który **wyłącznie na Twoje żądanie** (nigdy automatycznie) sprawdza najnowsze
wydanie na GitHub i pozwala je zainstalować jednym kliknięciem.

Żeby to działało z Twoim repozytorium:

1. Otwórz `lib/app_version.dart` i podmień `kGithubRepo` na swoje
   repozytorium, np. `'janek123/copypaste-clone'`.
2. Przy każdym nowym wydaniu:
   - podbij `kAppVersion` w tym samym pliku (np. `'0.2.0'`),
   - podbij też `version:` w `pubspec.yaml`,
   - zbuduj nową paczkę portable (lokalnie albo przez Actions),
   - na GitHub wejdź w **Releases → Draft a new release**, ustaw tag np.
     `v0.2.0`, i **załącz plik `CopyPaste-Windows-Portable.zip`** jako asset
     (nazwa pliku musi zawierać słowo "portable" i kończyć się na `.zip`,
     żeby aplikacja sama go znalazła).
3. Opublikuj wydanie ("Publish release").

Od tej pory każdy, kto ma starszą wersję aplikacji i kliknie "Sprawdź
aktualizacje", zobaczy informację o nowej wersji i będzie mógł ją
zainstalować jednym przyciskiem — skrypt `update.ps1` (dołączony
automatycznie do każdej paczki portable) sam pobierze nową wersję,
zrobi kopię zapasową starej, podmieni pliki i uruchomi aplikację ponownie.

## Struktura projektu

```
lib/
  domain/          - encje i interfejsy (ClipItem, HistoryRepository, ...)
  data/            - implementacja SQLite
  application/     - stan aplikacji (Riverpod), logika łącząca warstwy
  platform/        - schowek, tray, globalny skrót, autostart
  security/        - heurystyczny detektor sekretów
  settings/        - model i repozytorium ustawień
  presentation/    - ekrany, widgety, motyw
test/              - testy jednostkowe
.github/workflows/ - automatyczny build Windows w chmurze
```

## Ograniczenia i uwagi

- Monitorowanie schowka działa przez lekki polling (~500ms) — to
  najbardziej niezawodne podejście cross-platformowe dostępne z poziomu
  Fluttera na desktopie.
- Szyfrowanie zawartości (AES-GCM przez system keystore) jest
  przygotowane architektonicznie (`SecureStorage`), ale wymaga
  dodatkowej integracji z `flutter_secure_storage` przed produkcyjnym
  użyciem — zaznacz to wyraźnie w ustawieniach, jeśli nie jest w pełni
  wdrożone w Twojej wersji.
- Obsługa obrazów, HTML i RTF jest przygotowana w architekturze
  (`ClipContentType`), ale nie zaimplementowana w pierwszej wersji —
  zgodnie ze specyfikacją.
