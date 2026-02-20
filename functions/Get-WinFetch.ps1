function Get-WinFetch {
    [Alias('Screenfetch', 'winfetch', 'Get-Screenfetch')]
    param (
        [string]$Path = "$env:Scripts\winfetch.ps1",
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    if (-not (resolve-path -Path $Path -ErrorAction SilentlyContinue)) {
        Throw "The specified script path '$Path' does not exist."
    }
    $winfetch = Get-Content -Path $path -Raw
    $winfetchSB =[ScriptBlock]::Create($winfetch)
    if ($ComputerName -eq $env:COMPUTERNAME) {
        $winfetchSB.Invoke()
    } else {
        foreach ($computer in $ComputerName) {
            Invoke-Command -ComputerName $computer -ScriptBlock $winfetchSB
        }
    }
}