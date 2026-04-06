#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers the Gitea act_runner as a Windows service using NSSM.

.DESCRIPTION
    Creates a Windows service for act_runner using NSSM (Non-Sucking Service Manager).
    The runner must already be registered with Gitea before running this script.

.NOTES
    Requires: nssm (installed via Chocolatey in 01-install-base.ps1)
    Idempotent - safe to re-run.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ServiceName = 'act_runner'
$RunnerDir = 'C:\gittogallery\gitea-act_runner'
$RunnerExe = Join-Path $RunnerDir 'act_runner.exe'
$ConfigFile = Join-Path $RunnerDir 'config.yaml'

# Validate prerequisites
if (-not (Get-Command nssm -ErrorAction SilentlyContinue)) {
    throw "NSSM is not installed. Run 01-install-base.ps1 first."
}
if (-not (Test-Path $RunnerExe)) {
    throw "act_runner.exe not found at $RunnerExe. Run 02-download-tools.ps1 first."
}
if (-not (Test-Path $ConfigFile)) {
    throw "config.yaml not found at $ConfigFile. Generate and register the runner first."
}

# Check if service already exists
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Service '$ServiceName' already exists (Status: $($existing.Status)). Skipping install." -ForegroundColor Yellow
    return
}

Write-Host "=== Installing act_runner as a Windows service ===" -ForegroundColor Cyan

# Install the service via NSSM
nssm install $ServiceName $RunnerExe daemon --config $ConfigFile
nssm set $ServiceName AppDirectory $RunnerDir
nssm set $ServiceName DisplayName "Gitea Act Runner"
nssm set $ServiceName Description "Gitea Actions runner for CI/CD pipelines"
nssm set $ServiceName Start SERVICE_AUTO_START
nssm set $ServiceName AppStdout (Join-Path $RunnerDir 'service-stdout.log')
nssm set $ServiceName AppStderr (Join-Path $RunnerDir 'service-stderr.log')
nssm set $ServiceName AppRotateFiles 1
nssm set $ServiceName AppRotateBytes 1048576

Write-Host "Service '$ServiceName' installed. Starting..." -ForegroundColor Green

Start-Service $ServiceName
Get-Service $ServiceName

Write-Host "Done. Verify in Gitea: Site Administration > Runners" -ForegroundColor Cyan
