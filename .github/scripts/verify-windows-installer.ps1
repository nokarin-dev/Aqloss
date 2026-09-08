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

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $InstallerPath))
$utf16 = [System.Text.Encoding]::Unicode.GetString($bytes)
$utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
if ($utf16 -notmatch 'asInvoker' -and $utf8 -notmatch 'asInvoker') {
  throw "Installer is missing asInvoker in its manifest. Windows will treat it as a setup that needs admin."
}

Write-Host "Windows installer size and asInvoker check passed."
