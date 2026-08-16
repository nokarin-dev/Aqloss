# Windows installer

Flutter app that installs Aqloss for the current user (`%LOCALAPPDATA%\Aqloss`, no admin). The shipped file is a 7-Zip SFX: `Aqloss-windows-installer.exe`.

It reads the existing uninstall entry in HKCU to pick **Install**, **Repair** (same version), or **Update**. Uninstall is `uninstall.ps1`, or the GUI with `--uninstall`.

From the repo root, after `flutter build windows --release`:

```powershell
.\.github\scripts\package-windows.ps1 -Version 1.0.0
```

That syncs the icon, zips the Release build into `installer/assets/aqloss_bundle.zip`, builds this app, then concatenates SFX stub + config + payload. Patch icon/version on the stub **before** that concat — `rcedit` on the final exe strips the 7z payload.

To iterate on the installer UI itself:

```powershell
cd installer
flutter pub get
flutter run -d windows
```
