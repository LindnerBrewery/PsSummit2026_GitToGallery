# Install rootCA.pem into WSL Ubuntu's CA certificate store

$sourcePem = "C:\gittogallery\certs\rootCA.pem"
# We have to change the filename to .crt for it to be recognized as a certificate by the CA store update process
$wslCertName = "rootCA.crt"
$wslCertDest = "/usr/local/share/ca-certificates/$wslCertName"

# Check if the certificate is already installed and trusted
$verifyResult = wsl -e sh -c "openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt $wslCertDest 2>&1"
if ($verifyResult -match ': OK$') {
    Write-Host "Root CA is already installed and trusted in the WSL CA store. Everything is configured."
    return
}

# Convert Windows path to WSL path
$wslSourcePath = wsl wslpath -u $sourcePem.Replace('\', '\\')

# Copy the cert into the WSL CA directory and update the store
wsl -e sh -c "sudo cp '$wslSourcePath' '$wslCertDest' && sudo update-ca-certificates"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Certificate installed successfully and CA store updated."

    # Validate the certificate is trusted by the system bundle
    $verifyResult = wsl -e sh -c "openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt $wslCertDest 2>&1"
    if ($verifyResult -match ': OK$') {
        Write-Host "Validation passed: $verifyResult"
    }
    else {
        Write-Warning "Certificate installed but verification failed: $verifyResult"
    }
}
else {
    Write-Error "Failed to install certificate. Exit code: $LASTEXITCODE"
}