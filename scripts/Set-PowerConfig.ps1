<#
.SYNOPSIS
    Configure Windows Power Plan
.NOTES
#Start-Process "control.exe" -ArgumentList "powercfg.cpl" -Wait
#>
[CmdletBinding()]
param (
    [ValidateSet('HighPerformance', 'Balanced')]
    $Option = 'HighPerformance'
)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity ]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $msg = "Restarting $PSCommandPath script as Administrator"
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    $argString = $(foreach ($key in $PSBoundParameters.Keys) {
            if ($PSBoundParameters[$key] -is [switch] -and $PSBoundParameters[$key].IsPresent) { "-$key"; continue }
            if ($PSBoundParameters[$key] -is [string]) { "-$key `"$PSBoundParameters[$key]`"" } else { "-$key $PSBoundParameters[$key]" }
        }) -join ' '
    if ($null -ne $argString) { $msg = "$msg, with additional arguments { $argString }" }
    Write-Host $msg -ForegroundColor Yellow
    Start-Process $PSexe "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argString" -Verb RunAs
    return
}
switch ($Option) {
    'HighPerformance' {
        powercfg /S 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
        Write-Verbose 'Set Power Settings to High Performance'
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -standby-timeout-ac 0
        powercfg -change -hibernate-timeout-ac 0
        Write-Verbose 'Disabled hibernate, standby, and monitor timeout while on AC power'
    }
    'Balanced' {
        powercfg /S 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
        Write-Verbose 'Set Power Settings to Balanced Performance'
    } 
}

$currentConfig = powercfg /GETACTIVESCHEME
Write-Verbose "`rCurrently applied PowerScheme: $currentConfig"

return
