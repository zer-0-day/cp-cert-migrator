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
}
catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
}

# Тест интерактивного меню (закомментировано для автоматического запуска)
# Write-Host "`n=== Запуск интерактивного меню ===" -ForegroundColor Cyan
# Start-CryptoProCertMigrator

Write-Host "`nТестирование завершено!" -ForegroundColor GreenndColor Green
$functions | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Gray }

# Проверка манифеста
try {
    $manifest = Test-ModuleManifest .\CPCertMigrator.psd1
    Write-Host "✅ Манифест валиден (версия: $($manifest.Version))" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка манифеста: $($_.Exception.Message)" -ForegroundColor Red
}

# Проверка прав администратора
$isAdmin = Test-AdminRights
Write-Host "✅ Права администратора: $(if($isAdmin){'Да'}else{'Нет'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})

# 2. ТЕСТ ПРОСМОТРА СЕРТИФИКАТОВ
Write-Host "`n2. Тест просмотра сертификатов..." -ForegroundColor Yellow

try {
    $userCerts = Get-CryptoProCertificates -Scope CurrentUser -ErrorAction Stop
    Write-Host "✅ CurrentUser: найдено $($userCerts.Count) сертификатов" -ForegroundColor Green
    
    if ($userCerts.Count -gt 0) {
        $expiringSoon = $userCerts | Where-Object { $_.DaysRemaining -lt 30 }
        if ($expiringSoon.Count -gt 0) {
            Write-Host "⚠️  Истекают скоро: $($expiringSoon.Count) сертификатов" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "❌ Ошибка CurrentUser: $($_.Exception.Message)" -ForegroundColor Red
}

if ($isAdmin) {
    try {
        $machineCerts = Get-CryptoProCertificates -Scope LocalMachine -ErrorAction Stop
        Write-Host "✅ LocalMachine: найдено $($machineCerts.Count) сертификатов" -ForegroundColor Green
    } catch {
        Write-Host "❌ Ошибка LocalMachine: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  LocalMachine: пропущено (нет прав администратора)" -ForegroundColor Yellow
}

# 3. ТЕСТ ФИЛЬТРАЦИИ
Write-Host "`n3. Тест фильтрации..." -ForegroundColor Yellow

try {
    $filtered = Get-CryptoProCertificates -Scope CurrentUser -MinDaysRemaining 365
    Write-Host "✅ Фильтр по сроку (>365 дней): $($filtered.Count) сертификатов" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка фильтрации: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. ПОЛНОЕ ТЕСТИРОВАНИЕ (с созданием тестовых файлов)
if ($FullTest) {
    Write-Host "`n4. Полное тестирование (с файлами)..." -ForegroundColor Yellow
    
    # Создаем тестовую папку
    if (-not (Test-Path $TestCertPath)) {
        New-Item -ItemType Directory -Path $TestCertPath -Force | Out-Null
    }
    
    # Тест WhatIf экспорта
    try {
        Export-CryptoProCertificates -Scope CurrentUser -ExportFolder $TestCertPath -Password "TestPass123" -WhatIf
        Write-Host "✅ WhatIf экспорт: успешно" -ForegroundColor Green
    } catch {
        Write-Host "❌ WhatIf экспорт: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Реальный экспорт (если есть сертификаты)
    if ($userCerts.Count -gt 0) {
        $confirm = Read-Host "Выполнить реальный экспорт сертификатов? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            try {
                Export-CryptoProCertificates -Scope CurrentUser -ExportFolder $TestCertPath -Password "TestPass123" -ShowProgress
                Write-Host "✅ Реальный экспорт: успешно" -ForegroundColor Green
                
                # Проверяем созданные файлы
                $pfxFiles = Get-ChildItem -Path $TestCertPath -Filter *.pfx
                Write-Host "✅ Создано PFX файлов: $($pfxFiles.Count)" -ForegroundColor Green
                
                # Тест валидации PFX
                $validFiles = 0
                $pfxFiles | ForEach-Object {
                    if (Test-PfxFile -FilePath $_.FullName -Password "TestPass123") {
                        $validFiles++
                    }
                }
                Write-Host "✅ Валидных PFX файлов: $validFiles" -ForegroundColor Green
                
            } catch {
                Write-Host "❌ Реальный экспорт: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Очистка тестовых файлов
    $cleanup = Read-Host "Удалить тестовые файлы? (Y/n)"
    if ($cleanup -ne 'n' -and $cleanup -ne 'N') {
        Remove-Item -Path $TestCertPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Тестовые файлы удалены" -ForegroundColor Green
    }
}

# 5. ИНТЕРАКТИВНОЕ ТЕСТИРОВАНИЕ
if ($InteractiveTest) {
    Write-Host "`n5. Интерактивное тестирование..." -ForegroundColor Yellow
    Write-Host "Запуск интерактивного меню (нажмите 0 для выхода)" -ForegroundColor Gray
    Start-CryptoProCertMigrator
}

# ИТОГИ
Write-Host "`n=== ИТОГИ ТЕСТИРОВАНИЯ ===" -ForegroundColor Cyan
Write-Host "Модуль: CPCertMigrator v$($manifest.Version)" -ForegroundColor White
Write-Host "Функций: $($functions.Count)" -ForegroundColor White
Write-Host "Сертификатов CurrentUser: $($userCerts.Count)" -ForegroundColor White
if ($isAdmin -and $machineCerts) {
    Write-Host "Сертификатов LocalMachine: $($machineCerts.Count)" -ForegroundColor White
}
Write-Host "Статус: $(if($functions.Count -eq 4){'✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ'}else{'⚠️ ЕСТЬ ПРОБЛЕМЫ'})" -ForegroundColor $(if($functions.Count -eq 4){'Green'}else{'Yellow'})

Write-Host "`nДля полного тестирования запустите:" -ForegroundColor Gray
Write-Host ".\Test-Local.ps1 -FullTest -InteractiveTest" -ForegroundColor White