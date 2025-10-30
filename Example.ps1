# Примеры использования CPCertMigrator

# ========================================
# УСТАНОВКА И БЫСТРЫЙ СТАРТ
# ========================================

# Установка модуля
Install-Module -Name CPCertMigrator -Scope CurrentUser
Import-Module CPCertMigrator

# Самый простой способ - интерактивное меню
Start-CryptoProCertMigrator

# ========================================
# ПРОСМОТР СЕРТИФИКАТОВ
# ========================================

# Все сертификаты пользователя
Get-CryptoProCertificates -Scope CurrentUser

# С фильтрацией по организации
Get-CryptoProCertificates -Scope CurrentUser -SubjectFilter "MyCompany"

# Истекающие сертификаты
Get-CryptoProCertificates -Scope CurrentUser -MinDaysRemaining 30 | 
    Where-Object { $_.DaysRemaining -lt 30 }

# ========================================
# ЭКСПОРТ СЕРТИФИКАТОВ
# ========================================

# Базовый экспорт
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass"

# С фильтрацией и прогрессом
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass" -SubjectFilter "Test" -ShowProgress

# Предварительный просмотр (WhatIf)
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -WhatIf

# С подробным логированием
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass" -Verbose

# ========================================
# ИМПОРТ СЕРТИФИКАТОВ
# ========================================

# Базовый импорт
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "MyPass"

# С пропуском дубликатов
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "MyPass" -SkipExisting

# Предварительный просмотр импорта
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "Pass" -WhatIf

# ========================================
# БЫСТРАЯ МИГРАЦИЯ
# ========================================

# Автоматическая миграция CurrentUser -> LocalMachine
# (через интерактивное меню - пункт 4)
Start-CryptoProCertMigrator

# Или вручную:
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\TempMigration" -Password "TempPass"
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\TempMigration" -Password "TempPass" -SkipExisting

# ========================================
# ПОЛУЧЕНИЕ СПРАВКИ
# ========================================

# Справка по функциям
Get-Help Export-CryptoProCertificates -Full
Get-Help Import-CryptoProCertificates -Examples
Get-Help Get-CryptoProCertificates -Detailed

# Список всех функций
Get-Command -Module CPCertMigrator