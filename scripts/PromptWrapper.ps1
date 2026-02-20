<# 
PowerShell Session Wrapper / Prompt Overlay
- Dot-source this file from $PROFILE
- Works in Windows PowerShell 5.1 and PowerShell 7+
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------------
# Session state / configuration
# ----------------------------
$script:PromptCfg = [ordered]@{
    ShowTime            = $true
    ShowUserHost        = $true
    ShowExitCode        = $true
    ShowLastDuration    = $true
    ShowGit             = $true
    GitStatusTimeoutMs  = 120   # keep prompt snappy
    MaxPathSegments     = 4     # shorten long paths
}

# Track last command duration + exit code
$script:LastCommandStopwatch = [System.Diagnostics.Stopwatch]::new()
$script:LastCommandDuration  = $null
$script:LastExitCode         = 0

# ----------------------------
# Utility helpers
# ----------------------------
function Convert-ToShortPath {
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [int] $MaxSegments = 4
    )

    try {
        $p = (Resolve-Path -LiteralPath $Path).Path
    } catch {
        $p = $Path
    }

    $sep = [IO.Path]::DirectorySeparatorChar
    $parts = $p -split ([Regex]::Escape([string]$sep))

    if ($parts.Count -le $MaxSegments) { return $p }

    $tail = $parts[-$MaxSegments..-1] -join $sep
    return "…$sep$tail"
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-GitInfo {
    if (-not $script:PromptCfg.ShowGit) { return $null }
    if (-not (Test-CommandExists git)) { return $null }

    # Fast checks: are we in a git repo?
    $isRepo = $false
    try {
        $isRepo = (git rev-parse --is-inside-work-tree 2>$null) -eq 'true'
    } catch { return $null }
    if (-not $isRepo) { return $null }

    # Branch name
    $branch = $null
    try {
        $branch = (git branch --show-current 2>$null)
        if (-not $branch) {
            # detached HEAD: show short SHA
            $branch = (git rev-parse --short HEAD 2>$null)
            if ($branch) { $branch = "detached:$branch" }
        }
    } catch { }

    # Status (with timeout-ish behavior by keeping operations minimal)
    # We avoid expensive calls; porcelain is usually okay but can be slow on huge repos.
    $dirty = $false
    $aheadBehind = $null

    try {
        # dirty?
        $status = (git status --porcelain 2>$null)
        $dirty = [bool]$status

        # ahead/behind?
        # This can fail if no upstream; swallow errors.
        $ab = (git rev-list --left-right --count @{u}...HEAD 2>$null)
        if ($ab) {
            $parts = $ab -split '\s+'
            if ($parts.Count -ge 2) {
                $behind = [int]$parts[0]
                $ahead  = [int]$parts[1]
                if ($ahead -or $behind) {
                    $aheadBehind = "↑$ahead ↓$behind"
                }
            }
        }
    } catch { }

    [pscustomobject]@{
        Branch      = $branch
        Dirty       = $dirty
        AheadBehind = $aheadBehind
    }
}

function Format-Duration {
    param([TimeSpan]$Duration)
    if (-not $Duration) { return $null }
    if ($Duration.TotalSeconds -lt 1) { return "{0}ms" -f [int]$Duration.TotalMilliseconds }
    if ($Duration.TotalMinutes -lt 1) { return "{0:n2}s" -f $Duration.TotalSeconds }
    return "{0:hh\:mm\:ss}" -f $Duration
}

# ----------------------------
# "Wrapper" functions (starter set)
# ----------------------------
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force -Attributes !Directory }
function c  { param([string]$Path='.') Set-Location -LiteralPath $Path }

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -LiteralPath $Path
}

function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command $Name -All | Select-Object Name, CommandType, Source, Version
}

function gs { if (Test-CommandExists git) { git status } }
function gb { if (Test-CommandExists git) { git branch } }
function gl { if (Test-CommandExists git) { git log --oneline --decorate -n 20 } }

function Prompt-Config {
    <#
    Quick toggle:
      Prompt-Config -Git:$false
      Prompt-Config -ShowTime:$false
    #>
    param(
        [Nullable[bool]]$ShowTime,
        [Nullable[bool]]$ShowUserHost,
        [Nullable[bool]]$ShowExitCode,
        [Nullable[bool]]$ShowLastDuration,
        [Nullable[bool]]$Git,
        [Nullable[int]] $MaxPathSegments
    )

    if ($PSBoundParameters.ContainsKey('ShowTime'))         { $script:PromptCfg.ShowTime = [bool]$ShowTime }
    if ($PSBoundParameters.ContainsKey('ShowUserHost'))     { $script:PromptCfg.ShowUserHost = [bool]$ShowUserHost }
    if ($PSBoundParameters.ContainsKey('ShowExitCode'))     { $script:PromptCfg.ShowExitCode = [bool]$ShowExitCode }
    if ($PSBoundParameters.ContainsKey('ShowLastDuration')) { $script:PromptCfg.ShowLastDuration = [bool]$ShowLastDuration }
    if ($PSBoundParameters.ContainsKey('Git'))              { $script:PromptCfg.ShowGit = [bool]$Git }
    if ($PSBoundParameters.ContainsKey('MaxPathSegments'))  { $script:PromptCfg.MaxPathSegments = [int]$MaxPathSegments }

    [pscustomobject]$script:PromptCfg
}

# ----------------------------
# Prompt + duration tracking
# ----------------------------
# Capture start time for each command
# (Works in Windows PowerShell and PowerShell 7+)
$ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = {
    param($commandName, $commandLookupEventArgs)
    # don't interfere; just return
}

# Use PSReadLine hooks when available for more accurate timing
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction SilentlyContinue | Out-Null

        # OnCommandLineAccepted runs right before execution
        Set-PSReadLineOption -AddToHistoryHandler {
            param($line)
            $script:LastCommandStopwatch.Restart()
            return $true
        } | Out-Null
    } catch {
        # fall back later
    }
}

# Fallback: start timing when prompt renders (previous command has completed)
function global:prompt {
    # Stop timing for last command (if running)
    if ($script:LastCommandStopwatch.IsRunning) {
        $script:LastCommandStopwatch.Stop()
        $script:LastCommandDuration = $script:LastCommandStopwatch.Elapsed
    }

    # Capture last exit code
    # $LASTEXITCODE is for native apps; $? for PowerShell success.
    $script:LastExitCode = if ($?) { 0 } else { 1 }
    if ($global:LASTEXITCODE -ne 0) { $script:LastExitCode = $global:LASTEXITCODE }

    # Start timing for the *next* command (fallback mode)
    # (PSReadLine handler may have already restarted it; harmless)
    $script:LastCommandStopwatch.Restart()

    # Build prompt segments
    $segments = New-Object System.Collections.Generic.List[string]

    if ($script:PromptCfg.ShowTime) {
        $segments.Add( (Get-Date).ToString("HH:mm:ss") )
    }

    if ($script:PromptCfg.ShowUserHost) {
        $segments.Add(("{0}@{1}" -f $env:USERNAME, $env:COMPUTERNAME))
    }

    $shortPath = Convert-ToShortPath -Path (Get-Location).Path -MaxSegments $script:PromptCfg.MaxPathSegments
    $segments.Add($shortPath)

    if ($script:PromptCfg.ShowGit) {
        $gi = Get-GitInfo
        if ($gi) {
            $gitText = $gi.Branch
            if ($gi.AheadBehind) { $gitText += " $($gi.AheadBehind)" }
            if ($gi.Dirty) { $gitText += " *" }
            $segments.Add("git:$gitText")
        }
    }

    if ($script:PromptCfg.ShowLastDuration -and $script:LastCommandDuration) {
        $segments.Add("took:{0}" -f (Format-Duration $script:LastCommandDuration))
    }

    if ($script:PromptCfg.ShowExitCode -and $script:LastExitCode -ne 0) {
        $segments.Add("exit:{0}" -f $script:LastExitCode)
    }

    # Styling (simple + compatible)
    $prefix = "[" + ($segments -join " | ") + "]"

    # Newline prompt with a clear input marker
    return "$prefix`nPS> "
}