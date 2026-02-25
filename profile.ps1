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
$Env:PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
if ((Get-Item -LiteralPath $PSCommandPath -Force).Target) {
    $Env:PSProfile = (Get-Item -LiteralPath $PSCommandPath -Force).Target  # handle symlink path
} else {
    $Env:PSProfile = $PSCommandPath
}
# 
$Env:Profile = (Split-Path $Env:PSProfile -Parent)
$Env:Configs = (Join-Path $Env:Profile '.config')
$Env:Functions = (Join-Path $Env:Profile 'functions')
$Env:Scripts = (Join-Path $Env:Profile 'scripts')
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Theme settings
$Env:WallPapers = (Join-Path $Env:Configs 'walls')
$Env:WallPaper = "$env:WallPapers\979745.jpg"
$Env:LockScreen = "$env:WallPapers\986372.jpg"
$Env:AccentColor = '57c845'
$Env:SecondaryColor = '1f4919'
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

function Get-UserResponse {
    [alias('confirm')]
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

function Update-PSModules {
    param ([String[]]$PSModule)
    Write-Verbose 'install PS modules'
    foreach ($name in $PSModule) {
        if (!(Get-Module -ListAvailable -Name $name)) {
            Install-Module -Name $name -Force -AcceptLicense -Scope CurrentUser
        } else {
            Update-Module -Name $name -Force -AcceptLicense -Scope CurrentUser
        }
    }
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Aliases 🔗

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Prompt & Shell Configuration 🐚
Start-ThreadJob -ScriptBlock {
    Set-Location -Path $Env:Profile
    $gitUpdates = git fetch && git status
    if ($gitUpdates -match 'behind') {
        $Env:PROFILE_UPDATE_AVAILABLE = $true
    } else {
        $Env:PROFILE_UPDATE_AVAILABLE = $false
    }
} | Out-Null

$PSReadLineOptions = @{
    PredictionViewStyle = 'ListView'
    EditMode            = 'Windows'
    PredictionSource    = 'History'
}
Set-PSReadLineOption @PSReadLineOptions

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #Start-ThreadJob -ScriptBlock {

Get-WinFetch
