#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs WSL2, Ubuntu, Docker, and PowerShell inside WSL for the Linux act_runner.

.DESCRIPTION
    Phase 2 provisioning script. Requires nested virtualization to be enabled
    (VM version upgraded + ExposeVirtualizationExtensions).

    Installs:
    - WSL2 with Ubuntu distribution
    - Docker Engine inside Ubuntu WSL
    - PowerShell for Linux

.NOTES
    Run as Phase 2: vagrant provision --provision-with phase2-wsl
    Requires VM reboot after Phase 1 and nested virtualization enabled.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 2: Installing WSL2 + Ubuntu + Docker + PowerShell ===" -ForegroundColor Cyan

# Verify required Windows features are enabled
Write-Host 'Checking required Windows features...' -ForegroundColor Cyan
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -ErrorAction SilentlyContinue
$vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -ErrorAction SilentlyContinue

if ((-not $wslFeature) -or ($wslFeature.State -ne 'Enabled') -or (-not $vmPlatform) -or ($vmPlatform.State -ne 'Enabled')) {
    Write-Error @"
Required Windows features are not enabled.

To enable them, run these commands and reboot:

  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
  Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
  Restart-Computer -Force

Note: C:\gittogallery\scripts\04-install-docker.ps1 automatically installs these features before its reboot.
If you ran 04-install-docker.ps1 and rebooted, these features should already be enabled.

Current state:
  Microsoft-Windows-Subsystem-Linux: $($wslFeature.State)
  VirtualMachinePlatform: $($vmPlatform.State)
"@
    exit 1
}

Write-Host 'Required Windows features are enabled.' -ForegroundColor Green

# Install WSL
Write-Host "Installing WSL..." -ForegroundColor Yellow
wsl --install --no-distribution 2>&1

# Set WSL2 as default
Write-Host "Setting WSL2 as default version..." -ForegroundColor Yellow
wsl --set-default-version 2 2>&1

# Install Ubuntu
Write-Host "Installing Ubuntu distribution..." -ForegroundColor Yellow
wsl --install -d Ubuntu --no-launch 2>&1

# Wait for Ubuntu to be available
Start-Sleep -Seconds 10

# Create default user with password
Write-Host "Creating default user 'vagrant' in Ubuntu..." -ForegroundColor Yellow
$userSetup = "useradd -m -s /bin/bash vagrant && echo 'vagrant:vagrant' | chpasswd && usermod -aG sudo vagrant && echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant"
wsl -d Ubuntu -u root -- bash -c $userSetup

# Set vagrant as default user and enable systemd via wsl.conf
Write-Host "Setting default user to 'vagrant' and enabling systemd..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash -c 'echo -e "[user]\ndefault=vagrant\n\n[boot]\nsystemd=true" > /etc/wsl.conf'

# Shutdown and restart WSL to apply wsl.conf changes
Write-Host "Restarting WSL to apply configuration..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 5

# Initialize Ubuntu and install Docker
Write-Host "Setting up Docker inside WSL Ubuntu..." -ForegroundColor Yellow

# Clean up any previous failed installation attempts
Write-Host "Cleaning up previous installation attempts..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash -c 'rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/sources.list.d/docker.list'

Write-Host "Running Docker installation script..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash /mnt/c/gittogallery/scripts/install-docker-wsl.sh

Write-Host "Enabling Docker and containerd to start on boot..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash -c 'systemctl enable docker containerd'

Write-Host "Running PowerShell installation script..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash /mnt/c/gittogallery/scripts/install-powershell-wsl.sh

Write-Host "Running WSL tools installation script (lazydocker, Microsoft Edit)..." -ForegroundColor Yellow
wsl -d Ubuntu -u root -- bash /mnt/c/gittogallery/scripts/install-wsl-tools.sh

Write-Host "=== Phase 2: WSL2 + Ubuntu complete + Docker + PowerShell ===" -ForegroundColor Green
Write-Host "To verify Docker: wsl -d Ubuntu -- docker version" -ForegroundColor Cyan
Write-Host "To verify PowerShell: wsl -d Ubuntu -- pwsh --version" -ForegroundColor Cyan
Write-Host "Default user: vagrant (password: vagrant)" -ForegroundColor Cyan
