<#
    .SYNOSIS
        Setup.ps1 - configure windows shell profile

    .NOTES
        Author: Will Rowe
#>
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
[CmdletBinding()]
param()
#Requires -Version 7.0
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    #Start-Process $PSexe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Start-Process $PSexe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return
}
# link configurations ( repo Source => local Destination )
$symlinks = @{
    "profile.ps1"                     = $PROFILE.CurrentUserAllHosts
    ".config\vscode\settings.json"    = "$env:APPDATA\code\user\settings.json"
    ".config\vscode\keybindings.json" = "$env:APPDATA\code\user\keybindings.json"
    ".config\terminal\settings.json"  = "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    ".config\git\.gitconfig"          = "$HOME\.gitconfig"
}

# Chocolatey Packages 
$chocoDep = @(
    'git'
    'PowerShell.Core'
    'VSCode'
)

# PS Modules to install
$psModules = @(
    'ThreadJob'
    'PSScriptAnalyzer'
    'InvokeBuild'
    'Pester'
)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
Push-Location $PSScriptRoot

Function Get-UserResponse {
    param ($Msg = "Do you want to continue? (Y/N)")
    do {# Simple Yes/No validation loop in PowerShell
        $response = Read-Host $Msg
        $response = $response.Trim().ToUpper()
        switch ($response) {
            'Y' { $valid = $true; $return = $true; break }
            'N' { $valid = $true; $return = $false; break }
            default { Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red; $valid = $false; break }
        }
    } until ($valid)
    return $return
}
if ($PROFILE.CurrentUserAllHosts -match [regex]::Escape($env:OneDrive)) {
    Write-Warning "PS Profile is located on OneDrive filesystem! [$($PROFILE.CurrentUserAllHosts)]
    It is recommended to move the Powershell profile off of OneDrive,
    and move it back onto to local filesystem for performance and stability."
    $response = Get-UserResponse "Relocate PowerShell Profile to local filesystem? (Y/N)"
    if ($response) {
        Write-Host "Attempting to move PowerShell profile off of OneDrive to local FileSystem..."
        . $env:Scripts\Move-ProfileLocal.ps1 
    }
}

Write-Verbose "install PS modules"
foreach ($psModule in $psModules) {
    if (!(Get-Module -ListAvailable -Name $psModule)) {
        Install-Module -Name $psModule -Force -AcceptLicense -Scope CurrentUser
    }
}

Write-Verbose "capture current git user"
$currentGitEmail = (git config --global user.email)
$currentGitName = (git config --global user.name)

# Create Symbolic Links
foreach ($symlink in $symlinks.GetEnumerator()) {
    $source = $symlink.key; $destination = $symlink.value
    if (-not(Test-Path $source)) { continue } # skip linking if we don't have a source file.
    Write-Host "Linking File: $source to local path: $destination" -ForegroundColor Cyan
    Get-Item -Path $destination -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $destination -Target (Resolve-Path $source) -Force | Out-Null
}

Write-Verbose "refresh git config user"
git config --global --unset user.email | Out-Null
git config --global --unset user.name | Out-Null
git config --global user.email $currentGitEmail | Out-Null
git config --global user.name $currentGitName | Out-Null

Pop-Location
$parent = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId).Name
if ($parent -in @('explorer', 'powershell', 'pwsh')) { exit } # close process, if opened in new window
