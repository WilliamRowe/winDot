function Get-KeePassSecrets {
    [CmdletBinding()]
    [Alias('gkps', 'Get-KPSecrets')]
    param (
        [String]$DatabaseName = 'secrets',

        [ValidateScript({ if (Test-Path $_ ) { $true } else { throw "Invalid Database File Path given! $_" } })]
        $DatabaseFilePath = $env:KeePassDB,
        
        [switch]$WindowsAuth = [switch]::Present,

        [ValidateScript({ if (Test-Path $_ ) { $true } else { throw "Invalid Keyfile given! $_" } })]
        $KeyFile,

        [PSCredential]$MasterKey
    )
    # Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
    # Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
    if (-not (Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue)) {
        # Register a vault
        Register-SecretVault -Name $VaultName -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault
    }
    $line = "New-KeePassDatabaseConfiguration -DatabaseProfileName $DatabaseName -DatabasePath $DatabaseFilePath"
    if ($keyFile) { $line = "$line -KeyPath $KeyFile" }
    if ($WindowsAuth) { $line = "$line -UseNetworkAccount" } 
    if ($MasterKey) { $line = "$line -UseMasterKey" }
    $getKeePassEntries = @"
Import-Module Microsoft.PowerShell.SecretManagement -Force
Import-Module Microsoft.PowerShell.SecretStore -Force
if (-not (Get-KeePassDatabaseConfiguration -DatabaseProfileName $DatabaseName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating DB Configuration $DatabaseFilePath"
    $line 
}
Get-KeePassEntry -asplaintext -DatabaseProfileName $DatabaseName | foreach-object {
    Set-Secret -Name `$(`$_.Title) -Secret `$(`$_.Password)
}
"@; $result = Start-Process 'powershell.exe' -ArgumentList "-ExecutionPolicy bypass -Command & { $getKeePassEntries }" -Wait -PassThru
#$result = Start-Process 'powershell.exe' -ArgumentList "-ExecutionPolicy bypass -Command & { $getKeePassEntries }" -Wait -PassThru
    # if ($PSVersionTable.PSEdition -eq 'Core') { Start-Process 'PowerShell.exe' "-ExecutionPolicy Bypass -File `"$PSCommandPath`""; return }
    if (-not (Get-KeePassDatabaseConfiguration -DatabaseProfileName $DatabaseName -ErrorAction SilentlyContinue)) {
        $auth = @{}
        if ($keyFile) { $auth.add('KeyPath', $KeyFile) }
        if ($WindowsAuth) { $auth.add('UseNetworkAccount', $true) } 
        if ($MasterKey) { $auth.add('UseMasterKey', $true) }
        Write-Host "Creating DB Configuration $DatabaseFilePath"
        New-KeePassDatabaseConfiguration -DatabaseProfileName $DatabaseName -DatabasePath $DatabaseFilePath @auth 
    }
    return (Get-KeePassEntry -DatabaseProfileName $DatabaseName)
}