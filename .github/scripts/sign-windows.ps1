param(
  [Parameter(Mandatory = $true)][string[]]$Files
)

$ErrorActionPreference = "Stop"

$pfxB64 = $env:WINDOWS_CODESIGN_PFX_BASE64
$pass = $env:WINDOWS_CODESIGN_PASSWORD

if (-not $pfxB64 -or -not $pass) {
  Write-Host "Skipping code signing (WINDOWS_CODESIGN_PFX_BASE64 / WINDOWS_CODESIGN_PASSWORD not set)."
  return
}

$signtool = Get-Command signtool.exe -ErrorAction SilentlyContinue
if (-not $signtool) {
  $sdkBin = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
  if (Test-Path $sdkBin) {
    $signtool = Get-ChildItem -Path $sdkBin -Filter signtool.exe -Recurse |
      Where-Object { $_.FullName -match '\\x64\\' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
  }
}
if (-not $signtool) {
  throw "signtool.exe not found. Install Windows SDK or run on a Windows build agent."
}
$signtoolPath = if ($signtool -is [System.IO.FileInfo]) { $signtool.FullName } else { $signtool.Source }

$pfxPath = Join-Path $env:TEMP "aqloss-codesign.pfx"
[System.IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($pfxB64))

try {
  foreach ($file in $Files) {
    if (-not (Test-Path $file)) {
      throw "File to sign not found: $file"
    }
    Write-Host "Signing $file"
    & $signtoolPath `
      sign /fd SHA256 /tr "http://timestamp.digicert.com" /td SHA256 `
      /f $pfxPath /p $pass `
      $file
    if ($LASTEXITCODE -ne 0) {
      throw "signtool failed for $file (exit $LASTEXITCODE)"
    }
  }
} finally {
  Remove-Item $pfxPath -Force -ErrorAction SilentlyContinue
}
