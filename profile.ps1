<#
.SYNOPSIS
    PowerShell Profile

.NOTES
    Author: Will Rowe
#>
[CmdletBinding()]
param()
if ([Environment]::GetCommandLineArgs().Contains('-NonInteractive')) { return } # do NOT execute for non-interactive sessions
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[system.console]::Clear()

# Environment Variables 🌐
if ((Get-Item -LiteralPath $PSCommandPath -Force).Target) { 
    $Env:PSProfile = (Get-Item -LiteralPath $PSCommandPath -Force).Target
} else {
    $Env:PSProfile = $PSCommandPath
}
$Env:ProfileRepo = (Split-Path $Env:PSProfile -Parent)
$Env:Configs = (Join-Path $Env:ProfileRepo '.config')
$Env:Functions = (Join-Path $Env:ProfileRepo 'functions')
$Env:Scripts = (Join-Path $Env:ProfileRepo 'scripts')
$Env:WallPapers = (Join-Path $Env:Configs 'walls')
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Functions 🎉
foreach ($import in @(Get-ChildItem $Env:Functions\*.ps1 -Recurse -ErrorAction SilentlyContinue)) {
    if ($null -eq $import.fullname) { continue }
    try {
        # "Dot source" import functions
        # 'ExecutionContext' optimized method to improve import times when function file counts increase.
        $ExecutionContext.InvokeCommand.InvokeScript( 
            $false,
            ([scriptblock]::Create([io.file]::ReadAllText($import.FullName, [Text.Encoding]::UTF8))),
            $null,
            $null
        )
    } catch {
        Write-Warning "Failed to import function: $($import.fullname). Trying again."
        try {
            . $import.FullName
        } catch {
            Write-Warning "Failed to import function: $($import.fullname): $_`n$($_)ScriptStackTrace`n$($_.ScriptStackTrace)"
        }
    }
}
function which { param($cmd) Get-Command "*$($cmd)*" }

function def { param($cmd); return (Get-Command $cmd | Select-Object -ExpandProperty Definition) }
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Aliases 🔗
New-Alias -Name def -Value Get-Definition
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Prompt & Shell Configuration 🐚
# Start-ThreadJob -ScriptBlock {
#     Set-Location -Path $ENV:WindotsLocalRepo
#     $gitUpdates = git fetch && git status
#     if ($gitUpdates -match "behind") {
#         $ENV:DOTFILES_UPDATE_AVAILABLE = "󱤛 "
#     }
#     else {
#         $ENV:DOTFILES_UPDATE_AVAILABLE = ""
#     }
# } | Out-Null

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #Start-ThreadJob -ScriptBlock {

Get-WinFetch
