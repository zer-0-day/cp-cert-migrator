#Requires -Version 5.1

# CryptoPro Certificate Migrator Launcher
# Версия: 1.8.2

param(
    [switch]$Version
)

if ($Version) {
    Write-Host "CryptoPro Certificate Migrator v1.8.2"
    exit 0
}

# Проверка PowerShell версии
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "ОШИБКА: Требуется PowerShell 5.1 или выше!" -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

# Встроенный модуль CPCertMigrator будет здесь при компиляции
# Для разработки загружаем из файла
try {
    if (Test-Path ".\CPCertMigrator.psm1") {
        Import-Module ".\CPCertMigrator.psm1" -Force
        Start-CryptoProCertMigrator
    } else {
        Write-Host "Модуль CPCertMigrator не найден" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода"
    }
} catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
}