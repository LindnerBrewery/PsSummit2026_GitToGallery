$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Find newest powershell release
$releases = "https://api.github.com/repos/PowerShell/powershell/releases/latest"
$latest = Invoke-RestMethod $releases
$asset = $latest.assets | Where-Object Name -Like "*win-x64.zip"
 
# Using IWR is slow under PS 5
# Invoke-WebRequest -Uri  $asset.browser_download_url -OutFile PowerShell-Win64.zip -UseBasicParsing

Write-Output "Downloading Powershell"
# Create the new WebClient
$webClient = [System.Net.WebClient]::new()
# Download the file
$webClient.DownloadFile($asset.browser_download_url, "PowerShell-Win64.zip")


Write-Output "Expanding Powershell"
Expand-Archive -Path PowerShell-Win64.zip -DestinationPath $env:ProgramData\pwsh
Remove-Item -Force PowerShell-Win64.zip

$newPath = "$env:ProgramData\pwsh;" + [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)