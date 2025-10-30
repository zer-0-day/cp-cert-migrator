# =============================================================================
# Module: CryptoProCertMigrator
# File: CPCertMigrator.psm1
# Purpose: PowerShell module to export and import certificates/containers
#          for CryptoPro CSP for both LocalMachine and CurrentUser scopes.
# Version: 1.1.0
# Author: zeroday
# =============================================================================

# Helper function to check administrator privileges
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Helper function to validate PFX file
function Test-PfxFile {
    param(
        [string]$FilePath,
        [string]$Password
    )
    
    try {
        $pwdSecure = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $null = Get-PfxCertificate -FilePath $FilePath -Password $pwdSecure
        return $true
    }
    catch {
        return $false
    }
}

# Helper function to generate smart file names
function Get-SmartFileName {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    $subject = $Certificate.Subject -replace 'CN=([^,]+).*', '$1' -replace '[\\\/:\*\?\"<>|]', '_'
    $serial = $Certificate.SerialNumber.Substring(0, [Math]::Min(8, $Certificate.SerialNumber.Length))
    
    if ([string]::IsNullOrEmpty($subject)) {
        return "Cert_$serial"
    }
    
    return "${subject}_${serial}"
}

function Export-CryptoProCertificates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("LocalMachine", "CurrentUser")]
        [string] $Scope,

        [Parameter(Mandatory = $true)]
        [string] $ExportFolder,

        [Parameter(Mandatory = $true)]
        [string] $Password,

        [Parameter()]
        [int] $MinDaysRemaining = 0,

        [Parameter()]
        [string] $SubjectFilter = "",

        [Parameter()]
        [string] $IssuerFilter = "",

        [Parameter()]
        [switch] $WhatIf,

        [Parameter()]
        [switch] $ShowProgress
    )

    # Check admin rights for LocalMachine scope
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        throw "Administrator privileges required for LocalMachine scope operations"
    }

    $storePath = "Cert:\$Scope\My"

    if (-not (Test-Path $ExportFolder) -and -not $WhatIf) {
        New-Item -ItemType Directory -Path $ExportFolder | Out-Null
    }

    # Get certificates with filters
    $certificates = Get-ChildItem -Path $storePath |
    Where-Object { $_.NotAfter -gt (Get-Date).AddDays($MinDaysRemaining) }

    if ($SubjectFilter) {
        $certificates = $certificates | Where-Object { $_.Subject -like "*$SubjectFilter*" }
    }

    if ($IssuerFilter) {
        $certificates = $certificates | Where-Object { $_.Issuer -like "*$IssuerFilter*" }
    }

    $totalCerts = $certificates.Count
    Write-Host "Found $totalCerts certificates to export"

    if ($WhatIf) {
        Write-Host "WhatIf: Would export the following certificates:"
        $certificates | ForEach-Object {
            $smartName = Get-SmartFileName -Certificate $_
            Write-Host "  - Subject: $($_.Subject)"
            Write-Host "    Thumbprint: $($_.Thumbprint)"
            Write-Host "    File: $smartName.pfx"
            Write-Host "    Expires: $($_.NotAfter)"
            Write-Host ""
        }
        return
    }

    $pwdSecure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $logFile = Join-Path -Path $ExportFolder -ChildPath "ExportPfxLog.csv"
    "DateTime,Scope,ContainerName,Thumbprint,Subject,FilePath,Status,Detail" | Out-File -FilePath $logFile -Encoding UTF8

    $counter = 0
    $certificates | ForEach-Object {
        $cert = $_
        $counter++
        $thumb = $cert.Thumbprint
        $smartName = Get-SmartFileName -Certificate $cert
        $filePath = Join-Path -Path $ExportFolder -ChildPath ("{0}.pfx" -f $smartName)

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($counter / $totalCerts) * 100)
            Write-Progress -Activity "Exporting Certificates" -Status "Processing $smartName" -PercentComplete $percentComplete
        }

        Write-Verbose "Exporting: Scope=$Scope, Cert=$smartName, Thumbprint=$thumb, File=$filePath"

        # Check if file already exists
        if (Test-Path $filePath) {
            $filePath = Join-Path -Path $ExportFolder -ChildPath ("{0}_{1}.pfx" -f $smartName, $thumb.Substring(0, 8))
        }

        try {
            $cert | Export-PfxCertificate -FilePath $filePath -Password $pwdSecure -Force
            $line = ("{0},{1},{2},{3},{4},{5},Success," -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
        catch {
            $detail = $_.Exception.Message.Replace(",", ";")
            $line = ("{0},{1},{2},{3},{4},{5},Failed,{6}" -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath, $detail)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Warning "Failed to export $smartName : $($_.Exception.Message)"
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Exporting Certificates" -Completed
    }

    Write-Host "Export completed. Exported $counter certificates. Log: $logFile"
}

function Import-CryptoProCertificates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("LocalMachine", "CurrentUser")]
        [string] $Scope,

        [Parameter(Mandatory = $true)]
        [string] $ImportFolder,

        [Parameter(Mandatory = $true)]
        [string] $Password,

        [Parameter()]
        [switch] $WhatIf,

        [Parameter()]
        [switch] $ShowProgress,

        [Parameter()]
        [switch] $SkipExisting
    )

    # Check admin rights for LocalMachine scope
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        throw "Administrator privileges required for LocalMachine scope operations"
    }

    $targetStore = "Cert:\$Scope\My"
    
    # Get PFX files
    $pfxFiles = Get-ChildItem -Path $ImportFolder -Filter *.pfx
    $totalFiles = $pfxFiles.Count
    
    Write-Host "Found $totalFiles PFX files to import"

    if ($totalFiles -eq 0) {
        Write-Warning "No PFX files found in $ImportFolder"
        return
    }

    # Validate files first
    Write-Host "Validating PFX files..."
    $validFiles = @()
    $pfxFiles | ForEach-Object {
        if (Test-PfxFile -FilePath $_.FullName -Password $Password) {
            $validFiles += $_
        }
        else {
            Write-Warning "Invalid PFX file or wrong password: $($_.Name)"
        }
    }

    Write-Host "Valid files: $($validFiles.Count) of $totalFiles"

    if ($WhatIf) {
        Write-Host "WhatIf: Would import the following files:"
        $validFiles | ForEach-Object {
            Write-Host "  - File: $($_.Name)"
            Write-Host "    Size: $([math]::Round($_.Length / 1KB, 2)) KB"
            Write-Host ""
        }
        return
    }

    # Get existing certificates for duplicate check
    $existingCerts = @{}
    if ($SkipExisting) {
        Get-ChildItem -Path $targetStore | ForEach-Object {
            $existingCerts[$_.Thumbprint] = $true
        }
    }

    $pwdSecure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $logFile = Join-Path -Path $ImportFolder -ChildPath "ImportPfxLog.csv"
    "DateTime,Scope,FileName,Thumbprint,Subject,Status,Detail" | Out-File -FilePath $logFile -Encoding UTF8

    $counter = 0
    $imported = 0
    $skipped = 0

    $validFiles | ForEach-Object {
        $file = $_.FullName
        $fileName = $_.Name
        $counter++

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($counter / $validFiles.Count) * 100)
            Write-Progress -Activity "Importing Certificates" -Status "Processing $fileName" -PercentComplete $percentComplete
        }

        Write-Verbose "Importing: Scope=$Scope, File=$file"

        try {
            # Get certificate info for duplicate check
            $tempCert = Get-PfxCertificate -FilePath $file -Password $pwdSecure
            
            if ($SkipExisting -and $existingCerts.ContainsKey($tempCert.Thumbprint)) {
                $line = ("{0},{1},{2},{3},{4},Skipped,Certificate already exists" -f (Get-Date -Format s), $Scope, $fileName, $tempCert.Thumbprint, $tempCert.Subject)
                $line | Out-File -FilePath $logFile -Append -Encoding UTF8
                $skipped++
                Write-Verbose "Skipped existing certificate: $($tempCert.Subject)"
                return
            }

            Import-PfxCertificate -FilePath $file -CertStoreLocation $targetStore -Password $pwdSecure -Exportable
            $line = ("{0},{1},{2},{3},{4},Success," -f (Get-Date -Format s), $Scope, $fileName, $tempCert.Thumbprint, $tempCert.Subject)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
            $imported++
        }
        catch {
            $detail = $_.Exception.Message.Replace(",", ";")
            $line = ("{0},{1},{2},,Failed,{3}" -f (Get-Date -Format s), $Scope, $fileName, $detail)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Warning "Failed to import $fileName : $($_.Exception.Message)"
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Importing Certificates" -Completed
    }

    Write-Host "Import completed. Imported: $imported, Skipped: $skipped. Log: $logFile"
}

# New function to list certificates with details
function Get-CryptoProCertificates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("LocalMachine", "CurrentUser")]
        [string] $Scope,

        [Parameter()]
        [int] $MinDaysRemaining = 0,

        [Parameter()]
        [string] $SubjectFilter = "",

        [Parameter()]
        [string] $IssuerFilter = ""
    )

    # Check admin rights for LocalMachine scope
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        throw "Administrator privileges required for LocalMachine scope operations"
    }

    $storePath = "Cert:\$Scope\My"
    
    $certificates = Get-ChildItem -Path $storePath |
    Where-Object { $_.NotAfter -gt (Get-Date).AddDays($MinDaysRemaining) }

    if ($SubjectFilter) {
        $certificates = $certificates | Where-Object { $_.Subject -like "*$SubjectFilter*" }
    }

    if ($IssuerFilter) {
        $certificates = $certificates | Where-Object { $_.Issuer -like "*$IssuerFilter*" }
    }

    $certificates | Select-Object @{
        Name       = 'Subject'
        Expression = { $_.Subject }
    }, @{
        Name       = 'Issuer'
        Expression = { $_.Issuer }
    }, @{
        Name       = 'Thumbprint'
        Expression = { $_.Thumbprint }
    }, @{
        Name       = 'NotBefore'
        Expression = { $_.NotBefore }
    }, @{
        Name       = 'NotAfter'
        Expression = { $_.NotAfter }
    }, @{
        Name       = 'DaysRemaining'
        Expression = { [math]::Round(($_.NotAfter - (Get-Date)).TotalDays) }
    }, @{
        Name       = 'HasPrivateKey'
        Expression = { $_.HasPrivateKey }
    }, @{
        Name       = 'FriendlyName'
        Expression = { $_.FriendlyName }
    }
}

# Interactive menu-driven function
function Start-CryptoProCertMigrator {
    [CmdletBinding()]
    param()

    do {
        Clear-Host
        Write-Host "=== CryptoPro Certificate Migrator ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Просмотр сертификатов" -ForegroundColor Green
        Write-Host "2. Экспорт сертификатов" -ForegroundColor Yellow
        Write-Host "3. Импорт сертификатов" -ForegroundColor Yellow
        Write-Host "4. Быстрая миграция (CurrentUser -> LocalMachine)" -ForegroundColor Magenta
        Write-Host "0. Выход" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Выберите действие (0-4)"
        
        switch ($choice) {
            "1" {
                # Просмотр сертификатов
                Write-Host ""
                Write-Host "Выберите область:" -ForegroundColor Cyan
                Write-Host "1. CurrentUser"
                Write-Host "2. LocalMachine"
                $scopeChoice = Read-Host "Область (1-2)"
                
                $scope = switch ($scopeChoice) {
                    "1" { "CurrentUser" }
                    "2" { "LocalMachine" }
                    default { $null }
                }
                
                if ($scope) {
                    try {
                        $certs = Get-CryptoProCertificates -Scope $scope
                        $certs | Format-Table -AutoSize
                        Write-Host "Всего найдено: $($certs.Count) сертификатов" -ForegroundColor Green
                        Read-Host "Нажмите Enter для продолжения"
                    }
                    catch {
                        Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
                        Read-Host "Нажмите Enter для продолжения"
                    }
                }
            }
            "2" {
                # Экспорт сертификатов
                Write-Host ""
                Write-Host "=== Экспорт сертификатов ===" -ForegroundColor Yellow
                
                Write-Host "Выберите область:" -ForegroundColor Cyan
                Write-Host "1. CurrentUser"
                Write-Host "2. LocalMachine"
                $scopeChoice = Read-Host "Область (1-2)"
                
                $scope = switch ($scopeChoice) {
                    "1" { "CurrentUser" }
                    "2" { "LocalMachine" }
                    default { $null }
                }
                
                if ($scope) {
                    $folder = Read-Host "Папка для экспорта (по умолчанию: $env:USERPROFILE\Desktop\CertExport)"
                    if ([string]::IsNullOrWhiteSpace($folder)) {
                        $folder = "$env:USERPROFILE\Desktop\CertExport"
                    }
                    
                    $password = Read-Host "Пароль для PFX файлов" -AsSecureString
                    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
                    
                    try {
                        Export-CryptoProCertificates -Scope $scope -ExportFolder $folder -Password $passwordText -ShowProgress
                        Write-Host "Экспорт завершен!" -ForegroundColor Green
                        Read-Host "Нажмите Enter для продолжения"
                    }
                    catch {
                        Write-Host "Ошибка экспорта: $($_.Exception.Message)" -ForegroundColor Red
                        Read-Host "Нажмите Enter для продолжения"
                    }
                }
            }
            "3" {
                # Импорт сертификатов
                Write-Host ""
                Write-Host "=== Импорт сертификатов ===" -ForegroundColor Yellow
                
                Write-Host "Выберите область:" -ForegroundColor Cyan
                Write-Host "1. CurrentUser"
                Write-Host "2. LocalMachine"
                $scopeChoice = Read-Host "Область (1-2)"
                
                $scope = switch ($scopeChoice) {
                    "1" { "CurrentUser" }
                    "2" { "LocalMachine" }
                    default { $null }
                }
                
                if ($scope) {
                    $folder = Read-Host "Папка с PFX файлами (по умолчанию: $env:USERPROFILE\Desktop\CertExport)"
                    if ([string]::IsNullOrWhiteSpace($folder)) {
                        $folder = "$env:USERPROFILE\Desktop\CertExport"
                    }
                    
                    $password = Read-Host "Пароль для PFX файлов" -AsSecureString
                    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
                    
                    try {
                        Import-CryptoProCertificates -Scope $scope -ImportFolder $folder -Password $passwordText -ShowProgress -SkipExisting
                        Write-Host "Импорт завершен!" -ForegroundColor Green
                        Read-Host "Нажмите Enter для продолжения"
                    }
                    catch {
                        Write-Host "Ошибка импорта: $($_.Exception.Message)" -ForegroundColor Red
                        Read-Host "Нажмите Enter для продолжения"
                    }
                }
            }
            "4" {
                # Быстрая миграция
                Write-Host ""
                Write-Host "=== Быстрая миграция ===" -ForegroundColor Magenta
                Write-Host "CurrentUser -> LocalMachine" -ForegroundColor Yellow
                Write-Host ""
                
                if (-not (Test-AdminRights)) {
                    Write-Host "ОШИБКА: Требуются права администратора!" -ForegroundColor Red
                    Read-Host "Нажмите Enter для продолжения"
                    continue
                }
                
                $confirm = Read-Host "Продолжить миграцию? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    $tempFolder = "$env:TEMP\CertMigration_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    $password = "TempMigration$(Get-Random -Minimum 100000 -Maximum 999999)"
                    
                    try {
                        Write-Host "Экспорт из CurrentUser..." -ForegroundColor Yellow
                        Export-CryptoProCertificates -Scope CurrentUser -ExportFolder $tempFolder -Password $password -ShowProgress
                        
                        Write-Host "Импорт в LocalMachine..." -ForegroundColor Yellow
                        Import-CryptoProCertificates -Scope LocalMachine -ImportFolder $tempFolder -Password $password -ShowProgress -SkipExisting
                        
                        Write-Host "Очистка временных файлов..." -ForegroundColor Yellow
                        Remove-Item -Path $tempFolder -Recurse -Force
                        
                        Write-Host "Миграция успешно завершена!" -ForegroundColor Green
                        Read-Host "Нажмите Enter для продолжения"
                    }
                    catch {
                        Write-Host "Ошибка миграции: $($_.Exception.Message)" -ForegroundColor Red
                        if (Test-Path $tempFolder) {
                            Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Read-Host "Нажмите Enter для продолжения"
                    }
                }
            }
            "0" {
                Write-Host "До свидания!" -ForegroundColor Green
                break
            }
            default {
                Write-Host "Неверный выбор. Попробуйте снова." -ForegroundColor Red
                Start-Sleep 1
            }
        }
    } while ($choice -ne "0")
}

Export-ModuleMember -Function Export-CryptoProCertificates, Import-CryptoProCertificates, Get-CryptoProCertificates, Start-CryptoProCertMigrator