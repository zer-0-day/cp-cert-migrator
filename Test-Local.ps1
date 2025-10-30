# Локальное тестирование модуля CPCertMigrator

# Импорт модуля
Import-Module .\CPCertMigrator.psd1 -Force

# Проверка функций
Write-Host "=== Доступные функции ===" -ForegroundColor Cyan
Get-Command -Module CPCertMigrator

# Проверка манифеста
Write-Host "`n=== Проверка манифеста ===" -ForegroundColor Cyan
Test-ModuleManifest .\CPCertMigrator.psd1

# Тест основных функций (безопасно)
Write-Host "`n=== Тест просмотра сертификатов ===" -ForegroundColor Cyan
try {
    $certs = Get-CryptoProCertificates -Scope CurrentUser -ErrorAction Stop
    Write-Host "Найдено сертификатов: $($certs.Count)" -ForegroundColor Green
} catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
}

# Тест интерактивного меню (закомментировано для автоматического запуска)
# Write-Host "`n=== Запуск интерактивного меню ===" -ForegroundColor Cyan
# Start-CryptoProCertMigrator

Write-Host "`nТестирование завершено!" -ForegroundColor Green