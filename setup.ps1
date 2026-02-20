<#
    .SYNOSIS
        Setup.ps1 - configure windows shell profile

    .NOTES
        Author: Will Rowe
#>
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
#Requires -Version 7.0
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..."
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    #Start-Process $PSexe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Start-Process $PSexe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return
}

# Linked Files (Destination => Source)
$symlinks = @{
    $PROFILE.CurrentUserAllHosts                                                                    = ".\Profile.ps1"
    "$env:APPDATA\code\user\settings.json"                                                          = ".\.config\vscode\settings.json"
    "$env:APPDATA\code\user\keybindings.json"                                                       = ".\.config\vscode\keybindings.json"
    "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = ".\.config\terminal\settings.json"
    "$HOME\.gitconfig"                                                                              = ".\.config\git\.gitconfig"
}

# PS Modules
$psModules = @(
    'ThreadJob'
    'PSScriptAnalyzer'
    'InvokeBuild'
    'Pester'
)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
Push-Location $PSScriptRoot

# TODO : add test, if current profile on OneDrive, warn & prompt, move to local directory based on response
#. .\Scripts\Move-ProfileLocal.ps1

# install PS modules
foreach ($psModule in $psModules) {
    if (!(Get-Module -ListAvailable -Name $psModule)) {
        Install-Module -Name $psModule -Force -AcceptLicense -Scope CurrentUser
    }
}

# git config
$currentGitEmail = (git config --global user.email)
$currentGitName = (git config --global user.name)

# Create Symbolic Links
foreach ($symlink in $symlinks.GetEnumerator()) {
    Get-Item -Path $symlink.Key -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $symlink.Key -Target (Resolve-Path $symlink.Value) -Force | Out-Null
}

# refresh git config
git config --global --unset user.email | Out-Null
git config --global --unset user.name | Out-Null
git config --global user.email $currentGitEmail | Out-Null
git config --global user.name $currentGitName | Out-Null

Pop-Location
