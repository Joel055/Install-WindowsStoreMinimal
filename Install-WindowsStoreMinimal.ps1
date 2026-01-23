<#PSScriptInfo
.VERSION 1.0.0
.GUID 94b0cf8f-12aa-4c53-ac47-ffff60587fe2
.AUTHOR Joel055
.TAGS WindowsStore MicrosoftStore AppX MSIX Restore
.LICENSEURI https://github.com/Joel055/Install-WindowsStoreMinimal/blob/main/LICENSE
.PROJECTURI https://github.com/Joel055/Install-WindowsStoreMinimal
.RELEASENOTES Initial public release.
.DESCRIPTION Installs the minimal latest Microsoft Store dependency set required for Store and winget functionality on Windows, without installing the full Store app suite. Resolves official Store packages via rg-adguard.net.
#>

#Requires -RunAsAdministrator

<#
.SYNOPSIS
Installs the minimal set of Microsoft Store dependencies required for
Microsoft Store and winget functionality, without installing the full
Store app suite.

Resolves official Store packages via rg-adguard.net and installs them
offline using Add-AppxPackage.

.NOTES
Requires administrative privileges.
For x64 installations only.
May set the Microsoft Account Sign-in Assistant (wlidsvc) service to Manual if disabled.
rg-adguard.net is not affiliated with Microsoft and is used at your own risk.

.PARAMETER Force
Forces re-evaluation of Store dependencies even if Microsoft Store is already installed.

.PARAMETER KeepDownloads
Prevents deletion of downloaded package files (subsequent runs will reset the folder).

.EXAMPLE
Install-WindowsStoreMinimal

.EXAMPLE
.\Install-WindowsStoreMinimal.ps1 -Force -KeepDownloads
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$KeepDownloads
)

$bitsSvc      = "BITS"
$msSigninSvc  = "wlidsvc"
$downloadPath = "$env:TEMP\WindowsStoreMinimal"

$packageTable = @(
    [pscustomobject]@{
        FamilyBase = "Microsoft.WindowsStore"
        Publisher  = "8wekyb3d8bbwe"
        IgnoreVer  = $false
        Patterns   = @(
            "Microsoft\.VCLibs\.[^A-Za-z]*x64.*\.appx"
            "Microsoft\.UI\.Xaml\..*x64.*\.appx"
            "Microsoft\.NET\.Native\.Framework\..*x64.*\.appx"
            "Microsoft\.NET\.Native\.Runtime\..*x64.*\.appx"
            "Microsoft\.WindowsStore.*neutral.*\.msixbundle"
        )
    }

    [pscustomobject]@{
        FamilyBase = "Microsoft.DesktopAppInstaller" 
        Publisher  = "8wekyb3d8bbwe"
        IgnoreVer  = $true # DesktopAppInstaller's bundle version always mismatches local install (manifest ver), skip version check
        Patterns   = @("Microsoft\.DesktopAppInstaller.*neutral.*\.msixbundle")
    }

    [pscustomobject]@{
        FamilyBase = "Microsoft.StorePurchaseApp"
        Publisher  = "8wekyb3d8bbwe"
        IgnoreVer  = $false
        Patterns   = @("Microsoft\.StorePurchaseApp.*neutral.*\.appxbundle")
    }
)

function Get-AdguardLinks {
    param($PackageTable)
    
    $packageURLs = @()

    foreach ($pkg in $PackageTable) {
        Write-Host "Checking: $($pkg.FamilyBase)" -ForegroundColor Yellow
        $url  = "https://store.rg-adguard.net/api/GetFiles"
        $body = "type=PackageFamilyName&url=$($pkg.FamilyBase)_$($pkg.Publisher)&ring=Retail&lang=en-US"
        $response = Invoke-WebRequest -Uri $url -Method POST -Body $body -UseBasicParsing -ErrorAction Stop

        foreach ($pattern in $pkg.Patterns) {
            $versions = $response.Links | 
                Where-Object { $_.outerHTML -match $pattern } |
                ForEach-Object {
                   if ($_.outerHTML -match '">(.*?)(?=_(x64|neutral)).*(\.[^.]+)</') {
                        $name = $matches[1]
                        $arch = $matches[2]
                        $ext  = $matches[3]   # .appx / .appxbundle / .msixbundle etc

                        if ($arch -eq 'neutral') { $arch = 'x64' }

                        # Normalize version strings to a numeric value for comparison; Store package versions are inconsistent.
                        [long]$ver = $name -replace "[^0-9]", ""
                        [PSCustomObject]@{
                            Name         = $name
                            Architecture = $arch
                            Extension    = $ext
                            Version      = $ver
                            URL          = $_.href
                        }
                    }
                }

            # Fail fast at first sign of dependency-mismatch, avoids partial installations.
            if (-not $versions) {
                throw "Dependency resolution failed for $($pkg.FamilyBase) (pattern '$pattern'). Store dependency metadata has changed; this script is out of date."
            }

            $maxLen = ($versions.Version | ForEach-Object { $_.ToString().Length } | Measure-Object -Maximum).Maximum

            $latest = $versions | 
                Sort-Object @{Expression={ $_.Version.ToString().PadRight($maxLen,'0') }} -Descending | 
                Select-Object -First 1

            Write-Host " Package : " -NoNewline
            Write-Host "$($latest.Name)" -ForegroundColor Cyan

            if ($pkg.IgnoreVer) {
                $installed = Get-AppxPackage -AllUsers |
                    Where-Object { $_.Name -eq $pkg.FamilyBase -and $_.Architecture -eq $latest.Architecture }
            }
            else {
                $installed = (Get-AppxPackage -AllUsers |
                    Where-Object { $_.PackageFullName -match "$($latest.Name)_(x64|neutral)" })
            }

            if ($installed) {
                Write-host " Already installed, skipping`n" -ForegroundColor DarkGray
                continue
            }
            else {
                Write-Host " Queued for download/install`n" -ForegroundColor Green
            }

            $packageURLs += $latest
        }
    }

    $packageURLs
}

$isInstalled = Get-AppxPackage -AllUsers -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue

if ($isInstalled -and -not $Force) {
    Write-Warning "Microsoft Store is already installed. Use -Force to run anyway."
    return
}

try {
    Invoke-WebRequest -Uri "https://store.rg-adguard.net" -Method Head -TimeoutSec 5 -ErrorAction Stop | Out-Null
}
catch {
    throw "Cannot reach store.rg-adguard.net over HTTPS. Internet access, DNS, proxy, or firewall may be blocking the connection."
}

if ((Get-Service -Name $bitsSvc).StartType -eq "Disabled") {
    throw "BITS service is disabled but required for dependency downloads."
}

# Make sure MS sign-in assistant service is enabled, needed for Store auth
if ((Get-Service -Name $msSigninSvc).StartType -eq "Disabled") {
    Set-Service -Name $msSigninSvc -StartupType Manual | Out-Null
    Write-Warning "Startup-type of service `"$msSigninSvc`" set to Manual, from Disabled`n"
    Start-Service -Name $msSigninSvc -ErrorAction Stop | Out-Null
}

$packages = Get-AdguardLinks -PackageTable $packageTable

if (-not $packages) {
    Write-Host "All dependencies are already up to date." -ForegroundColor Yellow
    return
}

if (-not (Test-Path -Path $downloadPath)) {
    New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null
}
else {
    # Remove old files from previous runs
    Get-ChildItem -Path $downloadPath -Recurse | Remove-Item -Force -Recurse
}

foreach ($pkt in $packages) {
    Write-Host "Processing: $($pkt.Name)" -ForegroundColor Yellow
    $outFile  = Join-Path $downloadPath ($pkt.Name + $pkt.Extension)

    Write-Host " Downloading..." -ForegroundColor Cyan
    Start-BitsTransfer -Source $pkt.URL -Destination $outFile -ErrorAction Stop

    Write-Host " Installing...`n" -ForegroundColor Cyan
    Add-AppxPackage -Path $outFile -ForceApplicationShutdown -ErrorAction Stop 
}

if (-not $KeepDownloads) {
    Remove-Item -Path $downloadPath -Recurse -Force 
}
else {
    Write-Host "Downloaded package-files can be found at: `"$($downloadPath)`"`n"
}

Write-Host "Done!`n" -ForegroundColor Green