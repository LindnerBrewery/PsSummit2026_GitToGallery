#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs base software via Chocolatey for the PSSummit Gitea Pipeline demo.

.DESCRIPTION
    Phase 1 provisioning script. Installs:
    - Chocolatey package manager
    - PowerShell 7 (pwsh)
    - VS Code + PowerShell extension
    - Git
    - Node.js
    - nginx
    - nssm (service manager for Gitea/Nexus)
    - NuGet CLI (for pushing packages to Nexus)

.NOTES
    Run during Vagrant provisioning. Idempotent - safe to re-run.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 1: Installing base software ===" -ForegroundColor Cyan

# Install Chocolatey if not present
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

# Install packages
$packages = @(
    'powershell-core'
    'vscode'
    'vscode-powershell'
    'git'
    'nodejs'
    'nginx'
    'edit'
    'nuget.commandline'
)

foreach ($pkg in $packages) {
    Write-Host "Installing $pkg..." -ForegroundColor Yellow
    choco install $pkg -y --no-progress
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "choco install $pkg exited with code $LASTEXITCODE (may already be installed)"
    }
}

Write-Host "=== Phase 1 complete ===" -ForegroundColor Green
