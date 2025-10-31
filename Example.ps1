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

# Базовый экспорт (с защищенным паролем)
$password = ConvertTo-SecureString "MyPass" -AsPlainText -Force
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password $password

# С фильтрацией и прогрессом
$password = Read-Host "Введите пароль" -AsSecureString
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password $password -SubjectFilter "Test" -ShowProgress

# Предварительный просмотр (WhatIf)
$password = ConvertTo-SecureString "Pass" -AsPlainText -Force
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password $password -WhatIf

# С подробным логированием
$password = ConvertTo-SecureString "Pass" -AsPlainText -Force
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password $password -Verbose

# ========================================
# ИМПОРТ СЕРТИФИКАТОВ
# ========================================

# Базовый импорт (с защищенным паролем)
$password = ConvertTo-SecureString "MyPass" -AsPlainText -Force
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password $password

# С пропуском дубликатов
$password = Read-Host "Введите пароль" -AsSecureString
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password $password -SkipExisting

# Предварительный просмотр импорта
$password = ConvertTo-SecureString "Pass" -AsPlainText -Force
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password $password -WhatIf

# ========================================
# БЫСТРАЯ МИГРАЦИЯ
# ========================================

# Автоматическая миграция CurrentUser -> LocalMachine
# (через интерактивное меню - пункт 4)
Start-CryptoProCertMigrator

# Или вручную:
$tempPassword = ConvertTo-SecureString "TempPass" -AsPlainText -Force
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\TempMigration" -Password $tempPassword
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\TempMigration" -Password $tempPassword -SkipExisting

# ========================================
# ПОЛУЧЕНИЕ СПРАВКИ
# ========================================

# Справка по функциям
Get-Help Export-CryptoProCertificates -Full
Get-Help Import-CryptoProCertificates -Examples
Get-Help Get-CryptoProCertificates -Detailed

# Список всех функций
Get-Command -Module CPCertMigrator