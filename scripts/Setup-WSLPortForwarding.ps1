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