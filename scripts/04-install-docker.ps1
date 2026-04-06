#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Windows Containers feature, Docker CE, and Docker Compose.

.DESCRIPTION
    Single-entry script for Windows container runtime setup.
    It installs the Windows Containers feature, schedules itself to resume
    automatically after reboot when required, installs Docker CE, runs the
    Docker Compose installer script, and then removes bootstrap scheduled tasks.

.NOTES
    Run manually inside the VM:
      C:\gittogallery\scripts\04-install-docker.ps1
#>

[CmdletBinding()]
param(
    [string]
    $ComposeVersion = '2.32.4',

    [string]
    $ResumeUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [switch]
    $EnableAutoLogon,

    [string]
    $AutoLogonUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [string]
    $AutoLogonPassword,

    [string]
    $AutoLogonDomain = $env:COMPUTERNAME
)

$ErrorActionPreference = 'Stop'

$taskName = 'GitToGallery-DockerBootstrap'
$legacyTaskName = 'ContainerBootstrap'
$scriptPath = $PSCommandPath
if (-not $scriptPath) {
    $scriptPath = 'C:\gittogallery\scripts\04-install-docker.ps1'
}

function Remove-TaskIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-Host "Removing scheduled task: $TaskName" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

function Enable-LabAutoLogon {
    param(
        [Parameter(Mandatory = $true)]
        [string]$User,
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )

    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $policyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    $resolvedUser = $User
    $resolvedDomain = $Domain

    if ($resolvedUser -match '^(?<domain>[^\\]+)\\(?<name>.+)$') {
        $resolvedDomain = $Matches.domain
        $resolvedUser = $Matches.name
    }
    elseif ($resolvedUser -match '^(?<name>[^@]+)@(?<domain>.+)$') {
        $resolvedUser = $Matches.name
        $resolvedDomain = $Matches.domain
    }

    Write-Warning 'Auto-logon stores credentials in registry and is intended only for disposable lab VMs.'
    Write-Host "Configuring AutoAdminLogon for $resolvedDomain\$resolvedUser" -ForegroundColor Yellow

    Set-ItemProperty -Path $winlogonPath -Name 'AutoAdminLogon' -Value '1' -Type String
    Set-ItemProperty -Path $winlogonPath -Name 'ForceAutoLogon' -Value '1' -Type String
    Set-ItemProperty -Path $winlogonPath -Name 'AutoLogonCount' -Value '1' -Type DWord
    Set-ItemProperty -Path $winlogonPath -Name 'DefaultUserName' -Value $resolvedUser -Type String
    Set-ItemProperty -Path $winlogonPath -Name 'DefaultPassword' -Value $Password -Type String
    Set-ItemProperty -Path $winlogonPath -Name 'DefaultDomainName' -Value $resolvedDomain -Type String

    if (Test-Path $policyPath) {
        Set-ItemProperty -Path $policyPath -Name 'DisableCAD' -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $policyPath -Name 'dontdisplaylastusername' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $policyPath -Name 'legalnoticecaption' -Value '' -Type String -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $policyPath -Name 'legalnoticetext' -Value '' -Type String -ErrorAction SilentlyContinue
    }

    Write-Host 'Auto-logon registry settings applied for next reboot.' -ForegroundColor Green
}

function Disable-LabAutoLogon {
    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    Write-Host 'Disabling AutoAdminLogon...' -ForegroundColor Yellow

    Set-ItemProperty -Path $winlogonPath -Name 'AutoAdminLogon' -Value '0' -Type String -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $winlogonPath -Name 'ForceAutoLogon' -Value '0' -Type String -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name 'AutoLogonCount' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name 'DefaultPassword' -ErrorAction SilentlyContinue

    Write-Host 'Auto-logon disabled.' -ForegroundColor Green
}

function Register-ResumeTask {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$RunAsUser
    )

    Remove-TaskIfExists -TaskName $taskName

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        throw 'PowerShell 7 (pwsh) was not found. Install pwsh before scheduling reboot resume.'
    }

    $pwshPath = $pwshCommand.Source
    $escapedPath = $Path.Replace('"', '""')
    $escapedVersion = $Version.Replace('"', '""')
    $escapedUser = $RunAsUser.Replace('"', '""')
    $arguments = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$escapedPath`" -ComposeVersion `"$escapedVersion`" -ResumeUser `"$escapedUser`""

    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $RunAsUser
    $principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    Write-Host "Registering scheduled task '$taskName' to resume after reboot as $RunAsUser using pwsh..." -ForegroundColor Yellow
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
}

Write-Host "=== Installing Windows Containers feature + Docker CE + Docker Compose ===" -ForegroundColor Cyan

if (-not $EnableAutoLogon) {
    Disable-LabAutoLogon
}

# Pre-install WSL features alongside Containers feature to save a second reboot
# This prepares the VM for WSL2 setup (05-install-wsl2.ps1) which requires these features
Write-Host 'Pre-installing WSL features (for future WSL2 setup)...' -ForegroundColor Cyan
try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -ErrorAction SilentlyContinue
    if ($wslFeature -and $wslFeature.State -ne 'Enabled') {
        Write-Host '  - Enabling Microsoft-Windows-Subsystem-Linux' -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart | Out-Null
    }
    
    $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -ErrorAction SilentlyContinue
    if ($vmPlatform -and $vmPlatform.State -ne 'Enabled') {
        Write-Host '  - Enabling VirtualMachinePlatform' -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -All -NoRestart | Out-Null
    }
    
    Write-Host 'WSL features queued for installation (will activate after reboot).' -ForegroundColor Green
}
catch {
    Write-Warning "Could not enable WSL features: $_. You may need to run 05-install-wsl2.ps1 twice (once to enable features, reboot, then again)."
}

$feature = Get-WindowsFeature -Name Containers -ErrorAction SilentlyContinue

if (-not $feature) {
    Write-Warning "Unable to query Windows Containers feature. Ensure ServerManager module is available."
    exit 1
}

if (-not $feature.Installed) {
    Write-Host "Installing Windows Containers feature..." -ForegroundColor Yellow
    $result = Install-WindowsFeature -Name Containers -IncludeManagementTools

    if (-not $result.Success) {
        Write-Warning 'Containers feature installation failed.'
        exit 1
    }

    if ($result.RestartNeeded -eq 'Yes') {
        Write-Host 'Containers feature requires reboot. Scheduling automatic resume...' -ForegroundColor Yellow
        Register-ResumeTask -Path $scriptPath -Version $ComposeVersion -RunAsUser $ResumeUser

        if ($EnableAutoLogon) {
            if ([string]::IsNullOrWhiteSpace($AutoLogonPassword)) {
                Write-Warning 'EnableAutoLogon was specified but AutoLogonPassword was not provided. Skipping auto-logon configuration.'
            }
            else {
                $effectiveAutoLogonUser = $AutoLogonUser
                if ([string]::IsNullOrWhiteSpace($effectiveAutoLogonUser)) {
                    $effectiveAutoLogonUser = $ResumeUser
                }

                Enable-LabAutoLogon -User $effectiveAutoLogonUser -Password $AutoLogonPassword -Domain $AutoLogonDomain
            }
        }
        else {
            Write-Host 'Auto-logon is disabled. After reboot, sign in (Enhanced Session is fine) and the scheduled task will continue in a visible PowerShell 7 window.' -ForegroundColor Yellow
        }

        Write-Host 'Restarting computer now...' -ForegroundColor Yellow
        Restart-Computer -Force
        exit 0
    }
}

Write-Host 'Containers feature is installed.' -ForegroundColor Green

$dockerInstallerPath = 'C:\gittogallery\scripts\install-docker-ce.ps1'
if (-not (Test-Path $dockerInstallerPath)) {
    Write-Warning "install-docker-ce.ps1 not found at $dockerInstallerPath"
    exit 1
}

if (Get-Service docker -ErrorAction SilentlyContinue) {
    Write-Host 'Docker service already exists.' -ForegroundColor Green
} else {
    Write-Host 'Running install-docker-ce.ps1 -NoRestart...' -ForegroundColor Yellow
    & $dockerInstallerPath -NoRestart
}

if (Get-Service docker -ErrorAction SilentlyContinue) {
    Write-Host 'Docker installed successfully.' -ForegroundColor Green
} else {
    Write-Warning 'Docker service not found after installation. A reboot may be required.'
    exit 1
}

$composeInstallerPath = 'C:\gittogallery\scripts\install-docker-compose.ps1'
if (-not (Test-Path $composeInstallerPath)) {
    Write-Warning "install-docker-compose.ps1 not found at $composeInstallerPath"
    exit 1
}

Write-Host 'Running Docker Compose installer (install-docker-compose.ps1)...' -ForegroundColor Yellow
& $composeInstallerPath -ComposeVersion $ComposeVersion

Remove-TaskIfExists -TaskName $taskName
Remove-TaskIfExists -TaskName $legacyTaskName
Disable-LabAutoLogon

Write-Host 'Validating Docker and Compose versions...' -ForegroundColor Cyan
docker version
docker compose version

Write-Host '=== Docker stack install complete ===' -ForegroundColor Green
