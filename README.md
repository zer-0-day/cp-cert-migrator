# CPCertMigrator

PowerShell модуль для миграции сертификатов CryptoPro CSP между пользовательскими и машинными хранилищами.

## Описание

Модуль предоставляет функции для экспорта и импорта сертификатов CryptoPro CSP в формате PFX с удобным интерфейсом.

## Возможности

- ✅ Экспорт сертификатов из хранилища в файлы PFX
- ✅ Импорт сертификатов из файлов PFX в хранилище
- ✅ Поддержка пользовательских и машинных хранилищ
- ✅ Фильтрация по сроку действия, Subject и Issuer
- ✅ Подробное логирование операций
- ✅ Безопасная работа с паролями
- ✅ WhatIf режим для предварительного просмотра
- ✅ Индикатор прогресса для больших операций
- ✅ Умные имена файлов (Subject + SerialNumber)
- ✅ Проверка дубликатов при импорте
- ✅ Валидация PFX файлов перед импортом
- ✅ Автоматическая проверка прав администратора
- ✅ Просмотр сертификатов с детальной информацией

- ✅ Интерактивное консольное меню
- ✅ Быстрая миграция между хранилищами

## Установка

```powershell
# Из PowerShell Gallery
Install-Module -Name CPCertMigrator -Scope CurrentUser
Import-Module CPCertMigrator

# Или клонировать из GitHub
git clone https://github.com/YourUsername/CPCertMigrator.git
Import-Module .\CPCertMigrator\CPCertMigrator.psd1
```

## Использование

```powershell
# Интерактивное консольное меню
Start-CryptoProCertMigrator
```

### Консольные команды

```powershell
# Просмотр сертификатов
Get-CryptoProCertificates -Scope CurrentUser

# Экспорт
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass"

# Импорт
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "MyPass"
```

## Функции

- `Get-CryptoProCertificates` - просмотр сертификатов
- `Export-CryptoProCertificates` - экспорт в PFX файлы
- `Import-CryptoProCertificates` - импорт из PFX файлов
- `Start-CryptoProCertMigrator` - интерактивное меню


## Примеры

```powershell
# Миграция CurrentUser -> LocalMachine
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Temp" -Password "Pass123"
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\Temp" -Password "Pass123"

# Резервное копирование
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "BackupPass"
```

## Требования

- PowerShell 5.1+
- CryptoPro CSP
- Права администратора (для LocalMachine)

## Лицензия

MIT

## Разработка

Для разработчиков см. [PUBLISH.md](PUBLISH.md) - инструкция по публикации в PowerShell Gallery.

## Автор

zeroday