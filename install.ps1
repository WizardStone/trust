#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet("User", "Machine")]
    [string] $InstallScope
)

$ErrorActionPreference = "Stop"

# Change these values.
$certificateUrl = "https://wizardstone.github.io/trust/WizardStone-CodeSigning.cer"
$expectedThumbprint = "REPLACE_WITH_CERTIFICATE_THUMBPRINT"

$tempCertificate = Join-Path $env:TEMP "WizardStone-CodeSigning.cer"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Show-InstallMenu {
    $options = @(
        "Install for this user only",
        "Install for this PC - requires administrator permission",
        "Cancel installation"
    )

    $selected = 0

    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host

            Write-Host "WizardStone Publisher Certificate Installer" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Use the Up/Down arrow keys to select an option."
            Write-Host "Press Enter to continue or Esc to cancel."
            Write-Host ""

            for ($i = 0; $i -lt $options.Count; $i++) {
                if ($i -eq $selected) {
                    Write-Host "[>] $($options[$i])" -ForegroundColor Black -BackgroundColor White
                }
                else {
                    Write-Host "[ ] $($options[$i])"
                }
            }

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                "UpArrow" {
                    $selected--

                    if ($selected -lt 0) {
                        $selected = $options.Count - 1
                    }
                }

                "DownArrow" {
                    $selected++

                    if ($selected -ge $options.Count) {
                        $selected = 0
                    }
                }

                "Enter" {
                    return $selected
                }

                "Escape" {
                    return 2
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

function Download-And-ValidateCertificate {
    Write-Host "Downloading the WizardStone certificate..." -ForegroundColor Cyan

    Invoke-WebRequest `
        -Uri $certificateUrl `
        -OutFile $tempCertificate `
        -UseBasicParsing

    if (-not (Test-Path $tempCertificate)) {
        throw "The certificate could not be downloaded."
    }

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $tempCertificate
    )

    $actualThumbprint = $certificate.Thumbprint.Replace(" ", "").ToUpperInvariant()
    $expected = $expectedThumbprint.Replace(" ", "").ToUpperInvariant()

    if ($expected -eq "REPLACE_WITH_CERTIFICATE_THUMBPRINT") {
        throw "The expected certificate thumbprint has not been configured."
    }

    if ($actualThumbprint -ne $expected) {
        throw @"
Certificate fingerprint mismatch.

Expected: $expected
Received: $actualThumbprint

The certificate was not installed.
"@
    }

    if ($certificate.NotAfter -lt (Get-Date)) {
        throw "The certificate has expired. It was not installed."
    }

    return $certificate
}

function Install-Certificate {
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory)]
        [ValidateSet("CurrentUser", "LocalMachine")]
        [string]
        $StoreLocation
    )

    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        "TrustedPublisher",
        $StoreLocation
    )

    $store.Open(
        [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite
    )

    try {
        # Avoid adding the same certificate more than once.
        $existing = $store.Certificates |
            Where-Object {
                $_.Thumbprint -eq $Certificate.Thumbprint
            }

        if ($existing) {
            Write-Host "The certificate is already installed." -ForegroundColor Yellow
            return
        }

        $store.Add($Certificate)
    }
    finally {
        $store.Close()
    }
}

function Restart-AsAdministrator {
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath
    )

    Write-Host "Administrator permission is required for installation on this PC." `
        -ForegroundColor Yellow

    $arguments = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", "`"$ScriptPath`""
        "-InstallScope", "Machine"
    )

    try {
        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList $arguments `
            -Verb RunAs `
            -Wait | Out-Null
    }
    catch {
        throw "Administrator permission was not granted. Installation cancelled."
    }
}

try {
    # If no scope was supplied, show the interactive menu.
    if (-not $InstallScope) {
        $choice = Show-InstallMenu

        switch ($choice) {
            0 {
                $InstallScope = "User"
            }

            1 {
                $InstallScope = "Machine"
            }

            2 {
                Clear-Host
                Write-Host "Installation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # The machine option requires an elevated PowerShell process.
    if ($InstallScope -eq "Machine" -and -not (Test-IsAdministrator)) {
        if (-not $PSCommandPath) {
            throw "The script must be saved to a file before using the PC-wide option."
        }

        Restart-AsAdministrator -ScriptPath $PSCommandPath
        exit 0
    }

    Clear-Host

    $certificate = Download-And-ValidateCertificate

    if ($InstallScope -eq "User") {
        Install-Certificate `
            -Certificate $certificate `
            -StoreLocation "CurrentUser"

        Write-Host ""
        Write-Host "Installed for the current user." -ForegroundColor Green
    }
    else {
        Install-Certificate `
            -Certificate $certificate `
            -StoreLocation "LocalMachine"

        Write-Host ""
        Write-Host "Installed for this PC." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Publisher:   $($certificate.Subject)"
    Write-Host "Thumbprint:  $($certificate.Thumbprint)"
    Write-Host "Valid until: $($certificate.NotAfter)"
}
catch {
    Write-Host ""
    Write-Host "Installation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path $tempCertificate) {
        Remove-Item $tempCertificate -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Read-Host "Press Enter to exit"
