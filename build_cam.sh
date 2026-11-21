#!/bin/bash
# Buduje "Matrix Rain Cam.app" i instaluje do ~/Applications
set -e
cd "$(dirname "$0")"
OUT="${TMPDIR:-/tmp}/matrixrain-build/Matrix Rain Cam.app"
rm -rf "$OUT" && mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
if [ -f Resources/Matrix-Code.ttf ]; then cp Resources/Matrix-Code.ttf "$OUT/Contents/Resources/"; else echo "Uwaga/Note: brak/missing Resources/Matrix-Code.ttf - uzyto czcionki zastepczej / fallback font used"; fi
cat > "$OUT/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>MatrixRainCam</string>
<key>CFBundleIdentifier</key><string>com.bluerootstudio.MatrixRainCam</string>
<key>CFBundleName</key><string>Matrix Rain Cam</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSCameraUsageDescription</key><string>Matrix Rain Cam wyświetla obraz z kamery jako kod Matrixa.</string>
</dict></plist>
EOF
MD="${TMPDIR:-/tmp}/matrixrain-build/camsrc"; mkdir -p "$MD"; cp cam_main.swift "$MD/main.swift"
swiftc -O -module-name MatrixRainCam "$MD/main.swift" MatrixRainView.swift \
  -framework ScreenSaver -framework Metal -framework QuartzCore -framework AppKit \
  -framework CoreText -framework AVFoundation -framework CoreMedia -framework CoreVideo \
  -o "$OUT/Contents/MacOS/MatrixRainCam"
xattr -cr "$OUT"; codesign --force --sign - "$OUT"
echo "OK: $OUT"
mkdir -p ~/Applications
rm -rf ~/Applications/"Matrix Rain Cam.app"
cp -R "$OUT" ~/Applications/
echo "Zainstalowano w ~/Applications"
