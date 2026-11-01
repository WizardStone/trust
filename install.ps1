#requires -Version 5.1

param(
    [ValidateSet("", "CurrentUser", "LocalMachine")]
    [string]$InstallScope = ""
)

$ErrorActionPreference = "Stop"

$certificateUrl = "https://wizardstone.github.io/trust/WizardStone-CodeSigning.cer"
$expectedThumbprint = "30fddb1bb5b5e1ddf37a0c883a65baf18ff404ae"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Select-InstallScope {
    $options = @(
        "Current User",
        "Local Machine",
        "Cancel"
    )

    $selected = 0

    while ($true) {
        Clear-Host
        Write-Host "WizardStone Certificate Installer"
        Write-Host ""

        for ($i = 0; $i -lt $options.Count; $i++) {
            $shortcut = if ($i -eq 2) { "Esc" } else { $i + 1 }

            if ($i -eq $selected) {
                Write-Host "[>$shortcut<] $($options[$i])" -ForegroundColor Cyan
            }
            else {
                Write-Host "[ $shortcut ] $($options[$i])"
            }
        }

        Write-Host ""
        Write-Host "Use Up/Down arrows and Enter, or press 1/2/Esc."

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow" {
                $selected = ($selected - 1 + $options.Count) % $options.Count
            }
            "DownArrow" {
                $selected = ($selected + 1) % $options.Count
            }
            "D1" {
                return "CurrentUser"
            }
            "NumPad1" {
                return "CurrentUser"
            }
            "D2" {
                return "LocalMachine"
            }
            "NumPad2" {
                return "LocalMachine"
            }
            "Enter" {
                if ($selected -eq 0) {
                    return "CurrentUser"
                }

                if ($selected -eq 1) {
                    return "LocalMachine"
                }

                return "Cancel"
            }
            "Escape" {
                return "Cancel"
            }
        }
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($InstallScope)) {
        $InstallScope = Select-InstallScope

        if ($InstallScope -eq "Cancel") {
            Write-Host "Installation cancelled."
            exit 0
        }
    }

    if ($InstallScope -eq "LocalMachine" -and -not (Test-IsAdministrator)) {
        if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
            throw "Local Machine installation requires opening the shell as administrator"
        }

        Write-Host "Administrator permission is required. Requesting elevation..."

        $arguments = @(
            "-NoProfile"
            "-ExecutionPolicy", "Bypass"
            "-File", "`"$PSCommandPath`""
            "-InstallScope", "LocalMachine"
        )

        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList $arguments `
            -Verb RunAs

        exit 0
    }

    $storePath = if ($InstallScope -eq "LocalMachine") {
        "Cert:\LocalMachine\TrustedPublisher"
    }
    else {
        "Cert:\CurrentUser\TrustedPublisher"
    }

    $tempPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        "WizardStone-CodeSigning.cer"

    $expectedThumbprint = $expectedThumbprint.Replace(" ", "").ToUpperInvariant()

    if ($expectedThumbprint -eq "30FDBB1BB5B5E1DDF37A0C883A65BAF18FF404AE") {
        throw "Set `$expectedThumbprint to your certificate thumbprint first."
    }

    Write-Host "Downloading the public certificate..."

    Invoke-WebRequest `
        -Uri $certificateUrl `
        -OutFile $tempPath `
        -UseBasicParsing

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $tempPath
    )

    $actualThumbprint = $certificate.Thumbprint.Replace(" ", "").ToUpperInvariant()

    if ($actualThumbprint -ne $expectedThumbprint) {
        throw @"
Certificate thumbprint mismatch please open an issue on github.

Expected: $expectedThumbprint
Received: $actualThumbprint

The certificate was not installed.
"@
}

    if ($certificate.NotAfter -lt (Get-Date)) {
        throw "The certificate has expired. It was not installed."
    }

    $existing = Get-ChildItem -Path $storePath |
        Where-Object { $_.Thumbprint -eq $actualThumbprint }

    if ($existing) {
        Write-Host "The certificate is already installed in $storePath."
    }
    else {
        Import-Certificate `
            -FilePath $tempPath `
            -CertStoreLocation $storePath | Out-Null

        Write-Host "Certificate installed successfully."
        Write-Host "Store: $storePath"
    }

    Write-Host "Thumbprint: $actualThumbprint"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if ($tempPath -and (Test-Path $tempPath)) {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }
}
