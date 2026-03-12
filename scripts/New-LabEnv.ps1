[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "WinNetlab.Foundation.psm1") -Force

$logPath = Get-DefaultLogPath
Write-StructuredLog -Action "lab.init" -Message "Preparing repo-local lab scaffold." -LogPath $logPath

$result = Initialize-LabScaffold
$result.Operations | Format-Table -AutoSize

Write-StructuredLog -Action "lab.init" -Message "Repo-local lab scaffold is ready." -LogPath $logPath -Details @{
    root = $result.RootPath
    operation_count = $result.Operations.Count
}

Write-Host "Rollback note: remove .env.local and configs/lab.config.json if you want to return to template-only state."

