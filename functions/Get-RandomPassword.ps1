function Get-RandomPassword {
    [Alias('randomPW')]
    <#
    .SYNOPSIS
        Returns a random password string

    .DESCRIPTION
        Returns a random password string with given length and symbolscount.
        PowerShell 5.1 and below uses System.Web.Security.Membership::GeneratePassword
        PWSH 6.0 and above uses System.Security.Cryptography.RandomNumberGenerator

    .PARAMETER length
        Length of the password string

    .PARAMETER symbolsCount
        Number of symbols in the password string

    .EXAMPLE
        Get-RandomPassword -length 14 -symbolsCount 4

    .EXAMPLE
        Get-RandomPassword -AsPlainText

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(12, 128)]
        [int]$length = 18,
        [Parameter(Mandatory = $false)]
        [int]$symbolsCount = 4,
        [switch]$AsPlainText
    )
    if ($PSVersionTable.PSVersion.Major -le 5) {
        Add-Type -AssemblyName System.Web
        $password = [System.Web.Security.Membership]::GeneratePassword($length , $symbolsCount)
    } elseif ($PSVersionTable.PSVersion.Major -gt 5) {
        $symbols = '!@#$%^&*'.ToCharArray()
        $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $symbols
        do {
            $password = ''
            for ($i = 0; $i -lt $length; $i++) {
                $randomIndex = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $characterList.Length)
                $password += $characterList[$randomIndex]
            }
            [int]$hasLowerChar = $password -cmatch '[a-z]'
            [int]$hasUpperChar = $password -cmatch '[A-Z]'
            [int]$hasDigit = $password -match '[0-9]'
            [int]$hasSymbol = $password.IndexOfAny($symbols) -ne -1
            [int]$hasSymbolCount = ($symbols | ForEach-Object { $password.toCharArray() -eq $_ } ).count -ge $symbolsCount
        }
        until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol + $hasSymbolCount) -ge 4)
    }
    if ($AsPlainText) { 
        return $password 
    } else {
        return (ConvertTo-SecureString -AsPlainText $password)
    }
}
