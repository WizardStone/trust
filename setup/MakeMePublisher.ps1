#requires -Version 5.1

$ErrorActionPreference = "Stop"

$publisherName = "User"
$outputDirectory = Join-Path $PSScriptRoot "certificate-output"

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$pfxPath = Join-Path $outputDirectory "User-CodeSigning.pfx"
$cerPath = Join-Path $outputDirectory "User-CodeSigning.cer"

# Prevent accidentally overwriting an existing certificate.
if (Test-Path $pfxPath) {
    throw "The file already exists: $pfxPath`nDelete it or choose a different output directory."
}

if (Test-Path $cerPath) {
    throw "The file already exists: $cerPath`nDelete it or choose a different output directory."
}

Write-Host "Creating a self-signed Authenticode certificate for $publisherName..."

$certificate = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=$publisherName" `
    -FriendlyName "$publisherName Code Signing" `
    -KeyAlgorithm RSA `
    -KeyLength 3072 `
    -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(5)

Write-Host "Certificate created."
Write-Host "Subject:     $($certificate.Subject)"
Write-Host "Issuer:      $($certificate.Issuer)"
Write-Host "Thumbprint:  $($certificate.Thumbprint)"
Write-Host "Valid until: $($certificate.NotAfter)"

# Export the public certificate.
Export-Certificate `
    -Cert $certificate `
    -FilePath $cerPath `
    -Type CERT `
    -Force | Out-Null

# Prompt for a password before exporting the private key.
$pfxPassword = Read-Host `
    "Enter a password to protect the private-key PFX file" `
    -AsSecureString

# Export the certificate and private key.
Export-PfxCertificate `
    -Cert $certificate `
    -FilePath $pfxPath `
    -Password $pfxPassword `
    -Force | Out-Null

# Calculate a separate SHA-256 fingerprint for the public certificate.
$sha256Provider = [System.Security.Cryptography.SHA256]::Create()

try {
    $certificateBytes = [System.IO.File]::ReadAllBytes($cerPath)
    $sha256Bytes = $sha256Provider.ComputeHash($certificateBytes)
    $sha256Fingerprint = ($sha256Bytes | ForEach-Object {
        $_.ToString("X2")
    }) -join ""
}
finally {
    $sha256Provider.Dispose()
}

Write-Host ""
Write-Host "Finished."
Write-Host "Public certificate: $cerPath"
Write-Host "Private-key PFX:    $pfxPath"
Write-Host ""
Write-Host "Normal certificate thumbprint (SHA-1):"
Write-Host $certificate.Thumbprint
Write-Host ""
Write-Host "SHA-256 fingerprint of the .cer file:"
Write-Host $sha256Fingerprint
Write-Host ""
Write-Warning "Publish only the .cer file."
Write-Warning "Never publish, commit, or upload the .pfx file or its password."
