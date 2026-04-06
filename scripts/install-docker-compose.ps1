#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Docker Compose for Docker CE on Windows.

.DESCRIPTION
    Downloads the Docker Compose CLI plugin and places it in the
    Docker plugins directory so it can be used as 'docker compose'.

    Requires Docker CE to be installed first (04-install-docker.ps1).

.NOTES
    Called automatically by C:\gittogallery\scripts\04-install-docker.ps1.
#>

[CmdletBinding()]
param(
    [string]
    $ComposeVersion = '2.32.4'
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Installing Docker Compose ===" -ForegroundColor Cyan

function Test-DockerCompose {
    try {
        docker compose version *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

# Verify Docker is installed
if (-not (Get-Service docker -ErrorAction SilentlyContinue)) {
    Write-Warning "Docker service not found. Install Docker CE first (C:\gittogallery\scripts\04-install-docker.ps1)."
    exit 1
}

# If Docker Compose is already available, exit successfully
if (Test-DockerCompose) {
    Write-Host 'Docker Compose is already available.' -ForegroundColor Green
    docker compose version
    exit 0
}

$pluginDirs = @(
    "$env:ProgramFiles\Docker\cli-plugins",
    "$env:ProgramData\docker\cli-plugins"
) | Select-Object -Unique

$composeExeName = 'docker-compose.exe'
$tempComposePath = Join-Path $env:TEMP "docker-compose-v${ComposeVersion}.exe"

foreach ($pluginDir in $pluginDirs) {
    if (-not (Test-Path $pluginDir)) {
        Write-Host "Creating plugin directory: $pluginDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
    }
}

# Download Docker Compose
$uri = "https://github.com/docker/compose/releases/download/v${ComposeVersion}/docker-compose-windows-x86_64.exe"
Write-Host "Downloading Docker Compose v${ComposeVersion}..." -ForegroundColor Yellow
Write-Host "  URI: $uri" -ForegroundColor Gray

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-WebRequest -Uri $uri -OutFile $tempComposePath -UseBasicParsing
    Write-Host "  -> Saved to $tempComposePath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download Docker Compose: $_"
    exit 1
}

foreach ($pluginDir in $pluginDirs) {
    $composePath = Join-Path $pluginDir $composeExeName
    Copy-Item -Path $tempComposePath -Destination $composePath -Force
    Write-Host "Installed Docker Compose plugin to: $composePath" -ForegroundColor Green
}

if (Test-Path $tempComposePath) {
    Remove-Item $tempComposePath -Force -ErrorAction SilentlyContinue
}

# Verify
Write-Host ""
if (-not (Test-DockerCompose)) {
    Write-Warning 'Docker Compose plugin was installed, but docker compose is still unavailable.'
    Write-Warning 'Try opening a new PowerShell session and run: docker compose version'
    exit 1
}

docker compose version

Write-Host "=== Docker Compose installed ===" -ForegroundColor Green
