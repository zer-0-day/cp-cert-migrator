# Тестовый запуск launcher'а без компиляции

Write-Host "=== Тест CPCertMigrator Launcher ===" -ForegroundColor Cyan
Write-Host ""

# Проверяем, что все файлы на месте
$requiredFiles = @(
    "CPCertMigrator.psm1",
    "CPCertMigrator.psd1", 
    "CPCertMigrator-Launcher.ps1"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file найден" -ForegroundColor Green
    } else {
        Write-Host "❌ $file не найден" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Запуск launcher'а..." -ForegroundColor Yellow

# Запускаем launcher
try {
    & .\CPCertMigrator-Launcher.ps1
} catch {
    Write-Host "Ошибка запуска: $($_.Exception.Message)" -ForegroundColor Red
}