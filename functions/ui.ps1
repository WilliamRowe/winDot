function Add-StartMenuShortcut {
    param (
        [ValidateScript({ if (Get-Command $_ -ErrorAction SilentlyContinue) { $true } else { throw "Command '$_' not found." } })]
        $cmd,
        $shortcutName = $Cmd,
        [ValidateScript({ if (Test-Path $_) { $true } else { throw "Command Path '$_' not found." } })]
        $cmdPath = (Get-Command "*$($cmd)*").Source
    )
    $startMenuFolder = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
    if (-not (Test-Path $startMenuFolder)) {
        New-Item -Path $startMenuFolder -ItemType Directory | Out-Null
    }
    $shortcutPath = Join-Path $startMenuFolder "$shortcutName.lnk"
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $cmdPath
        $shortcut.Save()
        Write-Host "Shortcut for '$cmd' created in the Start Menu." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create shortcut for '$cmd'. Error: $_" -ForegroundColor Red
    }
}

function Add-TaskBar {
    param (
        [ValidateScript({ if (Get-Command $_ -ErrorAction SilentlyContinue) { $true } else { throw "Command '$_' not found." } })]
        $cmd,
        $shortcutName = $Cmd,
        [ValidateScript({ if (Test-Path $_) { $true } else { throw "Command Path '$_' not found." } })]
        $cmdPath = (Get-Command "*$($cmd)*").Source,
        [Switch]$RemovePin 
    )
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace((Split-Path -Path $cmdPath -Parent))
    $item = $folder.ParseName((Split-Path -Path $cmdPath -Leaf))

    if ($RemovePin) {
        $item.InvokeVerb('taskbarunpin')
    } else {
        $item.InvokeVerb('taskbarpin')
    }
}
