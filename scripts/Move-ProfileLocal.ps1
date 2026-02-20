[CmdletBinding()]
param(
    [string]$localProfilePath = "$home\Documents\PowerShell",
    [string]$OneDriveProfilePath = "$env:OneDrive\Documents\PowerShell",
    [bool]$RemoveOneDriveProfile = $false
)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..."
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    Start-Process $PSexe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return
}

# Create the local path directory, if it does not exist.
if (-not (Test-Path $localProfilePath)) {
    try { New-Item -ItemType Directory -Path $localProfilePath -ErrorAction Stop } catch { throw $_ }
}

# update current sessions profile and module variables path
try {
    $OneDriveRegexPath = [Regex]::Escape($OneDriveProfilePath)
} catch {
    Write-Error "Failed to escape path: $_"
}
if ($PROFILE.CurrentUserAllHosts -match $OneDriveRegexPath) {
    $PROFILE.CurrentUserAllHosts = $PROFILE.CurrentUserAllHosts -replace $OneDriveRegexPath, $localProfilePath
}
if ($PROFILE.CurrentUserCurrentHost -match $OneDriveRegexPath) {
    $PROFILE.CurrentUserCurrentHost = $PROFILE.CurrentUserCurrentHost -replace $OneDriveRegexPath, $localProfilePath
}
if ($env:PSModulePath  -match $OneDriveRegexPath) {
    $env:PSModulePath  = $env:PSModulePath  -replace $OneDriveRegexPath, $localProfilePath
}

# update registry for persistence
$psUserPath = @{
    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    Name = "Personal"
}
if ((Get-ItemProperty @psUserPath).Personal -ne (Split-Path $localProfilePath -Parent)) {
    try {
        Set-ItemProperty @psUserPath -Value (Split-Path $localProfilePath -Parent)
        Write-Host "Updated Registry PS Default user profile path: $(Split-Path $localProfilePath -Parent)"
    } catch {
        Write-Warning "Failed to update Registry PS Default user profile path!"
        throw $_
    }
}

if (-not (Test-Path $OneDriveProfilePath)) { 
    Write-Host "Nothing to do...OneDrive Path not found: $OneDriveProfilePath"
    return
}

Copy-Item "$OneDriveProfilePath\*profile.ps1"  $localProfilePath
if ($RemoveOneDriveProfile) {
    try {
        Remove-Item $OneDriveProfilePath -Recurse -Force -ErrorAction Stop
        Write-Host "Removed OneDrive PS Profile directory: $OneDriveProfilePath"
    } catch {
        Write-Warning "Failed to remove OneDrive PS Profile directory: $OneDriveProfilePath"
    }
}

Write-Warning "Restart required to apply changes!"
# Prompt the user to reboot the system
try {
    $choice = Read-Host "Do you want to reboot now? (Y/N)"
    switch -Regex ($choice.Trim()) {
        '^(Y|y)$' {
            Write-Host "Rebooting the system..." -ForegroundColor Yellow
            Restart-Computer -Force
        }
        '^(N|n)$' {
            Write-Host "Reboot canceled by user." -ForegroundColor Green
        }
        default {
            Write-Host "Invalid choice. Please run the script again and enter Y or N." -ForegroundColor Red
        }
    }
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
