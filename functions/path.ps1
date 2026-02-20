function Get-Path { # get the current path variable
    [alias('Get-PathVariable')]
    param()
    $env:path -split ';'
}

function Clear-PathDuplicate {
    param ( $Target = [EnvironmentVariableTarget]::User )
    $env:path = ((Get-Path | Select-Object -Unique) -join ";")
    [Environment]::SetEnvironmentVariable("Path", $env:Path, $Target)
}

function Test-IsPath { # check if path given is in path variable
    [alias('isPath', 'Test-IsPathVariable')]
    param ( $path = (resolve-path .\))
    $(Get-Path) -contains $path
}

function Add-Path { # add given path to path variable
    param ( $path = (resolve-path .\), $Target = [EnvironmentVariableTarget]::User )
    if (Test-IsPath $path) { return }
    $pathString = ";$Path"; 
    $env:Path = $env:path.Replace($pathString, '') 
    $env:Path = "$($env:Path)$($pathString)"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, $Target)
}

function Remove-Path { # remove current path from path variable
    param ( $path = (resolve-path .\), $Target = [EnvironmentVariableTarget]::User )
    if (-not (Test-IsPath $path)) { return }
    $pathString = ";$Path"
    $env:path = $env:path.Replace($pathString, '')
    [Environment]::SetEnvironmentVariable("Path", $env:Path, $Target)
}