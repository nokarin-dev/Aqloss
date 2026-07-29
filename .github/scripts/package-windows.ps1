param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$InstallerOutput = "Aqloss-windows-installer.exe",
  [string]$PortableOutput = "Aqloss-windows-portable.zip",
  [switch]$InstallerOnly,
  [switch]$PortableOnly
)

$ErrorActionPreference = "Stop"

function New-InnoScript {
  param([string]$AppVersion)
  @"
[Setup]
AppName=Aqloss
AppVersion=$AppVersion
AppPublisher=nokarin
AppPublisherURL=https://github.com/nokarin-dev/aqloss
AppSupportURL=https://github.com/nokarin-dev/aqloss/issues
DefaultDirName={localappdata}\Aqloss
DefaultGroupName=Aqloss
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=Aqloss-windows-installer
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\aqloss.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{userprograms}\Aqloss"; Filename: "{app}\aqloss.exe"
Name: "{userprograms}\Uninstall Aqloss"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Aqloss"; Filename: "{app}\aqloss.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\aqloss.exe"; Description: "{cm:LaunchProgram,Aqloss}"; Flags: nowait postinstall skipifsilent
"@ | Out-File -FilePath "installer.iss" -Encoding UTF8
}

if (-not $PortableOnly) {
  New-InnoScript -AppVersion $Version
  & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "installer.iss"
  if (-not (Test-Path $InstallerOutput)) {
    throw "Installer not produced: $InstallerOutput"
  }
  Write-Host "Built $InstallerOutput"
}

if (-not $InstallerOnly) {
  if (Test-Path $PortableOutput) { Remove-Item $PortableOutput -Force }
  Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath $PortableOutput
  Write-Host "Built $PortableOutput"
}
