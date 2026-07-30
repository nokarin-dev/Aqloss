param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$InstallerOutput = "Aqloss-windows-installer.exe",
  [string]$PortableOutput = "Aqloss-windows-portable.zip",
  [switch]$InstallerOnly,
  [switch]$PortableOnly
)

$ErrorActionPreference = "Stop"

$ReleaseDir = "build\windows\x64\runner\Release"
$InstallerRoot = "installer"
$BundleZip = Join-Path $InstallerRoot "assets\aqloss_bundle.zip"
$InstallerRelease = Join-Path $InstallerRoot "build\windows\x64\runner\Release"
$ToolsDir = Join-Path $env:TEMP "aqloss-7z-tools"

function Assert-ReleaseDir {
  if (-not (Test-Path $ReleaseDir)) {
    throw "Windows release directory not found: $ReleaseDir. Build Aqloss first (flutter build windows --release)."
  }
}

function Ensure-7ZipTools {
  New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
  $sevenZr = Join-Path $ToolsDir "7zr.exe"
  $extraArchive = Join-Path $ToolsDir "7z-extra.7z"
  $extraDir = Join-Path $ToolsDir "extra"

  if (-not (Test-Path $sevenZr)) {
    Write-Host "Downloading 7zr.exe..."
    Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $sevenZr
  }

  $sfx = Get-ChildItem -Path $ToolsDir -Filter "7zSD.sfx" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $sfx) {
    Write-Host "Downloading 7-Zip Extra (SFX module)..."
    $extraUrls = @(
      "https://www.7-zip.org/a/7z2501-extra.7z",
      "https://www.7-zip.org/a/7z2409-extra.7z",
      "https://www.7-zip.org/a/7z2408-extra.7z"
    )
    $downloaded = $false
    foreach ($url in $extraUrls) {
      try {
        Write-Host "Trying $url"
        Invoke-WebRequest -Uri $url -OutFile $extraArchive
        $downloaded = $true
        break
      } catch {
        Write-Host "Failed: $($_.Exception.Message)"
      }
    }
    if (-not $downloaded) {
      throw "Could not download 7-Zip Extra (SFX module)."
    }
    if (Test-Path $extraDir) { Remove-Item $extraDir -Recurse -Force }
    & $sevenZr x $extraArchive "-o$extraDir" -y | Out-Null
    $sfx = Get-ChildItem -Path $extraDir -Filter "7zSD.sfx" -Recurse |
      Select-Object -First 1
  }

  if (-not $sfx) {
    throw "7zSD.sfx not found after downloading 7-Zip Extra."
  }

  return @{
    SevenZr = $sevenZr
    Sfx     = $sfx.FullName
  }
}

function New-BundleZip {
  Assert-ReleaseDir
  $assetsDir = Join-Path $InstallerRoot "assets"
  New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
  if (Test-Path $BundleZip) { Remove-Item $BundleZip -Force }

  Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $BundleZip -CompressionLevel Optimal
  if (-not (Test-Path $BundleZip)) {
    throw "Failed to create bundle zip: $BundleZip"
  }
  Write-Host "Created $BundleZip"
}

function New-SelfExtractingInstaller {
  param(
    [string]$SevenZr,
    [string]$SfxPath,
    [string]$PayloadDir,
    [string]$OutputExe
  )

  $work = Join-Path $env:TEMP "aqloss-sfx-$([guid]::NewGuid().ToString('N').Substring(0,8))"
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  try {
    $payload7z = Join-Path $work "payload.7z"
    $config = Join-Path $work "config.txt"

    Push-Location $PayloadDir
    try {
      & $SevenZr a -t7z -mx=9 $payload7z * | Out-Null
    } finally {
      Pop-Location
    }
    if (-not (Test-Path $payload7z)) {
      throw "Failed to create SFX payload archive."
    }

    @"
;!@Install@!UTF-8!
Title="Aqloss Setup"
BeginPrompt=""
RunProgram="aqloss_installer.exe"
GUIFlags="8+32"
ExtractPathText="Extracting Aqloss installer..."
;!@InstallEnd@!
"@ | Set-Content -Path $config -Encoding Ascii

    if (Test-Path $OutputExe) { Remove-Item $OutputExe -Force }

    $outFull = [System.IO.Path]::GetFullPath($OutputExe)
    cmd.exe /c "copy /b `"$SfxPath`" + `"$config`" + `"$payload7z`" `"$outFull`" >nul"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutputExe)) {
      throw "Failed to assemble self-extracting installer: $OutputExe"
    }

    Write-Host "Built $OutputExe (v$Version)"
  } finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Build-FlutterInstaller {
  param([hashtable]$Tools)

  Push-Location $InstallerRoot
  try {
    flutter pub get
    flutter build windows --release
  } finally {
    Pop-Location
  }

  if (-not (Test-Path $InstallerRelease)) {
    throw "Installer release directory not found: $InstallerRelease"
  }

  $exe = Join-Path $InstallerRelease "aqloss_installer.exe"
  if (-not (Test-Path $exe)) {
    throw "Installer exe not found: $exe"
  }

  New-SelfExtractingInstaller `
    -SevenZr $Tools.SevenZr `
    -SfxPath $Tools.Sfx `
    -PayloadDir $InstallerRelease `
    -OutputExe $InstallerOutput
}

if (-not $PortableOnly) {
  $tools = Ensure-7ZipTools
  New-BundleZip
  Build-FlutterInstaller -Tools $tools
}

if (-not $InstallerOnly) {
  Assert-ReleaseDir
  if (Test-Path $PortableOutput) { Remove-Item $PortableOutput -Force }
  Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $PortableOutput -CompressionLevel Optimal
  if (-not (Test-Path $PortableOutput)) {
    throw "Portable zip not produced: $PortableOutput"
  }
  Write-Host "Built $PortableOutput"
}
