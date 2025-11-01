# =============================================================================
# Модуль: CryptoProCertMigrator
# Файл: CPCertMigrator.psm1
# Назначение: PowerShell модуль для экспорта и импорта сертификатов/контейнеров
#             CryptoPro CSP для областей LocalMachine и CurrentUser.
# Автор: zeroday
# =============================================================================

# Вспомогательная функция для проверки прав администратора
function Test-AdminRights {
    # Получаем текущего пользователя и проверяем его роль
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Вспомогательная функция для проверки установки CryptoPro CSP
function Test-CryptoProCSP {
    <#
    .SYNOPSIS
    Проверяет, установлен ли CryptoPro CSP в системе.
    
    .DESCRIPTION
    Функция использует несколько методов для определения наличия CryptoPro CSP:
    - Проверка CSP провайдеров через WMI
    - Проверка записей в реестре
    - Проверка ГОСТ алгоритмов в системе
    
    .OUTPUTS
    Возвращает объект с информацией о статусе CryptoPro CSP
    #>
    
    $result = @{
        IsInstalled = $false
        Version     = "Не определена"
        Method      = "Не найден"
        Details     = @()
    }
    
    # Метод 1: Проверка через WMI (CSP провайдеры)
    try {
        $cspProviders = Get-WmiObject -Class Win32_CSPProvider -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "*Crypto*Pro*" -or $_.Name -like "*ГОСТ*" }
        if ($cspProviders) {
            $result.IsInstalled = $true
            $result.Method = "WMI CSP провайдеры"
            $result.Details += $cspProviders.Name
        }
    }
    catch {
        Write-Verbose "WMI проверка не удалась: $($_.Exception.Message)"
    }
    
    # Метод 2: Проверка через реестр
    if (-not $result.IsInstalled) {
        try {
            $regPath = "HKLM:\SOFTWARE\Crypto Pro"
            if (Test-Path $regPath) {
                $result.IsInstalled = $true
                $result.Method = "Реестр Windows"
                
                # Пытаемся получить версию
                $versionPath = "$regPath\Settings\Base CSP"
                if (Test-Path $versionPath) {
                    $version = Get-ItemProperty -Path $versionPath -Name "Version" -ErrorAction SilentlyContinue
                    if ($version) {
                        $result.Version = $version.Version
                    }
                }
                $result.Details += "Найден в $regPath"
            }
        }
        catch {
            Write-Verbose "Проверка реестра не удалась: $($_.Exception.Message)"
        }
    }
    
    # Метод 3: Проверка ГОСТ алгоритмов
    if (-not $result.IsInstalled) {
        try {
            $gostRegPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg"
            if (Test-Path $gostRegPath) {
                $gostAlgorithms = Get-ChildItem $gostRegPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like "*1.2.643*" }
                if ($gostAlgorithms) {
                    $result.IsInstalled = $true
                    $result.Method = "ГОСТ алгоритмы"
                    $result.Details += "Найдены ГОСТ OID в системе"
                }
            }
        }
        catch {
            Write-Verbose "Проверка ГОСТ алгоритмов не удалась: $($_.Exception.Message)"
        }
    }
    
    return $result
}

# Вспомогательная функция для клонирования SecureString
function Copy-SecureString {
    param(
        [SecureString]$SecureString
    )
    
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        return ConvertTo-SecureString -String $plainText -AsPlainText -Force
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

# Вспомогательная функция для валидации PFX файла
function Test-PfxFile {
    param(
        [string]$FilePath,        # Путь к PFX файлу
        [SecureString]$Password,  # Пароль для расшифровки (защищенная строка)
        [switch]$SkipValidation   # Пропустить валидацию (для отладки)
    )
    
    if ($SkipValidation) {
        Write-Verbose "⚠️  Валидация PFX пропущена по запросу"
        return $true
    }
    
    try {
        Write-Verbose "Проверяем PFX файл: $FilePath"
        
        # Пытаемся открыть PFX файл с указанным паролем
        $cert = Get-PfxCertificate -FilePath $FilePath -Password $Password -ErrorAction Stop
        
        if ($cert) {
            Write-Verbose "✅ PFX файл корректен. Субъект: $($cert.Subject)"
            return $true
        }
        else {
            Write-Verbose "❌ PFX файл не содержит сертификат"
            return $false
        }
    }
    catch {
        # Если не удалось открыть - файл поврежден или неверный пароль
        Write-Verbose "❌ Ошибка валидации PFX: $($_.Exception.Message)"
        Write-Verbose "   Файл: $FilePath"
        Write-Verbose "   Размер файла: $((Get-Item $FilePath -ErrorAction SilentlyContinue).Length) байт"
        return $false
    }
}

# Вспомогательная функция для генерации умных имен файлов
function Get-SmartFileName {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    # Извлекаем CN из Subject и очищаем от недопустимых символов
    $subject = $Certificate.Subject -replace 'CN=([^,]+).*', '$1' -replace '[\\\/:\*\?\"<>|]', '_'
    # Берем первые 8 символов серийного номера для уникальности
    $serial = $Certificate.SerialNumber.Substring(0, [Math]::Min(8, $Certificate.SerialNumber.Length))
    
    # Если Subject пустой, используем только серийный номер
    if ([string]::IsNullOrEmpty($subject)) {
        return "Cert_$serial"
    }
    
    # Возвращаем комбинацию Subject и серийного номера
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
        [SecureString] $Password,

        [Parameter()]
        [int] $MinDaysRemaining = 0,

        [Parameter()]
        [string] $SubjectFilter = "",

        [Parameter()]
        [string] $IssuerFilter = "",

        [Parameter()]
        [switch] $ShowProgress
    )

    Write-Verbose "Начинаем операцию экспорта сертификатов"
    Write-Verbose "Область: $Scope, Папка экспорта: $ExportFolder, Мин. дней до истечения: $MinDaysRemaining"
    
    # Проверяем параметры
    if ($null -eq $Password -or $Password.Length -eq 0) {
        throw "Пароль не может быть пустым"
    }
    
    # Для SecureString проверяем длину через преобразование
    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    if ($passwordText.Length -lt 4) {
        Write-Warning "Пароль очень короткий. Рекомендуется использовать более надежный пароль."
    }
    # Очищаем временную переменную с паролем
    $passwordText = $null

    # Проверяем права администратора для области LocalMachine
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        $errorMsg = "Для работы с областью LocalMachine требуются права администратора. Запустите PowerShell от имени администратора."
        Write-Error $errorMsg -Category PermissionDenied -ErrorAction Stop
    }

    # Проверяем путь к хранилищу сертификатов
    $storePath = "Cert:\$Scope\My"
    Write-Verbose "Путь к хранилищу сертификатов: $storePath"
    
    if (-not (Test-Path $storePath)) {
        $errorMsg = "Путь к хранилищу сертификатов '$storePath' не найден. Убедитесь, что CryptoPro CSP установлен."
        Write-Error $errorMsg -Category ObjectNotFound -ErrorAction Stop
    }

    # Создаем папку для экспорта при необходимости
    if (-not $WhatIfPreference) {
        if (-not (Test-Path $ExportFolder)) {
            try {
                Write-Verbose "Создаем папку для экспорта: $ExportFolder"
                New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
                Write-Verbose "Папка для экспорта успешно создана"
            }
            catch {
                $errorMsg = "Не удалось создать папку для экспорта '$ExportFolder': $($_.Exception.Message)"
                Write-Error $errorMsg -Category WriteError -ErrorAction Stop
            }
        }
        else {
            Write-Verbose "Папка для экспорта уже существует: $ExportFolder"
        }
    }

    # Получаем сертификаты с применением фильтров
    Write-Verbose "Получаем сертификаты из хранилища..."
    try {
        $allCertificates = Get-ChildItem -Path $storePath -ErrorAction Stop
        Write-Verbose "Найдено $($allCertificates.Count) сертификатов в хранилище"
    }
    catch {
        $errorMsg = "Не удалось получить доступ к хранилищу сертификатов '$storePath': $($_.Exception.Message)"
        Write-Error $errorMsg -Category ReadError -ErrorAction Stop
    }

    # Применяем фильтр по дате
    $certificates = $allCertificates | Where-Object { $_.NotAfter -gt (Get-Date).AddDays($MinDaysRemaining) }
    Write-Verbose "После фильтра по дате (>$MinDaysRemaining дней): $($certificates.Count) сертификатов"

    # Применяем фильтр по Subject
    if ($SubjectFilter) {
        $beforeCount = $certificates.Count
        $certificates = $certificates | Where-Object { $_.Subject -like "*$SubjectFilter*" }
        Write-Verbose "После фильтра по Subject '$SubjectFilter': $($certificates.Count) сертификатов (отфильтровано: $($beforeCount - $certificates.Count))"
    }

    # Применяем фильтр по Issuer
    if ($IssuerFilter) {
        $beforeCount = $certificates.Count
        $certificates = $certificates | Where-Object { $_.Issuer -like "*$IssuerFilter*" }
        Write-Verbose "После фильтра по Issuer '$IssuerFilter': $($certificates.Count) сертификатов (отфильтровано: $($beforeCount - $certificates.Count))"
    }

    $totalCerts = $certificates.Count
    Write-Host "Найдено $totalCerts сертификатов для экспорта" -ForegroundColor Green
    
    if ($totalCerts -eq 0) {
        Write-Warning "Ни один сертификат не соответствует указанным критериям. Операция экспорта отменена."
        return
    }

    if ($WhatIfPreference) {
        Write-Host "Предварительный просмотр: будут экспортированы следующие сертификаты:"
        $certificates | ForEach-Object {
            $smartName = Get-SmartFileName -Certificate $_
            Write-Host "  - Субъект: $($_.Subject)"
            Write-Host "    Отпечаток: $($_.Thumbprint)"
            Write-Host "    Файл: $smartName.pfx"
            Write-Host "    Истекает: $($_.NotAfter)"
            Write-Host ""
        }
        return
    }

    # Подготавливаемся к экспорту
    Write-Verbose "Используем защищенный пароль..."
    $pwdSecure = $Password
    
    $logFile = Join-Path -Path $ExportFolder -ChildPath "ExportPfxLog.csv"
    Write-Verbose "Создаем файл журнала: $logFile"
    "Дата_Время,Область,Имя_Контейнера,Отпечаток,Субъект,Путь_Файла,Статус,Детали" | Out-File -FilePath $logFile -Encoding UTF8

    $counter = 0
    $successCount = 0
    $errorCount = 0
    Write-Verbose "Начинаем экспорт $totalCerts сертификатов..."
    $certificates | ForEach-Object {
        $cert = $_
        $counter++
        $thumb = $cert.Thumbprint
        $smartName = Get-SmartFileName -Certificate $cert
        $filePath = Join-Path -Path $ExportFolder -ChildPath ("{0}.pfx" -f $smartName)

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($counter / $totalCerts) * 100)
            Write-Progress -Activity "Экспорт сертификатов" -Status "Обрабатываем $smartName" -PercentComplete $percentComplete
        }

        Write-Verbose "Экспортируем: Область=$Scope, Сертификат=$smartName, Отпечаток=$thumb, Файл=$filePath"

        # Проверяем, существует ли файл с таким именем
        if (Test-Path $filePath) {
            $filePath = Join-Path -Path $ExportFolder -ChildPath ("{0}_{1}.pfx" -f $smartName, $thumb.Substring(0, 8))
        }

        try {
            Write-Verbose "Экспортируем сертификат в: $filePath"
            $cert | Export-PfxCertificate -FilePath $filePath -Password $pwdSecure -Force -ErrorAction Stop
            
            # Проверяем успешность экспорта
            if (Test-Path $filePath) {
                $fileSize = (Get-Item $filePath).Length
                Write-Verbose "Экспорт успешен. Размер файла: $fileSize байт"
                $successCount++
            }
            else {
                throw "PFX файл не был создан"
            }
            
            $line = ("{0},{1},{2},{3},{4},{5},Успешно," -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            $errorCount++
            $detail = $_.Exception.Message.Replace(",", ";")
            $line = ("{0},{1},{2},{3},{4},{5},Ошибка,{6}" -f (Get-Date -Format s), $Scope, $smartName, $thumb, $cert.Subject, $filePath, $detail)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
            
            Write-Warning "Не удалось экспортировать сертификат '$smartName'"
            Write-Verbose "Детали ошибки экспорта: $($_.Exception.Message)"
            
            # Дополнительный контекст ошибки
            if ($_.Exception.Message -like "*access*denied*" -or $_.Exception.Message -like "*доступ*запрещен*") {
                Write-Verbose "Возможная причина: Недостаточно прав или сертификат не экспортируемый"
            }
            elseif ($_.Exception.Message -like "*password*" -or $_.Exception.Message -like "*пароль*") {
                Write-Verbose "Возможная причина: Не соблюдены требования к сложности пароля"
            }
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Экспорт сертификатов" -Completed
    }

    # Итоговая сводка
    Write-Verbose "Операция экспорта завершена"
    Write-Verbose "Всего обработано: $counter сертификатов"
    Write-Verbose "Успешных экспортов: $successCount"
    Write-Verbose "Неудачных экспортов: $errorCount"
    Write-Verbose "Файл журнала: $logFile"
    
    if ($errorCount -eq 0) {
        Write-Host "✅ Экспорт успешно завершен! Экспортировано $successCount сертификатов." -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Экспорт завершен с проблемами. Успешно: $successCount, Ошибок: $errorCount" -ForegroundColor Yellow
    }
    
    Write-Host "📄 Файл журнала: $logFile" -ForegroundColor Gray
}

function Import-CryptoProCertificates {
    <#
    .SYNOPSIS
    Импортирует сертификаты CryptoPro CSP из PFX файлов.

    .DESCRIPTION
    Функция импортирует сертификаты из PFX файлов в указанное хранилище (CurrentUser или LocalMachine).
    Использует прямой метод импорта для максимальной надежности. Поддерживает проверку дубликатов и создает подробные логи операций.

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
        [SecureString] $Password,

        [Parameter()]
        [switch] $ShowProgress,

        [Parameter()]
        [switch] $SkipExisting
    )

    # Проверяем права администратора для области LocalMachine
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        throw "Для работы с областью LocalMachine требуются права администратора"
    }

    $targetStore = "Cert:\$Scope\My"
    
    # Получаем PFX файлы
    $pfxFiles = Get-ChildItem -Path $ImportFolder -Filter *.pfx
    $totalFiles = $pfxFiles.Count
    
    Write-Host "Найдено $totalFiles PFX файлов для импорта"

    if ($totalFiles -eq 0) {
        Write-Warning "PFX файлы не найдены в папке $ImportFolder"
        return
    }

    # Используем прямой импорт без предварительной проверки (надежный метод)
    Write-Host "Будем импортировать все найденные PFX файлы прямым методом" -ForegroundColor Cyan
    $validFiles = $pfxFiles

    if ($WhatIfPreference) {
        Write-Host "Предварительный просмотр: будут импортированы следующие файлы:"
        $validFiles | ForEach-Object {
            Write-Host "  - Файл: $($_.Name)"
            Write-Host "    Размер: $([math]::Round($_.Length / 1KB, 2)) КБ"
            Write-Host ""
        }
        return
    }

    # Получаем существующие сертификаты для проверки дубликатов
    $existingCerts = @{}
    if ($SkipExisting) {
        Get-ChildItem -Path $targetStore | ForEach-Object {
            $existingCerts[$_.Thumbprint] = $true
        }
    }

    $pwdSecure = $Password
    $logFile = Join-Path -Path $ImportFolder -ChildPath "ImportPfxLog.csv"
    "Дата_Время,Область,Имя_Файла,Отпечаток,Субъект,Статус,Детали" | Out-File -FilePath $logFile -Encoding UTF8

    $counter = 0
    $imported = 0
    $skipped = 0

    $validFiles | ForEach-Object {
        $file = $_.FullName
        $fileName = $_.Name
        $counter++

        if ($ShowProgress) {
            $percentComplete = [math]::Round(($counter / $validFiles.Count) * 100)
            Write-Progress -Activity "Импорт сертификатов" -Status "Обрабатываем $fileName" -PercentComplete $percentComplete
        }

        Write-Verbose "Импортируем: Область=$Scope, Файл=$file"

        try {
            Write-Verbose "Импортируем файл: $file"
            
            # Импортируем сертификат напрямую (как в рабочем скрипте)
            $importedCert = Import-PfxCertificate -FilePath $file -CertStoreLocation $targetStore -Password $pwdSecure -Exportable -ErrorAction Stop
            
            # Проверяем дубликаты после импорта
            if ($SkipExisting -and $existingCerts.ContainsKey($importedCert.Thumbprint)) {
                # Удаляем только что импортированный дубликат
                Remove-Item -Path "$targetStore\$($importedCert.Thumbprint)" -ErrorAction SilentlyContinue
                $line = ("{0},{1},{2},{3},{4},Пропущен,Сертификат уже существует" -f (Get-Date -Format s), $Scope, $fileName, $importedCert.Thumbprint, $importedCert.Subject)
                $line | Out-File -FilePath $logFile -Append -Encoding UTF8
                $skipped++
                Write-Verbose "Пропущен существующий сертификат: $($importedCert.Subject)"
                return
            }
            
            # Успешный импорт
            $line = ("{0},{1},{2},{3},{4},Успешно," -f (Get-Date -Format s), $Scope, $fileName, $importedCert.Thumbprint, $importedCert.Subject)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
            $imported++
            Write-Verbose "✅ Успешно импортирован: $($importedCert.Subject)"
        }
        catch {
            $detail = $_.Exception.Message.Replace(",", ";")
            $line = ("{0},{1},{2},,Ошибка,{3}" -f (Get-Date -Format s), $Scope, $fileName, $detail)
            $line | Out-File -FilePath $logFile -Append -Encoding UTF8
            Write-Warning "Не удалось импортировать $fileName : $($_.Exception.Message)"
        }
    }

    if ($ShowProgress) {
        Write-Progress -Activity "Импорт сертификатов" -Completed
    }

    Write-Host "Импорт завершен. Импортировано: $imported, Пропущено: $skipped. Журнал: $logFile"
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

    # Проверяем права администратора для области LocalMachine
    if ($Scope -eq "LocalMachine" -and -not (Test-AdminRights)) {
        throw "Для работы с областью LocalMachine требуются права администратора"
    }

    $storePath = "Cert:\$Scope\My"
    
    # Получаем сертификаты с фильтрацией по дате
    $certificates = Get-ChildItem -Path $storePath |
    Where-Object { $_.NotAfter -gt (Get-Date).AddDays($MinDaysRemaining) }

    # Применяем фильтр по Subject если указан
    if ($SubjectFilter) {
        $certificates = $certificates | Where-Object { $_.Subject -like "*$SubjectFilter*" }
    }

    # Применяем фильтр по Issuer если указан
    if ($IssuerFilter) {
        $certificates = $certificates | Where-Object { $_.Issuer -like "*$IssuerFilter*" }
    }

    # Возвращаем сертификаты с русскими названиями полей
    $certificates | Select-Object @{
        Name       = 'Субъект'
        Expression = { $_.Subject }
    }, @{
        Name       = 'Издатель'
        Expression = { $_.Issuer }
    }, @{
        Name       = 'Отпечаток'
        Expression = { $_.Thumbprint }
    }, @{
        Name       = 'Действителен_с'
        Expression = { $_.NotBefore }
    }, @{
        Name       = 'Действителен_до'
        Expression = { $_.NotAfter }
    }, @{
        Name       = 'Дней_осталось'
        Expression = { [math]::Round(($_.NotAfter - (Get-Date)).TotalDays) }
    }, @{
        Name       = 'Есть_закрытый_ключ'
        Expression = { $_.HasPrivateKey }
    }, @{
        Name       = 'Понятное_имя'
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
    Включает предварительную проверку системы и отображение статуса сертификатов.
    Подходит для пользователей, которые предпочитают пошаговый интерфейс.

    .EXAMPLE
    Start-CryptoProCertMigrator
    
    Запускает интерактивное меню с опциями:
    1. Просмотр сертификатов
    2. Экспорт сертификатов  
    3. Импорт сертификатов
    4. Быстрая миграция CurrentUser -> LocalMachine
    5. Повторить проверку системы

    .NOTES
    Требует установленный CryptoPro CSP.
    Для операций с LocalMachine необходимы права администратора.
    Автоматически проверяет состояние системы при запуске.
    Показывает количество сертификатов в каждом хранилище.
    Меню работает в цикле до выбора пункта "Выход".
    #>
    [CmdletBinding()]
    param()

    # Получение статуса системы для отображения в шапке
    function Get-SystemStatus {
        $status = @{
            IsAdmin       = Test-AdminRights
            UserCerts     = @{ Count = 0; Error = $null }
            MachineCerts  = @{ Count = 0; Error = $null }
            CryptoPro     = @{ IsInstalled = $false; Version = "Не определена"; Error = $null }
            ModuleVersion = (Get-Module CPCertMigrator).Version.ToString()
        }
        
        # Проверка CurrentUser
        try {
            $userCerts = Get-CryptoProCertificates -Scope CurrentUser -ErrorAction Stop
            $status.UserCerts.Count = $userCerts.Count
        }
        catch {
            $status.UserCerts.Error = $_.Exception.Message
        }
        
        # Проверка LocalMachine (если есть права)
        if ($status.IsAdmin) {
            try {
                $machineCerts = Get-CryptoProCertificates -Scope LocalMachine -ErrorAction Stop
                $status.MachineCerts.Count = $machineCerts.Count
            }
            catch {
                $status.MachineCerts.Error = $_.Exception.Message
            }
        }
        
        # Проверка CryptoPro CSP
        try {
            $cspStatus = Test-CryptoProCSP
            $status.CryptoPro.IsInstalled = $cspStatus.IsInstalled
            $status.CryptoPro.Version = $cspStatus.Version
        }
        catch {
            $status.CryptoPro.Error = $_.Exception.Message
        }
        
        return $status
    }

    # Предварительное тестирование системы (подробный вывод)
    function Test-SystemStatus {
        Write-Host "=== ПРОВЕРКА СИСТЕМЫ ===" -ForegroundColor Cyan
        Write-Host ""
        
        $status = Get-SystemStatus
        
        # Проверка прав администратора
        if ($status.IsAdmin) {
            Write-Host "Права администратора: Есть" -ForegroundColor Green
        }
        else {
            Write-Host "Права администратора: Нет (ограниченный функционал)" -ForegroundColor Yellow
        }
        
        # Проверка CurrentUser
        Write-Host "Проверка хранилища CurrentUser..." -ForegroundColor Gray
        if ($status.UserCerts.Error) {
            Write-Host "CurrentUser: Ошибка доступа - $($status.UserCerts.Error)" -ForegroundColor Red
        }
        else {
            Write-Host "CurrentUser: найдено $($status.UserCerts.Count) сертификатов" -ForegroundColor Green
        }
        
        # Проверка LocalMachine
        Write-Host "Проверка хранилища LocalMachine..." -ForegroundColor Gray
        if (-not $status.IsAdmin) {
            Write-Host "LocalMachine: Недоступно (нужны права администратора)" -ForegroundColor Yellow
        }
        elseif ($status.MachineCerts.Error) {
            Write-Host "LocalMachine: Ошибка доступа - $($status.MachineCerts.Error)" -ForegroundColor Red
        }
        else {
            Write-Host "LocalMachine: найдено $($status.MachineCerts.Count) сертификатов" -ForegroundColor Green
        }
        
        # Проверка CryptoPro CSP
        Write-Host "Проверка CryptoPro CSP..." -ForegroundColor Gray
        if ($status.CryptoPro.Error) {
            Write-Host "CryptoPro CSP: Ошибка проверки - $($status.CryptoPro.Error)" -ForegroundColor Red
        }
        elseif ($status.CryptoPro.IsInstalled) {
            Write-Host "CryptoPro CSP: Установлен" -ForegroundColor Green
            if ($status.CryptoPro.Version -ne "Не определена") {
                Write-Host "Версия: $($status.CryptoPro.Version)" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "CryptoPro CSP: Не найден или не установлен" -ForegroundColor Red
            Write-Host "Для работы модуля требуется установка CryptoPro CSP" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
    
    do {
        Clear-Host
        
        # Получаем статус системы
        $systemStatus = Get-SystemStatus
        
        # Шапка с информацией о системе
        Write-Host "=== CryptoPro Certificate Migrator v$($systemStatus.ModuleVersion) ===" -ForegroundColor Cyan
        Write-Host ""
        
        # Статус администратора
        if ($systemStatus.IsAdmin) {
            Write-Host "Статус: Администратор" -ForegroundColor Green
        }
        else {
            Write-Host "Статус: Пользователь" -ForegroundColor Yellow
        }
        
        # CurrentUser сертификаты
        if ($systemStatus.UserCerts.Error) {
            Write-Host "CurrentUser: недоступно" -ForegroundColor Red
        }
        else {
            Write-Host "CurrentUser: $($systemStatus.UserCerts.Count) сертификатов" -ForegroundColor Green
        }
        
        # LocalMachine сертификаты
        if (-not $systemStatus.IsAdmin) {
            Write-Host "LocalMachine: недоступно (нужны права администратора)" -ForegroundColor Yellow
        }
        elseif ($systemStatus.MachineCerts.Error) {
            Write-Host "LocalMachine: недоступно" -ForegroundColor Red
        }
        else {
            Write-Host "LocalMachine: $($systemStatus.MachineCerts.Count) сертификатов" -ForegroundColor Green
        }
        
        # CryptoPro CSP статус
        if ($systemStatus.CryptoPro.Error) {
            Write-Host "CryptoPro CSP: ошибка проверки" -ForegroundColor Red
        }
        elseif ($systemStatus.CryptoPro.IsInstalled) {
            Write-Host "CryptoPro CSP: установлен" -ForegroundColor Green
        }
        else {
            Write-Host "CryptoPro CSP: не установлен" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "1. Просмотр сертификатов" -ForegroundColor Green
        Write-Host "2. Экспорт сертификатов" -ForegroundColor Yellow
        Write-Host "3. Импорт сертификатов" -ForegroundColor Yellow
        Write-Host "4. Быстрая миграция (CurrentUser -> LocalMachine)" -ForegroundColor Magenta
        Write-Host "5. Повторить проверку системы" -ForegroundColor Blue
        Write-Host "0. Выход" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Выберите действие (0-5)"
        
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
                    
                    # Автоматическое создание папки если она не существует
                    if (-not (Test-Path $folder)) {
                        try {
                            Write-Host "Создаем папку: $folder" -ForegroundColor Yellow
                            New-Item -ItemType Directory -Path $folder -Force | Out-Null
                            Write-Host "✅ Папка успешно создана" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "❌ Не удалось создать папку: $($_.Exception.Message)" -ForegroundColor Red
                            Read-Host "Нажмите Enter для продолжения"
                            continue
                        }
                    }
                    else {
                        Write-Host "✅ Папка существует: $folder" -ForegroundColor Green
                    }
                    
                    $password = Read-Host "Пароль для PFX файлов" -AsSecureString
                    
                    try {
                        Export-CryptoProCertificates -Scope $scope -ExportFolder $folder -Password $password -ShowProgress
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
                    
                    # Проверка существования папки для импорта
                    if (-not (Test-Path $folder)) {
                        Write-Host "❌ Папка не существует: $folder" -ForegroundColor Red
                        Write-Host "Создайте папку или укажите существующую папку с PFX файлами" -ForegroundColor Yellow
                        Read-Host "Нажмите Enter для продолжения"
                        continue
                    }
                    else {
                        $pfxCount = (Get-ChildItem -Path $folder -Filter "*.pfx" -ErrorAction SilentlyContinue).Count
                        if ($pfxCount -eq 0) {
                            Write-Host "⚠️  В папке нет PFX файлов: $folder" -ForegroundColor Yellow
                            $confirm = Read-Host "Продолжить импорт? (y/N)"
                            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                                continue
                            }
                        }
                        else {
                            Write-Host "✅ Найдено PFX файлов: $pfxCount в папке $folder" -ForegroundColor Green
                        }
                    }
                    
                    # Прямой импорт (надежный метод)
                    Write-Host ""
                    Write-Host "Импорт будет выполнен прямым методом (без предварительной проверки)" -ForegroundColor Cyan
                    $password = Read-Host "Введите пароль для PFX файлов" -AsSecureString

                    
                    try {
                        Import-CryptoProCertificates -Scope $scope -ImportFolder $folder -Password $password -ShowProgress -SkipExisting
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
                    $passwordText = "TempMigration$(Get-Random -Minimum 100000 -Maximum 999999)"
                    $password = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
                    
                    try {
                        Write-Host "Экспортируем из CurrentUser..." -ForegroundColor Yellow
                        Export-CryptoProCertificates -Scope CurrentUser -ExportFolder $tempFolder -Password $password -ShowProgress
                        
                        # Клонируем пароль для импорта, чтобы избежать проблем с повторным использованием
                        $importPassword = Copy-SecureString -SecureString $password
                        
                        Write-Host "Импортируем в LocalMachine..." -ForegroundColor Yellow
                        Import-CryptoProCertificates -Scope LocalMachine -ImportFolder $tempFolder -Password $importPassword -ShowProgress -SkipExisting
                        
                        Write-Host "Удаляем временные файлы..." -ForegroundColor Yellow
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
            "5" {
                # Повторная проверка системы
                Test-SystemStatus
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