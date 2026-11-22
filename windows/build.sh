#!/bin/bash
# Cross-build z macOS/Linux (wymaga .NET 8+ SDK). / Cross-build from macOS/Linux (needs .NET 8+ SDK).
set -e
cd "$(dirname "$0")"
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o out
cp out/MatrixRain.exe out/MatrixRain.scr
echo "OK: $(pwd)/out/MatrixRain.scr"
