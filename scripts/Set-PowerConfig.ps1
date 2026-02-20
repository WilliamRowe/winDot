param (
    [ValidateSet('HighPerformance', 'Balanced')]
    $Option = 'HighPerformance'
)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..."
    $PSexe = (Get-Process -Id $PID).Path # get current PowerShell executable path
    Start-Process $PSexe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return -1
}
#Start-Process "control.exe" -ArgumentList "powercfg.cpl" -Wait
switch ($Option) {
    'HighPerformance' {
        # Set the system power plan to High Performance
        powercfg /S 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        # prevent the computer from going to sleep or turning off the display
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -standby-timeout-ac 0
        powercfg -change -hibernate-timeout-ac 0
    }
    'Balanced' {
        # Set the system power plan to Balanced Performance
        powercfg /S 381b4222-f694-41f0-9685-ff5bb260df2e
    } 
}
powercfg /GETACTIVESCHEME
