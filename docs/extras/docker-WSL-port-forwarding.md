# Docker WSL Port Forwarding on Windows Server

When running Docker containers inside WSL2 on Windows Server, the containers bind to localhost within WSL's virtual network. To access these containers from external hosts, you need to:

1. **Set up port proxy rules** - Forward traffic from Windows to WSL
2. **Open Windows Firewall** - Allow inbound traffic on the required ports

## Prerequisites

- WSL2 installed on Windows Server
- Docker running inside WSL
- Administrator privileges on Windows Server

## Manual Setup Steps

### 1. Get WSL IP Address

```powershell
wsl hostname -I
# Returns something like: 172.27.97.204 172.18.0.1 ...
# Use the first IP address
```

### 2. Add Port Proxy Rules

```powershell
# Replace <WSL_IP> with the IP from step 1
# Replace <PORT> with the container port you want to expose

netsh interface portproxy add v4tov4 listenport=<PORT> listenaddress=0.0.0.0 connectport=<PORT> connectaddress=<WSL_IP>
```

### 3. Add Firewall Rules

```powershell
New-NetFirewallRule -DisplayName "<RULE_NAME>" -Direction Inbound -LocalPort <PORT> -Protocol TCP -Action Allow
```

### 4. Verify Configuration

```powershell
# Show all port proxy rules
netsh interface portproxy show all

# Test connectivity from remote host
curl -I http://<SERVER_HOSTNAME>:<PORT>
```

## Automated PowerShell Script

Save as `Setup-WSLPortForwarding.ps1` and run as Administrator:

```powershell
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [hashtable]$Ports = @{
        17170 = "LLDAP Web UI"
        3890  = "LLDAP LDAP"
    }
)

# Get WSL IP address (first one)
$wslIp = (wsl hostname -I).Split(' ')[0].Trim()

if (-not $wslIp) {
    Write-Error "Could not get WSL IP address. Is WSL running?"
    exit 1
}

Write-Host "WSL IP Address: $wslIp" -ForegroundColor Cyan

foreach ($port in $Ports.Keys) {
    $ruleName = $Ports[$port]
    
    # Remove existing port proxy rule (ignore errors if doesn't exist)
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
    
    # Add port proxy rule
    Write-Host "Adding port proxy: 0.0.0.0:$port -> ${wslIp}:$port" -ForegroundColor Green
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIp
    
    # Check if firewall rule exists
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    
    if (-not $existingRule) {
        Write-Host "Adding firewall rule: $ruleName (port $port)" -ForegroundColor Green
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow | Out-Null
    } else {
        Write-Host "Firewall rule already exists: $ruleName" -ForegroundColor Yellow
    }
}

Write-Host "`nCurrent port proxy rules:" -ForegroundColor Cyan
netsh interface portproxy show all
```

## Usage Examples

### Run with default ports (LLDAP)

```powershell
.\Setup-WSLPortForwarding.ps1
```

### Run with custom ports

```powershell
.\Setup-WSLPortForwarding.ps1 -Ports @{
    8080 = "My Web App"
    5432 = "PostgreSQL"
    6379 = "Redis"
}
```

## Cleanup

To remove port forwarding rules:

```powershell
# Remove port proxy
netsh interface portproxy delete v4tov4 listenport=17170 listenaddress=0.0.0.0

# Remove firewall rule
Remove-NetFirewallRule -DisplayName "LLDAP Web UI"
```

## Important Notes

- **WSL IP changes on reboot** - Run the script after each Windows restart, or set it up as a scheduled task
- **Docker must be running** - Ensure Docker containers are started inside WSL before testing
- The script must be run as **Administrator**
