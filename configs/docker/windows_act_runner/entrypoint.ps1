$ErrorActionPreference = 'Stop'



# Optional: install provided CA/root (or self-signed server cert) into Trusted Root.
if ((Get-ChildItem -Path C:\Certs\* -Include '*.crt','*.pem').Count -gt 0){
    Write-Host "Installing provided root/CA certificates into Trusted Root store..."
    $certs = Get-ChildItem -Path C:\Certs\* -Include '*.crt','*.pem', '*.crt'
    foreach ($cert in $certs) {
        try {    
            Import-Module PKI -ErrorAction Stop
            Import-Certificate -FilePath $cert.FullName -CertStoreLocation 'Cert:\LocalMachine\Root' -ErrorAction stop | Out-Null
            Write-Host "Trusted root installed from file: $($cert.FullName) via Import-Certificate."
        } catch {
            throw "Failed to import trusted root certificate from file $($cert.FullName): $_"
        }
    }
}else{
    Write-Host "No root/CA certificates provided to install."
    Write-Host "If you want to install custom root/CA certificates, mount them into C:\Certs as .crt or .pem files. -v C:\path\to\certs:C:\Certs"
}

#check if act_runner is available
if (Test-Path -LiteralPath "./act_runner.exe") {
    $exe = Resolve-Path -LiteralPath "./act_runner.exe"
}else{
    Write-Error "act_runner.exe not found in current directory. Please make sure it is present."
    exit 1
}

$instance = $env:GITEA_INSTANCE
$token = $env:GITEA_REGISTRATION_TOKEN
$label = $env:GITEA_LABEL

# The runner CLI uses `--name` for the runner name shown in Gitea.
$runnerName = $env:GITEA_RUNNER_NAME
if ([string]::IsNullOrWhiteSpace($runnerName)) {
  $runnerName = $env:COMPUTERNAME
}

if ([string]::IsNullOrWhiteSpace($label)) {
  $label = 'windows-2025:host,windows-latest:host,windows:host'   
}else{
  $labels = ($label -split ',').trim()
  $newlabel = foreach ($lbl in $labels) {
    if ($lbl -notmatch ':(?i)host$') {
      $lbl = "$($lbl):host"
      $lbl
    }else{
      $lbl
    }
  }
  $label = $newlabel -join ','
}

if ([string]::IsNullOrWhiteSpace($instance)) {
  throw 'GITEA_INSTANCE is required (e.g. https://gitea.example.com)'
}
if ([string]::IsNullOrWhiteSpace($token)) {
  throw 'GITEA_REGISTRATION_TOKEN is required (runner registration token from Gitea UI)'
}

Write-Host "Registering runner '$runnerName' against instance '$instance'..."
$ephemeralRaw = $env:GITEA_EPHEMERAL
$isEphemeral = $false
if (-not [string]::IsNullOrWhiteSpace($ephemeralRaw)) {
  switch ($ephemeralRaw.Trim().ToLowerInvariant()) {
    '1' { $isEphemeral = $true }
    'true' { $isEphemeral = $true }
    'yes' { $isEphemeral = $true }
    'y' { $isEphemeral = $true }
    'on' { $isEphemeral = $true }
    default { $isEphemeral = $false }
  }
}

$registerArgs = @(
  'register',
  '--no-interactive',
  '--instance', $instance,
  '--token', $token,
  '--name', $runnerName,
  '--labels', $label
)
if ($isEphemeral) {
  $registerArgs += '--ephemeral'
}

& $exe @registerArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-host "Remove resgistration token env variable for security."
Remove-Item Env:\GITEA_REGISTRATION_TOKEN

Write-Host 'Starting runner daemon...'
& ./act_runner.exe daemon
exit $LASTEXITCODE
