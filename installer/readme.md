# Aqloss Installer

Custom Flutter Windows installer for [Aqloss](https://github.com/nokarin-dev/aqloss).

## Features

- Custom dark UI (welcome → folder → progress → done)
- **Install / Update / Repair** from HKCU uninstall version
- Default path: `%LOCALAPPDATA%\Aqloss` (no admin)
- Desktop / Start Menu shortcuts
- Add/Remove Programs (`HKCU`)
- Quiet uninstall: `uninstall.ps1`
- GUI uninstall: `--uninstall`
- Single file: `Aqloss-windows-installer.exe` (7-Zip SFX)

## Mode detection

| Existing install | UI |
| --- | --- |
| Not installed | **Install** |
| Same version | **Repair** |
| Older version (e.g. 0.3.4 → 1.0.0) | **Update** |

## Build (Windows packaging)

After `flutter build windows --release` at repo root:

```powershell
.\.github\scripts\package-windows.ps1 -Version 1.0.0
```

1. Sync app icon → `installer/windows/runner/resources/app_icon.ico`
2. Zip Release → `installer/assets/aqloss_bundle.zip`
3. Build installer app
4. Wrap runner as SFX → `Aqloss-windows-installer.exe` (icon patched with rcedit)
5. Build `Aqloss-windows-portable.zip`

```bash
cd installer
flutter pub get
flutter run -d linux
```
