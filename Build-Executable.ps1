#Requires -Version 5.1

<#
.SYNOPSIS
Скрипт для сборки CPCertMigrator в исполняемый файл

.DESCRIPTION
Создает standalone .exe версию модуля CPCertMigrator используя ps2exe
#>

param(
    [Parameter()]
    [string]$OutputPath = ".\dist",
    
    [Parameter()]
    [switch]$SkipInstall  # Пропустить установку ps2exe
)

$ModuleVersion = "1.8.1"

Write-Host "=== Сборка CPCertMigrator v$ModuleVersion в .exe ===" -ForegroundColor Cyan
Write-Host ""

# Проверка и установка ps2exe
if (-not $SkipInstall) {
    Write-Host "Проверка ps2exe..." -ForegroundColor Yellow
    
    if (-not (Get-Module -ListAvailable -Name ps2exe)) {
        Write-Host "Установка ps2exe..." -ForegroundColor Yellow
        try {
            Install-Module -Name ps2exe -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "ps2exe установлен успешно!" -ForegroundColor Green
        } catch {
            Write-Host "ОШИБКА: Не удалось установить ps2exe" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "ps2exe уже установлен" -ForegroundColor Green
    }
}

# Создание папки для сборки
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Создана папка: $OutputPath" -ForegroundColor Green
}

# Создание встроенного launcher'а с модулем
Write-Host "Создание встроенного launcher'а..." -ForegroundColor Yellow

$moduleContent = Get-Content ".\CPCertMigrator.psm1" -Raw -Encoding UTF8
$launcherContent = Get-Content ".\CPCertMigrator-Launcher.ps1" -Raw -Encoding UTF8

# Заменяем загрузку модуля на встроенный код
$embeddedLauncher = $launcherContent -replace 'if \(Test-Path.*?\}', @"
# Встроенный модуль CPCertMigrator
`$moduleCode = @'
$moduleContent
'@

# Загрузка встроенного модуля
Invoke-Expression `$moduleCode
"@

# Сохраняем встроенный launcher
$embeddedLauncherPath = Join-Path $OutputPath "CPCertMigrator-Embedded.ps1"
$embeddedLauncher | Out-File -FilePath $embeddedLauncherPath -Encoding UTF8
Write-Host "Встроенный launcher создан: $embeddedLauncherPath" -ForegroundColor Green

# Импорт ps2exe
Import-Module ps2exe -Force

# Параметры сборки
$buildParams = @{
    inputFile = $embeddedLauncherPath
    outputFile = Join-Path $OutputPath "CPCertMigrator.exe"
    noConsole = $false
    noOutput = $false
    noError = $false
    noVisualStyles = $false
    exitOnCancel = $true
    DPIAware = $true
    winFormsDPIAware = $true
    requireAdmin = $false
    supportOS = $true
    virtualize = $false
    longPaths = $true
}

# Сборка основной версии
Write-Host "Сборка CPCertMigrator.exe..." -ForegroundColor Yellow
try {
    Invoke-ps2exe @buildParams -ErrorAction Stop
    Write-Host "✅ CPCertMigrator.exe создан успешно!" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка сборки основной версии:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# Сборка версии с требованием прав администратора
$buildParams.outputFile = Join-Path $OutputPath "CPCertMigrator-Admin.exe"
$buildParams.requireAdmin = $true

Write-Host "Сборка CPCertMigrator-Admin.exe..." -ForegroundColor Yellow
try {
    Invoke-ps2exe @buildParams -ErrorAction Stop
    Write-Host "✅ CPCertMigrator-Admin.exe создан успешно!" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка сборки admin версии:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# Создание README для релиза
$readmeContent = @"
# CryptoPro Certificate Migrator v$ModuleVersion

## Исполняемые файлы

### CPCertMigrator.exe
- Основная версия для обычных пользователей
- Работает с правами текущего пользователя
- Ограниченный доступ к LocalMachine хранилищу

### CPCertMigrator-Admin.exe  
- Версия с требованием прав администратора
- Полный доступ ко всем функциям
- Рекомендуется для системных администраторов

## Использование

1. Скачайте нужную версию .exe файла
2. Запустите двойным кликом или из командной строки
3. Следуйте инструкциям в интерактивном меню

## Параметры командной строки

```
CPCertMigrator.exe --version    # Показать версию
CPCertMigrator.exe --admin      # Запросить права администратора
```

## Требования

- Windows 7/Server 2008 R2 или выше
- PowerShell 5.1 или выше
- CryptoPro CSP (для работы с сертификатами)

## Функции

- Просмотр сертификатов в CurrentUser и LocalMachine
- Экспорт сертификатов в PFX файлы
- Импорт сертификатов из PFX файлов
- Быстрая миграция между хранилищами
- Проверка состояния системы

## Поддержка

GitHub: https://github.com/zer-0-day/cp-cert-migrator
PowerShell Gallery: https://www.powershellgallery.com/packages/CPCertMigrator
"@

$readmePath = Join-Path $OutputPath "README.txt"
$readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
Write-Host "README создан: $readmePath" -ForegroundColor Green

# Копирование лицензии
if (Test-Path ".\LICENSE") {
    Copy-Item ".\LICENSE" -Destination (Join-Path $OutputPath "LICENSE.txt")
    Write-Host "Лицензия скопирована" -ForegroundColor Green
}

# Итоги сборки
Write-Host ""
Write-Host "=== СБОРКА ЗАВЕРШЕНА ===" -ForegroundColor Cyan
Write-Host "Папка сборки: $OutputPath" -ForegroundColor White
Write-Host "Файлы:" -ForegroundColor White

Get-ChildItem $OutputPath -Filter "*.exe" | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  📦 $($_.Name) ($size MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Готово к релизу! 🎉" -ForegroundColor Green