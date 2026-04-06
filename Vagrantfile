# -*- mode: ruby -*-
# vi: set ft=ruby :

# PSSummit - PowerShell Build Pipeline with Gitea, Gitea Actions, and Nexus
# Usage:
#   vagrant up    # Creates VM, installs choco packages, upgrades to config version 12 + nested virt
#   Then RDP/SSH into the VM and run scripts manually for Docker CE, WSL2, downloads, etc.

NAME = 'gitToGallery'

Vagrant.configure("2") do |config|

  config.vm.box = "gusztavvargadr/windows-server"
  config.vm.provider "hyperv"
  config.vm.network "public_network", bridge: "Default Switch"
  config.vm.hostname = NAME
  config.vm.boot_timeout = 600

  # Disable default synced folder (avoids SMB credential prompts)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "hyperv" do |h|
    h.enable_virtualization_extensions = false
    h.linked_clone = false
    h.memory = 8192
    h.cpus = 2
    h.vmname = NAME
  end

  # Copy scripts to the VM (includes install-docker-ce.ps1)
  config.vm.provision "copy-scripts", type: "file",
    source: "scripts",
    destination: "C:\\gittogallery\\scripts"

  # Copy configs to the VM (includes nginx/, docker/, etc.)
  config.vm.provision "copy-configs", type: "file",
    source: "configs",
    destination: "C:\\gittogallery\\configs"

  # Copy PowerShell modules to the VM (Certificates, etc.)
  config.vm.provision "copy-modules", type: "file",
    source: "module",
    destination: "C:\\gittogallery\\module"

  # Copy docs to the VM (includes README - Next Steps.md for desktop)
  config.vm.provision "copy-docs", type: "file",
    source: "docs",
    destination: "C:\\gittogallery\\docs"

  # Copy certificates to the VM (includes certs needed for Gitea/Nexus)
  config.vm.provision "copy-certs", type: "file",
    source: "certs",
    destination: "C:\\gittogallery\\certs"

  # Install Chocolatey and base packages via script
  config.vm.provision "shell", inline: <<-SHELL
    Set-ExecutionPolicy Bypass -Scope Process -Force
    & "C:/gittogallery/scripts/01-install-base.ps1"
    # Refresh PATH so pwsh child processes see newly-installed tools (git, node, etc.)
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    # Run additional scripts under PowerShell 7
    & "C:/Program Files/PowerShell/7/pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "C:/gittogallery/scripts/02-download-tools.ps1"
    & "C:/Program Files/PowerShell/7/pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "C:/gittogallery/scripts/03-configure-windows.ps1"

    # Drop a README on the vagrant user's desktop
    Copy-Item -Path 'C:\\gittogallery\\docs\\README - Next Steps.md' -Destination 'C:\\Users\\vagrant\\Desktop\\README - Next Steps.md' -Force

  SHELL

  # After VM is up: stop it, upgrade to config version 12, enable nested virtualization, restart
  config.trigger.after :up do |trigger|
    trigger.info = "Upgrading VM to configuration version 12 and enabling nested virtualization..."
    trigger.run = {
      inline: "powershell -Command \"" \
              "$ErrorActionPreference = 'Stop'; " \
              "$vm = Get-VM -Name '#{NAME}' -ErrorAction SilentlyContinue; " \
              "if (-not $vm) { $vm = Get-VM -Name '#{NAME}*' -ErrorAction Stop | Select-Object -First 1 }; " \
              "if (-not $vm) { throw 'VM not found for name #{NAME}' }; " \
              "$vmName = $vm.Name; " \
              "Stop-VM -Name $vmName; " \
              "Update-VMVersion -Name $vmName -Force; " \
              "Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions \$true; " \
              "$proc = Get-VMProcessor -VMName $vmName; " \
              "if (-not $proc.ExposeVirtualizationExtensions) { throw 'Failed to enable ExposeVirtualizationExtensions.' }; " \
              "Start-VM -Name $vmName" \
              "\""
    }
  end

end
