#!/bin/bash
# Buduje "Matrix Rain.saver" i (z argumentem install) instaluje do ~/Library/Screen Savers
set -e
cd "$(dirname "$0")"
OUT="${TMPDIR:-/tmp}/matrixrain-build/Matrix Rain.saver"
rm -rf build "$OUT" && mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
if [ -f Resources/Matrix-Code.ttf ]; then cp Resources/Matrix-Code.ttf "$OUT/Contents/Resources/"; else echo "Uwaga/Note: brak/missing Resources/Matrix-Code.ttf - uzyto czcionki zastepczej / fallback font used"; fi
cat > "$OUT/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>MatrixRain</string>
<key>CFBundleIdentifier</key><string>com.bluerootstudio.MatrixRain</string>
<key>CFBundleName</key><string>Matrix Rain</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSPrincipalClass</key><string>MatrixRainView</string>
</dict></plist>
EOF
swiftc -O -module-name MatrixRain -emit-library -Xlinker -bundle \
  -framework ScreenSaver -framework Metal -framework QuartzCore -framework AppKit -framework CoreText \
  MatrixRainView.swift -o "$OUT/Contents/MacOS/MatrixRain"
xattr -cr "$OUT"; codesign --force --sign - "$OUT"
echo "OK: $OUT"
if [ "$1" = "install" ]; then
  mkdir -p ~/Library/Screen\ Savers
  rm -rf ~/Library/Screen\ Savers/"Matrix Rain.saver"
  cp -R "$OUT" ~/Library/Screen\ Savers/
  echo "Zainstalowano w ~/Library/Screen Savers"
fi
