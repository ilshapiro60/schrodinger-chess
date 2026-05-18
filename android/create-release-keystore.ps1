# One-time setup: Play Store upload keystore + key.properties
# Run from this folder:  .\create-release-keystore.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Test-Path "upload-keystore.jks") {
    Write-Error "upload-keystore.jks already exists. Back it up and delete it only if you intend to replace it."
}

function Read-PlainPassword([string]$prompt) {
    $secure = Read-Host $prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

Write-Host ""
Write-Host "You choose the passwords (not Google/Flutter). Save them in a password manager."
Write-Host ""

$storePass = Read-PlainPassword "Keystore password (store password)"
$keyPassInput = Read-Host "Key password (press Enter to use the same as keystore)"
$keyPass = if ([string]::IsNullOrWhiteSpace($keyPassInput)) { $storePass } else { $keyPassInput }

$dname = Read-Host "Certificate name [Schrodinger Chess]"
if ([string]::IsNullOrWhiteSpace($dname)) { $dname = "Schrodinger Chess" }

Write-Host ""
Write-Host "Creating upload-keystore.jks ..."

& keytool -genkeypair -v `
    -keystore upload-keystore.jks `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias upload `
    -storepass $storePass `
    -keypass $keyPass `
    -dname "CN=$dname, OU=Mobile, O=Pryro Inc, C=US"

$props = @"
storePassword=$storePass
keyPassword=$keyPass
keyAlias=upload
storeFile=upload-keystore.jks
"@

Set-Content -Path key.properties -Value $props -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "  upload-keystore.jks"
Write-Host "  key.properties"
Write-Host ""
Write-Host "Back up both files and your passwords. Then from the project root:"
Write-Host "  flutter build appbundle --release"
Write-Host ""
