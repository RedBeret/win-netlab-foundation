Set-StrictMode -Version Latest

function Get-RepositoryRoot {
    [CmdletBinding()]
    param()

    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Initialize-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        return $true
    }

    return $false
}

function Get-DefaultLogPath {
    [CmdletBinding()]
    param(
        [string]$RootPath = (Get-RepositoryRoot)
    )

    $logDirectory = Join-Path $RootPath "artifacts\logs"
    Initialize-Directory -Path $logDirectory | Out-Null
    return Join-Path $logDirectory ("session-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd"))
}

function Write-StructuredLog {
    [CmdletBinding()]
    param(
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [Parameter(Mandatory)]
        [string]$Action,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,
        [hashtable]$Details = @{},
        [string]$LogPath = (Get-DefaultLogPath)
    )

    $entry = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        level = $Level
        action = $Action
        message = $Message
        details = $Details
    }

    Initialize-Directory -Path (Split-Path -Parent $LogPath) | Out-Null
    Add-Content -Path $LogPath -Value ($entry | ConvertTo-Json -Compress -Depth 8)

    $prefix = "[{0}] {1}" -f $Level, $Action
    switch ($Level) {
        "ERROR" { Write-Host "$prefix $Message" -ForegroundColor Red }
        "WARN" { Write-Host "$prefix $Message" -ForegroundColor Yellow }
        "DEBUG" { Write-Host "$prefix $Message" -ForegroundColor DarkGray }
        default { Write-Host "$prefix $Message" -ForegroundColor Cyan }
    }
}

function New-CheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateSet("pass", "fail", "warn", "skip")]
        [string]$Status,
        [Parameter(Mandatory)]
        [string]$Message,
        [bool]$Required = $true,
        [hashtable]$Details = @{}
    )

    return [pscustomobject]@{
        Name = $Name
        Status = $Status
        Required = $Required
        Message = $Message
        Details = $Details
    }
}

function Get-OverallStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Checks
    )

    $requiredFailures = @($Checks | Where-Object { $_.Required -and $_.Status -eq "fail" })
    if ($requiredFailures.Count -gt 0) {
        return "fail"
    }

    $warnings = @($Checks | Where-Object { $_.Status -in @("warn", "fail") })
    if ($warnings.Count -gt 0) {
        return "pass-with-warnings"
    }

    return "pass"
}

function Write-HealthReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Report,
        [string]$OutputPath = (Join-Path (Get-RepositoryRoot) "artifacts\host-health.json")
    )

    Initialize-Directory -Path (Split-Path -Parent $OutputPath) | Out-Null
    $Report | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath
    return $OutputPath
}

function Resolve-CommandPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $command = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }

    if ($command.Path) {
        return $command.Path
    }

    return $command.Source
}

function Invoke-Process {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 30,
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    foreach ($argument in $Arguments) {
        [void]$psi.ArgumentList.Add($argument)
    }

    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $WorkingDirectory

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    $startedAt = Get-Date
    [void]$process.Start()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            $process.Kill($true)
        }
        catch {
            # Best effort cleanup only.
        }

        [void]$process.WaitForExit(2000)

        $timedOutStdOut = ""
        $timedOutStdErr = ""
        if ($process.HasExited) {
            try {
                $timedOutStdOut = $process.StandardOutput.ReadToEnd()
                $timedOutStdErr = $process.StandardError.ReadToEnd()
            }
            catch {
                # Ignore stream-drain errors after a forced kill.
            }
        }

        return [pscustomobject]@{
            FilePath = $FilePath
            Arguments = $Arguments
            ExitCode = -1
            TimedOut = $true
            StdOut = $timedOutStdOut
            StdErr = $timedOutStdErr
            DurationMs = [int]((Get-Date) - $startedAt).TotalMilliseconds
        }
    }

    return [pscustomobject]@{
        FilePath = $FilePath
        Arguments = $Arguments
        ExitCode = $process.ExitCode
        TimedOut = $false
        StdOut = $process.StandardOutput.ReadToEnd()
        StdErr = $process.StandardError.ReadToEnd()
        DurationMs = [int]((Get-Date) - $startedAt).TotalMilliseconds
    }
}

function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory)]
        [scriptblock]$SuccessScript,
        [int]$MaxAttempts = 3,
        [int]$InitialDelaySeconds = 1
    )

    $lastResult = $null
    $lastError = $null

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $lastResult = & $ScriptBlock
            if (& $SuccessScript $lastResult) {
                return $lastResult
            }

            $lastError = "Attempt $attempt returned an unsuccessful result."
        }
        catch {
            $lastError = $_.Exception.Message
        }

        if ($attempt -lt $MaxAttempts) {
            $sleepSeconds = [Math]::Pow(2, $attempt - 1) * $InitialDelaySeconds
            Write-StructuredLog -Level "WARN" -Action $OperationName -Message "Retrying after a failed attempt." -Details @{
                attempt = $attempt
                next_delay_seconds = [int]$sleepSeconds
                last_error = $lastError
            }
            Start-Sleep -Seconds $sleepSeconds
        }
    }

    throw "Operation '$OperationName' failed after $MaxAttempts attempts. Last error: $lastError"
}

function Convert-WindowsPathToWsl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WindowsPath
    )

    if ($WindowsPath -notmatch "^(?<drive>[A-Za-z]):\\(?<rest>.*)$") {
        throw "Only absolute Windows drive paths can be converted to WSL paths."
    }

    $drive = $Matches.drive.ToLowerInvariant()
    $rest = $Matches.rest -replace "\\", "/"
    if ([string]::IsNullOrWhiteSpace($rest)) {
        return "/mnt/$drive"
    }

    return "/mnt/$drive/$rest"
}

function ConvertTo-BashSingleQuotedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "'""'""'") + "'"
}

function Get-WslState {
    [CmdletBinding()]
    param(
        [string]$UbuntuDistroRegex = "^Ubuntu"
    )

    $wslPath = Resolve-CommandPath -CommandName "wsl.exe"
    if ($null -eq $wslPath) {
        return [pscustomobject]@{
            WslPresent = $false
            Distributions = @()
            UbuntuDistro = $null
            PythonVersion = $null
            BashVersion = $null
            Detail = "wsl.exe was not found on PATH."
            WslCommandPath = $null
        }
    }

    $listResult = Invoke-Process -FilePath $wslPath -Arguments @("-l", "-q") -TimeoutSeconds 20
    $distros = @()
    if ($listResult.ExitCode -eq 0) {
        $distros = @(
            $listResult.StdOut -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    $ubuntuDistro = $distros | Where-Object { $_ -match $UbuntuDistroRegex } | Select-Object -First 1
    $pythonVersion = $null
    $bashVersion = $null

    if ($ubuntuDistro) {
        $pythonResult = Invoke-Process -FilePath $wslPath -Arguments @("-d", $ubuntuDistro, "--", "bash", "-lc", "python3 --version") -TimeoutSeconds 20
        if ($pythonResult.ExitCode -eq 0) {
            $pythonVersion = @(
                $pythonResult.StdOut.Trim()
                $pythonResult.StdErr.Trim()
            ) | Where-Object { $_ } | Select-Object -First 1
        }

        $bashResult = Invoke-Process -FilePath $wslPath -Arguments @("-d", $ubuntuDistro, "--", "bash", "-lc", 'printf ''%s'' "$BASH_VERSION"') -TimeoutSeconds 20
        if ($bashResult.ExitCode -eq 0) {
            $bashVersion = $bashResult.StdOut.Trim()
        }
    }

    return [pscustomobject]@{
        WslPresent = $true
        Distributions = $distros
        UbuntuDistro = $ubuntuDistro
        PythonVersion = $pythonVersion
        BashVersion = $bashVersion
        Detail = if ($listResult.ExitCode -eq 0) { "WSL query succeeded." } else { (@($listResult.StdErr.Trim()) | Where-Object { $_ } | Select-Object -First 1) ?? "WSL query failed without stderr output." }
        WslCommandPath = $wslPath
    }
}

function Get-DockerState {
    [CmdletBinding()]
    param()

    $dockerPath = Resolve-CommandPath -CommandName "docker"
    if ($null -eq $dockerPath) {
        return [pscustomobject]@{
            DockerPresent = $false
            DockerRunning = $false
            ComposeAvailable = $false
            Context = $null
            OperatingSystem = $null
            Detail = "docker was not found on PATH."
            DockerCommandPath = $null
        }
    }

    $infoResult = Invoke-Process -FilePath $dockerPath -Arguments @("info", "--format", "{{json .}}") -TimeoutSeconds 20
    $composeResult = Invoke-Process -FilePath $dockerPath -Arguments @("compose", "version") -TimeoutSeconds 20
    $contextResult = Invoke-Process -FilePath $dockerPath -Arguments @("context", "show") -TimeoutSeconds 20

    $context = if ($contextResult.ExitCode -eq 0) { $contextResult.StdOut.Trim() } else { $null }
    $operatingSystem = $null
    if ($infoResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($infoResult.StdOut)) {
        try {
            $info = $infoResult.StdOut | ConvertFrom-Json
            $operatingSystem = $info.OperatingSystem
        }
        catch {
            $operatingSystem = "unparsed"
        }
    }

    return [pscustomobject]@{
        DockerPresent = $true
        DockerRunning = $infoResult.ExitCode -eq 0
        ComposeAvailable = $composeResult.ExitCode -eq 0
        Context = $context
        OperatingSystem = $operatingSystem
        Detail = if ($infoResult.ExitCode -eq 0) { "Docker daemon responded successfully." } else { (@($infoResult.StdErr.Trim()) | Where-Object { $_ } | Select-Object -First 1) ?? "docker info failed without stderr output." }
        DockerCommandPath = $dockerPath
    }
}

function Get-HostPrereqReport {
    [CmdletBinding()]
    param()

    $wslState = Get-WslState
    $dockerState = Get-DockerState
    $gitPath = Resolve-CommandPath -CommandName "git"
    $codePath = Resolve-CommandPath -CommandName "code"

    $checks = @(
        (New-CheckResult -Name "PowerShell 7+" -Status ($(if ($PSVersionTable.PSVersion.Major -ge 7) { "pass" } else { "fail" })) -Message ("Current version: {0}" -f $PSVersionTable.PSVersion.ToString()) -Details @{ version = $PSVersionTable.PSVersion.ToString() }),
        (New-CheckResult -Name "Git installed" -Status ($(if ($gitPath) { "pass" } else { "fail" })) -Message ($(if ($gitPath) { "git was found on PATH." } else { "Install Git for Windows before continuing." })) -Details @{ path = $gitPath }),
        (New-CheckResult -Name "WSL present" -Status ($(if ($wslState.WslPresent) { "pass" } else { "fail" })) -Message ($(if ($wslState.WslPresent) { $wslState.Detail } else { "Enable WSL before continuing." })) -Details @{ distributions = $wslState.Distributions }),
        (New-CheckResult -Name "Ubuntu available in WSL" -Status ($(if ($wslState.UbuntuDistro) { "pass" } else { "fail" })) -Message ($(if ($wslState.UbuntuDistro) { "Using distro '$($wslState.UbuntuDistro)'." } else { "Install an Ubuntu distro for Linux-only tooling." })) -Details @{ distro = $wslState.UbuntuDistro }),
        (New-CheckResult -Name "Python 3 available in WSL" -Status ($(if ($wslState.PythonVersion -match "^Python 3") { "pass" } else { "fail" })) -Message ($(if ($wslState.PythonVersion) { $wslState.PythonVersion } else { "Install python3 inside Ubuntu." })) -Details @{ version = $wslState.PythonVersion }),
        (New-CheckResult -Name "Docker Desktop running" -Status ($(if ($dockerState.DockerRunning) { "pass" } else { "fail" })) -Message ($(if ($dockerState.DockerRunning) { $dockerState.Detail } else { "Start Docker Desktop with the WSL backend enabled." })) -Details @{ context = $dockerState.Context; operating_system = $dockerState.OperatingSystem }),
        (New-CheckResult -Name "Docker Compose available" -Status ($(if ($dockerState.ComposeAvailable) { "pass" } else { "fail" })) -Message ($(if ($dockerState.ComposeAvailable) { "docker compose is available." } else { "Update Docker Desktop so docker compose is available." })) -Details @{ context = $dockerState.Context }),
        (New-CheckResult -Name "VS Code installed (optional)" -Status ($(if ($codePath) { "pass" } else { "warn" })) -Message ($(if ($codePath) { "VS Code was found on PATH." } else { "VS Code is optional, but useful for opening the repo from Windows." })) -Required:$false -Details @{ path = $codePath })
    )

    $report = [pscustomobject]@{
        generated_at = (Get-Date).ToString("o")
        repo_root = Get-RepositoryRoot
        host_platform = "windows"
        runtime_boundary = [pscustomobject]@{
            windows_host = "PowerShell orchestration, reports, and user entrypoints"
            wsl_runtime = "Python, make, pytest, and Linux-only tooling"
            containers = "Optional synthetic service for local health checks"
        }
        overall_status = Get-OverallStatus -Checks $checks
        checks = $checks
        remediation = @(
            "Run .\scripts\Test-HostPrereqs.ps1 after each host change.",
            "Use .\scripts\New-LabEnv.ps1 to create repo-local config files without overwriting existing ones.",
            "Use WSL Ubuntu for Linux-only tooling and Docker Desktop for the synthetic container demo."
        )
    }

    return $report
}

function Initialize-LabScaffold {
    [CmdletBinding()]
    param(
        [string]$RootPath = (Get-RepositoryRoot)
    )

    $operations = New-Object System.Collections.Generic.List[object]
    $directories = @(
        "artifacts",
        "artifacts\logs",
        "configs",
        "inventory",
        "labs",
        "labs\future-01",
        "playbooks",
        "topologies"
    )

    foreach ($directory in $directories) {
        $fullPath = Join-Path $RootPath $directory
        $created = Initialize-Directory -Path $fullPath
        $operations.Add([pscustomobject]@{
            Path = $fullPath
            Kind = "directory"
            Action = if ($created) { "created" } else { "exists" }
            Message = "Directory is ready."
        })
    }

    $copyPairs = @(
        @{ Source = ".env.example"; Destination = ".env.local" },
        @{ Source = "configs\lab.config.example.json"; Destination = "configs\lab.config.json" }
    )

    foreach ($pair in $copyPairs) {
        $sourcePath = Join-Path $RootPath $pair.Source
        $destinationPath = Join-Path $RootPath $pair.Destination

        if (-not (Test-Path -LiteralPath $sourcePath)) {
            $operations.Add([pscustomobject]@{
                Path = $destinationPath
                Kind = "file"
                Action = "skipped"
                Message = "Template source '$sourcePath' was not present."
            })
            continue
        }

        if (-not (Test-Path -LiteralPath $destinationPath)) {
            Copy-Item -Path $sourcePath -Destination $destinationPath
            $operations.Add([pscustomobject]@{
                Path = $destinationPath
                Kind = "file"
                Action = "created"
                Message = "Copied from template."
            })
        }
        else {
            $operations.Add([pscustomobject]@{
                Path = $destinationPath
                Kind = "file"
                Action = "exists"
                Message = "Existing local file was left untouched."
            })
        }
    }

    return [pscustomobject]@{
        RootPath = $RootPath
        OverallStatus = "pass"
        Operations = $operations
    }
}

function Test-HttpHealthEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [int]$TimeoutSeconds = 5
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -Method Get -TimeoutSec $TimeoutSeconds
        return [pscustomobject]@{
            Success = $response.StatusCode -eq 200
            StatusCode = $response.StatusCode
            Body = $response.Content
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            StatusCode = $null
            Body = $null
            Error = $_.Exception.Message
        }
    }
}

function Invoke-WslRepoCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [int]$TimeoutSeconds = 180
    )

    $wslState = Get-WslState
    if (-not $wslState.WslPresent -or -not $wslState.UbuntuDistro) {
        throw "An Ubuntu WSL distro is required before running Linux-side commands."
    }

    $rootPath = Get-RepositoryRoot
    $rootPathWsl = Convert-WindowsPathToWsl -WindowsPath $rootPath
    $quotedPath = ConvertTo-BashSingleQuotedString -Value $rootPathWsl
    $fullCommand = "cd $quotedPath && $Command"

    return Invoke-Process -FilePath $wslState.WslCommandPath -Arguments @("-d", $wslState.UbuntuDistro, "--", "bash", "-lc", $fullCommand) -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $rootPath
}

function Write-CheckTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Checks
    )

    $Checks | Select-Object Name, Status, Required, Message | Format-Table -AutoSize
}

Export-ModuleMember -Function @(
    "Convert-WindowsPathToWsl",
    "Initialize-Directory",
    "Get-DefaultLogPath",
    "Get-DockerState",
    "Get-HostPrereqReport",
    "Get-OverallStatus",
    "Get-RepositoryRoot",
    "Get-WslState",
    "Initialize-LabScaffold",
    "Invoke-Process",
    "Invoke-WslRepoCommand",
    "Invoke-WithRetry",
    "New-CheckResult",
    "Resolve-CommandPath",
    "Write-CheckTable",
    "Test-HttpHealthEndpoint",
    "Write-HealthReport",
    "Write-StructuredLog"
)
