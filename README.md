# Matrix Rain

**EN:** macOS screen saver and camera app with the "digital rain" look — Swift + Metal. &nbsp;·&nbsp; **PL:** wygaszacz ekranu i aplikacja z kamerą w stylu „kodu Matrixa” — Swift + Metal.

[English](#english) · [Polski](#polski)

<p align="center">
  <img src="https://raw.githubusercontent.com/Carrot79PL/matrix-rain/main/docs/preview-rain.png" alt="Matrix Rain – digital rain screen saver / wygaszacz" width="100%">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/Carrot79PL/matrix-rain/main/docs/preview-clock-red.png" alt="Clock made of code, red theme / zegar z kodu, motyw czerwony" width="100%">
</p>

---

## English

### Features

- Dense, layered rain with depth of field (far streams dimmer and blurred), mirrored glyphs, white heads with a glowing "neck"
- Multi-level bloom, chromatic aberration, film grain, flicker, glitch bands
- **CRT effects:** screen curvature that still fills the screen, scanlines, RGB phosphor mask, rolling refresh band, vignette
- **Image from code:** your photos or a live clock assembled out of falling glyphs (optionally in the photo's colors)
- 6 color themes: classic green, red pill, blue pill, gold, violet, mono
- Options panel in tabs, **Polish / English** UI
- **Matrix Rain Cam** — a separate app that shows your camera as code (mirror, fullscreen, hotkeys)

### Requirements

macOS 12+, Xcode command-line tools (`xcode-select --install`), a Metal-capable Mac.

### Build & install

```bash
# screen saver -> ~/Library/Screen Savers/Matrix Rain.saver
./build.sh install

# camera app -> ~/Applications/Matrix Rain Cam.app
./build_cam.sh
```

Then pick **Matrix Rain** in System Settings → Screen Saver. If an old version keeps showing up, switch to another
saver and back, or run `killall legacyScreenSaver`.

### Font

The original look uses the *Matrix Code* font (e.g. "Matrix Code NFI"). It is **not** included in this repository.
Put your own copy at `Resources/Matrix-Code.ttf` before building. Without it the build falls back to a system
katakana font (the rain still works, glyphs just look different).

### Options (screen saver)

| Tab | Settings |
|---|---|
| Look | color theme, glyph size, brightness, glow, vignette |
| Motion | density, speed, glitch, auto-zoom of glyphs (range + cycle) |
| CRT | curvature, scanlines, RGB mask, refresh band, grain |
| Image | rain only / photos / clock / photos + clock, image color, strength, change interval, choose photos (up to 12) |
| About | author, version, license |

The language list (Polski / English) is in the top-right corner of the options window.

### Matrix Rain Cam — hotkeys

`1` camera · `2` rain · `3` clock · `T` theme · `C` photo colors · `M` mirror · `+`/`-` glyph size · `[`/`]` image strength ·
`G` glitch · `K` CRT · `V` vignette · `Z` auto-zoom · `F`/Enter fullscreen · `H` help · `L` language · `Esc`/`Q` quit

macOS screen savers run in a sandbox that does not grant camera access, which is why the camera lives in a separate app.
The first launch asks for camera permission.

---

## Polski

### Funkcje

- Gęsty, warstwowy deszcz kodu z głębią ostrości (dalsze strumienie ciemniejsze i rozmyte), odbite lustrzanie znaki, białe głowy ze świecącą „szyją”
- Wielopoziomowa poświata (bloom), aberracja chromatyczna, ziarno filmowe, migotanie, pasy glitch
- **Efekty CRT:** wygięcie ekranu wypełniające cały ekran, linie skanowania, maska RGB luminoforu, przesuwające się pasmo odświeżania, winieta
- **Obraz z kodu:** Twoje zdjęcia albo zegar na żywo układane ze spadających znaków (opcjonalnie w kolorach zdjęcia)
- 6 motywów kolorów: klasyczny zielony, czerwona pigułka, niebieska pigułka, złoto, fiolet, mono
- Panel opcji w zakładkach, interfejs **po polsku i angielsku**
- **Matrix Rain Cam** — osobna aplikacja pokazująca obraz z kamery jako kod (lustro, pełny ekran, skróty klawiszowe)

### Wymagania

macOS 12+, narzędzia wiersza poleceń Xcode (`xcode-select --install`), Mac z obsługą Metal.

### Budowanie i instalacja

```bash
# wygaszacz -> ~/Library/Screen Savers/Matrix Rain.saver
./build.sh install

# aplikacja z kamerą -> ~/Applications/Matrix Rain Cam.app
./build_cam.sh
```

Następnie wybierz **Matrix Rain** w Ustawieniach systemu → Wygaszacz ekranu. Jeśli nadal widać starą wersję, wybierz inny
wygaszacz i wróć albo uruchom `killall legacyScreenSaver`.

### Czcionka

Oryginalny wygląd używa czcionki *Matrix Code* (np. „Matrix Code NFI”). **Nie ma jej** w tym repozytorium.
Przed budową wstaw własną kopię do `Resources/Matrix-Code.ttf`. Bez niej skrypt użyje systemowej czcionki z katakaną
(deszcz działa, tylko znaki wyglądają inaczej).

### Opcje wygaszacza

| Zakładka | Ustawienia |
|---|---|
| Wygląd | motyw kolorów, rozmiar znaków, jasność, poświata, winieta |
| Ruch | gęstość, prędkość, glitch, auto-zoom znaków (zakres + cykl) |
| Ekran CRT | wygięcie, linie skanowania, maska RGB, pasmo odświeżania, ziarno |
| Obraz | tylko deszcz / zdjęcia / zegar / zdjęcia i zegar, kolor obrazu, widoczność, czas zmiany, wybór zdjęć (do 12) |
| Info | autor, wersja, licencja |

Lista języka (Polski / English) jest w prawym górnym rogu okna opcji.

### Matrix Rain Cam — skróty

`1` kamera · `2` deszcz · `3` zegar · `T` motyw · `C` kolory zdjęcia · `M` lustro · `+`/`-` rozmiar znaków · `[`/`]` widoczność obrazu ·
`G` glitch · `K` CRT · `V` winieta · `Z` auto-zoom · `F`/Enter pełny ekran · `H` pomoc · `L` język · `Esc`/`Q` wyjście

Wygaszacze macOS działają w piaskownicy bez dostępu do kamery, dlatego kamera jest w osobnej aplikacji.
Przy pierwszym uruchomieniu system poprosi o zgodę na kamerę.

---

## License / Licencja

MIT © 2026 Tomasz Marchewka — see / zobacz [LICENSE](LICENSE).

Unofficial fan project, not affiliated with or endorsed by the makers or owners of the film "The Matrix".
Nieoficjalny projekt fanowski, niezwiązany z filmem „Matrix” ani jego właścicielami.
