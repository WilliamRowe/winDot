<#
.SYNOPSIS
    Adjust user interface/experience configurations
#>
[CmdletBinding()]
param (
    [string]$DesktopImagePath,

    [string]$LockScreenImagePath,

    [ValidateScript({ if ($_ -notmatch '^[0-9A-Fa-f]{6}$') { throw "Invalid HexColor entered. Expecting format: '009AFF'" } else { $true } })]
    [string]$AccentColor,

    [ValidateScript({ if ($_ -notmatch '^[0-9A-Fa-f]{6}$') { throw "Invalid HexColor entered. Expecting format: '009AFF'" } else { $true } })]
    [string]$SecondaryColor,

    [ValidateSet('Left', 'Center')]
    [string]$TaskBarPosition = 'Left',

    [ValidateSet('Dark', 'Light')]
    [string]$Theme = 'Dark',

    [switch]$DevMode
)
if (-not (Test-Path $DesktopImagePath)) { throw "Desktop image file not found: $DesktopImagePath" }
if (-not (Test-Path $LockScreenImagePath)) { throw "Lock screen image file not found: $LockScreenImagePath" }

if ($devMode) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Write-Host 'Restarting script as Administrator...' -ForegroundColor Yellow
        $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
        Start-Process $PSexe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        return
    }
    reg add 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' /t REG_DWORD /f /v 'AllowDevelopmentWithoutDevLicense' /d '1'
    sudo config --enable normal
}

if ($LockScreenImagePath) {
    Write-Verbose 'processing local machine settings:'
    $localMachineSettings = @(
        @{ 
            Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Personalization'
            Name  = 'LockScreenImagePath'
            Value = $LockScreenImagePath
        },
        @{ 
            Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Personalization'
            Name  = 'LockScreenImageUrl'
            Value = $LockScreenImagePath
        },
        @{ 
            Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Personalization'
            Name  = 'LockScreenImageStatus'
            Value = 1
        }
    )
    foreach ($setting in $localMachineSettings) {
        if (-not (Test-Path $Setting.Path)) { New-Item -Path $Setting.Path -Force | Out-Null }
        if ((Get-ItemProperty -Path $Setting.Path -Name $Setting.Name -ErrorAction SilentlyContinue).$Name -eq $Settings.Value) { Write-Verbose "Key: $($Setting.Name) value $($Settings.value) already applied"; continue }
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
            Write-Host 'Restarting script as Administrator...' -ForegroundColor Yellow
            $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
            Start-Process $PSexe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            return
        }
        Write-Verbose "Key: $($setting.Name) Value: $($setting.Value) Path: $($setting.Path)"
        Set-ItemProperty @setting -Force
    }
}
Write-Verbose 'processing current user settings'
function ConvertFrom-HexColor ($HexColor) {
    $r = [Convert]::ToInt32($HexColor.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($HexColor.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($HexColor.Substring(4, 2), 16)
    return (($b -shl 16) -bor ($g -shl 8) -bor $r)
}
$currentUserSettings = @(
    # Disable web search
    @{
        Path  = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
        Name  = 'DisableSearchBoxSuggestions`'
        Value = 1
        Type  = 'Dword'
    },
    # Show file extensions
    @{ 
        Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Name  = 'HideFileExt'
        Value = 0
        Type  = 'Dword'
    }
)

if ($accentColor) {
    # Configure Accent Colors
    @(
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'AccentColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'StartColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'ColorizationColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'AccentColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'StartColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'ColorizationColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'AccentColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'StartColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'ColorizationColor'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        # Start Color menu
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'StartColorMenu'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'StartColorMenu'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'StartColorMenu'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        # Taskbar Color menu
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'TaskbarColorOverride'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'TaskbarColorOverride'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'TaskbarColorOverride'
            Value = (ConvertFrom-HexColor $AccentColor)
            Type  = 'Dword'
        },
        # Show accent color on Start and Taskbar
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'ColorPrevalence'
            Value = 1
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'ColorPrevalence'
            Value = 1
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'ColorPrevalence'
            Value = 1
            Type  = 'Dword'
        },
        # Show accent color on title bars and windows borders
        @{
            Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
            Name  = 'EnableWindowColorization'
            Value = 1
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
            Name  = 'EnableWindowColorization'
            Value = 1
            Type  = 'Dword'
        },
        @{ 
            Path  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'EnableWindowColorization'
            Value = 1
            Type  = 'Dword'
        }
    ) | ForEach-Object { $currentUserSettings += $_ }
}

if ($SecondaryColor) {
    $currentUserSettings += @{ 
        Path  = 'HKCU:\Software\Microsoft\Windows\DWM'
        Name  = 'AccentColorInactive'
        Value = (ConvertFrom-HexColor $SecondaryColor)
        Type  = 'Dword'
    }
}

if ($DesktopImagePath) {
    # Set Background image
    $currentUserSettings += @{
        Path  = 'HKCU:\Control Panel\Desktop'
        Name  = 'wallpaper'
        Value = $DesktopImagePath
    }
}

switch ($TaskBarPosition) {
    'Left' { 
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'TaskbarAl'
            Value = 0
            Type  = 'Dword'
        }
    }
    'Center' { 
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name  = 'TaskbarAl'
            Value = 1
            Type  = 'Dword'
        }
    }
}

switch ($Theme) {
    'Dark' {
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Name  = 'SystemUsesLightTheme'
            Value = 0
            Type  = 'Dword'
        }
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Name  = 'AppsUseLightTheme'
            Value = 0
            Type  = 'Dword'
        }
    }
    'Light' {
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Name  = 'SystemUsesLightTheme'
            Value = 1
            Type  = 'Dword'
        }
        $currentUserSettings += @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Name  = 'AppsUseLightTheme'
            Value = 1
            Type  = 'Dword'
        }
    }
}

# apply settings
foreach ($setting in $currentUserSettings) {
    Write-Verbose "Key: $($setting.Name) Value: $($setting.Value) Path: $($setting.Path)"
    Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Force
}

return
