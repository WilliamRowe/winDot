param (
    $Script:LOG_PATH = "..\out\logs\default_$(get-date -Format yyyyMMdd_HHmmss).log"
)
#region Module-Script scoped variables
# parameter PACKAGE_NAME - default value handler

# function write-log {
#     param (
#         [parameter(Mandatory=$false, Position=0)]
#         [object[]]$Message,
#         [Switch]$NoLogFile
#     )
#     Write-Host $Message
#     $Message | Out-File -FilePath $LOG_PATH -Append -Encoding utf8

# # Alternative approach to preserve encoding
# $bytes = [System.IO.File]::ReadAllBytes("input.txt")
# # Write the bytes back without altering encoding

# [System.IO.File]::WriteAllBytes("output.txt", $bytes)

# # Detect encoding from BOM (if present)
# $reader = New-Object System.IO.StreamReader("input.txt", $true)
# $content = $reader.ReadToEnd()
# $encoding = $reader.CurrentEncoding
# $reader.Close()

# # Write back using the same encoding
# [System.IO.File]::WriteAllText("output.txt", $content, $encoding)
# }

enum ERRORCODE {
    Default = 0
    LogFileUndefined = 800001
    FailedToWriteLogFile = 800002
}

enum LogType {
    # write-log's Severity LogType enumerator
    Success = 0 # Green
    Default = 1 # Default
    Warning = 2 # Yellow
    Error = 3 # Red
    Information = 4 # Cyan
    Quiet = 5 # No Console Output
}

function Write-Log {
    <#
    .SYNOPSIS
        Write message to console and log file.

    .DESCRIPTION
        Write-Log function writes a specified message to a log file defined during the import of the PxPackage PowerShell module.
        The Write-Log function also handles the Exiting or termination of a package

    .EXAMPLE
        # Basic Log entry :: Write-Host $msg
        Write-Log -Message "Hello World"
        Write-Log -msg "Hello World"
        Write-Log -M "Hello World"
        Write-Log "Hello World"
        logger "Hello World"
        log "Hello World"

    .EXAMPLE
        # Write a Warning :: Write-Warning $msg
        Write-Log -Warning "Warning!"
        Write-Log -Wound "Warning!"
        Write-Log -W "Warning!"

    .EXAMPLE
        # Write a Warning :: Write-Error $msg
        Write-Log -Halt "Failure! Exit the package" -ExitCode 500
        Write-Log -Failure "Failure!"
        Write-Log -F "Failure!"
        Exit-Script  "Failure!" -ExitCode 500
        Exit-Script  "Failure!"

    .EXAMPLE
        # Write default horizontal-rule line :: Write-Host $HL
        Write-Log -line
        Write-Log -hl
        Write-Line
        hl

    .NOTES
        Author: Will Rowe
        Date: 20250909
    #>
    [CmdletBinding(DefaultParameterSetName = 'Severity')]
    [Alias('log', 'logger', 'hl', 'Write-Line', 'Exit-Script')]
    param(
        [ValidateScript({ if (Test-Path $_) { return $true } else { throw "The specified path '$_' does not exist." } })]
        [String]$LogFile = $Script:LOG_PATH,

        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('M','Msg', 'Text')]
        [String]$Message = '',

        [Alias('hl')]
        [Switch]$line,

        [Parameter(ParameterSetName = 'Line')]
        [String]$LineCharacter = '#',

        [Parameter(ParameterSetName = 'Line')]
        [int]$LineLength = 110,

        [Parameter(ParameterSetName = 'Line')]
        [switch]$AutoSizeLine = [Switch]::Present,

        [Parameter(Mandatory = $false, ParameterSetName = 'Severity')]
        [Alias('LogType', 'SeverityCode')]
        [LogType]$Severity = [LogType]::Default,

        [Parameter(ParameterSetName = 'Success')]
        [Alias('S', 'Pass')]
        [Switch]$Success,

        # Do we need a $Script:WarningCounter variable?
        [Parameter(ParameterSetName = 'Warning')]
        [Alias('W', 'Wound')]
        [Switch]$Warning,

        [Parameter(ParameterSetName = 'Error')]
        [Alias('F', 'Failure', 'Error', 'Exit')]
        [Switch]$Halt,

        [Parameter(ParameterSetName = 'Info')]
        [Alias('I', 'Info')]
        [Switch]$Information,

        [Parameter(ParameterSetName = 'Quiet')]
        [Alias('Q', 'Silent', 'HideConsoleOutput')]
        [Switch]$Quiet,

        [Parameter(Position = 1, ParameterSetName = 'Severity')]
        [Parameter(Position = 1, ParameterSetName = 'Error')]
        [Parameter(Position = 1, ParameterSetName = 'Success')]
        $ExitCode = [ERRORCODE]::Default,

        [Parameter(ParameterSetName = 'Severity')]
        [Parameter(ParameterSetName = 'Error')]
        [Switch]$NoExit,


        [Alias('TimeStamp')]
        [String]$logDateTimeFormat = 'yyyy-MM-ddThh:mm:ss.fff'
    )
    begin {
        # Stop if logfile undefined - Probably not needed with ValidateScript on parameter
        if (-not $LogFile) {
            Write-Warning "'LogFile' Argument is Null. Module Variable ``$LOG_PATH` undefined!"
            Exit -1
        }
    }
    process {
        foreach ($msg in $Message) {
            # error handler - capture exit-package or exit-script alias function calls
            switch -regex ($MyInvocation.InvocationName) { 'Exit-Script'{ $Halt = [Switch]::Present } }
            #  Severity assessment with function switch parameters
            if ($Severity -eq [LogType]::Default) { # when not explicitly defined
                $Severity = switch ($true) {
                    $Halt { [LogType]::Error }
                    $Quiet { [LogType]::Quiet }
                    $Warning { [LogType]::Warning }
                    $Success {  [LogType]::Success }
                    $Information { [LogType]::Information }
                    Default { [LogType]::Default }
                }
            }
            # line handler - capture write-line and hl alias function calls
            switch -regex ($MyInvocation.InvocationName) { 'Write-line|hl'{ $line = [Switch]::Present } }
            if ($line) {
                if ($autoSizeLine) {
                    $lineSize = switch($Host.UI.RawUI.WindowSize.Width){ {$_ -lt $LineLength}{ $_ }; default{ $LineLength } }
                } else { $lineSize = $LineLength }
                $HL = $LineCharacter * $lineSize # define line from arguments
                if ($msg) { # wrap messages in lines.
                    if ($msg.length -lt $lineSize) { $padMsg = " " * (($lineSize - $msg.length) / 2) } else { $padMsg = '' }
                        $msg = "`n$HL`n$padMsg$msg`n$HL"
                } else { $msg = "`n$HL" }
            }

            # Construct Output message
            [String]$timestamp = Get-Date -Format $logDateTimeFormat #"YYYY-/dd/yy hh:mm:ss.fff"
            $CommandPath = if ($MyInvocation.PSCommandPath) { $(Split-Path $MyInvocation.PSCommandPath -Leaf) } else { 'Console' }
            [String]$MessageHeader = "$timestamp - [$($Severity.toString())] - $($CommandPath):Line:$($MyInvocation.ScriptLineNumber)"
            if (-not $msg) {
                $_msg = $MessageHeader
            } else {
                $_msg = "$MessageHeader - $msg"
            }

            # Output >> Console
            switch -regex ($Severity) {
                'Quiet' { continue }
                'Warning' { $color = 'Yellow' }
                'Error' { $color = 'Red' }
                'Warning|Error' {
                    if (($Error[0])  -and ($Error[0].InvocationInfo.HistoryId -eq ($MyInvocation.HistoryId - 1))) {
                        Write-Host -ForegroundColor $color $Error[0]
                        Write-Host -ForegroundColor $color $Error[0].ScriptStackTrace
                    }
                    Write-Host -ForegroundColor $color $_msg
                }
                'Information' {  Write-Host $_msg -ForegroundColor Cyan }
                'Success' {  Write-Host $_msg -ForegroundColor Green }
                'Default' { Write-Host $_msg }
            }

            # Output >> Logfile
            try {
                Add-Content -Path $LogFile -Value $_msg -ErrorAction Stop
            } catch {
                Write-Log -Halt "Failed to append log file with last message : $_msg" -ExitCode [ERRORCODE]::FailedToWriteLogFile
            }

            # Exit !! Fail Package !!
            if (($Severity -eq [LogType]::Error) -and (-not $NoExit)) {
                if ($ExitCode -eq [ERRORCODE]::Default) { $ExitCode = [ERRORCODE]::LogFileUndefined }
                if (-Not $SkipPackageHistoryUpdate) { Update-PackageHistory -InstallState 'Fail' }
                Pop-Location
                Exit [int]$ExitCode.Value__
            }
        }
    }
    end{}
}

if (-not (Test-Path $Script:LOG_PATH)) { 
    Write-Host "Attempting to initialize log: $($Script:LOG_PATH) . . ." -ForegroundColor Cyan
    try { New-Item -ItemType File -Path $Script:LOG_PATH -Force } catch { 
        Write-Host "Failed to create log file at path: $($Script:LOG_PATH) ! `n$_ `n$($_.ScriptStackTrace)" -ForegroundColor Red
        Exit [ERRORCODE]::LogFileUndefined
    }
    Write-Log -I "Initialized Log File: $($Script:LOG_PATH)" -Line
}
