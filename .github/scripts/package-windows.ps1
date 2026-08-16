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
$AppIcon = Join-Path $InstallerRoot "windows\runner\resources\app_icon.ico"
$MainAppIcon = "windows\runner\resources\app_icon.ico"
$Publisher = "nokarin-dev"

function Get-VersionQuad {
  param([string]$RawVersion)
  $parts = $RawVersion.Split('.')
  while ($parts.Count -lt 4) { $parts += '0' }
  return ($parts[0..3] -join '.')
}

function Set-ExeVersionInfo {
  param(
    [string]$ExePath,
    [string]$RawVersion,
    [string]$FileDescription,
    [string]$OriginalFilename,
    [string]$InternalName,
    [string]$ProductName = "Aqloss"
  )
  if (-not (Test-Path $ExePath)) {
    throw "Executable not found: $ExePath"
  }
  $quad = Get-VersionQuad $RawVersion
  $year = (Get-Date).Year
  $rcedit = Ensure-Rcedit
  & $rcedit $ExePath `
    --set-version-string CompanyName $Publisher `
    --set-version-string FileDescription $FileDescription `
    --set-version-string ProductName $ProductName `
    --set-version-string LegalCopyright "Copyright (C) $year $Publisher" `
    --set-version-string OriginalFilename $OriginalFilename `
    --set-version-string InternalName $InternalName `
    --set-file-version $quad `
    --set-product-version $quad
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to set version info on $ExePath"
  }
  Write-Host "Applied version info to $ExePath"
}

function Invoke-OptionalCodeSign {
  param([string[]]$Files)
  $signScript = Join-Path $PSScriptRoot "sign-windows.ps1"
  if (-not (Test-Path $signScript)) { return }
  & $signScript -Files $Files
}

function Sync-InstallerIcon {
  if (-not (Test-Path $MainAppIcon)) {
    throw "App icon not found: $MainAppIcon"
  }
  $iconDir = Split-Path -Parent $AppIcon
  New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
  Copy-Item -Path $MainAppIcon -Destination $AppIcon -Force
  Write-Host "Synced installer icon from $MainAppIcon"
}

function Ensure-Rcedit {
  $rcedit = Join-Path $ToolsDir "rcedit-x64.exe"
  if (-not (Test-Path $rcedit)) {
    Write-Host "Downloading rcedit..."
    Invoke-WebRequest -Uri "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe" -OutFile $rcedit
  }
  return $rcedit
}

function Set-ExeIcon {
  param(
    [string]$ExePath,
    [string]$IconPath
  )
  if (-not (Test-Path $IconPath)) {
    throw "Icon file not found: $IconPath"
  }
  $rcedit = Ensure-Rcedit
  & $rcedit $ExePath --set-icon $IconPath
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to set icon on $ExePath"
  }
  Write-Host "Applied icon to $ExePath"
}

function Assert-ReleaseDir {
  if (-not (Test-Path $ReleaseDir)) {
    throw "Windows release directory not found: $ReleaseDir. Build Aqloss first (flutter build windows --release)."
  }
}

function Find-SfxModule {
  param([string]$Root)
  foreach ($name in @("7zSD.sfx", "7zS.sfx")) {
    $hit = Get-ChildItem -Path $Root -Filter $name -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($hit) { return $hit }
  }
  return $null
}

function Ensure-7ZipTools {
  New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
  $sevenZr = Join-Path $ToolsDir "7zr.exe"
  $sdkDir = Join-Path $ToolsDir "lzma-sdk"

  if (-not (Test-Path $sevenZr)) {
    Write-Host "Downloading 7zr.exe..."
    Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $sevenZr
  }

  $sfx = Find-SfxModule -Root $ToolsDir
  if (-not $sfx) {
    Write-Host "Downloading LZMA SDK (for 7zSD.sfx)..."
    $sdkUrls = @(
      "https://www.7-zip.org/a/lzma2602.7z",
      "https://www.7-zip.org/a/lzma2501.7z",
      "https://www.7-zip.org/a/lzma2409.7z",
      "https://www.7-zip.org/a/7z920_extra.7z"
    )
    $archive = Join-Path $ToolsDir "sfx-source.7z"
    $downloaded = $false
    foreach ($url in $sdkUrls) {
      try {
        Write-Host "Trying $url"
        Invoke-WebRequest -Uri $url -OutFile $archive
        if ((Get-Item $archive).Length -lt 1024) {
          throw "Download too small, likely not an archive."
        }
        $downloaded = $true
        break
      } catch {
        Write-Host "Failed: $($_.Exception.Message)"
      }
    }
    if (-not $downloaded) {
      throw "Could not download LZMA SDK / Extra with 7zSD.sfx."
    }

    if (Test-Path $sdkDir) { Remove-Item $sdkDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $sdkDir | Out-Null
    & $sevenZr x $archive "-o$sdkDir" -y *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to extract SFX source archive (exit $LASTEXITCODE)."
    }

    $sfx = Find-SfxModule -Root $sdkDir
  }

  if (-not $sfx) {
    throw "7zSD.sfx not found after extracting LZMA SDK / Extra."
  }

  Write-Host "Using SFX module: $($sfx.FullName)"
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

function Join-BinaryFiles {
  param(
    [string[]]$InputPaths,
    [string]$OutputPath
  )

  foreach ($path in $InputPaths) {
    if (-not (Test-Path $path)) {
      throw "Cannot assemble installer; missing input: $path"
    }
  }

  if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
  $output = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
  try {
    foreach ($path in $InputPaths) {
      $source = [System.IO.File]::OpenRead($path)
      try {
        $source.CopyTo($output)
      } finally {
        $source.Dispose()
      }
    }
  } finally {
    $output.Dispose()
  }
}

function Prepare-SfxStub {
  param(
    [string]$SfxPath,
    [string]$WorkDir,
    [string]$RawVersion
  )

  $stubExe = Join-Path $WorkDir "sfx_stub.exe"
  Copy-Item -Path $SfxPath -Destination $stubExe -Force

  Set-ExeIcon -ExePath $stubExe -IconPath $AppIcon
  Set-ExeVersionInfo `
    -ExePath $stubExe `
    -RawVersion $RawVersion `
    -FileDescription "Aqloss Installer" `
    -OriginalFilename "Aqloss-windows-installer.exe" `
    -InternalName "AqlossInstaller"

  return $stubExe
}

function Assert-InstallerArtifact {
  param(
    [string]$InstallerPath,
    [long]$PayloadBytes,
    [long]$MinInstallerBytes = 1048576
  )

  if (-not (Test-Path $InstallerPath)) {
    throw "Installer not found: $InstallerPath"
  }

  $installerBytes = (Get-Item $InstallerPath).Length
  Write-Host "Installer size: $installerBytes bytes (payload 7z: $PayloadBytes bytes)"

  if ($PayloadBytes -lt 1024) {
    throw "SFX payload archive is too small ($PayloadBytes bytes)."
  }
  if ($installerBytes -lt $MinInstallerBytes) {
    throw "Installer is suspiciously small ($installerBytes bytes). SFX payload may be missing."
  }
  if ($installerBytes -lt ($PayloadBytes / 2)) {
    throw "Installer ($installerBytes bytes) is much smaller than its 7z payload ($PayloadBytes bytes)."
  }
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
      & $SevenZr a -t7z -mx=9 $payload7z *
      if ($LASTEXITCODE -ne 0) {
        throw "7zr failed to create payload archive (exit $LASTEXITCODE)."
      }
    } finally {
      Pop-Location
    }
    if (-not (Test-Path $payload7z)) {
      throw "Failed to create SFX payload archive."
    }

    $payloadBytes = (Get-Item $payload7z).Length
    if ($payloadBytes -lt 1024) {
      throw "SFX payload archive is too small ($payloadBytes bytes)."
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

    $stubExe = Prepare-SfxStub -SfxPath $SfxPath -WorkDir $work -RawVersion $Version
    $outFull = [System.IO.Path]::GetFullPath($OutputExe)
    Join-BinaryFiles -InputPaths @($stubExe, $config, $payload7z) -OutputPath $outFull

    Assert-InstallerArtifact -InstallerPath $outFull -PayloadBytes $payloadBytes
    Write-Host "Built $OutputExe (v$Version)"
  } finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Build-FlutterInstaller {
  param([hashtable]$Tools)

  Sync-InstallerIcon

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

  Set-ExeVersionInfo `
    -ExePath $exe `
    -RawVersion $Version `
    -FileDescription "Aqloss Setup" `
    -OriginalFilename "aqloss_installer.exe" `
    -InternalName "aqloss_installer"

  Invoke-OptionalCodeSign -Files @($exe)

  $installerOut = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $InstallerOutput))

  New-SelfExtractingInstaller `
    -SevenZr $Tools.SevenZr `
    -SfxPath $Tools.Sfx `
    -PayloadDir $InstallerRelease `
    -OutputExe $installerOut

  Invoke-OptionalCodeSign -Files @($installerOut)
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
