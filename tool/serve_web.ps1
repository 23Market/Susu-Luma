# Serves the compiled Susu Luma Flutter web app over HTTP.
# Run from any directory: powershell -ExecutionPolicy Bypass -File .\tool\serve_web.ps1
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot "build\web"
$indexPath = Join-Path $buildDir "index.html"

Push-Location $projectRoot
try {
  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutter) {
    Write-Host "Flutter found. Building the release web app..."
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web --release failed with exit code $LASTEXITCODE" }
  } elseif (-not (Test-Path $indexPath)) {
    Write-Host ""
    Write-Host "Flutter is not installed or is not on PATH, and build\web\index.html is missing." -ForegroundColor Yellow
    Write-Host "Option A: install Flutter and add its bin folder to PATH: https://docs.flutter.dev/install"
    Write-Host "Option B: download the 'susu-luma-web-release' artifact from the latest successful GitHub Actions run,"
    Write-Host "         extract its contents into '$buildDir', then run this script again."
    Write-Host "GitHub Actions: https://github.com/23Market/Susu-Luma/actions"
    exit 1
  } else {
    Write-Host "Flutter is not on PATH; serving the existing build\web files without rebuilding."
  }

  foreach ($required in @("index.html", "flutter_bootstrap.js", "main.dart.js")) {
    if (-not (Test-Path (Join-Path $buildDir $required))) {
      throw "Web build is incomplete: missing build\web\$required"
    }
  }

  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) {
    Write-Host "Serving Susu Luma at http://localhost:8000 (Ctrl+C to stop)"
    python -m http.server 8000 --directory $buildDir
    exit $LASTEXITCODE
  }
  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) {
    Write-Host "Serving Susu Luma at http://localhost:8000 (Ctrl+C to stop)"
    py -3 -m http.server 8000 --directory $buildDir
    exit $LASTEXITCODE
  }
  throw "Python was not found. Install Python 3, then rerun this script."
}
finally {
  Pop-Location
}
