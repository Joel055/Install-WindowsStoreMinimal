# Install-WindowsStoreMinimal

Installs the minimal Microsoft Store dependency set required for Microsoft Store and winget functionality, without installing the full Store app suite. by

Optionally includes WinGet/App Installer support via ```-IncludeWinget.```

The script resolves official Microsoft Store package download links via the rg-adguard.net API and then downloads and inställs these AppX/MSIC packages offline using ```Add-AppxPackage```

Designed for LTSC, stripped, or otherwise modified Windows installations where the Microsoft Store dependency stack might be missing or broken.

## Install

**From PowerShell Gallery:**
```powershell
Install-Script -Name Install-WindowsStoreMinimal
```
Or download and run the script-file directly.

## Usage
```powershell
Install-WindowsStoreMinimal
```
Include WinGet/App Installer support aswell:
```powershell
Install-WindowsStoreMinimal -IncludeWinget
```
For full details, run:
```powershell
Get-Help Install-WindowsStoreMinimal -Full
```

## Notes
- Requires administrative privileges.
- For x64 Windows installations only.
- May set the Microsoft Account Sign-in Assistant (wlidsvc) service to Manual if disabled.
- rg-adguard.net is not affiliated with Microsoft.

## Licensing
This project is released under the [MIT License](LICENSE).
