<#
    .SYNOPSIS
        Setup.ps1 - configure windows shell profile

    .NOTES
        Author: Will Rowe
#>
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Alias('CurrentUserSettings')]
    [Switch]$UI = [Switch]::Present,

    [Alias('PSModuleName')]
    [string[]]$PSModules = @(
        #'SecretManagement.KeePass'
        'Microsoft.PowerShell.SecretStore'
        'Microsoft.PowerShell.SecretManagement'
        'ThreadJob'
        'PSScriptAnalyzer'
        'InvokeBuild'
        'Pester'
        'PoShKeePass'
        'PsPAS'
        'Terminal-Icons'
    ),

    [Parameter(Mandatory = $false, ParameterSetName = 'Admin')]
    [string[]]$Choco = @(
        'Git'
        'PowerShell.Core'
        'VSCode'
        'PowerToys'
    ),

    $symlinks = [Ordered]@{
        'profile.ps1'                     = $PROFILE.CurrentUserAllHosts
        '.config\vscode\settings.json'    = "$env:APPDATA\code\user\settings.json"
        '.config\vscode\keybindings.json' = "$env:APPDATA\code\user\keybindings.json"
        '.config\vscode\extensions.json'  = "$env:APPDATA\code\user\extensions.json"
        '.config\terminal\settings.json'  = "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        '.config\git\.gitconfig'          = "$HOME\.gitconfig"
        '.config\fonts'                   = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    },

    [Switch]$VScode = (if (Get-Command code.cmd -ErrorAction SilentlyContinue) { [Switch]::Present }),

    [Parameter(Mandatory = $false, ParameterSetName = 'Admin')]
    [Switch]$LockScreen,

    [Parameter(Mandatory = $false, ParameterSetName = 'Admin')]
    [Switch]$PowerConfig,

    [Switch]$Force
)
#Requires -Version 7.0
# load-in current profile, first time to populate initial environment variables, functions, etc.
if ($Force -or ($null -eq $env:SETUP_INSTALL_STATE)) {
    . .\profile.ps1
    $env:SETUP_INSTALL_STATE = 'partial'
}

# move PS profile off of OneDrive, if discovered
if ($PROFILE.CurrentUserAllHosts -match [regex]::Escape($env:OneDrive)) {
    Write-Warning "PS Profile is located on OneDrive filesystem! [$($PROFILE.CurrentUserAllHosts)]
      It is recommended to move the Powershell profile off of OneDrive,
        and move it back onto to local filesystem for performance and stability."
    if ($force -or $(Get-UserResponse 'Relocate PowerShell Profile to local filesystem? (Y/N)')) {
        Write-Host 'Attempting to move PowerShell profile off of OneDrive to local FileSystem...'
        . "$Env:Scripts\Move-ProfileLocal.ps1" @PSBoundParameters
    }
}

if ($PSModule -or $Force) { Update-PSModules $psModules } 
 
if ($UI -or $Force) { 
    Write-Verbose 'applying UI configurations...'
    & "$Env:Scripts\Set-UI.ps1" @PSBoundParameters -DesktopImagePath $Env:WallPaper -AccentColor $Env:AccentColor -SecondaryColor $Env:SecondaryColor
}

if ($LockScreen -or $Force) {
    Write-Verbose 'applying lock screen configurations...'
    & "$Env:Scripts\Set-UI.ps1" -LockScreenImagePath $Env:LockScreen 
}

if ($PowerConfig -or $Force) { 
    Write-Verbose 'applying power configurations...'
    & "$Env:Scripts\Set-PowerConfig.ps1" @PSBoundParameters
}

if ($VScode -or $Force) {
    . "$Env:Scripts\Install-VSCodeExtension.ps1" @PSBoundParameters -Extensions (Get-Content (Join-Path $env:Configs 'vscode\extensions.json') -Raw | ConvertFrom-Json).recommendations
}
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
Write-Verbose 'capture current git user'
$currentGitEmail = (git config --global user.email)
$currentGitName = (git config --global user.name)

Write-Verbose 'Create Symbolic Links'
foreach ($symlink in $symlinks.GetEnumerator()) {
    $source = $symlink.key; $destination = $symlink.value
    if (-not(Test-Path $source)) { continue } # skip linking if we don't have a source file at the moment.
    try {
        Write-Host "Attempting SymLink on File: $source to local path: $destination" -ForegroundColor Cyan
        Get-Item -Path $destination -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        New-Item -ItemType SymbolicLink -Path $destination -Target (Resolve-Path $source) -Force | Out-Null
    } catch {
        $response = Get-UserResponse 'Relocate PowerShell Profile to local filesystem? (Y/N)'
        if ($response) {
            $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
            Start-Process $PSexe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
                Write-Host 'Restarting script as Administrator...' -ForegroundColor Yellow
                $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
                Start-Process $PSexe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
                return
            }
            Write-Host "Linking File: $source to local path: $destination" -ForegroundColor Cyan
            Get-Item -Path $destination -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            New-Item -ItemType SymbolicLink -Path $destination -Target (Resolve-Path $source) -Force | Out-Null
        }
    }
}

Write-Verbose 'refresh git config user'
git config --global --unset user.email | Out-Null
git config --global --unset user.name | Out-Null
git config --global user.email $currentGitEmail | Out-Null
git config --global user.name $currentGitName | Out-Null

Write-Verbose 'refresh font cache'
Get-Service FontCache | Restart-Service -Force

Write-Verbose 'refresh user space'
RUNDLL32.EXE user32.dll, UpdatePerUserSystemParameters
Stop-Process -Name Explorer -Force

return
