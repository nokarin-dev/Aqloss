#include "file_assoc.h"

#include <windows.h>
#include <shlobj.h>
#include <string>

static void WriteReg(const wchar_t *subkey, const wchar_t *name,
                     const wchar_t *value)
{
    HKEY hKey;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, subkey, 0, nullptr, 0,
                        KEY_WRITE, nullptr, &hKey, nullptr) == ERROR_SUCCESS)
    {
        RegSetValueExW(hKey, name, 0, REG_SZ,
                       reinterpret_cast<const BYTE *>(value),
                       static_cast<DWORD>((wcslen(value) + 1) * sizeof(wchar_t)));
        RegCloseKey(hKey);
    }
}

void RegisterFileAssociations()
{
    wchar_t exe[MAX_PATH];
    GetModuleFileNameW(nullptr, exe, MAX_PATH);
    std::wstring exePath(exe);
    std::wstring openCmd = L"\"" + exePath + L"\" \"%1\"";

    // .aqp
    WriteReg(L"Software\\Classes\\.aqp", nullptr, L"AqlossPlaylist");
    WriteReg(L"Software\\Classes\\AqlossPlaylist", nullptr, L"Aqloss Playlist");
    WriteReg(L"Software\\Classes\\AqlossPlaylist\\DefaultIcon", nullptr, (exePath + L",0").c_str());
    WriteReg(L"Software\\Classes\\AqlossPlaylist\\shell\\open\\command", nullptr, openCmd.c_str());

    // .aqx
    WriteReg(L"Software\\Classes\\.aqx", nullptr, L"AqlossPlugin");
    WriteReg(L"Software\\Classes\\AqlossPlugin", nullptr, L"Aqloss Plugin");
    WriteReg(L"Software\\Classes\\AqlossPlugin\\DefaultIcon", nullptr, (exePath + L",1").c_str());
    WriteReg(L"Software\\Classes\\AqlossPlugin\\shell\\open\\command", nullptr, openCmd.c_str());

    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}