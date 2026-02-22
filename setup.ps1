<#
    .SYNOPSIS
        Setup.ps1 - configure windows shell profile

    .NOTES
        Author: Will Rowe
#>
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
[CmdletBinding()]
param()
#Requires -Version 7.0
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity ]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $msg = "Restarting $PSCommandPath script as Administrator"
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    $argString = $(foreach ($key in $PSBoundParameters.Keys) { 
            if ($PSBoundParameters[$key] -is [switch] -and $PSBoundParameters[$key].IsPresent) { "-$key"; continue }
            if ($PSBoundParameters[$key] -is [string]) { "-$key `"$PSBoundParameters[$key]`"" } else { "-$key $PSBoundParameters[$key]" }
        }) -join ' '
    if ($null -ne $argString) { $msg = "$msg, with additional arguments { $argString }" }
    Write-Host $msg -ForegroundColor Yellow
    #Start-Process $PSexe "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Start-Process $PSexe "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argString" -Verb RunAs
    return
}

# link configurations ( repo Source => local Destination )
$symlinks = [Ordered]@{
    'profile.ps1'                     = $PROFILE.CurrentUserAllHosts
    '.config\vscode\settings.json'    = "$env:APPDATA\code\user\settings.json"
    '.config\vscode\keybindings.json' = "$env:APPDATA\code\user\keybindings.json"
    '.config\vscode\extensions.json'  = "$env:APPDATA\code\user\extensions.json"
    '.config\terminal\settings.json'  = "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    '.config\git\.gitconfig'          = "$HOME\.gitconfig"
    '.config\fonts'                   = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
}

# Chocolatey Packages 
$chocoDep = @(
    'Git'
    'PowerShell.Core'
    'VSCode'
    'PowerToys'
)

# PS Modules to install
$psModules = @(
    'ThreadJob'
    'PSScriptAnalyzer'
    'InvokeBuild'
    'Pester'
    'Terminal-Icons'
)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ## # # # # # # # # # # # # # # # # #
Push-Location $Env:Scripts
function Get-UserResponse {
    param ($Msg = 'Do you want to continue? (Y/N)')
    do {
        # Simple Yes/No validation loop
        $response = Read-Host $Msg
        $response = $response.Trim().ToUpper()
        switch ($response) {
            'Y' { $valid = $true; $return = $true; break }
            'N' { $valid = $true; $return = $false; break }
            default { Write-Host 'Invalid input. Please enter Y or N.' -ForegroundColor Red; $valid = $false; break }
        }
    } until ($valid)
    return $return
}
if ($PROFILE.CurrentUserAllHosts -match [regex]::Escape($env:OneDrive)) {
    Write-Warning "PS Profile is located on OneDrive filesystem! [$($PROFILE.CurrentUserAllHosts)]
    It is recommended to move the Powershell profile off of OneDrive,
    and move it back onto to local filesystem for performance and stability."
    $response = Get-UserResponse 'Relocate PowerShell Profile to local filesystem? (Y/N)'
    if ($response) {
        Write-Host 'Attempting to move PowerShell profile off of OneDrive to local FileSystem...'
        . '.\Move-ProfileLocal.ps1' @PSBoundParameters
    }
}

Write-Verbose 'applying UI configurations...'
. '.\Set-UI.ps1' @PSBoundParameters -DesktopImagePath "$env:WallPapers\979745.jpg" -LockScreenImagePath "$env:WallPapers\986372.jpg" -AccentColor '57c845' -SecondaryColor '1f4919'

reg import "$env:Config\themes\Dark_Green.reg"

Write-Verbose 'applying power configurations...'
. '.\Set-PowerConfig.ps1' @PSBoundParameters

if (Get-Command code.cmd -ErrorAction SilentlyContinue) {
    . '.\Install-VSCodeExtension.ps1' @PSBoundParameters -Extensions (Get-Content (Join-Path $env:Configs 'vscode\extensions.json') -Raw | ConvertFrom-Json).recommendations
}

Write-Verbose 'install PS modules'
foreach ($psModule in $psModules) {
    if (!(Get-Module -ListAvailable -Name $psModule)) {
        Install-Module -Name $psModule -Force -AcceptLicense -Scope CurrentUser
    }
}

Write-Verbose 'capture current git user'
$currentGitEmail = (git config --global user.email)
$currentGitName = (git config --global user.name)

Write-Verbose 'Create Symbolic Links'
foreach ($symlink in $symlinks.GetEnumerator()) {
    $source = $symlink.key; $destination = $symlink.value
    if (-not(Test-Path $source)) { continue } # skip linking if we don't have a source file at the moment.
    Write-Host "Linking File: $source to local path: $destination" -ForegroundColor Cyan
    Get-Item -Path $destination -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $destination -Target (Resolve-Path $source) -Force | Out-Null
}

Pop-Location

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
Start-Process Explorer

return
