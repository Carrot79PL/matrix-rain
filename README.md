# Matrix Rain

A macOS screen saver and a camera app that render the "digital rain" look — written in Swift + Metal.
Screen saver w Swift + Metal oraz aplikacja z kamerą w stylu „kodu Matrixa”. [Po polsku niżej ↓](#po-polsku)

| Rain | Clock made of code |
|---|---|
| ![rain](docs/preview-rain.png) | ![clock](docs/preview-clock-red.png) |

## Features

- Dense, layered rain with depth of field (far streams are dimmer and blurred), mirrored glyphs, white heads with a glowing "neck"
- Multi-level bloom, chromatic aberration, film grain, flicker, glitch bands
- **CRT effects:** screen curvature that still fills the screen, scanlines, RGB phosphor mask, rolling refresh band, vignette
- **Image from code:** your photos or a live clock are assembled out of falling glyphs (optionally in the photo's colors)
- 6 color themes (classic green, red pill, blue pill, gold, violet, mono)
- Options panel organised in tabs, **Polish / English** UI
- **Matrix Rain Cam** – a separate app that shows your camera as code (mirror, fullscreen, hotkeys)

## Requirements

macOS 12+, Xcode command-line tools (`xcode-select --install`), a Metal-capable Mac.

## Build & install

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

## Options (screen saver)

| Tab | Settings |
|---|---|
| Look | color theme, glyph size, brightness, glow, vignette |
| Motion | density, speed, glitch |
| CRT | curvature, scanlines, RGB mask, refresh band, grain |
| Image | rain only / photos / clock / photos + clock, image color, strength, change interval, choose photos (up to 12) |
| About | author, version, license |

## Matrix Rain Cam – hotkeys

`1` camera · `2` rain · `3` clock · `T` theme · `C` photo colors · `M` mirror · `+`/`-` glyph size · `[`/`]` image strength ·
`G` glitch · `K` CRT · `V` vignette · `F`/Enter fullscreen · `H` help · `L` language · `Esc`/`Q` quit

macOS screen savers run in a sandbox that does not grant camera access, which is why the camera lives in a separate app.
The first launch asks for camera permission.

## Po polsku

**Matrix Rain** to wygaszacz ekranu macOS i osobna aplikacja **Matrix Rain Cam** (obraz z kamery złożony z kodu).
Budowanie: `./build.sh install` (wygaszacz) i `./build_cam.sh` (aplikacja). Czcionki *Matrix Code* nie ma w repozytorium —
wstaw własną kopię do `Resources/Matrix-Code.ttf` przed budową. Opcje (zakładki Wygląd, Ruch, Ekran CRT, Obraz, Info)
są dostępne po polsku i angielsku (lista „Język” w prawym górnym rogu okna opcji).

## License / Licencja

MIT © 2026 Tomasz Marchewka — see [LICENSE](LICENSE).

Unofficial fan project, not affiliated with or endorsed by the makers or owners of the film "The Matrix".
Nieoficjalny projekt fanowski, niezwiązany z filmem „Matrix” ani jego właścicielami.
