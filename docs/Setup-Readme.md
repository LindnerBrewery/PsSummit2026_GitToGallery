# PSSummit: PowerShell Build Pipeline with Gitea, Gitea Actions & Nexus

Step-by-step setup guide for participants to prepare their environment and follow along with the walkthrough during the talk.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Windows Server VM (gittogallery)                       │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │  Gitea   │  │  Nexus   │  │  nginx   │               │
│  │ :3000    │  │ :8081    │  │  :4443   │               │
│  │          │  │          │  │  :8443   │               │
│  └──────────┘  └──────────┘  └──────────┘               │
│                                                         │
│  ┌─────────────────────┐  ┌─────────────────────────┐   │
│  │ Windows act_runner  │  │  WSL2 Ubuntu            │   │
│  │ (Docker CE)         │  │  ┌───────────────────┐  │   │
│  │ Windows containers  │  │  │ Linux act_runner  │  │   │
│  │                     │  │  │ (Docker Engine)   │  │   │
│  │                     │  │  │ Linux containers  │  │   │
│  └─────────────────────┘  │  └───────────────────┘  │   │
│                           └─────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 1. Clone the Repository

Clone the repository to your local machine:

## 2. Prepare a Virtual Machine

You need a **Windows Server 2025** VM with the following minimum specifications:

| Resource | Minimum | Recommended |
|---------- | --------- | ------------- |
| CPUs | 2 | 4 |
| RAM | 8 GB | 16 GB |
| Disk | 60 GB | 100 GB |

You can use any of the following hypervisors:

- **Hyper-V** (recommended — required for Vagrant path)
- **VMware Workstation / Fusion**
- **VirtualBox** (see nested virtualization note below)

### VM Naming — Important

> **Name your VM `gittogallery`.**
>
> Pre-built TLS certificates in the `certs/` folder are issued for `gittogallery` and `gittogallery.mshome.net`.
> Using this exact hostname lets you skip manual certificate creation and simplifies the setup significantly.

## 3. Enable Virtualization Features

Docker and WSL both require virtualization support inside the VM (nested virtualization):

| Hypervisor | How to enable nested virtualization |
|------------|-------------------------------------|
| **Hyper-V** | See the Vagrant path below — the `Vagrantfile` enables it automatically |
| **VMware** | Enable *Virtualize Intel VT-x/EPT* or *Virtualize AMD-V/RVI* in VM settings |
| **VirtualBox** | Not supported — use a different hypervisor if you need WSL2/Docker |

## 4. Setup — Option A: Vagrant + Hyper-V (Recommended)

If you have Hyper-V available, Vagrant automates the entire VM creation and software installation.

### Prerequisites

1. **Vagrant** (2.3+): https://www.vagrantup.com/downloads
2. **Hyper-V** enabled on your Windows host
3. Add your user to the Hyper-V Administrators group:
   ```powershell
   Add-LocalGroupMember -Group 'Hyper-V Administrators' -Member $env:USERNAME
   # Log out and back in for the change to take effect
   ```

### Step 1: Create the VM

```powershell
cd <path to repo>\gittogallery
vagrant up
```

This will:
- Create a Windows Server VM on Hyper-V (8 GB RAM, 2 CPUs, hostname `gittogallery`)
- Copy scripts, configs, modules, docs, and certificates to the VM
- Install base tools via `01-install-base.ps1` (Chocolatey, PowerShell 7, Git, VS Code, nginx, etc.)
- Download Gitea, act_runner, and Nexus binaries via `02-download-tools.ps1`
- Apply Windows defaults via `03-configure-windows.ps1`
- After provisioning: stop the VM, upgrade to Hyper-V config version 12, enable nested virtualization, and restart

**Expected duration**: ~15–20 minutes

### Step 2: Run the remaining scripts inside the VM

```powershell
vagrant rdp   # or: vagrant powershell
```

Once connected, run in order: 

> This step can take up to 20min

```powershell
# Install Windows Containers feature + Docker CE + Docker Compose
# Handles the required reboot and resumes automatically via a scheduled task
C:\gittogallery\scripts\04-install-docker.ps1

# After 04 finishes and reboots, log back in and run:
# Install WSL2 + Ubuntu + Docker Engine inside WSL
C:\gittogallery\scripts\05-install-wsl2.ps1
```

## 5. Setup — Option B: Manual VM (Without Vagrant)

If you are not using Hyper-V, create a Windows Server 2025 VM manually with nested virtualization enabled, then follow these steps. Copy the repository to `C:\gittogallery\` on the VM, or copy individual folders as needed.

> Follow the same provisioning sequence described in the `Vagrantfile` — the numbered scripts match the Vagrant provisioning steps exactly.

Run these scripts **in order** from an elevated PowerShell 7 prompt:

```powershell
# 1. Chocolatey + base tools (PowerShell 7, Git, VS Code, nginx, etc.)
C:\gittogallery\scripts\01-install-base.ps1

# 2. Download Gitea, act_runner, and Nexus binaries
C:\gittogallery\scripts\02-download-tools.ps1

# 3. Windows defaults: Edge first-run policy, Explorer view options, firewall prep
C:\gittogallery\scripts\03-configure-windows.ps1

# 4. Windows Containers feature + Docker CE + Docker Compose
#    Handles the required reboot automatically via a scheduled task
C:\gittogallery\scripts\04-install-docker.ps1

# 5. After 04 finishes and reboots, log back in and run:
#    WSL2 + Ubuntu + Docker Engine inside WSL + PowerShell for Linux
C:\gittogallery\scripts\05-install-wsl2.ps1
```

## 6. (Optional) Pre-download Docker Images

This step is optional. If you want to experiment with the Docker-based act runners before the talk, pre-pull the images now to save time later.

**Linux act runner (runs inside WSL Docker):**
```bash
# Run inside WSL Ubuntu ~240 MB
docker pull macinally/act_runner:latest
```

**Windows act runner (runs in Windows Docker CE):**
```powershell
# Run on the Windows host (Docker CE, Windows containers mode) ~6 GB
docker pull macinally/act_runner:windows-ltsc
```

## 7. LDAP Image (Required)

The demo uses **lldap** as a lightweight Active Directory mock. Pull the image in advance:

```bash
# Run inside WSL Ubuntu ~26 MB
docker pull lldap/lldap:stable
```

The lldap service definition is in `configs/docker/lldap/docker-compose.yml`. Start it with:

```bash
# From WSL, navigate to the lldap folder and start the service
cd /mnt/c/gittogallery/configs/docker/lldap
docker compose up -d
# Access UI at http://localhost:17170  (admin / test123!)
```

## Verification

Run these checks inside the VM after setup completes:

```powershell
# Base tools
choco --version
pwsh --version
git --version
node --version

# Docker (Windows containers)
docker version

# WSL2 + Linux Docker
wsl --list --verbose
wsl -d Ubuntu -u root -- docker version

# Tool binaries
Test-Path C:\gittogallery\gitea-server\gitea.exe
Test-Path C:\gittogallery\gitea-act_runner\act_runner.exe
Test-Path C:\gittogallery\nexus\nexus.zip
```

## File Structure

```
gittogallery/
├── Vagrantfile
├── certs/
│   ├── rootCA.pem / rootCA.pfx    # Pre-built root CA (hostname: gittogallery)
│   ├── Server.pem / Server.key    # Server cert + key for nginx
│   └── Server.pfx
├── scripts/
│   ├── 01-install-base.ps1                       # Chocolatey + base tools
│   ├── 02-download-tools.ps1                     # Download Gitea, act_runner, Nexus
│   ├── 03-configure-windows.ps1                  # Edge policy, Explorer, firewall prep
│   ├── 04-install-docker.ps1                     # Containers feature + Docker CE + Compose
│   ├── 05-install-wsl2.ps1                       # WSL2 + Ubuntu + Docker + PowerShell
│   ├── Install-ActRunnerService.ps1              # Register act_runner as Windows service
│   ├── Install-rootCA-to-wsl-ca-certificates.ps1 # Import root CA into WSL Ubuntu CA store
│   ├── Setup-WSLPortForwarding.ps1               # netsh portproxy for WSL-hosted services
│   ├── install-docker-ce.ps1                     # Docker CE installer (called by 04)
│   ├── install-docker-compose.ps1                # Docker Compose plugin (called by 04)
│   ├── install-docker-wsl.sh                     # Docker Engine installer for WSL Ubuntu
│   ├── install-powershell-wsl.sh                 # PowerShell installer for WSL Ubuntu
│   └── install-wsl-tools.sh                      # lazydocker + Microsoft Edit for WSL
├── configs/
│   ├── nginx/                     # nginx.conf + conf.d/ (gitea_4443, nexus_8443)
│   ├── gitea/custom/options/      # Custom .gitignore and README templates
│   ├── custom/                    # Gitea landing page templates + CSS/assets
│   └── docker/
│       ├── lldap/                 # lldap LDAP mock (docker-compose.yml)
│       ├── linux_act_runner/      # Linux act runner (Docker Compose, Dockerfile)
│       └── windows_act_runner/    # Windows act runner (Docker Compose, Dockerfile)
├── module/
│   └── Certificates/              # PowerShell module for TLS certificate management
└── docs/
    ├── Demo-Walkthrough.ps1       # Executable walkthrough script (runnable step-by-step)
    ├── Demo-Walkthrough.md        # Same walkthrough in readable Markdown
    ├── Setup-Readme.md            # This file
    └── extras/
        └── docker-WSL-port-forwarding.md
```

## Troubleshooting

### Nested virtualization not enabled

WSL2 and Docker CE both require nested virtualization inside the VM.

**Hyper-V (check on the host, not inside the VM):**
```powershell
Get-VMProcessor -VMName gittogallery | Select-Object ExposeVirtualizationExtensions
# Should show: ExposeVirtualizationExtensions : True
```

The Vagrantfile enables this automatically after `vagrant up`. If it shows `False`, run on the host:
```powershell
Stop-VM -Name gittogallery
Set-VMProcessor -VMName gittogallery -ExposeVirtualizationExtensions $true
Start-VM -Name gittogallery
```

**VMware:** Enable *Virtualize Intel VT-x/EPT* or *Virtualize AMD-V/RVI* in VM settings.

**VirtualBox:** Nested virtualization is not supported — switch to Hyper-V or VMware.

### VM enters "stopping" state on startup (Vagrant only)

The Hyper-V configuration version is too old. Destroy and recreate:
```powershell
vagrant destroy -f
vagrant up
```

### Docker CE install fails

Ensure the Windows Containers feature is installed and the VM has been rebooted:
```powershell
Get-WindowsFeature Containers
# If not installed, re-run C:\gittogallery\scripts\04-install-docker.ps1
```

### WSL2 install fails with "ERROR_NOT_SUPPORTED"

Nested virtualization is not active or the required Windows features are missing.

1. Verify nested virtualization is enabled (see above)
2. Ensure the VM has been rebooted after enabling nested virtualization
3. Check that Windows features are enabled:
   ```powershell
   Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
   Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
   # Both should show State: Enabled
   ```
4. If features were just installed, reboot the VM and re-run `05-install-wsl2.ps1`

### Provisioning times out (Vagrant only)

```powershell
vagrant reload
```
