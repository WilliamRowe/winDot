<#
.SYNOPSIS
    Install VSCode recommended extensions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string[]]$extensions
)
$cmd = 'code --list-extensions'
Invoke-Expression $cmd -OutVariable output | Out-Null
$installed = $output -split '\s'
foreach ($ext in $extensions) {
    if ($installed.Contains($ext)) { Write-Verbose "$ext is installed"; continue }
    try { code --install-extension $ext } catch { Write-Warning "Failed to install extension $ext`n$_"; continue }
    Write-Verbose "Installed $ext"
}
