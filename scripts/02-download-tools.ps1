#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Downloads Gitea, act_runner, and Nexus binaries.

.DESCRIPTION
    Creates the directory structure and downloads tool binaries.
    Idempotent - skips downloads if files already exist.

.NOTES
    Run during Vagrant provisioning (Phase 1).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Downloading tools ===" -ForegroundColor Cyan

# Tool definitions
$tools = @(
    @{
        Name    = 'Gitea'
        Uri     = 'https://dl.gitea.com/gitea/1.25.5/gitea-1.25.5-gogit-windows-4.0-amd64.exe'
        OutDir  = 'c:\gittogallery\gitea-server'
        OutFile = 'gitea.exe'
    }
    @{
        Name    = 'act_runner'
        Uri     = 'https://dl.gitea.com/act_runner/0.3.0/act_runner-0.3.0-windows-amd64.exe'
        OutDir  = 'c:\gittogallery\gitea-act_runner'
        OutFile = 'act_runner.exe'
    }
    @{
        Name    = 'Nexus'
        Uri     = 'https://links.sonatype.com/products/nxrm3/download-win-x86'
        OutDir  = 'c:\gittogallery\nexus'
        OutFile = 'nexus.zip'
    }
)

foreach ($tool in $tools) {
    $outPath = Join-Path $tool.OutDir $tool.OutFile

    # Create directory
    if (-not (Test-Path $tool.OutDir)) {
        Write-Host "Creating directory: $($tool.OutDir)" -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $tool.OutDir | Out-Null
    }

    # Download if not present
    if (-not (Test-Path $outPath)) {
        Write-Host "Downloading $($tool.Name) from $($tool.Uri)..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $tool.Uri -OutFile $outPath -UseBasicParsing
            Write-Host "  -> Saved to $outPath" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to download $($tool.Name): $_"
        }
    }
    else {
        Write-Host "$($tool.Name) already downloaded at $outPath" -ForegroundColor Green
    }
}

# Unzip Nexus if not already extracted
$nexusZip = 'c:\gittogallery\nexus\nexus.zip'
if (Test-Path $nexusZip) {
    Write-Host "Extracting Nexus..." -ForegroundColor Yellow
    Expand-Archive -Path $nexusZip -DestinationPath 'c:\gittogallery\nexus' -Force
    Write-Host "  -> Extracted to c:\gittogallery\nexus" -ForegroundColor Green
}

Write-Host "=== Tool downloads complete ===" -ForegroundColor Green
