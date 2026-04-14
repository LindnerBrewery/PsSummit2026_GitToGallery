#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Gitea Server Demo — Full Walkthrough Script

.DESCRIPTION
    This script contains every step from the Technical Guide in executable form.
    Read the comments, explain to the audience, and run commands as needed.

    All demo passwords are: test123!
#>

# ============================================================
# STEP 1 — Start Gitea for the first time                      (~2 min)
# ============================================================

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

# ============================================================
# STEP 2 — Initial Configuration (Web UI)                      (~4 min)
# ============================================================
# Open http://localhost:3000 in a browser.
#
# Database Settings:
#   Database Type: SQLite (suitable for 10–20 PowerShell developers)
#
# General Settings:
#   Site Name:        my company
#   Server Domain:    gittogallery
#   HTTP Listen Port: 3000
#
# Administrator Account:
#   Username: gitadmin
#   Email:    gitadmin@sample.com
#   Password: test123!
#
# Click "Install Gitea".

# ============================================================
# STEP 3 — Verify Installation                                 (~2 min)
# ============================================================

Set-Location C:\gittogallery\gitea-server
Get-ChildItem

# Expected: log/, data/, custom/, app.ini
# Open app.ini to review the auto-generated configuration.


# ============================================================
# STEP 4 — SSL Certificates (creation)                        (~ 5 min) # optional
# ============================================================

# --- Quick Path (pre-configured VM named "gittogallery") ---
# If the VM was provisioned with the name "gittogallery", pre-built
# certificates already exist in C:\gittogallery\certs. You can skip creation and
# jump straight to copying them to nginx and importing the root CA:

$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password

# Copy C:\gittogallery\certs\Server.pem and C:\gittogallery\certs\Server.key to the nginx certs
# folder (see Step 6).

# --- Full Path (create certificates from scratch) ---

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
# This makes Windows trust any certificate signed by our root CA
Import-PfxCertificate -FilePath .\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password

# Verify: open certmgr.msc → Trusted Root Certification Authorities → Certificates
# Look for "myRootCert"

# ============================================================
# STEP 5 — Import Certificates into Windows and Nginx         (~5 min)
# ============================================================
# Import root CA into the Windows trusted root certificate store
# This makes Windows trust any certificate signed by our root CA

$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation "Cert:\LocalMachine\Root\" -Password $password

# Copy the server certificate and key to the nginx certs folder:
New-Item -Path "C:\tools\nginx-1.29.7\certs" -ItemType Directory -Force
Copy-Item -Path "C:\gittogallery\certs\Server.pem" -Destination "C:\tools\nginx-1.29.7\certs\Server.pem"
Copy-Item -Path "C:\gittogallery\certs\Server.key" -Destination "C:\tools\nginx-1.29.7\certs\Server.key"

# ============================================================
# STEP 6 — Configure Nginx                                     (~5 min)
# ============================================================
# Nginx config files in the repo mirror the target layout:
#   configs/nginx/nginx.conf             — Main config (adds conf.d include)
#   configs/nginx/conf.d/gitea_4443.conf — Gitea reverse proxy on port 4443
#   configs/nginx/conf.d/nexus_8443.conf — Nexus reverse proxy on port 8443



# Deploy all nginx configs in one go (nginx.conf + conf.d/)
Copy-Item -Path 'C:\gittogallery\configs\nginx\*' -Destination 'C:\tools\nginx-1.29.7\conf\' -Recurse -Force

# Create certs directory and copy certificate files
# gitea_4443.conf references ../certs/ relative to conf → C:\tools\nginx-1.29.7\certs\
New-Item -Path "C:\tools\nginx-1.29.7\certs" -ItemType Directory -Force
Copy-Item -Path "C:\gittogallery\certs\Server.pem" -Destination "C:\tools\nginx-1.29.7\certs\Server.pem"
Copy-Item -Path "C:\gittogallery\certs\Server.key" -Destination "C:\tools\nginx-1.29.7\certs\Server.key"

# Restart nginx and test HTTPS access
# If you ran configure-windows.ps1 during provisioning, firewall ports 443 and 4443 are already open.
Restart-Service nginx

# Import the root CA into the trusted root store so browsers trust our self-signed certs
$password = 'test123!' | ConvertTo-SecureString -AsPlainText
Import-PfxCertificate -FilePath C:\gittogallery\certs\rootCA.pfx -CertStoreLocation 'Cert:\LocalMachine\Root\' -Password $password

# Open https://gittogallery:4443 in a browser to verify


# ============================================================
# STEP 7 — Gitea Configuration (app.ini)                       (~5 min)
# ============================================================
# Config file: C:\gittogallery\gitea-server\custom\conf\app.ini
# Most settings can also be configured via the Gitea CLI (gitea.exe).
# Changes require a Gitea restart.

# --- ROOT_URL and HTTP_ADDR ---
# After putting Gitea behind nginx, update the [server] section:
#
#   [server]
#   ROOT_URL  = https://gittogallery:4443/  # public URL used for clone URLs, email links, OAuth callbacks
#   HTTP_ADDR = 127.0.0.1                    # listen address — 127.0.0.1 binds to localhost only (no direct :3000 access)


# After saving app.ini, stop the Gitea process in the terminal with Ctrl+C, then restart it:
Set-Location C:\gittogallery\gitea-server
C:\gittogallery\gitea-server\gitea.exe web 

# ============================================================
# STEP 8 — Email / SMTP Configuration                          (~3 min) # optional
# ============================================================
# Add or update the [mailer] section in app.ini:
#
#   [mailer]
#   ENABLED  = true                         # enable outgoing email
#   PROTOCOL = smtps                        # mail protocol: smtp, smtps, smtp+starttls, sendmail, dummy
#   SMTP_ADDR = smtp.gmail.com              # SMTP server hostname
#   SMTP_PORT = 465                         # SMTP port (25=insecure, 465=smtps, 587=starttls)
#   FROM     = powershelltalks@gmail.com    # sender address shown in emails (RFC 5322)
#   USER     = powershelltalks@gmail.com    # SMTP authentication username
#   PASSWD   = <app-password>               # SMTP authentication password (Gmail 2FA → App Password)

# After saving app.ini, stop the Gitea process in the terminal with Ctrl+C, then restart it:
C:\gittogallery\gitea-server\gitea.exe web

# ============================================================
# STEP 9 — Verify Email                                        (~2 min) # optional
# ============================================================
# 1. Log in as gitadmin
# 2. Avatar → Site Administration
# 3. Configuration → Summary tab
# 4. Scroll to Email section at the bottom
# 5. Enter a test address → Send Test Email
# 6. Check inbox


# ============================================================
# STEP 10 — Restrict Registration                               (~3 min) # optional
# ============================================================
# Update [service] in app.ini:
#
#   [service]
#   EMAIL_DOMAIN_ALLOWLIST   = macinally.de, macinally.co.uk  # only these email domains can register (comma-separated, wildcard supported)
#   REGISTER_EMAIL_CONFIRM   = true                          # require email confirmation before account is active
#   REQUIRE_SIGNIN_VIEW      = true                          # force login to view any page — no anonymous browsing
#
# Save app.ini and restart Gitea.


# ============================================================
# STEP 11 — Disable OpenID                                     (~1 min)
# ============================================================
# OpenID sign-in and sign-up bypass the domain allowlist configured above.
# Disable both to ensure the only way in is through local registration
# with an approved email domain.
#
# Update [openid] in app.ini:
#
#   [openid]
#   ENABLE_OPENID_SIGNIN = false  # disable OpenID login (bypasses domain allowlist if left enabled)
#   ENABLE_OPENID_SIGNUP = false  # disable OpenID registration
#
# Save app.ini and restart Gitea
# stop gitea crtl + c
# start gitea
C:\gittogallery\gitea-server\gitea.exe


# ============================================================
# STEP 12 — Customise the Gitea Landing Page                    (~3 min)
# ============================================================
# The custom folder at gitea-server\custom\ contains:
#   templates/home.tmpl                    — replaces the default landing page
#   templates/custom/header.tmpl           — injects conference CSS into <head>
#   public/assets/css/conference.css       — conference colour scheme
#   public/assets/img/logo.svg             — custom logo
#   public/assets/img/favicon.svg/.png     — custom favicons
#
# Gitea reads the custom folder automatically. Restart to apply template changes.

# Copy cutom landing page files to Gitea server
Copy-Item C:\gittogallery\configs\custom\* C:\gittogallery\gitea-server\custom -Recurse -Force

# stop gitea crtl + c
# start gitea
C:\gittogallery\gitea-server\gitea.exe

# Open https://gittogallery:4443 and hard-refresh (Ctrl+Shift+R)


# ============================================================
# STEP 13 — Start lldap (Lightweight LDAP)                     (~3 min)
# ============================================================
# lldap mocks Active Directory. Users and groups are pre-configured.
#
# 1. Open Windows Explorer → navigate to C:\gittogallery\configs\docker\lldap
# 2. Click address bar → type "wsl" → Enter
# 3. In the WSL terminal:

# docker compose up -d

# Access lldap UI: http://localhost:17170
# Login: admin / test123!


# ============================================================
# STEP 14 — Disable Self-Registration for LDAP                 (~2 min)
# ============================================================
# Now that LDAP handles authentication, disable self-registration
# and clear the domain allowlist (otherwise LDAP users are blocked).
#
# Update [service] in app.ini:
#
#   [service]
#   DISABLE_REGISTRATION     = true   # disable self-registration — only admins can create accounts
#   EMAIL_DOMAIN_ALLOWLIST   =        # clear allowlist so LDAP users with any email domain can log in
#   REGISTER_EMAIL_CONFIRM   = true   # require email confirmation before account is active
#   REQUIRE_SIGNIN_VIEW      = true   # force login to view any page — no anonymous browsing
#
# Save app.ini and restart Gitea.


# ============================================================
# STEP 15 — Connect Gitea to LDAP                              (~5 min)
# ============================================================
# Full reference: Setting-up-LDAP-connections-in-Gitea.md
#
# Via Web UI:
#   Site Administration → Identity and Access → Authentication Sources
#   → Add Authentication Source
#
#   Authentication Name:  ldap
#   Security Protocol:    Unencrypted
#   Host:                 localhost
#   Port:                 3890
#   Bind DN:              uid=gitea-bind,ou=people,dc=demo,dc=local
#   Bind Password:        test123!
#   User Search Base:     ou=people,dc=demo,dc=local
#   User Filter:          (|(uid=%[1]s)(mail=%[1]s))
#   Admin Filter:         (memberOf=cn=gitea-admins,ou=groups,dc=demo,dc=local)
#   Username Attribute:   uid
#   First Name Attribute: firstname
#   Surname Attribute:    lastname
#   Email Attribute:      mail
#   Avatar Attribute:     avatar

# Or via CLI:
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


# ============================================================
# STEP 16 — LDAP Group Sync                                    (~4 min) # optional
# ============================================================
# On the same Authentication Source form, enable LDAP Groups:
#
#   Group Search Base DN:                       ou=groups,dc=demo,dc=local
#   Group Attribute Containing List Of Users:   member
#   User Attribute Listed In Group:             dn
#   Remove user from sync when not in group:    true
#
# Group-to-team JSON mapping:
# {
#   "cn=devs,ou=groups,dc=demo,dc=local":          { "my_team": ["devs"] },
#   "cn=engineers,ou=groups,dc=demo,dc=local":      { "my_team": ["readonly"] },
#   "cn=gitea-admins,ou=groups,dc=demo,dc=local":   { "my_team": ["Owners"] }
# }


# ============================================================
# STEP 17 — Enable Periodic LDAP Sync                          (~2 min)
# ============================================================
# Add to app.ini:
#
#   [cron.sync_external_users]
#   ENABLED  = true
#   SCHEDULE = @every 1h  
#
# Save app.ini and restart Gitea.
# stop gitea crtl + c
# start gitea
C:\gittogallery\gitea-server\gitea.exe

# ============================================================
# STEP 18 — Register Gitea as a Windows Service                (~4 min)
# ============================================================

# Update app.ini for service mode:
#
#   RUN_USER = GITTOGALLERY$  # OS user the service runs as (must match sc.exe service account)
#
#   [log]
#   MODE      = file                                # log output: console, file, conn (file for services)
#   LEVEL     = Info                                # log level: Trace, Debug, Info, Warn, Error, Critical, Fatal
#   ROOT_PATH = C:\gittogallery\gitea-server\log     # directory for log files
#
#   [server]
#   BUILTIN_SSH_SERVER_USER = git  # system user for Gitea's built-in SSH server
#   SSH_USER                = git  # username shown in SSH clone URLs

# Register the service (elevated prompt)
# stop current gitea process with crtl + c 
sc.exe create gitea start= auto binPath= '"C:\gittogallery\gitea-server\gitea.exe" web --config "C:\gittogallery\gitea-server\custom\conf\app.ini"'

# stop gitea process if it's still running in the foreground

# Start and verify
Start-Service gitea
Get-Service gitea




# ============================================================
# STEP 19 — Migrate a GitHub Repository                        (~3 min)
# ============================================================
# Gitea can import repositories from GitHub, GitLab, Gitbucket, etc.
#
# Web UI:
#   + (top-right) → New Migration
#   Platform:       GitHub
#   Clone Address:  https://github.com/lindnerbrewery/importcertificate.git
#   Owner:          gitadmin (or an org)
#   Repository Name: <repo>
#   [] Mirror      (optional — keeps pulling from upstream)
#   → Migrate Repository
#
# This imports code, issues, pull requests, releases, labels, and milestones. There are optional app.ini settings for mirroring (disable, sync interval, etc.)



# ============================================================
# STEP 20 — Create an Empty Repository (myFirstRepo)           (~2 min)
# ============================================================
# Create a simple repository to explore Gitea's repo features.
#
# Web UI:
#   + (top-right) → New Repository
#   Repository Name: myFirstRepo
#   Visibility:      Public (or Private)
#   Default Branch:  main
#   → Create Repository
#
# This creates an empty repo you can push to or use to explore the UI.


# ============================================================
# STEP 21 — Create a Repository Template                       (~3 min) # optional
# ============================================================
# A template repo is just a normal repo with a checkbox ticked.
# Any future changes you push to the template repo will be picked up
# the next time someone generates a new repo from it.
#
# Web UI:
#   Navigate to any repo → Settings (tab)
#   [x] Template Repository  →  Save
#
# Now when creating a new repo:
#   + → New Repository → "Generate from template" dropdown → select your template
#
# Good candidates for template content:
#   .gitea/workflows/    — CI/CD pipeline definitions
#   build.ps1            — build entry point
#   psakeFile.ps1        — psake build tasks
#   requirements.psd1    — build dependencies
#   .gitignore           — PowerShell ignores
#
# Variable expansion:
#   Create a .gitea/template file listing glob patterns of files to expand.
#   Inside those files, Gitea replaces variables at generation time:
#     $REPO_NAME         — name of the new repo
#     $REPO_DESCRIPTION  — description entered during creation
#     $REPO_OWNER        — owner (user or org) of the new repo
#     $YEAR, $MONTH, $DAY — date of generation
#   Transformers: $REPO_NAME_PASCAL, $REPO_NAME_SNAKE, etc.
#
# Example .gitea/template:
#   **/*.psd1
#   **/*.ps1
#   README.md
#
# Example in a .psd1:
#   ModuleName = '$REPO_NAME'
#
# Docs: https://docs.gitea.com/usage/template-repositories


# ============================================================
# STEP 22 — Deploy Gitea Template Files                        (~2 min) # optional
# ============================================================
# Gitea lets you add custom .gitignore and README templates that appear
# in the "New Repository" dropdowns. They live under Gitea's CustomPath:
#   custom/options/gitignore/   → .gitignore templates
#   custom/options/readme/      → README templates
#
# We ship two templates in this repo:
#   configs/gitea/custom/options/gitignore/PowerShell
#   configs/gitea/custom/options/readme/PowerShell-Module.md
#
# The .gitignore template covers build output, Pester results, certificates,
# dependency caches, and IDE files.
#
# The README template uses Gitea's {Name} and {Description} placeholders —
# these are replaced automatically when creating a new repository.
# (Note: these are different from the $REPO_NAME template-repo variables
# in Step 20 — readme templates use curly braces, template repos use $variables.)
#
# Deploy them to the Gitea server:

Copy-Item -Path 'C:\gittogallery\configs\gitea\custom\options' -Destination 'C:\gittogallery\gitea-server\custom\' -Recurse -Force

# Restart Gitea to pick up the new templates
Restart-Service gitea

# Verify: + → New Repository → .gitignore dropdown should list "PowerShell"
#         and README dropdown should list "PowerShell-Module"


# ============================================================
# STEP 23 — Create an Organisation                             (~3 min)
# ============================================================
# Organisations group repos, teams and users — ideal for departments or projects.
#
# Web UI:
#   + (top-right) → New Organisation
#   Organisation Name:  my_team
#   Visibility:         Public (or Private)
#   → Create Organisation

# Or via API:
# You will need an access token to use the API. Go to User Settings → Applications → Generate New Token
# Or you can use the the gitea admin token create command to generate a token for the gitadmin user:

$token = (C:\gittogallery\gitea-server\gitea.exe admin user generate-access-token --username 'sam.sung' --scopes all --token-name mytoken) -split ": " | Select-Object -Last 1

$orgBody = @{ username = 'my_team'; visibility = 'private' } | ConvertTo-Json
$orgParams = @{
    Uri         = 'https://gittogallery:4443/api/v1/orgs'
    Method      = 'Post'
    ContentType = 'application/json'
    Body        = $orgBody
    Headers     = @{ Authorization = "token $token" }
}
Invoke-RestMethod @orgParams


# ============================================================
# STEP 24 — Add Users to an Organisation                       (~2 min) # optional
# ============================================================
# Users can be added to teams within the organisation.
#
# Web UI:
#   Navigate to the org → Settings → Teams
#   Choose a team (e.g. "Owners" or create a new one)
#   → Add Team Member → enter username → Add
#
# To add LDAP users: they must log in once first so their Gitea account exists.
# LDAP Group Sync (Step 16) automates this for mapped groups.


# ============================================================
# STEP 25 — Create Certificates Repo in the Organisation       (~2 min)
# ============================================================
# Create the Certificates repo under the my_team organisation.
#
# --- OPTION A: REST API ---

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

# Or via Gitea CLI (tea):
# tea repo create --name Certificates --owner my_team

# --- OPTION B: UI Walkthrough ---
# Navigate to https://gittogallery:4443/my_team
#   + (top-right) → New Repository
#     Owner:           my_team (select from dropdown)
#     Repository Name: Certificates
#     Visibility:      Public (or Private)
#     Description:     PowerShell module for certificate management
#     Default Branch:  main
#   → Create Repository
#
# Verify: https://gittogallery:4443/my_team/Certificates


# ============================================================
# STEP 26 — Import the Certificates Module                     (~4 min)
# ============================================================
# The Certificates module source is pre-copied to C:\gittogallery\module\Certificates on the VM.
# Push it to Gitea as a new repo under the organisation.

Set-Location C:\gittogallery\module\Certificates

# Initialise git and push to Gitea
git init
git checkout -b main
git add .
git commit -m "Initial commit — Certificates module"
git remote add origin https://gittogallery:4443/my_team/Certificates.git
git push -u origin main

# Verify in Gitea: https://gittogallery:4443/my_team/Certificates
# The repo should show the module structure:
#   Certificates/        — module source (psd1, psm1, Public/, Private/)
#   tests/               — Pester tests
#   build.ps1            — build entry point
#   psakeFile.ps1        — psake build tasks
#   requirements.psd1    — build dependencies


# ============================================================
# STEP 27 — Windows act_runner Setup                           (~8 min)
# ============================================================
# The binary is at C:\gittogallery\gitea-act_runner\act_runner.exe
# Important!: Never run an act_runner on the same machine as a gitea server in production — this is just for demo purposes. 
# In production, runners should be on separate machines to isolate them from the server. A act_runner machine is disposable. Action can manipulate the machine its running on.

# 1. Create a private repo in Gitea (Web UI):
#    Log in as gitadmin → + → New Repository → Visibility: Private

# 2. Get a runner registration token:
#    Site Administration → Runners → Create runner token → copy it

# 3. Generate and patch config.yaml
Set-Location C:\gittogallery\gitea-act_runner

.\act_runner.exe generate-config | Out-File config.yaml -Encoding UTF8

# Set capacity to 2 parallel jobs
(Get-Content config.yaml) -replace '  capacity: \d+', '  capacity: 2' |
Set-Content config.yaml -Encoding UTF8

# Replace labels with Windows host label
$cfg = Get-Content config.yaml -Raw
$cfg = [regex]::Replace($cfg, '(?s)(  labels:)(\s*- ".*?")+', "  labels:`n    - `"windows:host`"")
Set-Content config.yaml $cfg -Encoding UTF8 -NoNewline

# 4. Register the runner (replace <TOKEN> with your token)
$registerArgs = @(
    'register'
    '--config', 'config.yaml'
    '--instance', 'https://gittogallery:4443'
    '--token', '82hLQubY84Y4n2BmIvrsD7xKxHcnVHDfMI8CyjcP'
    '--name', 'windows-runner'
    '--no-interactive'
)
.\act_runner.exe @registerArgs

# 5. Test as a foreground process first
.\act_runner.exe daemon --config config.yaml
# Verify in Gitea: Site Administration → Runners → status should be Online
# Press Ctrl+C once confirmed

# 6. Register as a Windows service using NSSM
#    NSSM handles the working directory, log rotation, and service lifecycle
#    better than sc.exe for binaries not designed as native Windows services.
C:\gittogallery\scripts\Install-ActRunnerService.ps1

# 7. Verify
Get-Service act_runner


# ============================================================
# STEP 28 — Nexus Repository Setup                             (~6 min)
# ============================================================
# Nexus is at C:\gittogallery\nexus\

# The nexus_8443.conf was already deployed to C:\tools\nginx-1.29.7\conf\conf.d\ in Step 5.
# Replace the hostname placeholder:
$nexusConfPath = 'C:\tools\nginx-1.29.7\conf\conf.d\nexus_8443.conf'
$content = (Get-Content $nexusConfPath) -replace '<HOSTNAME>', 'gittogallery'
$content | Set-Content $nexusConfPath

Restart-Service nginx

# Bind Nexus to loopback — edit nexus-default.properties:
#   C:\gittogallery\nexus\nexus-3.89.0-09\etc\nexus-default.properties
#
#   application-port=8081
#   application-host=127.0.0.1

# Install Nexus as a Windows service
cmd /c 'C:\gittogallery\nexus\nexus-3.90.1-01\bin\install-nexus-service.bat'

# Start and verify
Start-Service SonatypeNexusRepository
Get-Service SonatypeNexusRepository

# Tail the log — wait for "Started Sonatype Nexus"
Get-Content "C:\gittogallery\nexus\sonatype-work\nexus3\log\nexus.log" -Wait -Tail 20

# Get the initial admin password
Get-Content "C:\gittogallery\nexus\sonatype-work\nexus3\admin.password"

# First login: http://localhost:8081
#   Username: admin
#   Password: (from above)
#   Setup wizard:
#     1. Next
#     2. New password: test123! → Next
#     3. Enable anonymous access → Next (if you don't allow anonymous, you will need to use credentials when registering the repos as PSRepositories)
#     4. Finish
#
# Set Base URL: Administration → System → HTTP → Base URL
#   https://gittogallery:8443


# ============================================================
# STEP 29 — Create psgallery-private Repository                (~2 min)
# ============================================================
# --- OPTION A: REST API (used in this demo) ---
# Create nuget (hosted) repository via REST API
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

# Verify in UI: Administration → Repositories → psgallery-private
# URL: https://gittogallery:8443/repository/psgallery-private/

# --- OPTION B: UI Walkthrough ---
# Administration → Repositories → Create repository → nuget (hosted)
#   Name:              psgallery-private
#   Blob store:        default
#   Deployment policy: Allow redeploy
#   Cleanup policies:  (leave unset)
# Click "Create repository"


# ============================================================
# STEP 30 — Register PowerShell Repository                     (~2 min)
# ============================================================
# Register the psgallery-private repository in PowerShell so you can install
# modules from it without using the full URL each time.

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


# ============================================================
# STEP 31 — Connect Nexus to LDAP                              (~3 min)
# ============================================================
# Two options: run the REST API calls below (Option A) or follow
# the commented UI walkthrough (Option B) — both produce the same result.
# The Nexus Swagger UI is at https://gittogallery:8443/#admin/system/api
#
# --- OPTION A: REST API (used in this demo) ---

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

# Verify in UI: Administration → Security → LDAP → lldap should appear

# --- OPTION B: UI Walkthrough ---
# Navigate to Administration (gear icon) → Security → LDAP → Create connection
#
# Connection tab:
#   Name:              lldap
#   Protocol:          ldap
#   Hostname:          localhost
#   Port:              3890
#   Base DN:           dc=demo,dc=local
#   Authentication:    Simple Authentication
#   Username or DN:    uid=gitea-bind,ou=people,dc=demo,dc=local
#   Password:          test123!
# Click "Verify connection" → confirm success → Next
#
# User and group tab:
#   Template:              Generic LDAP Server
#   User Relative DN:      ou=people
#   User subtree:          unchecked
#   Object class:          person
#   User filter:           (leave empty)
#   Username attribute:    uid
#   Real name attribute:   cn
#   Email attribute:       mail
#   Password attribute:    (leave blank)
#   Enable user synchronisation: checked
# Click "Verify login" to test credentials
#
# Check "Map LDAP groups as roles":
#   Group type:            Static Groups
#   Group relative DN:     ou=groups
#   Group subtree:         unchecked
#   Group object class:    groupOfUniqueNames
#   Group ID attribute:    cn
#   Group member attribute: member
#   Group member format:   uid=${username},ou=people,dc=demo,dc=local
# Click "Verify user mapping" → Create


# ============================================================
# STEP 32 — Map LDAP engineers to nx-admin                     (~1 min)
# ============================================================
# --- OPTION A: REST API (used in this demo) ---
# Map LDAP engineers → nx-admin
$engineersBody = @{
    id          = 'engineers'
    name        = 'ldap-engineers'
    description = 'LDAP engineers mapped to nx-admin'
    privileges  = @()
    roles       = @('nx-admin')
} | ConvertTo-Json

$engineersRoleParams = @{
    Uri         = "$nexusBase/service/rest/v1/security/roles"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $engineersBody
}
Invoke-RestMethod @engineersRoleParams

# Verify in UI: Administration → Security → Roles → ldap-engineers

# --- OPTION B: UI Walkthrough ---
# LDAP Role Mapping (engineers → nx-admin):
#    Administration → Security → Roles → Create Role → External Role Mapping
#      External role type:  LDAP
#      Mapped role:         engineers
#      Role ID:             ldap-engineers
#      Role name:           ldap-engineers
#      Role description:    Maps LDAP engineers group to Nexus administrator access
#      Applied Roles:       nx-admin
#    Click "Create role"


# ============================================================
# STEP 33 — Create PowerUsers role and map LDAP devs           (~2 min)
# ============================================================
# --- OPTION A: REST API (used in this demo) ---
# Create PowerUsers role with specific privileges
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

$powerUsersRoleParams = @{
    Uri         = "$nexusBase/service/rest/v1/security/roles"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $powerUsersBody
}
Invoke-RestMethod @powerUsersRoleParams

# Map LDAP devs → PowerUsers
$devsBody = @{
    id          = 'ldap-devs'
    name        = 'ldap-devs'
    description = 'LDAP devs mapped to PowerUsers'
    privileges  = @()
    roles       = @('PowerUsers')
} | ConvertTo-Json

$devsRoleParams = @{
    Uri         = "$nexusBase/service/rest/v1/security/roles"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $devsBody
}
Invoke-RestMethod @devsRoleParams

# Verify in UI: Administration → Security → Roles

# --- OPTION B: UI Walkthrough ---
# 1. PowerUsers Nexus Role:
#    Administration → Security → Roles → Create Role → Nexus Role
#      Role ID:             PowerUsers
#      Role name:           PowerUsers
#      Role description:    Browse/read, NuGet API key, publish to psgallery-private
#      Privileges:
#        - nx-repository-view-*-*-browse
#        - nx-repository-view-*-*-read
#        - nx-repository-view-nuget-psgallery-private-edit
#        - nx-repository-admin-nuget-psgallery-private-edit
#        - nx-apikey-all
#    Click "Save"
#
# 2. LDAP Role Mapping (devs → PowerUsers):
#    Administration → Security → Roles → Create Role → External Role Mapping
#      External role type:  LDAP
#      Mapped role:         devs
#      Role ID:             ldap-devs
#      Role name:           ldap-devs
#      Role description:    Maps LDAP devs group to PowerUsers role
#      Applied Roles:       PowerUsers
#    Click "Create role"


# ============================================================
# STEP 34 — Enable NuGet API Key Realm                         (~1 min)
# ============================================================
# --- OPTION A: REST API (used in this demo) ---
# Get current active realms and add the NuGet API-Key realm
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

# Verify in UI: Administration → Security → Realms → NuGetApiKey should be Active

# --- OPTION B: UI Walkthrough ---
# Administration → Security → Realms
# Move "NuGet API-Key Realm" from Available to Active → Save


# ============================================================
# STEP 35 — End-to-End: Publish a Module                       (~5 min)
# ============================================================

# 1. Generate a NuGet API Key
#    Log in to Nexus as a devs group member (e.g. sam.sung)
#    Profile → NuGet API Key → Access API Key → copy

# 2. Add as Gitea Actions secret
#    Gitea → Certificates repo → Settings → Actions → Secrets
#    Name:  NEXUS_NUGET_API_KEY
#    Value: <paste key>

# 3. Run the publish pipeline from Gitea Actions
#    (Make sure you register the psgallery-private repository in the build scripts (Step 36) before running the pipeline, 
#    otherwise the publish will fail because it won't find the repository to publish to, 
#    as the act runner is now running under a different user context that doesn't have the repository registered.)
#    Go to certificates repo → Actions → release.yml → Run workflow againt main 
#    The pipeline runs Pester tests then publishes to psgallery-private

# 4. Verify in Nexus: Browse → psgallery-private → Certificates module


# ============================================================
# STEP 36 — Add a Private Gallery Dependency                   (~3 min)
# ============================================================
# Edit Certificates.psd1:
#   RequiredModules = @('ImportCertificate')

# Edit requirements.psd1:
#   'ImportCertificate' = @{ Version = 'latest' }

# Bump version in Certificates.psd1:
#   ModuleVersion = '0.2.0'

# Commit and push → pipeline fails because ImportCertificate
# doesn't exist in psgallery-private (only on public PSGallery).


# ============================================================
# STEP 37 — Fix: PSGallery Proxy + Group Repository            (~5 min)
# ============================================================

# Get the PSGallery NuGet v2 feed URL
Get-PSRepository -Name PSGallery | Select-Object -ExpandProperty SourceLocation

# --- OPTION A: REST API (used in this demo) ---
# Create nuget (proxy) for PSGallery via REST API
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

$proxyRepoParams = @{
    Uri         = "$nexusBase/service/rest/v1/repositories/nuget/proxy"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $proxyBody
}
Invoke-RestMethod @proxyRepoParams

# Verify the proxy
$proxyRegParams = @{
    Name               = 'psgallery-proxy'
    SourceLocation     = 'https://gittogallery:8443/repository/psgallery-proxy/'
    InstallationPolicy = 'Trusted'
}
Register-PSRepository @proxyRegParams

Find-Module Pester -Repository psgallery-proxy

# Create nuget (group) combining hosted + proxy via REST API
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

$groupRepoParams = @{
    Uri         = "$nexusBase/service/rest/v1/repositories/nuget/group"
    Method      = 'Post'
    Headers     = $nexusAuth
    ContentType = $contentType
    Body        = $groupBody
}
Invoke-RestMethod @groupRepoParams

# Verify the group
$groupRegParams = @{
    Name               = 'PSGallery-Group'
    SourceLocation     = 'https://gittogallery:8443/repository/psgallery-group/'
    PublishLocation    = 'https://gittogallery:8443/repository/psgallery-private/'
    InstallationPolicy = 'Trusted'
}
Register-PSRepository @groupRegParams

Find-Module Pester -Repository PSGallery-Group

# --- OPTION B: UI Walkthrough ---
# 1. PSGallery-Proxy (NuGet proxy):
#    Administration → Repositories → Create repository → nuget (proxy)
#      Name:             PSGallery-Proxy
#      Protocol version: NuGet V2
#      Remote storage:   https://www.powershellgallery.com/api/v2
#      Blob store:       default
#    Click "Create repository"
#
# 2. psgallery-group (NuGet group):
#    Administration → Repositories → Create repository → nuget (group)
#      Name:               psgallery-group
#      Blob store:         default
#      Member repositories: psgallery-private, PSGallery-Proxy
#    Click "Create repository"


# ============================================================
# STEP 38 — Update Build Scripts & Re-run Pipeline             (~5 min)
# ============================================================
# In psakeFile.ps1, change:
#   $PSBPreference.Publish.PSRepository = 'psgallery-group'
#
# In build.ps1, replace the repository registration with:
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

# Commit and push. The pipeline now succeeds:
#   1. Registers psgallery-group on the runner
#   2. Runs Pester tests
#   3. Publishes to psgallery-private, resolves ImportCertificate via the proxy
#
# Full cycle complete!


# ============================================================
# STEP 39 — Linux Act Runner (Docker in WSL)                   (~10 min) # optional
# ============================================================
# Runs Gitea Actions workflows inside Linux Docker containers via WSL2 Ubuntu.
# Two images are involved:
#   1. Runner daemon  — gitea/act_runner:latest (official image from Gitea).
#      This is the orchestrator. It polls Gitea for jobs, manages registration,
#      and launches sibling job containers via the mounted Docker socket.
#   2. Job container  — macinally/act_runner:latest (custom image, built from the dockerfile below).
#      This is where your workflow steps actually execute. When a workflow
#      requests the "ubuntu-pwsh" label, the runner spins up a container from
#      this image. It is based on Ubuntu 24.04 and comes with PowerShell 7,
#      Node.js, Git, and curl pre-installed — everything needed to run the
#      Certificates module build pipeline on Linux.
#
# The dockerfile is fully customisable. Add any tools your build needs:
#   - Python, .NET SDK, Go, Ruby
#   - Linting tools, static analysers
#   - Additional PowerShell modules
#   - Custom build frameworks
# Simply edit the dockerfile, rebuild the image, and your workflows pick it up.
#
# Folder: C:\gittogallery\configs\docker\linux_act_runner
#
#   .env          — Environment variables consumed by compose.yaml:
#                   GITEA_INSTANCE_URL           = https://gittogallery:4443
#                   GITEA_RUNNER_REGISTRATION_TOKEN = <paste token here>
#                   GITEA_RUNNER_NAME            = Linux-Act-Runner
#                   GITEA_RUNNER_LABELS          = ubuntu-pwsh:docker://macinally/act_runner:latest
#                   The label format is  name:docker://image  — it tells the runner which
#                   Docker image to launch when a workflow's runs-on matches that label.
#
#   compose.yaml  — Docker Compose service definition for the runner daemon.
#                   Key volume mounts:
#                     /var/run/docker.sock  → lets the runner create sibling job containers
#                     ./config.yaml         → runner configuration (see below)
#                     /etc/ssl/certs/ca-certificates.crt (read-only) → WSL's CA bundle,
#                       so the runner daemon trusts the self-signed Gitea/Nexus certificates.
#
#   config.yaml   — Act runner configuration controlling runtime behaviour:
#                   - log level (info), job concurrency (1), job timeout (3h)
#                   - insecure: false (TLS verification enabled — requires valid CA chain)
#                   - container.options: mounts the CA bundle into every job container and
#                     sets NODE_EXTRA_CA_CERTS so Node.js also trusts our root CA.
#                   - valid_volumes: whitelists /etc/ssl/certs/ca-certificates.crt so
#                     the mount is permitted.
#                   - labels: can override .env labels (commented out by default).
#
#   dockerfile    — Defines the custom job image (macinally/act_runner:latest).
#                   Base: Ubuntu 24.04
#                   Installs: PowerShell 7, Node.js (LTS), Git, curl, wget, ca-certificates.
#                   This image does NOT run the act_runner daemon — it is the environment
#                   where workflow job steps execute. Think of it like a GitHub-hosted runner
#                   image, but you control exactly what is installed.
#
# Certificate Trust Chain (required for self-signed certs):
#   The build pipeline connects to Gitea (clone) and Nexus (publish) over HTTPS.
#   With self-signed certificates, each layer must trust the root CA:
#     WSL host           → Install-rootCA-to-wsl-ca-certificates.ps1 (Step 39.1 below)
#     Runner daemon      → compose.yaml mounts WSL's /etc/ssl/certs/ca-certificates.crt
#     Job containers     → config.yaml container.options mounts the same CA bundle
#   Without this chain, git clone and Invoke-RestMethod calls fail with SSL errors.
#
# Prerequisites:
#   A Gitea runner registration token is required.
#   Obtain one from: Site Administration → Actions → Runners → Create new Runner.
#   Paste the token into .env as GITEA_RUNNER_REGISTRATION_TOKEN.

# 1. Install root CA into WSL's certificate store:
C:\gittogallery\scripts\Install-rootCA-to-wsl-ca-certificates.ps1

# 2. Open Explorer → C:\gittogallery\configs\docker\linux_act_runner → address bar → type "wsl" → Enter

# 3. Start the runner:
#    docker compose up -d
#    The macinally/act_runner:latest image is published on Docker Hub.
#    docker compose will pull it automatically on first run — no build required.
#    To pull it manually:  docker pull macinally/act_runner:latest

# 4. (Optional) Build a custom job image if you modify the dockerfile:
#    docker build -t macinally/act_runner:latest .

# Important — Label Precedence:
#   .env GITEA_RUNNER_LABELS is only used during initial registration. 
#   Label in .env is only used if labels in config.yaml are empty or commented out. If config.yaml labels are set, they take precedence over .env and .runner file labels at daemon startup.
#   The .runner file (in the data folder) caches the labels from registration.
#   Since Gitea 1.21, non-empty labels in config.yaml override the .runner file
#   at daemon startup — the runner picks them up on restart without re-registering.
#   If config.yaml labels are empty (or commented out), the .runner file labels are used.
#   To force a full re-registration, delete the data folder.

Go to your certificates repo and add ubuntu-pwsh to the runs-on section of the CI.yml or release.yml workflow:
runs-on: ubuntu-pwsh

Then commit and push. The runner should pick up the new label and run the workflow in a container based on the macinally/act_runner:latest image, which has PowerShell 7 and other tools pre-installed.


# ============================================================
# STEP 40 — Windows Act Runner (Docker Container)              (~10 min) # optional
# ============================================================
# Runs Gitea Actions workflows inside Windows Docker containers.
# Unlike the Linux runner (Step 39), this is a single-image design:
#   The act_runner.exe binary is baked directly into the container image.
#   The container registers itself, then runs the daemon — all in one process.
#   Jobs execute on the host (inside the container), not in nested containers.
#
# Base image: mcr.microsoft.com/windows/server:windows-ltsc
# The dockerfile installs PowerShell 7, Chocolatey, Git, and Node.js during
# build, so workflows have those tools available immediately.
#
# The runner is NOT ephemeral (GITEA_EPHEMERAL=0). Each container registers
# once, then runs the daemon indefinitely, picking up jobs as they arrive.
# The container restarts automatically (restart: unless-stopped) and can
# survive host reboots without re-registration.
#
# Folder: C:\gittogallery\configs\docker\windows_act_runner
#
#   .env              — Environment variables consumed by docker-compose.yml:
#                        GITEA_REGISTRATION_TOKEN = <paste token here>
#                        This is the only secret. Do not commit real values.
#
#   docker-compose.yml — Docker Compose service definition.
#                        Runs 2 replicas by default (deploy.replicas: 2).
#                        Environment variables:
#                          GITEA_INSTANCE           = https://gittogallery:4443
#                          GITEA_REGISTRATION_TOKEN = from .env
#                          GITEA_RUNNER_NAME        = win-docker
#                          GITEA_EPHEMERAL          = 0 (persistent runner)
#                          GITEA_LABELS             = windows2025:host,windows-latest:host
#                        Volume mount:
#                          ./certs → C:/Certs (read-only) — for root CA trust.
#
#   dockerfile         — Builds the custom runner image (macinally/act_runner:windows-ltsc).
#                        FROM mcr.microsoft.com/windows/server:ltsc2025
#                        Installs: PowerShell 7 (via install-pwsh.ps1), Chocolatey,
#                        Git, Node.js.
#                        Copies act_runner.exe and entrypoint.ps1 into C:/runner.
#                        ENTRYPOINT runs entrypoint.ps1 via pwsh.
#
#   entrypoint.ps1     — Container startup script. Handles:
#                        1. Certificate trust — imports any .crt/.pem files from
#                           C:\Certs into the Windows Trusted Root store.
#                        2. Label processing — defaults to
#                           "windows-2025:host,windows-latest:host,windows:host".
#                           Custom labels from GITEA_LABEL are normalised to
#                           ensure each ends with ":host".
#                        3. Runner registration — calls act_runner.exe register
#                           with --no-interactive. Adds --ephemeral only when
#                           GITEA_EPHEMERAL is set to 1/true/yes/y/on.
#                        4. Security — removes GITEA_REGISTRATION_TOKEN from the
#                           environment after registration so it is not exposed
#                           to workflow steps.
#                        5. Daemon — calls act_runner.exe daemon to start
#                           polling for jobs.
#
#   install-pwsh.ps1   — Downloads and installs the latest PowerShell 7 release
#                        from GitHub into $env:ProgramData\pwsh and adds it to PATH.
#
#   act_runner.exe     — The Gitea act_runner binary. Only needed if building
#                        the image locally (see optional build step below).
#                        Download from: https://gitea.com/gitea/act_runner/releases
#
# Certificate Trust Chain (required for self-signed certs):
#   The Windows runner connects to Gitea over HTTPS. With self-signed
#   certificates, the container must trust the root CA:
#     1. Place your rootCA.pem (or .crt) file in the certs/ subdirectory.
#     2. docker-compose.yml mounts ./certs → C:/Certs (read-only).
#     3. entrypoint.ps1 imports all .crt/.pem files from C:\Certs into
#        Cert:\LocalMachine\Root on container startup.
#   Without this, git clone and HTTPS calls inside workflows will fail
#   with SSL/TLS trust errors.
#
# Label Format:
#   Labels use the ":host" scheme because jobs execute directly inside
#   the container (not in nested Docker containers). The format is:
#     <label-name>:host
#   For example: windows-latest:host, windows2025:host
#   When a workflow specifies runs-on: windows-latest, Gitea matches it
#   to a runner with the "windows-latest" label and the job runs on
#   the container's host environment.
#
# Prerequisites:
#   1. Docker Desktop for Windows must be running with Windows containers enabled.
#   2. A Gitea runner registration token is required.
#      Obtain one from: Site Administration → Actions → Runners → Create new Runner.
#      Paste the token into .env as GITEA_REGISTRATION_TOKEN.
#   3. (Optional) Place rootCA.pem in a certs/ subdirectory for self-signed certs.

# The macinally/act_runner:windows-ltsc image is published on Docker Hub.
# docker compose will pull it automatically on first run — no build required.
# To pull it manually:  docker pull macinally/act_runner:windows-ltsc

# 1. Create .env file with the registration token (if not already present):
#    GITEA_REGISTRATION_TOKEN=<TOKEN>

# 2. (Optional) Place rootCA.pem (or .crt) in certs/ subdirectory
#    for self-signed certificate trust.

Set-Location C:\gittogallery\configs\docker\windows_act_runner

# 3. Start the runners (2 replicas by default):
docker compose up -d

# 4. (Optional) Scale up to more replicas:
docker compose up -d --scale gitea-runner=4

# 5. Verify: Site Administration → Runners → should show Online.

# 6. (Optional) Build a custom image if you modify the dockerfile:
#    docker build -t macinally/act_runner:windows-ltsc .
#    Requires act_runner.exe in the windows_act_runner folder.
#    Download from: https://gitea.com/gitea/act_runner/releases

# To add windows-latest to your workflow, set runs-on:
#   runs-on: windows-latest
# or
#   runs-on: windows2025
# Then commit and push. The Windows runner will pick up the job.
