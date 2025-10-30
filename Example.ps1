# Пример использования CPCertMigrator

# Установка
Install-Module -Name CPCertMigrator -Scope CurrentUser
Import-Module CPCertMigrator

# Интерактивное меню (рекомендуется)
Start-CryptoProCertMigrator

# Консольные команды
Get-CryptoProCertificates -Scope CurrentUser
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass"
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\Backup" -Password "MyPass"