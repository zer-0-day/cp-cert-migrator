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
    <#
    .SYNOPSIS
    Экспортирует сертификаты CryptoPro CSP в PFX файлы.

    .DESCRIPTION
    Функция экспортирует сертификаты из указанного хранилища (CurrentUser или LocalMachine) 
    в защищенные паролем PFX файлы. Поддерживает фильтрацию по различным критериям и 
    создает подробные логи операций.

    .PARAMETER Scope
    Область хранилища сертификатов: CurrentUser или LocalMachine.
    Для LocalMachine требуются права администратора.

    .PARAMETER ExportFolder
    Путь к папке для сохранения экспортированных PFX файлов.
    Папка будет создана автоматически, если не существует.

    .PARAMETER Password
    Пароль для защиты экспортируемых PFX файлов.

    .PARAMETER MinDaysRemaining
    Минимальное количество дней до истечения сертификата.
    По умолчанию 0 (экспортируются все сертификаты).

    .PARAMETER SubjectFilter
    Фильтр по полю Subject сертификата (поддерживает wildcards).

    .PARAMETER IssuerFilter
    Фильтр по полю Issuer сертификата (поддерживает wildcards).

    .PARAMETER WhatIf
    Режим предварительного просмотра без выполнения операций.

    .PARAMETER ShowProgress
    Показывать индикатор прогресса выполнения.

    .EXAMPLE
    Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\CertBackup" -Password "MySecurePassword"
    
    Экспортирует все сертификаты из пользовательского хранилища.

    .EXAMPLE
    Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass123" -SubjectFilter "MyOrg" -MinDaysRemaining 30 -ShowProgress
    
    Экспортирует сертификаты организации MyOrg, действующие более 30 дней, с индикатором прогресса.

    .EXAMPLE
    Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\Backup" -Password "Pass123" -WhatIf
    
    Предварительный просмотр экспорта из машинного хранилища без выполнения операций.

    .NOTES
    Требует установленный CryptoPro CSP.
    Для работы с LocalMachine необходимы права администратора.
    Создает лог файл ExportPfxLog.csv в папке экспорта.
    #>
    [CmdletBinding(SupportsShouldProcess)]
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

    Write-Verbose "Starting certificate export operation"
    Write-Verbose "Scope: $Scope, ExportFolder: $ExportFolder, MinDaysRemaining: $MinDaysRemaining"
    
    # Validate parameters
    if ([string]::IsNullOrWhiteSpace($Password)) {
        throw "Password cannot be empty or whitespace"
    }
    
    if ($Password.Length -lt 4) {
        Write-Warning "Password is very short. Consider using a stronger password."
    }

    # Check admin rights for LocalMachine scope
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        $errorMsg = "Administrator privileges required for LocalMachine scope operations. Please run PowerShell as Administrator."
        Write-Error $errorMsg -Category PermissionDenied -ErrorAction Stop
    }

    # Validate certificate store path
    $storePath = "Cert:\$Scope\My"
    Write-Verbose "Certificate store path: $storePath"
    
    if (-not (Test-Path $storePath)) {
        $errorMsg = "Certificate store path '$storePath' not found. Please ensure CryptoPro CSP is installed."
        Write-Error $errorMsg -Category ObjectNotFound -ErrorAction Stop
    }

    # Create export folder if needed
    if (-not $WhatIf) {
        if (-not (Test-Path $ExportFolder)) {
            try {
                Write-Verbose "Creating export folder: $ExportFolder"
                New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
                Write-Verbose "Export folder created successfully"
            }
            catch {
                $errorMsg = "Failed to create export folder '$ExportFolder': $($_.Exception.Message)"
                Write-Error $errorMsg -Category WriteError -ErrorAction Stop
            }
        }
        else {
            Write-Verbose "Export folder already exists: $ExportFolder"
        }
    }

    # Get certificates with filters
    Write-Verbose "Retrieving certificates from store..."
    try {
        $allCertificates = Get-ChildItem -Path $storePath -ErrorAction Stop
        Write-Verbose "Found $($allCertificates.Count) total certificates in store"
    }
    catch {
        $errorMsg = "Failed to access certificate store '$storePath': $($_.Exception.Message)"
        Write-Error $errorMsg -Category ReadError -ErrorAction Stop
    }

    # Apply date filter
    $certificates = $allCertificates | Where-Object { $_.NotAfter -gt (Get-Date).AddDays($MinDaysRemaining) }
    Write-Verbose "After date filter (>$MinDaysRemaining days): $($certificates.Count) certificates"

    # Apply subject filter
    if ($SubjectFilter) {
        $beforeCount = $certificates.Count
        $certificates = $certificates | Where-Object { $_.Subject -like "*$SubjectFilter*" }
        Write-Verbose "After Subject filter '$SubjectFilter': $($certificates.Count) certificates (filtered out: $($beforeCount - $certificates.Count))"
    }

    # Apply issuer filter
    if ($IssuerFilter) {
        $beforeCount = $certificates.Count
        $certificates = $certificates | Where-Object { $_.Issuer -like "*$IssuerFilter*" }
        Write-Verbose "After Issuer filter '$IssuerFilter': $($certificates.Count) certificates (filtered out: $($beforeCount - $certificates.Count))"
    }

    $totalCerts = $certificates.Count
    Write-Host "Found $totalCerts certificates to export" -ForegroundColor Green
    
    if ($totalCerts -eq 0) {
        Write-Warning "No certificates match the specified criteria. Export operation cancelled."
        return
    }

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

    # Prepare for export
    Write-Verbose "Converting password to secure string..."
    $pwdSecure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    
    $logFile = Join-Path -Path $ExportFolder -ChildPath "ExportPfxLog.csv"
    Write-Verbose "Creating log file: $logFile"
    "DateTime,Scope,ContainerName,Thumbprint,Subject,FilePath,Status,Detail" | Out-File -FilePath $logFile -Encoding UTF8

    $counter = 0
    $successCount = 0
    $errorCount = 0
    Write-Verbose "Starting export of $totalCerts certificates..."
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
            Write-Verbose "Exporting certificate to: $filePath"
            $cert | Export-PfxCertificate -FilePath $filePath -Password $pwdSecure -Force -ErrorAction Stop
            
            # Verify export success
            if (Test-Path $filePath) {
                $fileSize = (Get-Item $filePath).Length
                Write-Verbose "Export successful. File size: $fileSize bytes"
                $successCount++
            } else {
                throw "PFX file was not created"
            }
            
            $line = ("{0},{1},{2},{3},{4},{5},Success," -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            $errorCount++
            $detail = $_.Exception.Message.Replace(",", ";")
            $line = ("{0},{1},{2},{3},{4},{5},Failed,{6}" -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath, $detail)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
            
            Write-Warning "Failed to export certificate '$smartName'"
            Write-Verbose "Export error details: $($_.Exception.Message)"
            
            # Additional error context
            if ($_.Exception.Message -like "*access*denied*") {
                Write-Verbose "Possible cause: Insufficient permissions or certificate is not exportable"
            }
            elseif ($_.Exception.Message -like "*password*") {
                Write-Verbose "Possible cause: Password complexity requirements not met"
            }
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Exporting Certificates" -Completed
    }

    # Final summary
    Write-Verbose "Export operation completed"
    Write-Verbose "Total processed: $counter certificates"
    Write-Verbose "Successful exports: $successCount"
    Write-Verbose "Failed exports: $errorCount"
    Write-Verbose "Log file: $logFile"
    
    if ($errorCount -eq 0) {
        Write-Host "✅ Export completed successfully! Exported $successCount certificates." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Export completed with issues. Success: $successCount, Failed: $errorCount" -ForegroundColor Yellow
    }
    
    Write-Host "📄 Log file: $logFile" -ForegroundColor Gray
}

function Import-CryptoProCertificates {
    <#
    .SYNOPSIS
    Импортирует сертификаты CryptoPro CSP из PFX файлов.

    .DESCRIPTION
    Функция импортирует сертификаты из PFX файлов в указанное хранилище (CurrentUser или LocalMachine).
    Поддерживает валидацию файлов, проверку дубликатов и создает подробные логи операций.

    .PARAMETER Scope
    Область хранилища сертификатов: CurrentUser или LocalMachine.
    Для LocalMachine требуются права администратора.

    .PARAMETER ImportFolder
    Путь к папке с PFX файлами для импорта.

    .PARAMETER Password
    Пароль для расшифровки PFX файлов.

    .PARAMETER WhatIf
    Режим предварительного просмотра без выполнения операций.

    .PARAMETER ShowProgress
    Показывать индикатор прогресса выполнения.

    .PARAMETER SkipExisting
    Пропускать сертификаты, которые уже существуют в хранилище.

    .EXAMPLE
    Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\CertBackup" -Password "MySecurePassword"
    
    Импортирует все PFX файлы из папки в пользовательское хранилище.

    .EXAMPLE
    Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\Backup" -Password "Pass123" -SkipExisting -ShowProgress
    
    Импортирует сертификаты в машинное хранилище, пропуская существующие, с индикатором прогресса.

    .EXAMPLE
    Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "Pass123" -WhatIf
    
    Предварительный просмотр импорта без выполнения операций.

    .NOTES
    Требует установленный CryptoPro CSP.
    Для работы с LocalMachine необходимы права администратора.
    Создает лог файл ImportPfxLog.csv в папке импорта.
    #>
    [CmdletBinding(SupportsShouldProcess)]
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

function Get-CryptoProCertificates {
    <#
    .SYNOPSIS
    Получает список сертификатов CryptoPro CSP с детальной информацией.

    .DESCRIPTION
    Функция возвращает список сертификатов из указанного хранилища с подробной информацией
    включая Subject, Issuer, сроки действия и статус приватного ключа.
    Поддерживает фильтрацию по различным критериям.

    .PARAMETER Scope
    Область хранилища сертификатов: CurrentUser или LocalMachine.
    Для LocalMachine требуются права администратора.

    .PARAMETER MinDaysRemaining
    Минимальное количество дней до истечения сертификата.
    По умолчанию 0 (показываются все сертификаты).

    .PARAMETER SubjectFilter
    Фильтр по полю Subject сертификата (поддерживает wildcards).

    .PARAMETER IssuerFilter
    Фильтр по полю Issuer сертификата (поддерживает wildcards).

    .EXAMPLE
    Get-CryptoProCertificates -Scope CurrentUser
    
    Получает все сертификаты из пользовательского хранилища.

    .EXAMPLE
    Get-CryptoProCertificates -Scope CurrentUser -MinDaysRemaining 30 -SubjectFilter "MyOrg"
    
    Получает сертификаты организации MyOrg, действующие более 30 дней.

    .EXAMPLE
    Get-CryptoProCertificates -Scope LocalMachine -IssuerFilter "MyCA" | Format-Table
    
    Получает сертификаты от определенного УЦ из машинного хранилища в табличном виде.

    .NOTES
    Требует установленный CryptoPro CSP.
    Для работы с LocalMachine необходимы права администратора.
    Возвращает объекты с полями: Subject, Issuer, Thumbprint, NotBefore, NotAfter, DaysRemaining, HasPrivateKey, FriendlyName.
    #>
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

function Start-CryptoProCertMigrator {
    <#
    .SYNOPSIS
    Запускает интерактивное консольное меню для работы с сертификатами CryptoPro CSP.

    .DESCRIPTION
    Функция предоставляет удобное интерактивное меню для выполнения основных операций
    с сертификатами: просмотр, экспорт, импорт и быстрая миграция между хранилищами.
    Подходит для пользователей, которые предпочитают пошаговый интерфейс.

    .EXAMPLE
    Start-CryptoProCertMigrator
    
    Запускает интерактивное меню с опциями:
    1. Просмотр сертификатов
    2. Экспорт сертификатов  
    3. Импорт сертификатов
    4. Быстрая миграция CurrentUser -> LocalMachine

    .NOTES
    Требует установленный CryptoPro CSP.
    Для операций с LocalMachine необходимы права администратора.
    Меню работает в цикле до выбора пункта "Выход".
    #>
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