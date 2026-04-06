#!/bin/bash
set -e

echo "Installing PowerShell in WSL Ubuntu..."

# Update package lists
apt-get update -qq

# Install prerequisites
apt-get install -y wget apt-transport-https software-properties-common

# Get Ubuntu version
source /etc/os-release

# Download and install Microsoft repository GPG key
wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
rm -f packages-microsoft-prod.deb

# Update package lists after adding Microsoft repository
apt-get update -qq

# Install PowerShell
apt-get install -y powershell

echo "PowerShell installation complete!"
pwsh --version
