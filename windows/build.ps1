# Buduje MatrixRain.scr (Windows 11 x64). Wymaga .NET 8 SDK. / Builds MatrixRain.scr (needs .NET 8 SDK).
Set-Location $PSScriptRoot
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o out
Copy-Item out\MatrixRain.exe out\MatrixRain.scr -Force
Write-Host "OK: $PSScriptRoot\out\MatrixRain.scr"
