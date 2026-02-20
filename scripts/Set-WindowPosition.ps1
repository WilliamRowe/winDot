
<#
    Open app list and move to specific position on screen
#>

<# Apps to test:
    Windows Terminal
    Edge
    OneNote
    VSCode
    Teams

    KeePass2
    Task Manager
    Start-Process taskmgr; Start-Process perfmon
    Explorer
#>

<#  Possible Monitor Layouts:
        Single Monitor
            Laptop Monitor:
                primary - 1920x1080
        Dual Monitor
            Office Monitors
                primary - 1920x1080
                Right - 1920x1080
        Triple Monitor
            Home Monitors:
                primary - 5120x1440
                top left - 2560x1440
                top right - 2560x1440
            Office + Laptop:
                primary - 1920x1080
                Right - 1920x1080
                Laptop - 1920x1080
#>

# Get the primary screen resolution using .NET's System.Windows.Forms
try {
    Add-Type -AssemblyName System.Windows.Forms
    $allScreens = [System.Windows.Forms.Screen]::AllScreens
    $screen = $allScreens.where({ $_.Primary -eq $true })

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen

    $width  = $screen.Bounds.Width
    $height = $screen.Bounds.Height

    Write-Host "Primary Display Resolution: ${width} x ${height}" -ForegroundColor Green
} catch {
    throw "Error: Unable to retrieve display resolution.`n$($_)"
}

# UI Automation Assemblies
# Add-Type -AssemblyName @('UIAutomationClient', 'UIAutomationTypes')

# Define a function to set window position
Function Set-WindowPosition {
   param (
       [string]$ProcessName,
       [int]$X,
       [int]$Y,
       [int]$Width,
       [int]$Height
   )
   Add-Type @"
       using System;
       using System.Runtime.InteropServices;
       public class Window {
           [DllImport("user32.dll")]
           public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
           [DllImport("user32.dll")]
           public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
       }
"@
   $process = Get-Process -Name $ProcessName -ErrorAction Stop
   $handle = $process.MainWindowHandle
   # Move the window to specified position and size
   [Window]::MoveWindow($handle, $X, $Y, $Width, $Height, $true)
}
# Example: Open Notepad and move it to (100, 100) with size 800x600
Start-Process "notepad.exe"
Start-Sleep -Seconds 2 # Wait for the application to launch


<# to find screen resolution
Get-CimInstance Win32_DesktopMonitor | Select-Object ScreenWidth, ScreenHeight
#>
Set-WindowPosition -ProcessName "notepad" -X 100 -Y 100 -Width 800 -Height 600