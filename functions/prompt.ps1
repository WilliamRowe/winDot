function prompt {
    <#
    .SYNOPSIS
        Override the default prompt function
    .DESCRIPTION
        This function is called every time the console prompt is displayed
    
    .EXAMPLE
        000000.10 Sec : 0000104.9 ms : 000104921 μs
        [10:54:58] will@myComputer : ~ > 
    
        .NOTES
        TODO: Research incorporating StringBuilder for performance optimization in string concatenation
            # Create a StringBuilder object
            $prompt = New-Object -TypeName System.Text.StringBuilder

            # Append text to the StringBuilder
            for ($i = 1; $i -le 100000; $i++) {
                $stringBuilder.Append("This is line $i`n") | Out-Null
            }

            # Convert the StringBuilder content to a single string and output it
            $output = $stringBuilder.ToString()
            Write-Output $output
    #>
    <#
    #  Gather information for the prompt
    #>
    if ($null -eq $Script:OriginalScriptBlock) {
        #$defaultPrompt = "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) 1"S
        [ScriptBlock]$Script:OriginalScriptBlock = (Get-Command prompt).ScriptBlock
    }
    # color definitions
    $userColors = @{
        # TODO: look into using ANSI escape codes for more color options. 
        default = 'White'
        background = 'Black'
        foreground = 'LightGray'
        admin = @{ computer = 'Red'; user = 'DarkRed'; accent = 'DarkYellow'; alt = 'DarkMagenta' }
        user = @{ computer = 'Green'; user = 'DarkGreen'; accent = 'DarkMagenta'; alt = 'DarkYellow' }
        location = @{ local = 'darkGray'; remote = 'Yellow'; home = 'Cyan' }
        time = @{ current = $null; hours = 'DarkRed'; minutes = 'DarkYellow'; seconds = 'DarkBlue'; milliseconds = 'DarkGray'; microseconds = 'DarkGray' }
    }
    # default color settings
    $colorSetting = @{
        default = $userColors.default
        computerColor = $userColors.user.computer
        userColor = $userColors.user.user
        accentColor = $userColors.user.accent
        altColor = $userColors.user.alt
        locationColor = $userColors.location.local
    }
    # skew users color when not on a native domain system
    if ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Domain -ne $env:USERDNSDOMAIN) {
        $colorSetting.userColor = $colorSetting.altColor
    }
    # adjust prompt color when user is admin
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        $colorSetting.computerColor = $userColors.admin.computer
        $colorSetting.userColor = $userColors.admin.user
        $colorSetting.accentColor = $userColors.admin.accent
        $colorSetting.alternateColor = $userColors.admin.alternate
    }
    # Get the current directory, format the title path, and adjust location color; based whether path is remote, home, or local directory.
    $Path = Get-Location
    $currentDir = Split-Path -Path $Path -Leaf
    # Resize-Path function to shorten long path strings
    function Resize-Path {
        param ( [string]$path = $((Get-Location).path),  [int]$maxLength = 50 )
        $currentDir = Split-Path -Path $path -Leaf
        $rootIndex = 0
        $remotePrefix = ''
        if ($path.StartsWith('Microsoft.PowerShell.Core\FileSystem::')) {
            $path = $path.replace('Microsoft.PowerShell.Core\FileSystem::', '')
            $rootIndex = 2
            $remotePrefix = '\\'
        }
        if ($path.Length -gt $maxLength) {
            $pathSplit = $path -split '\\'
            $newPath = "$remotePrefix$($pathSplit[$rootIndex])"
            $pathSplit[($rootIndex + 1)..$($pathSplit.Length - 1)] | ForEach-Object {
                if ((@($newPath, $_, '...', $currentDir) -join '\').length -le $maxLength) {
                    $newPath += "\$_"; continue;
                } elseif ((@($newPath, '...', $currentDir) -join '\').length -le $maxLength) {
                    $path = @($newPath, '...', $currentDir) -join '\'; break;
                }
            }
        }
        return $path
    }
    switch ($Path) {
        {$_.Path.StartsWith('Microsoft.PowerShell.Core\FileSystem::')} { # remote filesystem
            $titlePath = resize-path "$($_.Path)"
            $colorSetting.locationColor = $userColors.location.remote
            break
        }
        {$_ -in @($env:USERPROFILE, $home)} { # home directory
            $titlePath = "$($_.Path)"
            $currentDir = '~'
            $colorSetting.locationColor = $userColors.location.home
            break
        }
        default { # local filesystem
            $titlePath = resize-path "$($_.Path)"
            break
        }
    }
    # calculate nested prompt indicator
    $nestedPromptIndicator = '>' * ($NestedPromptLevel + 1)
    <#
    # Calculate the runtime of the last command
    #>
    $lastCommand = Get-History -Count 1
    [TimeSpan]$runtime = New-TimeSpan -Seconds 0
    if ($lastCommand) { [TimeSpan]$runtime = $lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime }
    $Hours = @{ Object = "$("{0:00.000000} Hr" -f $runtime.TotalHours)"; ForegroundColor = $userColors.time.hours; NoNewline = $true }
    $Minutes = @{ Object = "$("{0:00.000000} Min" -f $runtime.TotalMinutes)"; ForegroundColor = $userColors.time.minutes; NoNewline = $true }
    $Seconds = @{ Object = "$("{0:00.000000} Sec" -f $runtime.TotalSeconds)"; ForegroundColor = 'DarkBlue'; NoNewline = $true }
    $MilliSeconds = @{ Object = "$("{0:00.000000} ms" -f $runtime.TotalMilliseconds)"; ForegroundColor = 'DarkGray' }
    $Microseconds = @{ Object = "$("{0:000000000} μs" -f $runtime.TotalMicroseconds)"; ForegroundColor = 'DarkGray' }
    $delimiter = @{ Object = " : "; ForegroundColor = 'Gray'; NoNewline = $true }
    <#
    # build prompt components
    #>
    $TimeStamp = @{ Object = "[$(get-date -f 'HH:mm:ss')] "; ForegroundColor = $colorSetting.accentColor; NoNewline = $true }
    $UserName = @{ Object = "$($env:USERNAME.ToLower())"; ForegroundColor = $colorSetting.userColor; NoNewline = $true }
    $atSymbol = @{ Object = "@"; ForegroundColor = $colorSetting.accentColor; NoNewline = $true }
    $computerName = @{ Object = "$($env:COMPUTERNAME.ToLower())"; ForegroundColor = $colorSetting.computerColor; NoNewline = $true }
    $colonSymbol = @{ Object = " : "; ForegroundColor = $colorSetting.Default; NoNewline = $true }
    $location = @{ Object = "$currentDir"; ForegroundColor = $colorSetting.locationColor; NoNewline = $true }
    $promptIndicator = @{ Object = " $nestedPromptIndicator"; ForegroundColor = $colorSetting.accentColor; NoNewline = $true }
    <#
    #  Display Prompt
    #>
    # Clear the console
    [system.console]::WriteLine()
    # Set the console title as `$titlePath`, derived from current location
    [system.console]::Title = $titlePath
    # Show last command runtimes > Hours : Minutes : Seconds : Milliseconds : Microseconds
    if ($runtime.Hours -gt 0) {
        Write-Host @Hours; Write-Host @delimiter; Write-Host @Minutes; Write-Host @delimiter; Write-Host @Seconds
    } elseif (($runtime.Minutes -gt 0) -OR ($PSVersionTable.PSVersion.Major -lt 7))  {
        Write-Host @Minutes; Write-Host @delimiter; Write-Host @Seconds; Write-Host @delimiter; Write-Host @MilliSeconds
    } else { 
        Write-Host @Seconds; Write-Host @delimiter; Write-Host @MilliSeconds -NoNewline; Write-Host @delimiter; Write-Host @Microseconds 
    }
    Write-Host @TimeStamp
    Write-Host @UserName
    Write-Host @atSymbol
    Write-Host @computerName
    Write-Host @colonSymbol
    Write-Host @location
    Write-Host @promptIndicator
    return " "
}