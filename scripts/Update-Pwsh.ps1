function Update-Pwsh {
    [Alias('Update-PowerShell')]
    [CmdletBinding()]
    param()
    # run function as admin to update PowerShell
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Throw "This function must be run as an administrator."
    }
    Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -useMSI -Quiet"
}
