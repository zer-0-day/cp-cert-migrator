#Requires -Version 5.1

<#
.SYNOPSIS
CryptoPro Certificate Migrator - Standalone Launcher

.DESCRIPTION
Автономный запускатель для модуля CPCertMigrator.
Встраивает весь модуль и запускает интерактивное меню.

.NOTES
Версия: 1.8.1
Автор: zeroday
Требует: PowerShell 5.1+, CryptoPro CSP
#>

param(
    [Parameter()]
    [switch]$Admin,  # Принудительный запрос прав администратора
    
    [Parameter()]
    [switch]$Version  # Показать версию и выйти
)

# Константы
$ModuleVersion = "1.8.1"
$ModuleName = "CPCertMigrator"

# Функция для проверки и запроса прав администратора
function Request-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "Для полного функционала требуются права администратора." -ForegroundColor Yellow
        Write-Host "Перезапустить с правами администратора? (y/N): " -NoNewline -ForegroundColor Cyan
        $response = Read-Host
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            # Перезапуск с правами администратора
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            exit
        }
    }
    
    return $isAdmin
}

# Функция для отображения заголовка
function Show-Header {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "    CryptoPro Certificate Migrator v$ModuleVersion (Standalone)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Основная функция запуска
function Start-StandaloneMigrator {
    Show-Header
    
    # Проверка версии PowerShell
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "ОШИБКА: Требуется PowerShell 5.1 или выше!" -ForegroundColor Red
        Write-Host "Текущая версия: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
    
    # Проверка прав администратора (если требуется)
    if ($Admin) {
        $isAdmin = Request-AdminRights
        if (-not $isAdmin) {
            Write-Host "Права администратора не получены. Выход." -ForegroundColor Red
            Read-Host "Нажмите Enter для выхода"
            exit 1
        }
    }
    
    Write-Host "Инициализация модуля..." -ForegroundColor Gray
    
    try {
        # Здесь будет встроен весь код модуля
        # Пока загружаем из файла (для разработки)
        if (Test-Path ".\CPCertMigrator.psm1") {
            Import-Module ".\CPCertMigrator.psm1" -Force -ErrorAction Stop
        } else {
            throw "Файл модуля CPCertMigrator.psm1 не найден"
        }
        
        Write-Host "Модуль загружен успешно!" -ForegroundColor Green
        Write-Host ""
        
        # Запуск интерактивного меню
        Start-CryptoProCertMigrator
        
    } catch {
        Write-Host "ОШИБКА при загрузке модуля:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Возможные причины:" -ForegroundColor Yellow
        Write-Host "• CryptoPro CSP не установлен" -ForegroundColor Gray
        Write-Host "• Недостаточно прав доступа" -ForegroundColor Gray
        Write-Host "• Поврежденная установка PowerShell" -ForegroundColor Gray
        Write-Host ""
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
}

# Обработка параметров командной строки
if ($Version) {
    Write-Host "CryptoPro Certificate Migrator v$ModuleVersion" -ForegroundColor Cyan
    Write-Host "Standalone executable version" -ForegroundColor Gray
    exit 0
}

# Запуск основной функции
Start-StandaloneMigrator