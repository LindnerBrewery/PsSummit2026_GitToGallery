#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures Windows baseline policies for the GitToGallery VM.

.DESCRIPTION
    Phase 7 provisioning script.
    - Disables Microsoft Edge first-run experience prompts.
    - Shows file extensions and hidden folders in Explorer.
    - Prepares firewall rule definitions for session services.
    - Optionally applies firewall rules when -ApplyFirewallRules is specified.

.NOTES
    Idempotent - safe to re-run.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 7: Configuring Windows ===" -ForegroundColor Cyan

function Set-EdgeFirstRunPolicies {
    [CmdletBinding()]
    param()

    Write-Host "Configuring Edge first-run policies..." -ForegroundColor Yellow

    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name "HideFirstRunExperience" -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $path -Name "SuppressFirstRunDefaultBrowserPrompt" -PropertyType DWord -Value 1 -Force | Out-Null

    Write-Host "  -> Edge first-run policies configured" -ForegroundColor Green
}

function Set-ExplorerViewOptions {
    [CmdletBinding()]
    param()

    Write-Host "Configuring Explorer view options..." -ForegroundColor Yellow

    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name 'HideFileExt' -PropertyType DWord -Value 0 -Force | Out-Null
    New-ItemProperty -Path $path -Name 'Hidden' -PropertyType DWord -Value 1 -Force | Out-Null
    Stop-Process -Name explorer
    Start-Process explorer
    Write-Host "  -> Explorer configured to show file extensions and hidden folders" -ForegroundColor Green
}

function Get-FirewallRuleDefinitions {
    [CmdletBinding()]
    param()

    @(
        @{
            DisplayName = 'GitToGallery - HTTP (80)'
            Direction   = 'Inbound'
            Protocol    = 'TCP'
            LocalPort   = '80'
            Action      = 'Allow'
            Profile     = 'Any'
            Description = 'Allow HTTP traffic for nginx.'
        }
        @{
            DisplayName = 'GitToGallery - HTTPS (443)'
            Direction   = 'Inbound'
            Protocol    = 'TCP'
            LocalPort   = '443'
            Action      = 'Allow'
            Profile     = 'Any'
            Description = 'Allow HTTPS traffic for nginx.'
        }
        @{
            DisplayName = 'GitToGallery - Gitea (4443)'
            Direction   = 'Inbound'
            Protocol    = 'TCP'
            LocalPort   = '4443'
            Action      = 'Allow'
            Profile     = 'Any'
            Description = 'Allow Gitea web traffic.'
        }
        @{
            DisplayName = 'GitToGallery - Nexus (8443)'
            Direction   = 'Inbound'
            Protocol    = 'TCP'
            LocalPort   = '8443'
            Action      = 'Allow'
            Profile     = 'Any'
            Description = 'Allow Nexus web traffic.'
        }
    )
}

function Set-FirewallRuleIfMissing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Rule
    )

    $existingRule = Get-NetFirewallRule -DisplayName $Rule.DisplayName -ErrorAction SilentlyContinue

    if ($existingRule) {
        Write-Host "  -> Firewall rule already exists: $($Rule.DisplayName)" -ForegroundColor Green
        return
    }

    New-NetFirewallRule `
        -DisplayName $Rule.DisplayName `
        -Direction $Rule.Direction `
        -Protocol $Rule.Protocol `
        -LocalPort $Rule.LocalPort `
        -Action $Rule.Action `
        -Profile $Rule.Profile `
        -Description $Rule.Description | Out-Null

    Write-Host "  -> Firewall rule created: $($Rule.DisplayName)" -ForegroundColor Green
}

Set-EdgeFirstRunPolicies
Set-ExplorerViewOptions

$firewallRules = Get-FirewallRuleDefinitions

Write-Host "Preparing firewall rule definitions..." -ForegroundColor Yellow
$firewallRules |
Select-Object DisplayName, LocalPort, Protocol, Direction, Action |
Format-Table -AutoSize


Write-Host "Applying firewall rules..." -ForegroundColor Yellow
foreach ($rule in $firewallRules) {
    Set-FirewallRuleIfMissing -Rule $rule
}
Write-Host "  -> Firewall rules applied" -ForegroundColor Green

Write-Host "  -> Configure git" -ForegroundColor Yellow
git config --global user.email "powershelltalks+sam.sungk@gmail.com"
git config --global user.name "Sam Sung"
git config --global credential.https://gittogallery:4443.provider generic # this will allow git to use the Windows Credential Manager for authentication when pushing.

Write-Host "  -> Configure PowerShell Gallery repository" -ForegroundColor Yellow


Write-Host "=== Phase 7 complete ===" -ForegroundColor Green
