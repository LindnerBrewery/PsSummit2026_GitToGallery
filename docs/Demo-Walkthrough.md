# Gitea Server Demo — Full Walkthrough

Every step from the Technical Guide in executable form.
Read the comments, explain to the audience, and run commands as needed.

> **All demo passwords are:** `test123!`

---

## Step 1 — Start Gitea for the First Time (~2 min)

```powershell
# Navigate to the Gitea server directory
Set-Location C:\gittogallery\gitea-server

# Explore what Gitea can do:
#   web      — Start the web server
#   dump     — Dump files and database to disk
#   admin    — Administration tasks
#   migrate  — Migrate database (SQLite → PostgreSQL / MSSQL)
#   restore  — Restore repositories
#   generate — Generate certificates and other items
C:\gittogallery\gitea-server\gitea.exe help

# Start Gitea for the first time (runs as a foreground process)
C:\gittogallery\gitea-server\gitea.exe web
```

---

## Step 2 — Initial Configuration (Web UI) (~4 min)

Open `http://localhost:3000` in a browser.

**Database Settings:**
- Database Type: SQLite (suitable for 10–20 PowerShell developers)

**General Settings:**
- Site Name: `my company`
- Server Domain: `gittogallery`
- HTTP Listen Port: `3000`

**Administrator Account:**
- Username: `gitadmin`
- Email: `gitadmin@sample.com`
- Password: `test123!`

Click **Install Gitea**.

---

## Step 3 — Verify Installation (~2 min)

```powershell
Set-Location C:\gittogallery\gitea-server
Get-ChildItem
```

Expected output: `log/`, `data/`, `custom/`, `app.ini`

Open `app.ini` to review the auto-generated configuration.

---

## Step 4 — SSL Certificates (creation) (~5 min)

> **Optional** — Only needed if you are creating certificates from scratch. If the VM is pre-configured with the name `gittogallery`, skip to Step 5.

### Quick Path (pre-configured VM named "gittogallery")

If the VM was provisioned with the name `gittogallery`, pre-built certificates already exist in `C:\gittogallery\certs`. Skip creation and jump straight to importing the root CA:

```powershell
$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password
```

Copy `C:\gittogallery\certs\Server.pem` and `C:\gittogallery\certs\Server.key` to the nginx certs folder (see Step 6).

### Full Path (create certificates from scratch)

```powershell
# Import the custom Certificates PowerShell module
Import-Module .\Certificates

# Store the certificate password as a SecureString — reused everywhere
$password = 'test123!' | ConvertTo-SecureString -AsPlainText

# Create a Root Certificate Authority
# Creates rootCA.pfx in the current directory
New-RootCA -DnsName myRootCert -Password $password

# Create a server certificate signed by the root CA
# Creates Server.pfx in the current directory
$newCertParams = @{
    CertificatePassword    = $password
    CaFilePath             = '.\rootCA.pfx'
    CaPassword             = $password
    subjectAlternativeName = 'gittogallery.mshome.net'
}
New-Certificate @newCertParams

# Verify: you should now have rootCA.pfx and Server.pfx
Get-ChildItem *.pfx

# Export server certificate to PEM format (required by nginx)
Export-CertificateAsPemFromPfx -Password $password -FilePath .\Server.pfx

# Export the server private key
Export-KeyFromPfx -Password $password -FilePath .\Server.pfx

# Verify certificate and key are a matching pair
Test-KeyPair -CertificatePath .\Server.pem -KeyPath .\Server.key

# Import root CA into the Windows trusted root certificate store
Import-PfxCertificate -FilePath .\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password
```

Verify: open `certmgr.msc` → Trusted Root Certification Authorities → Certificates → look for `myRootCert`.

---

## Step 5 — Import Certificates into Windows and Nginx (~5 min)

Import the root CA into the Windows trusted root certificate store so Windows and browsers trust certificates signed by it. Then copy the server certificate and key into the nginx certs folder.

```powershell
$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password

# Copy the server certificate and key to the nginx certs folder:
New-Item -Path "C:\tools\nginx-1.29.7\certs" -ItemType Directory -Force
Copy-Item -Path "C:\gittogallery\certs\Server.pem" -Destination "C:\tools\nginx-1.29.7\certs\Server.pem"
Copy-Item -Path "C:\gittogallery\certs\Server.key" -Destination "C:\tools\nginx-1.29.7\certs\Server.key"
```

---

## Step 6 — Configure Nginx (~5 min)

Nginx config files in the repo mirror the target layout:
- `configs/nginx/nginx.conf` — Main config (adds conf.d include)
- `configs/nginx/conf.d/gitea_4443.conf` — Gitea reverse proxy on port 4443
- `configs/nginx/conf.d/nexus_8443.conf` — Nexus reverse proxy on port 8443

```powershell
# Deploy all nginx configs in one go (nginx.conf + conf.d/)
Copy-Item -Path 'C:\gittogallery\configs\nginx\*' -Destination 'C:\tools\nginx-1.29.7\conf\' -Recurse -Force

# Create certs directory and copy certificate files
New-Item -Path "C:\tools\nginx-1.29.7\certs" -ItemType Directory -Force
Copy-Item -Path "C:\gittogallery\certs\Server.pem" -Destination "C:\tools\nginx-1.29.7\certs\Server.pem"
Copy-Item -Path "C:\gittogallery\certs\Server.key" -Destination "C:\tools\nginx-1.29.7\certs\Server.key"

# Restart nginx
Restart-Service nginx

# Import the root CA into the trusted root store
$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation 'Cert:\LocalMachine\Root\' -Password $password
```

Open `https://gittogallery:4443` in a browser to verify.

---

## Step 7 — Gitea Configuration (app.ini) (~5 min)

Config file: `C:\gittogallery\gitea-server\custom\conf\app.ini`

After putting Gitea behind nginx, update the `[server]` section:

```ini
[server]
ROOT_URL  = https://gittogallery:4443/  # public URL for clone URLs, email links, OAuth callbacks
HTTP_ADDR = 127.0.0.1                   # bind to localhost only (no direct :3000 access)
```

After saving `app.ini`, stop the Gitea process (Ctrl+C), then restart:

```powershell
Set-Location C:\gittogallery\gitea-server
C:\gittogallery\gitea-server\gitea.exe web
```

---

## Step 8 — Email / SMTP Configuration (~3 min)

> **Optional**

Add or update the `[mailer]` section in `app.ini`:

```ini
[mailer]
ENABLED   = true
PROTOCOL  = smtps
SMTP_ADDR = smtp.gmail.com
SMTP_PORT = 465
FROM      = powershelltalks@gmail.com
USER      = powershelltalks@gmail.com
PASSWD    = <app-password>
```

Restart Gitea after saving:

```powershell
C:\gittogallery\gitea-server\gitea.exe web
```

---

## Step 9 — Verify Email (~2 min)

> **Optional**

1. Log in as `gitadmin`
2. Avatar → Site Administration
3. Configuration → Summary tab
4. Scroll to Email section at the bottom
5. Enter a test address → Send Test Email
6. Check inbox

---

## Step 10 — Restrict Registration (~3 min)

> **Optional**

Update `[service]` in `app.ini`:

```ini
[service]
EMAIL_DOMAIN_ALLOWLIST = macinally.de, macinally.co.uk  # only these email domains can register
REGISTER_EMAIL_CONFIRM = true                            # require email confirmation
REQUIRE_SIGNIN_VIEW    = true                            # force login to view any page
```

Save `app.ini` and restart Gitea.

---

## Step 11 — Disable OpenID (~1 min)

OpenID sign-in and sign-up bypass the domain allowlist. Disable both.

Update `[openid]` in `app.ini`:

```ini
[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false
```

Restart Gitea:

```powershell
C:\gittogallery\gitea-server\gitea.exe
```

---

## Step 12 — Customise the Gitea Landing Page (~3 min)

The `custom` folder contains:
- `templates/home.tmpl` — replaces the default landing page
- `templates/custom/header.tmpl` — injects conference CSS into `<head>`
- `public/assets/css/conference.css` — conference colour scheme
- `public/assets/img/logo.svg` — custom logo
- `public/assets/img/favicon.svg/.png` — custom favicons

```powershell
# Copy custom landing page files to Gitea server
Copy-Item C:\gittogallery\configs\custom\* C:\gittogallery\gitea-server\custom -Recurse -Force

# Restart Gitea
C:\gittogallery\gitea-server\gitea.exe
```

Open `https://gittogallery:4443` and hard-refresh (Ctrl+Shift+R).

---

## Step 13 — Start lldap (Lightweight LDAP) (~3 min)

lldap mocks Active Directory. Users and groups are pre-configured.

1. Open Windows Explorer → navigate to `C:\gittogallery\configs\docker\lldap`
2. Click address bar → type `wsl` → Enter
3. In the WSL terminal:

```bash
docker compose up -d
```

Access lldap UI: `http://localhost:17170`  
Login: `admin` / `test123!`

---

## Step 14 — Disable Self-Registration for LDAP (~2 min)

Update `[service]` in `app.ini`:

```ini
[service]
DISABLE_REGISTRATION   = true  # only admins can create accounts
EMAIL_DOMAIN_ALLOWLIST =       # clear so LDAP users with any email domain can log in
REGISTER_EMAIL_CONFIRM = true
REQUIRE_SIGNIN_VIEW    = true
```

Save `app.ini` and restart Gitea.

---

## Step 15 — Connect Gitea to LDAP (~5 min)

### Option A: Web UI

Site Administration → Identity and Access → Authentication Sources → Add Authentication Source

| Field | Value |
|---|---|
| Authentication Name | `ldap` |
| Security Protocol | Unencrypted |
| Host | `localhost` |
| Port | `3890` |
| Bind DN | `uid=gitea-bind,ou=people,dc=demo,dc=local` |
| Bind Password | `test123!` |
| User Search Base | `ou=people,dc=demo,dc=local` |
| User Filter | `(|(uid=%[1]s)(mail=%[1]s))` |
| Admin Filter | `(memberOf=cn=gitea-admins,ou=groups,dc=demo,dc=local)` |
| Username Attribute | `uid` |
| First Name Attribute | `firstname` |
| Surname Attribute | `lastname` |
| Email Attribute | `mail` |
| Avatar Attribute | `avatar` |

### Option B: CLI

```powershell
$addLdapArgs = @(
    '--name', 'ldap'
    '--security-protocol', 'unencrypted'
    '--host', 'localhost'
    '--port', '3890'
    '--bind-dn', 'uid=gitea-bind,ou=people,dc=demo,dc=local'
    '--bind-password', 'test123!'
    '--user-search-base', 'ou=people,dc=demo,dc=local'
    '--user-filter', '(|(uid=%[1]s)(mail=%[1]s))'
    '--admin-filter', '(memberOf=cn=gitea-admins,ou=groups,dc=demo,dc=local)'
    '--username-attribute', 'uid'
    '--firstname-attribute', 'firstname'
    '--surname-attribute', 'lastname'
    '--email-attribute', 'mail'
    '--avatar-attribute', 'avatar'
    '--synchronize-users'
)
C:\gittogallery\gitea-server\gitea.exe admin auth add-ldap @addLdapArgs
```

---

## Step 16 — LDAP Group Sync (~4 min)

> **Optional**

On the Authentication Source form, enable LDAP Groups:

| Field | Value |
|---|---|
| Group Search Base DN | `ou=groups,dc=demo,dc=local` |
| Group Attribute Containing List Of Users | `member` |
| User Attribute Listed In Group | `dn` |
| Remove user from sync when not in group | `true` |

Group-to-team JSON mapping:

```json
{
  "cn=devs,ou=groups,dc=demo,dc=local":        { "my_team": ["devs"] },
  "cn=engineers,ou=groups,dc=demo,dc=local":   { "my_team": ["readonly"] },
  "cn=gitea-admins,ou=groups,dc=demo,dc=local": { "my_team": ["Owners"] }
}
```

---

## Step 17 — Enable Periodic LDAP Sync (~2 min)

Add to `app.ini`:

```ini
[cron.sync_external_users]
ENABLED  = true
SCHEDULE = @every 1h
```

Save and restart Gitea:

```powershell
C:\gittogallery\gitea-server\gitea.exe
```

---

## Step 18 — Register Gitea as a Windows Service (~4 min)

Update `app.ini`:

```ini
RUN_USER = GITTOGALLERY$

[log]
MODE      = file
LEVEL     = Info
ROOT_PATH = C:\gittogallery\gitea-server\log

[server]
BUILTIN_SSH_SERVER_USER = git
SSH_USER                = git
```

```powershell
# Stop the current Gitea process (Ctrl+C), then register the service
sc.exe create gitea start= auto binPath= '"C:\gittogallery\gitea-server\gitea.exe" web --config "C:\gittogallery\gitea-server\custom\conf\app.ini"'

# Start and verify
Start-Service gitea
Get-Service gitea
```

---

## Step 19 — Migrate a GitHub Repository (~3 min)

Web UI: `+` (top-right) → New Migration

| Field | Value |
|---|---|
| Platform | GitHub |
| Clone Address | `https://github.com/lindnerbrewery/importcertificate.git` |
| Owner | `gitadmin` (or an org) |
| Mirror | optional |

Click **Migrate Repository**.

This imports code, issues, pull requests, releases, labels, and milestones.

---

## Step 20 — Create an Empty Repository (myFirstRepo) (~2 min)

Web UI: `+` (top-right) → New Repository

| Field | Value |
|---|---|
| Repository Name | `myFirstRepo` |
| Visibility | Public (or Private) |
| Default Branch | `main` |

Click **Create Repository**.

---

## Step 21 — Create a Repository Template (~3 min)

> **Optional**

A template repo is a normal repo with a checkbox ticked.

Web UI: Navigate to any repo → Settings → `[x] Template Repository` → Save

Good candidates for template content:
- `.gitea/workflows/` — CI/CD pipeline definitions
- `build.ps1` — build entry point
- `psakeFile.ps1` — psake build tasks
- `requirements.psd1` — build dependencies
- `.gitignore` — PowerShell ignores

**Variable expansion** — create a `.gitea/template` file listing glob patterns. Inside those files Gitea replaces at generation time:

| Variable | Value |
|---|---|
| `$REPO_NAME` | name of the new repo |
| `$REPO_DESCRIPTION` | description entered during creation |
| `$REPO_OWNER` | owner (user or org) |
| `$YEAR`, `$MONTH`, `$DAY` | date of generation |

Transformers: `$REPO_NAME_PASCAL`, `$REPO_NAME_SNAKE`, etc.

Example `.gitea/template`:
```
**/*.psd1
**/*.ps1
README.md
```

Docs: https://docs.gitea.com/usage/template-repositories

---

## Step 22 — Deploy Gitea Template Files (~2 min)

> **Optional**

Custom `.gitignore` and README templates live under Gitea's CustomPath:
- `custom/options/gitignore/` → `.gitignore` templates
- `custom/options/readme/` → README templates

```powershell
Copy-Item -Path 'C:\gittogallery\configs\gitea\custom\options' -Destination 'C:\gittogallery\gitea-server\custom\' -Recurse -Force

Restart-Service gitea
```

Verify: `+` → New Repository → `.gitignore` dropdown should list `PowerShell`, README dropdown should list `PowerShell-Module`.

---

## Step 23 — Create an Organisation (~3 min)

### Option A: Web UI

`+` (top-right) → New Organisation

| Field | Value |
|---|---|
| Organisation Name | `my_team` |
| Visibility | Public (or Private) |

### Option B: REST API

```powershell
# Generate an access token first
$token = (C:\gittogallery\gitea-server\gitea.exe admin user generate-access-token --username 'sam.sung' --scopes all --token-name mytoken) -split ": " | select -last 1

$orgBody = @{ username = 'my_team'; visibility = 'private' } | ConvertTo-Json
$orgParams = @{
    Uri         = 'https://gittogallery:4443/api/v1/orgs'
    Method      = 'Post'
    ContentType = 'application/json'
    Body        = $orgBody
    Headers     = @{ Authorization = "token $token" }
}
Invoke-RestMethod @orgParams
```

---

## Step 24 — Add Users to an Organisation (~2 min)

> **Optional**

Web UI: Navigate to the org → Settings → Teams → Choose a team → Add Team Member → enter username → Add

> To add LDAP users: they must log in once first so their Gitea account exists. LDAP Group Sync (Step 16) automates this for mapped groups.

---

## Step 25 — Create Certificates Repo in the Organisation (~2 min)

### Option A: REST API

```powershell
$repoBody = @{
    name           = 'Certificates'
    description    = 'PowerShell module for certificate management'
    private        = $false
    default_branch = 'main'
} | ConvertTo-Json

$repoParams = @{
    Uri         = 'https://gittogallery:4443/api/v1/orgs/my_team/repos'
    Method      = 'Post'
    ContentType = 'application/json'
    Headers     = @{ Authorization = "token $token" }
    Body        = $repoBody
}
Invoke-RestMethod @repoParams
```

### Option B: Web UI

Navigate to `https://gittogallery:4443/my_team` → `+` → New Repository

| Field | Value |
|---|---|
| Owner | `my_team` |
| Repository Name | `Certificates` |
| Description | `PowerShell module for certificate management` |
| Default Branch | `main` |

Verify: `https://gittogallery:4443/my_team/Certificates`

---

## Step 26 — Import the Certificates Module (~4 min)

The Certificates module source is at `C:\gittogallery\module\Certificates`.

```powershell
Set-Location C:\gittogallery\module\Certificates

git init
git checkout -b main
git add .
git commit -m "Initial commit — Certificates module"
git remote add origin https://gittogallery:4443/my_team/Certificates.git
git push -u origin main
```

Verify in Gitea: `https://gittogallery:4443/my_team/Certificates`

Expected structure:
```
Certificates/     — module source (psd1, psm1, Public/, Private/)
tests/            — Pester tests
build.ps1         — build entry point
psakeFile.ps1     — psake build tasks
requirements.psd1 — build dependencies
```

---

## Step 27 — Windows act_runner Setup (~8 min)

The binary is at `C:\gittogallery\gitea-act_runner\act_runner.exe`.

Important: Never run an act_runner on the same machine as a Gitea server in production. This setup is for demo purposes only. In production, runners should be on separate machines to isolate them from the server. An act_runner machine is disposable, and actions can manipulate the machine they are running on.

**1.** Create a private repo in Gitea (Web UI): Log in as gitadmin → `+` → New Repository → Visibility: Private

**2.** Get a runner registration token: Site Administration → Runners → Create runner token → copy it

**3.** Generate and patch `config.yaml`:

```powershell
Set-Location C:\gittogallery\gitea-act_runner

.\act_runner.exe generate-config | Out-File config.yaml -Encoding UTF8

# Set capacity to 2 parallel jobs
(Get-Content config.yaml) -replace '  capacity: \d+', '  capacity: 2' |
Set-Content config.yaml -Encoding UTF8

# Replace labels with Windows host label
$cfg = Get-Content config.yaml -Raw
$cfg = [regex]::Replace($cfg, '(?s)(  labels:)(\s*- ".*?")+', "  labels:`n    - `"windows:host`"")
Set-Content config.yaml $cfg -Encoding UTF8 -NoNewline
```

**4.** Register the runner:

```powershell
$registerArgs = @(
    'register'
    '--config', 'config.yaml'
    '--instance', 'https://gittogallery:4443'
    '--token', '82hLQubY84Y4n2BmIvrsD7xKxHcnVHDfMI8CyjcP'
    '--name', 'windows-runner'
    '--no-interactive'
)
.\act_runner.exe @registerArgs
```

**5.** Test as a foreground process first:

```powershell
.\act_runner.exe daemon --config config.yaml
# Verify in Gitea: Site Administration → Runners → status should be Online
# Press Ctrl+C once confirmed
```

**6.** Register as a Windows service using NSSM:

```powershell
C:\gittogallery\scripts\Install-ActRunnerService.ps1
```

**7.** Verify:

```powershell
Get-Service act_runner
```

---

## Step 28 — Nexus Repository Setup (~6 min)

Bind Nexus to loopback — edit `C:\gittogallery\nexus\nexus-3.89.0-09\etc\nexus-default.properties`:

```properties
application-port=8081
application-host=127.0.0.1
```

```powershell
# Install Nexus as a Windows service
cmd /c 'C:\gittogallery\nexus\nexus-3.90.1-01\bin\install-nexus-service.bat'

# Start and verify
Start-Service SonatypeNexusRepository
Get-Service SonatypeNexusRepository

# Tail the log — wait for "Started Sonatype Nexus"
Get-Content "C:\gittogallery\nexus\sonatype-work\nexus3\log\nexus.log" -Wait -Tail 20

# Get the initial admin password
Get-Content "C:\gittogallery\nexus\sonatype-work\nexus3\admin.password"
```

First login: `http://localhost:8081` → admin / (password from above)

Setup wizard: Next → New password: `test123!` → Enable anonymous access → Finish

> **Note:** If you don't allow anonymous access, you will need to use credentials when registering the repos as PSRepositories.

---

## Step 29 — Create psgallery-private Repository (~2 min)

### Option A: REST API

```powershell
$nexusBase = 'https://gittogallery:8443'
$nexusAuth = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('admin:test123!')) }
$contentType = 'application/json'

$hostedBody = @{
    name    = 'psgallery-private'
    online  = $true
    storage = @{
        blobStoreName               = 'default'
        strictContentTypeValidation = $true
        writePolicy                 = 'ALLOW_ONCE'       # allow redeploy for demos
    }
} | ConvertTo-Json -Depth 3

$hostedRepoParams = @{
    Uri         = "$nexusBase/service/rest/v1/repositories/nuget/hosted"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $hostedBody
}
Invoke-RestMethod @hostedRepoParams
```

### Option B: Web UI

Administration → Repositories → Create repository → nuget (hosted)

| Field | Value |
|---|---|
| Name | `psgallery-private` |
| Blob store | `default` |
| Deployment policy | Allow redeploy |
| Cleanup policies | (leave unset) |

URL: `https://gittogallery:8443/repository/psgallery-private/`

---

## Step 30 — Register PowerShell Repository (~2 min)

Register the `psgallery-private` repository in PowerShell so you can install modules from it without using the full URL each time.

```powershell
$repoName = 'psgallery-private'
if (-not (Get-PSRepository -Name $repoName -ErrorAction SilentlyContinue)) {
    $registerRepoParams = @{
        Name               = $repoName
        SourceLocation     = 'https://gittogallery:8443/repository/psgallery-private/'
        PublishLocation    = 'https://gittogallery:8443/repository/psgallery-private/'
        InstallationPolicy = 'Trusted'
    }
    Register-PSRepository @registerRepoParams
}
```

---

## Step 31 — Connect Nexus to LDAP (~3 min)

### Option A: REST API

```powershell
$nexusBase = 'https://gittogallery:8443'
$nexusAuth = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('admin:test123!')) }
$contentType = 'application/json'

$ldapBody = @{
    name                        = 'lldap'
    protocol                    = 'ldap'
    useTrustStore               = $false
    host                        = 'localhost'
    port                        = 3890
    searchBase                  = 'dc=demo,dc=local'
    authScheme                  = 'SIMPLE'
    authRealm                   = ''
    authUsername                = 'uid=gitea-bind,ou=people,dc=demo,dc=local'
    authPassword                = 'test123!'
    connectionTimeoutSeconds    = 30
    connectionRetryDelaySeconds = 300
    maxIncidentsCount           = 3
    userBaseDn                  = 'ou=people'
    userSubtree                 = $false
    userObjectClass             = 'person'
    userLdapFilter              = ''
    userIdAttribute             = 'uid'
    userRealNameAttribute       = 'cn'
    userEmailAddressAttribute   = 'mail'
    userPasswordAttribute       = ''
    ldapGroupsAsRoles           = $true
    groupType                   = 'STATIC'
    groupBaseDn                 = 'ou=groups'
    groupSubtree                = $false
    groupObjectClass            = 'groupOfUniqueNames'
    groupIdAttribute            = 'cn'
    groupMemberAttribute        = 'member'
    groupMemberFormat           = 'uid=${username},ou=people,dc=demo,dc=local'
    userMemberOfAttribute       = ''
} | ConvertTo-Json

$ldapParams = @{
    Uri         = "$nexusBase/service/rest/v1/security/ldap"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $ldapBody
}
Invoke-RestMethod @ldapParams
```

### Option B: Web UI

Administration → Security → LDAP → Create connection

**Connection tab:**

| Field | Value |
|---|---|
| Name | `lldap` |
| Protocol | `ldap` |
| Hostname | `localhost` |
| Port | `3890` |
| Base DN | `dc=demo,dc=local` |
| Authentication | Simple Authentication |
| Username or DN | `uid=gitea-bind,ou=people,dc=demo,dc=local` |
| Password | `test123!` |

Click **Verify connection** → confirm success → Next

**User and group tab:**

| Field | Value |
|---|---|
| User Relative DN | `ou=people` |
| Object class | `person` |
| Username attribute | `uid` |
| Real name attribute | `cn` |
| Email attribute | `mail` |
| Group type | Static Groups |
| Group relative DN | `ou=groups` |
| Group object class | `groupOfUniqueNames` |
| Group ID attribute | `cn` |
| Group member attribute | `member` |
| Group member format | `uid=${username},ou=people,dc=demo,dc=local` |

Click **Verify user mapping** → Create

---

## Step 32 — Map LDAP engineers to nx-admin (~1 min)

### Option A: REST API

```powershell
# Map LDAP engineers → nx-admin
$engineersBody = @{
    id          = 'engineers'
    name        = 'ldap-engineers'
    description = 'LDAP engineers mapped to nx-admin'
    privileges  = @()
    roles       = @('nx-admin')
} | ConvertTo-Json

Invoke-RestMethod -Uri "$nexusBase/service/rest/v1/security/roles" -Method Post -Headers $nexusAuth -ContentType $contentType -Body $engineersBody
```

### Option B: Web UI

Administration → Security → Roles → Create Role → External Role Mapping

| Field | Value |
|---|---|
| External role type | LDAP |
| Mapped role | `engineers` |
| Role ID | `ldap-engineers` |
| Role name | `ldap-engineers` |
| Role description | Maps LDAP engineers group to Nexus administrator access |
| Applied Roles | `nx-admin` |

Click **Create role**

---

## Step 33 — Create PowerUsers role and map LDAP devs (~2 min)

### Option A: REST API

```powershell
# Create PowerUsers role
$powerUsersBody = @{
    id          = 'PowerUsers'
    name        = 'PowerUsers'
    description = 'Browse all repos + edit/publish to psgallery-private + API key access'
    privileges  = @(
        'nx-repository-view-*-*-browse'
        'nx-repository-view-*-*-read'
        'nx-repository-view-nuget-psgallery-private-edit'
        'nx-repository-admin-nuget-psgallery-private-edit'
        'nx-apikey-all'
    )
    roles       = @()
} | ConvertTo-Json

Invoke-RestMethod -Uri "$nexusBase/service/rest/v1/security/roles" -Method Post -Headers $nexusAuth -ContentType $contentType -Body $powerUsersBody

# Map LDAP devs → PowerUsers
$devsBody = @{
    id          = 'devs'
    name        = 'ldap-devs'
    description = 'LDAP devs mapped to PowerUsers'
    privileges  = @()
    roles       = @('PowerUsers')
} | ConvertTo-Json

Invoke-RestMethod -Uri "$nexusBase/service/rest/v1/security/roles" -Method Post -Headers $nexusAuth -ContentType $contentType -Body $devsBody
```

### Option B: Web UI

**Step 1: Create PowerUsers Nexus Role**

Administration → Security → Roles → Create Role → Nexus Role

| Field | Value |
|---|---|
| Role ID | `PowerUsers` |
| Role name | `PowerUsers` |
| Role description | Browse/read, NuGet API key, publish to psgallery-private |
| Privileges | `nx-repository-view-*-*-browse`, `nx-repository-view-*-*-read`, `nx-repository-view-nuget-psgallery-private-edit`, `nx-repository-admin-nuget-psgallery-private-edit`, `nx-apikey-all` |

Click **Save**

**Step 2: Map LDAP devs to PowerUsers**

Administration → Security → Roles → Create Role → External Role Mapping

| Field | Value |
|---|---|
| External role type | LDAP |
| Mapped role | `devs` |
| Role ID | `ldap-devs` |
| Role name | `ldap-devs` |
| Role description | Maps LDAP devs group to PowerUsers role |
| Applied Roles | `PowerUsers` |

Click **Create role**

---

## Step 34 — Enable NuGet API Key Realm (~1 min)

### Option A: REST API

```powershell
$getRealmsParams = @{
    Uri     = "$nexusBase/service/rest/v1/security/realms/active"
    Method  = 'Get'
    Headers = $nexusAuth
}
$realms = Invoke-RestMethod @getRealmsParams

if ('NuGetApiKey' -notin $realms) {
    $realms += 'NuGetApiKey'
    $putRealmsParams = @{
        Uri         = "$nexusBase/service/rest/v1/security/realms/active"
        Method      = 'Put'
        Headers     = $nexusAuth
        ContentType = $contentType
        Body        = ($realms | ConvertTo-Json)
    }
    Invoke-RestMethod @putRealmsParams
}
```

### Option B: Web UI

Administration → Security → Realms → Move **NuGet API-Key Realm** from Available to Active → Save

---

## Step 35 — End-to-End: Publish a Module (~5 min)

1. **Generate a NuGet API Key**: Log in to Nexus as a devs group member (for example `sam.sung`) → Profile → NuGet API Key → Access API Key → copy.

2. **Add as Gitea Actions secret**: Gitea → Certificates repo → Settings → Actions → Secrets.  
    Name: `NEXUS_NUGET_API_KEY`  
    Value: `<paste key>`

3. **Run the publish pipeline from Gitea Actions**: Make sure the `psgallery-private` repository is registered in the build scripts (Step 36) before running the pipeline. Otherwise publish fails because the repository is not found when the act runner runs under a different user context without that registration. Then go to certificates repo → Actions → `release.yml` → Run workflow against `main`. The pipeline runs Pester tests, then publishes to `psgallery-private`.

4. **Verify in Nexus**: Browse → `psgallery-private` → `Certificates` module.

---

## Step 36 — Add a Private Gallery Dependency (~3 min)

Edit `Certificates.psd1`:
```powershell
RequiredModules = @('ImportCertificate')
```

Edit `requirements.psd1`:
```powershell
'ImportCertificate' = @{ Version = 'latest' }
```

Bump version in `Certificates.psd1`:
```powershell
ModuleVersion = '0.2.0'
```

Commit and push → pipeline fails because `ImportCertificate` doesn't exist in `psgallery-private` (only on public PSGallery).

---

## Step 37 — Fix: PSGallery Proxy + Group Repository (~5 min)

```powershell
# Get the PSGallery NuGet v2 feed URL
Get-PSRepository -Name PSGallery | Select-Object -ExpandProperty SourceLocation
```

### Option A: REST API

```powershell
# Create nuget (proxy) for PSGallery
$proxyBody = @{
    name          = 'psgallery-proxy'
    online        = $true
    storage       = @{
        blobStoreName               = 'default'
        strictContentTypeValidation = $true
    }
    proxy         = @{
        remoteUrl      = 'https://www.powershellgallery.com/api/v2'
        contentMaxAge  = 1440
        metadataMaxAge = 1440
    }
    nugetProxy    = @{
        queryCacheItemMaxAge = 3600
        nugetVersion         = 'V2'
    }
    httpClient    = @{
        blocked   = $false
        autoBlock = $true
    }
    negativeCache = @{
        enabled    = $true
        timeToLive = 1440
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "$nexusBase/service/rest/v1/repositories/nuget/proxy" -Method Post -Headers $nexusAuth -ContentType $contentType -Body $proxyBody

# Verify the proxy
Register-PSRepository -Name 'psgallery-proxy' -SourceLocation 'https://gittogallery:8443/repository/psgallery-proxy/' -InstallationPolicy Trusted
Find-Module Pester -Repository psgallery-proxy

# Create nuget (group) combining hosted + proxy
$groupBody = @{
    name    = 'psgallery-group'
    online  = $true
    storage = @{
        blobStoreName               = 'default'
        strictContentTypeValidation = $true
    }
    group   = @{
        memberNames = @('psgallery-private', 'psgallery-proxy')
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "$nexusBase/service/rest/v1/repositories/nuget/group" -Method Post -Headers $nexusAuth -ContentType $contentType -Body $groupBody

# Verify the group
$groupRegParams = @{
    Name               = 'PSGallery-Group'
    SourceLocation     = 'https://gittogallery:8443/repository/psgallery-group/'
    PublishLocation    = 'https://gittogallery:8443/repository/psgallery-private/'
    InstallationPolicy = 'Trusted'
}
Register-PSRepository @groupRegParams
Find-Module Pester -Repository PSGallery-Group
```

### Option B: Web UI

1. **PSGallery-Proxy** (nuget proxy): Administration → Repositories → Create repository → nuget (proxy)  
   Name: `PSGallery-Proxy`, Protocol: NuGet V2, Remote: `https://www.powershellgallery.com/api/v2`

2. **psgallery-group** (nuget group): Administration → Repositories → Create repository → nuget (group)  
   Name: `psgallery-group`, Members: `psgallery-private`, `PSGallery-Proxy`

---

## Step 38 — Update Build Scripts & Re-run Pipeline (~5 min)

In `psakeFile.ps1`, change:
```powershell
$PSBPreference.Publish.PSRepository = 'psgallery-group'
```

In `build.ps1`, replace the repository registration with:

```powershell
$registerPSRepositoryParams = @{
    Name               = 'psgallery-group'
    SourceLocation     = 'https://gittogallery:8443/repository/psgallery-group/'
    PublishLocation    = 'https://gittogallery:8443/repository/psgallery-private/'
    InstallationPolicy = 'Trusted'
}
if (-not (Get-PSRepository -Name $registerPSRepositoryParams.Name -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSRepository '$($registerPSRepositoryParams.Name)'..."
    Register-PSRepository @registerPSRepositoryParams
}
else {
    Write-Host "PSRepository '$($registerPSRepositoryParams.Name)' is already registered."
}
```

Commit and push. The pipeline now succeeds:
1. Registers `psgallery-group` on the runner
2. Runs Pester tests
3. Publishes to `psgallery-private`, resolves `ImportCertificate` via the proxy

**Full cycle complete!**

---

## Step 39 — Linux Act Runner (Docker in WSL) (~10 min)

> **Optional**

Runs Gitea Actions workflows inside Linux Docker containers via WSL2 Ubuntu. Two images are involved:

1. **Runner daemon** — `gitea/act_runner:latest` (official image from Gitea). This is the orchestrator. It polls Gitea for jobs, manages registration, and launches sibling job containers via the mounted Docker socket.
2. **Job container** — `macinally/act_runner:latest` (custom image, built from the dockerfile). This is where your workflow steps actually execute. When a workflow requests the `ubuntu-pwsh` label, the runner spins up a container from this image. It is based on Ubuntu 24.04 and comes with PowerShell 7, Node.js, Git, and curl pre-installed.

The dockerfile is fully customisable. Add any tools your build needs (Python, .NET SDK, Go, Ruby, linting tools, additional PowerShell modules, etc.). Simply edit the dockerfile, rebuild the image, and your workflows pick it up.

### Folder: `C:\gittogallery\configs\docker\linux_act_runner`

| File | Purpose |
|---|---|
| `.env` | Environment variables consumed by `compose.yaml`: `GITEA_INSTANCE_URL`, `GITEA_RUNNER_REGISTRATION_TOKEN`, `GITEA_RUNNER_NAME`, `GITEA_RUNNER_LABELS`. The label format is `name:docker://image` — it tells the runner which Docker image to launch when a workflow's `runs-on` matches that label. |
| `compose.yaml` | Docker Compose service definition for the runner daemon. Key volume mounts: `/var/run/docker.sock` (lets the runner create sibling job containers), `./config.yaml` (runner configuration), `/etc/ssl/certs/ca-certificates.crt` (read-only — WSL's CA bundle, so the runner daemon trusts the self-signed Gitea/Nexus certificates). |
| `config.yaml` | Act runner configuration controlling runtime behaviour: log level (info), job concurrency (1), job timeout (3h), `insecure: false` (TLS verification enabled). `container.options` mounts the CA bundle into every job container and sets `NODE_EXTRA_CA_CERTS` so Node.js also trusts the root CA. `valid_volumes` whitelists the CA bundle path. Labels can override `.env` labels (commented out by default). |
| `dockerfile` | Defines the custom job image (`macinally/act_runner:latest`). Base: Ubuntu 24.04. Installs: PowerShell 7, Node.js (LTS), Git, curl, wget, ca-certificates. This image does NOT run the act_runner daemon — it is the environment where workflow job steps execute. |

### Certificate Trust Chain

The build pipeline connects to Gitea (clone) and Nexus (publish) over HTTPS. With self-signed certificates, each layer must trust the root CA:

- **WSL host** → `Install-rootCA-to-wsl-ca-certificates.ps1` (Step 39.1 below)
- **Runner daemon** → `compose.yaml` mounts WSL's `/etc/ssl/certs/ca-certificates.crt`
- **Job containers** → `config.yaml` `container.options` mounts the same CA bundle

Without this chain, `git clone` and `Invoke-RestMethod` calls fail with SSL errors.

### Prerequisites

- A Gitea runner registration token is required. Obtain one from: Site Administration → Actions → Runners → Create new Runner. Paste the token into `.env` as `GITEA_RUNNER_REGISTRATION_TOKEN`.

### Steps

1. Install root CA into WSL's certificate store:

```powershell
C:\gittogallery\scripts\Install-rootCA-to-wsl-ca-certificates.ps1
```

2. Open Explorer → `C:\gittogallery\configs\docker\linux_act_runner` → address bar → type `wsl` → Enter

3. Start the runner:

```bash
docker compose up -d
```

The `macinally/act_runner:latest` image is published on Docker Hub. `docker compose` will pull it automatically on first run — no build required. To pull it manually: `docker pull macinally/act_runner:latest`

4. (Optional) Build a custom job image if you modify the dockerfile:

```bash
docker build -t macinally/act_runner:latest .
```

> **Note — Label Precedence:** `.env` `GITEA_RUNNER_LABELS` is only used during initial registration. If `config.yaml` labels are set, they take precedence over `.env` and `.runner` file labels at daemon startup. The `.runner` file (in the data folder) caches the labels from registration. Since Gitea 1.21, non-empty labels in `config.yaml` override the `.runner` file at daemon startup — the runner picks them up on restart without re-registering. If `config.yaml` labels are empty (or commented out), the `.runner` file labels are used. To force a full re-registration, delete the data folder.

To use the Linux runner in your workflow, set `runs-on: ubuntu-pwsh`, then commit and push. The runner will pick up the job and run it in a container based on the `macinally/act_runner:latest` image.

---

## Step 40 — Windows Act Runner (Docker Container) (~10 min)

> **Optional**

Windows Docker runner for Gitea Actions workflows. Unlike the Linux runner (Step 39), this is a single-image design: the `act_runner.exe` binary is baked directly into the container image. The container registers itself, then runs the daemon — all in one process. Jobs execute on the host (inside the container), not in nested containers.

Base image: `mcr.microsoft.com/windows/server:windows-ltsc`. The dockerfile installs PowerShell 7, Chocolatey, Git, and Node.js during build so workflows have those tools available immediately.

The runner is **not ephemeral** (`GITEA_EPHEMERAL=0`). Each container registers once, then runs the daemon indefinitely, picking up jobs as they arrive. The container restarts automatically (`restart: unless-stopped`) and survives host reboots without re-registration.

### Folder: `C:\gittogallery\configs\docker\windows_act_runner`

| File | Purpose |
|---|---|
| `.env` | Environment variables consumed by `docker-compose.yml`. Contains `GITEA_REGISTRATION_TOKEN=<token>`. This is the only secret — do not commit real values. |
| `docker-compose.yml` | Compose service definition. Runs **2 replicas** by default. Sets `GITEA_INSTANCE`, `GITEA_RUNNER_NAME`, `GITEA_EPHEMERAL=0`, and labels `windows2025:host,windows-latest:host`. Mounts `./certs → C:/Certs` (read-only) for root CA trust. |
| `dockerfile` | Builds the custom runner image (`macinally/act_runner:windows-ltsc`). Installs PowerShell 7 (via `install-pwsh.ps1`), Chocolatey, Git, Node.js. Copies `act_runner.exe` and `entrypoint.ps1` into `C:/runner`. |
| `entrypoint.ps1` | Container startup script. Imports CA certificates from `C:\Certs` into the Windows Trusted Root store, normalises labels to end with `:host`, registers the runner with `act_runner.exe register --no-interactive`, removes the registration token from the environment for security, then starts the daemon with `act_runner.exe daemon`. |
| `install-pwsh.ps1` | Downloads and installs the latest PowerShell 7 release from GitHub into `$env:ProgramData\pwsh` and adds it to PATH. |
| `act_runner.exe` | The Gitea act_runner binary. Only needed if building the image locally. Download from: https://gitea.com/gitea/act_runner/releases |

### Certificate Trust Chain

The Windows runner connects to Gitea over HTTPS. With self-signed certificates, the container must trust the root CA:

1. Place your `rootCA.pem` (or `.crt`) file in the `certs/` subdirectory.
2. `docker-compose.yml` mounts `./certs → C:/Certs` (read-only).
3. `entrypoint.ps1` imports all `.crt`/`.pem` files from `C:\Certs` into `Cert:\LocalMachine\Root` on container startup.

Without this, `git clone` and HTTPS calls inside workflows will fail with SSL/TLS trust errors.

### Label Format

Labels use the `:host` scheme because jobs execute directly inside the container (not in nested Docker containers). Format: `<label-name>:host`

When a workflow specifies `runs-on: windows-latest`, Gitea matches it to a runner with the `windows-latest` label and the job runs on the container's host environment.

### Prerequisites

- Docker Desktop for Windows with **Windows containers** enabled.
- A Gitea runner registration token (Site Administration → Actions → Runners → Create new Runner). Paste into `.env`.
- (Optional) `rootCA.pem` in `certs/` subdirectory for self-signed certs.

### Steps

The `macinally/act_runner:windows-ltsc` image is published on Docker Hub. `docker compose` will pull it automatically on first run — no build required. To pull it manually: `docker pull macinally/act_runner:windows-ltsc`

- Create `.env` with `GITEA_REGISTRATION_TOKEN=<TOKEN>` (if not already present)
- Place `rootCA.pem` (or `.crt`) in `certs/` subdirectory for self-signed certificate trust

```powershell
Set-Location C:\gittogallery\configs\docker\windows_act_runner

# 1. Start the runners (2 replicas by default)
docker compose up -d

# 2. (Optional) Scale up to more replicas
docker compose up -d --scale gitea-runner=4
```

Verify: Site Administration → Runners → should show Online.

### (Optional) Build a custom image

Only needed if you modify the dockerfile. Requires `act_runner.exe` in the `windows_act_runner` folder ([download](https://gitea.com/gitea/act_runner/releases)).

```powershell
docker build -t macinally/act_runner:windows-ltsc .
```

To use the Windows runner in your workflow, set `runs-on: windows-latest` or `runs-on: windows2025`, then commit and push.
