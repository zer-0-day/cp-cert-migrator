# Локальное тестирование модуля CPCertMigrator

Write-Host "=== ТЕСТИРОВАНИЕ МОДУЛЯ CPCertMigrator ===" -ForegroundColor Cyan

# Загрузка модуля
Write-Host "Загрузка модуля..." -ForegroundColor Yellow
Import-Module .\CPCertMigrator.psd1 -Force

# Проверка функций
Write-Host "Проверка функций..." -ForegroundColor Yellow
$functions = Get-Command -Module CPCertMigrator
Write-Host "Найдено функций: $($functions.Count)" -ForegroundColor Green

# Проверка манифеста
Write-Host "Проверка манифеста..." -ForegroundColor Yellow
$manifest = Test-ModuleManifest .\CPCertMigrator.psd1
Write-Host "Манифест валиден (версия: $($manifest.Version))" -ForegroundColor Green

# Проверка прав администратора (функция внутренняя, не экспортируется)
Write-Host "Права администратора: проверка пропущена (внутренняя функция)" -ForegroundColor Yellow

# Тест просмотра сертификатов
Write-Host "Тест просмотра сертификатов..." -ForegroundColor Yellow
try {
    $userCerts = Get-CryptoProCertificates -Scope CurrentUser
    Write-Host "CurrentUser: найдено $($userCerts.Count) сертификатов" -ForegroundColor Green
} catch {
    Write-Host "Ошибка CurrentUser: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Тестирование завершено!" -ForegroundColor Green