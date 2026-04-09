function Get-GitHubRelease {
    <#
    .EXMAPLE
        Get-GitHubRelease -RepoOwner 'jgm' -RepoName 'pandoc' -AssetName 'windows-x86_64\.zip$' -DestinationPath "$env:LOCALAPPDATA\pandoc" -Extract -UpdatePath
    #>
    [Alias('Download-GitHubRelease')]
    param(
        [Parameter(Mandatory)]
        [string]$RepoOwner,

        [Parameter(Mandatory)]
        [string]$RepoName,

        [string]$Version = 'latest',

        [ValidateSet('windows', 'linux')]
        [string]$AssetOS = 'windows',

        [ValidateSet('zip', 'tar.gz', 'exe', 'msi', 'deb', 'rpm')]
        [string]$AssetType = 'zip',

        [string]$AssetName,

        [Switch]$Download,

        [Alias('TempPath')]
        [string]$DownloadPath = (join-path $home 'downloads'),

        [Switch]$Extract,

        [Switch]$Install,

        [Alias('DestinationPath')]
        [String]$InstallPath = $env:LOCALAPPDATA,

        [Switch]$UpdatePath
    )
    $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/$Version"
    $headers = @{
        "User-Agent" = "PowerShell"
    }
    Write-Host "Querying GitHub API for latest release of $RepoOwner/$RepoName ..."
    Write-Host "API URL: $apiUrl"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    Write-Host "Latest release: $($release.tag_name) - $($release.name)"
    # find asset by OS and type
    if ($AssetName) {
        $asset = $release.assets | Where-Object { $_.name -match $AssetName }
    } else {
        $asset = $release.assets | Where-Object { $_.name -match $AssetOS -and $_.name -match $AssetType }
    }
    if (-not $asset) {
        throw "Asset for '$RepoOwner/$RepoName' not found in latest release."
    } elseif ($asset.Count -gt 1) { # handle when multiple assets match criteria
        do {
            Write-Host "Multiple assets found matching criteria...Select which to download:`n"
            for ($i = 0; $i -lt $asset.Count; $i++) {
                Write-Host "  ($i) $($asset[$i].name)"
            }
            $selection = Read-Host -Prompt "Enter asset number to download (0 to $(($asset.Count)-1))"
        } while (-not ($selection -as [int]) -or $selection -lt 0 -or $selection -ge $asset.Count)
        $asset = $asset[$selection]
    }

    Write-Host "Selected asset: $($asset.name)"

    if (-not $download -and -not $Extract -and -not $Install) {
        Write-Host "Download switch not specified. Exiting without downloading."
        return $asset
    }

    $downloadUrl = $asset.browser_download_url

    if ($Extract -and (-not $Install)) {
        $tempZip = "$([System.IO.Path]::GetTempFileName()).zip"
        Write-Host "Downloading $($Asset.Name) to $tempZip ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -Headers $headers
        Expand-Archive -Path $tempZip -DestinationPath $DownloadPath -Force
        Remove-Item -Path $tempZip -Force
        Write-Host "Extracted $($Asset.Name) to $DownloadPath"

    } elseif ($Install) {
        $tempZip = "$([System.IO.Path]::GetTempFileName()).zip"
        Write-Host "Downloading $($Asset.Name) to $tempZip ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -Headers $headers

        try { $zip = [System.IO.Compression.ZipFile]::OpenRead($tempZip) } catch { throw "Failed to open ZIP archive. Error: $_" }

        # Get top-level folder in the archive
        $topLevel = $zip.Entries | Where-Object { $_.FullName -match '^([^/\\]+)[/\\]' } |  Select-Object -First 1
        if (-not $topLevel) {
            $zip.Dispose()
            Throw "No top-level directory found in the archive."
        }
        $topDirName = ($topLevel.FullName -split '[/\\]')[0]
        $toExtract = $zip.Entries | Where-Object {
            $_.FullName -like "$topDirName/*" -and
            -not $_.FullName.EndsWith("/") -and
            -not $_.FullName.EndsWith("\")
        }
        # Ensure destination directory exists
        $InstallPath = Join-Path $InstallPath $topDirName
        if (!(Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }
        foreach ($entry in $toExtract) {
            $relativePath = $entry.FullName.Substring($topDirName.Length + 1)
            $targetPath = Join-Path $InstallPath $relativePath
            $stream = $entry.Open()
            $fileStream = [System.IO.File]::Open($targetPath, [System.IO.FileMode]::Create)
            $stream.CopyTo($fileStream)
            $fileStream.Close()
            $stream.Close()
            Unblock-File -Path $targetPath
        }
        $zip.Dispose()
        Remove-Item -Path $tempZip -Force
        Write-Host "Installed $($Asset.Name) to $InstallPath"
    
    } else {
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$(Join-Path $DownloadPath $($Asset.Name))" -Headers $headers
    }

    if ($Install -and $UpdatePath) {
        $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
        if (-not ($currentPath -split ';' | Where-Object { $_ -eq $InstallPath })) {
            $env:path = $env:path.replace("$installpath", '')
            $env:path = "$env:path;$InstallPath"
            [System.Environment]::SetEnvironmentVariable('PATH', "$currentPath;$InstallPath", [System.EnvironmentVariableTarget]::User)
            Write-Host "Updated user PATH to include $InstallPath"
        } else {
            Write-Host "$InstallPath is already in the user PATH"
        }
    }
}
