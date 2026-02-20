function Update-Profile {
    <#
    .SYNOPSIS
        Gets the latest changes from git, reruns the setup script and reloads the profile.
        Note that functions won't be updated, this requires a full PS session restart. Alias: up
    #>
    Write-Verbose "Updating local profile from Github repository"
    Push-Location $env:ProfileRepo
    git stash | Out-Null
    git pull | Out-Null
    git stash pop | Out-Null

    Write-Verbose "Rerunning setup script to capture any new dependencies."
    ./
    # if (Get-Command -Name sudo -ErrorAction SilentlyContinue) {
    #     sudo pwsh ./Setup.ps1
    # } else {
    #     Start-Process wezterm -Verb runAs -WindowStyle Hidden -ArgumentList "start --cwd $PWD pwsh -NonInteractive -Command ./Setup.ps1"
    # }

    Write-Verbose "Reverting to previous working directory"
    Set-Location $currentWorkingDirectory

    Write-Verbose "Re-running profile script from $($PROFILE.CurrentUserAllHosts)"
    .$PROFILE.CurrentUserAllHosts
}