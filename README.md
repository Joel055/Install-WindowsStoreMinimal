# Install-WindowsStoreMinimal

Installs the minimal Microsoft Store dependency set required for Microsoft Store and winget functionality, without installing the full Store app suite by
resolving official Microsoft Store package download links via the rg-adguard.net API and then downloading/installing these.

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
For full details, run:
```powershell
Install-Get-Help Install-WindowsStoreMinimal -Full
```

## Licensing
This project is released under the [MIT License](LICENSE).