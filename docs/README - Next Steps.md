# Next Steps

Open an **elevated PowerShell 7** prompt and run these scripts in order:

```powershell
C:\gittogallery\scripts\04-install-docker.ps1
```

This will install Docker CE and **reboot the VM**. After reboot it resumes automatically via a scheduled task.

In seldom occasions this script might fail due to network issues. If this happens, just run the script a second time (This shouldn't take very long).

Once Docker is ready, run:

```powershell
C:\gittogallery\scripts\05-install-wsl2.ps1
```

This installs WSL2 with Ubuntu and configures Docker Engine inside WSL.

## Verify

```powershell
docker version
wsl --list --verbose
```
