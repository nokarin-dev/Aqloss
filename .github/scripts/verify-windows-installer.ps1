param(
  [string]$InstallerPath = "Aqloss-windows-installer.exe",
  [string]$PortablePath = "Aqloss-windows-portable.zip",
  [long]$MinInstallerBytes = 1048576
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InstallerPath)) {
  throw "Installer not found: $InstallerPath"
}
if (-not (Test-Path $PortablePath)) {
  throw "Portable zip not found: $PortablePath"
}

$installerSize = (Get-Item $InstallerPath).Length
$portableSize = (Get-Item $PortablePath).Length

Write-Host "Installer size: $installerSize bytes"
Write-Host "Portable size:  $portableSize bytes"

if ($installerSize -lt $MinInstallerBytes) {
  throw "Installer is suspiciously small ($installerSize bytes). Expected at least $MinInstallerBytes."
}

if ($installerSize -lt ($portableSize / 4)) {
  throw "Installer ($installerSize bytes) is much smaller than portable ($portableSize bytes)."
}

Write-Host "Windows installer size check passed."
