# Buduje MatrixRain.scr (Windows 11 x64). Wymaga .NET 8 SDK. / Builds MatrixRain.scr (needs .NET 8 SDK).
Set-Location $PSScriptRoot
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "Brak .NET SDK. Zainstaluj: winget install Microsoft.DotNet.SDK.8 (potem nowe okno PowerShell)" -ForegroundColor Red
    Write-Host "No .NET SDK found. Install: winget install Microsoft.DotNet.SDK.8 (then open a new PowerShell window)" -ForegroundColor Red
    exit 1
}
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o out
if ($LASTEXITCODE -ne 0 -or -not (Test-Path out\MatrixRain.exe)) { Write-Host "Budowanie nie powiodlo sie / Build failed" -ForegroundColor Red; exit 1 }
Copy-Item out\MatrixRain.exe out\MatrixRain.scr -Force
Write-Host "OK: $PSScriptRoot\out\MatrixRain.scr"
