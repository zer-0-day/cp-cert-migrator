# CPCertMigrator

PowerShell модуль для миграции сертификатов CryptoPro CSP между пользовательскими и машинными хранилищами.

## 🚀 Быстрый старт

```powershell
# Установка
Install-Module -Name CPCertMigrator -Scope CurrentUser

# Запуск интерактивного меню (самый простой способ)
Start-CryptoProCertMigrator
```

## Описание

Модуль предоставляет функции для экспорта и импорта сертификатов CryptoPro CSP в формате PFX с удобным интерфейсом и подробной документацией.

## 🎯 Возможности с примерами

### 📋 Просмотр сертификатов
Получение списка сертификатов с детальной информацией
```powershell
# Все сертификаты пользователя
Get-CryptoProCertificates -Scope CurrentUser

# С фильтрацией по организации
Get-CryptoProCertificates -Scope CurrentUser -SubjectFilter "MyCompany"

# Истекающие в течение 30 дней
Get-CryptoProCertificates -Scope CurrentUser -MinDaysRemaining 30
```
[📖 Подробнее](#просмотр-сертификатов)

### 📤 Экспорт сертификатов в PFX файлы
Сохранение сертификатов в защищенные файлы
```powershell
# Базовый экспорт
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass"

# С фильтрацией и прогрессом
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "MyPass" -SubjectFilter "Test" -ShowProgress
```
[📖 Подробнее](#экспорт-сертификатов)

### 📥 Импорт сертификатов из PFX файлов
Восстановление сертификатов из файлов
```powershell
# Базовый импорт
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "MyPass"

# С пропуском дубликатов
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "MyPass" -SkipExisting
```
[📖 Подробнее](#импорт-сертификатов)

### 🔍 WhatIf режим (предварительный просмотр)
Просмотр операций без их выполнения
```powershell
# Посмотреть что будет экспортировано
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -WhatIf

# Посмотреть что будет импортировано
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Test" -Password "Pass" -WhatIf
```
[📖 Подробнее](#whatif-режим)

### 🎮 Интерактивное консольное меню
Пошаговый интерфейс для всех операций
```powershell
# Запуск меню с выбором действий
Start-CryptoProCertMigrator
```
[📖 Подробнее](#интерактивное-меню)

### ⚡ Быстрая миграция между хранилищами
Автоматический перенос CurrentUser → LocalMachine
```powershell
# Через интерактивное меню (пункт 4)
Start-CryptoProCertMigrator

# Или вручную
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Temp" -Password "TempPass"
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\Temp" -Password "TempPass"
```
[📖 Подробнее](#быстрая-миграция)

### 🔧 Дополнительные возможности
- ✅ **Фильтрация** по сроку действия, Subject и Issuer
- ✅ **Подробное логирование** операций (используйте `-Verbose`)
- ✅ **Индикатор прогресса** для больших операций (`-ShowProgress`)
- ✅ **Умные имена файлов** (Subject + SerialNumber)
- ✅ **Проверка дубликатов** при импорте (`-SkipExisting`)
- ✅ **Валидация PFX файлов** перед импортом
- ✅ **Автоматическая проверка прав** администратора

## 📦 Установка

```powershell
# Из PowerShell Gallery (рекомендуется)
Install-Module -Name CPCertMigrator -Scope CurrentUser
Import-Module CPCertMigrator

# Проверка установки
Get-Command -Module CPCertMigrator
```

## 📚 Подробные примеры

### Просмотр сертификатов

```powershell
# Получить справку
Get-Help Get-CryptoProCertificates -Examples

# Все сертификаты пользователя
Get-CryptoProCertificates -Scope CurrentUser

# Сертификаты машинного хранилища (нужны права администратора)
Get-CryptoProCertificates -Scope LocalMachine

# Фильтрация по организации
Get-CryptoProCertificates -Scope CurrentUser -SubjectFilter "ООО Рога и копыта"

# Сертификаты от конкретного УЦ
Get-CryptoProCertificates -Scope CurrentUser -IssuerFilter "Тестовый УЦ"

# Истекающие сертификаты (менее 30 дней)
Get-CryptoProCertificates -Scope CurrentUser -MinDaysRemaining 30 | 
    Where-Object { $_.DaysRemaining -lt 30 } | 
    Format-Table Subject, DaysRemaining, NotAfter
```

### Экспорт сертификатов

```powershell
# Получить справку
Get-Help Export-CryptoProCertificates -Full

# Базовый экспорт всех сертификатов
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\CertBackup" -Password "MySecurePassword"

# Экспорт с фильтрацией и прогрессом
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass123" -SubjectFilter "MyOrg" -ShowProgress

# Экспорт только действующих сертификатов (более 30 дней)
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\ActiveCerts" -Password "Pass123" -MinDaysRemaining 30

# Предварительный просмотр (WhatIf)
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass123" -WhatIf

# С подробным логированием
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass123" -Verbose
```

### Импорт сертификатов

```powershell
# Получить справку
Get-Help Import-CryptoProCertificates -Examples

# Базовый импорт
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\CertBackup" -Password "MySecurePassword"

# Импорт с пропуском существующих сертификатов
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "Pass123" -SkipExisting -ShowProgress

# Предварительный просмотр импорта
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "Pass123" -WhatIf

# Импорт в машинное хранилище (требуются права администратора)
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\Backup" -Password "Pass123" -SkipExisting
```

### WhatIf режим

WhatIf режим позволяет увидеть что произойдет без выполнения операций:

```powershell
# Посмотреть какие сертификаты будут экспортированы
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -WhatIf

# Результат покажет:
# WhatIf: Would export the following certificates:
#   - Subject: CN=Тестовый сертификат
#     Thumbprint: 1234567890ABCDEF...
#     File: Тестовый_сертификат_12345678.pfx
#     Expires: 15.12.2025 10:30:00

# Посмотреть какие файлы будут импортированы
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\Backup" -Password "Pass" -WhatIf

# Результат покажет:
# WhatIf: Would import the following files:
#   - File: cert1.pfx
#     Size: 2.5 KB
#   - File: cert2.pfx  
#     Size: 3.1 KB
```

### Интерактивное меню

Самый простой способ использования модуля:

```powershell
# Запуск интерактивного меню
Start-CryptoProCertMigrator

# Появится меню:
# === CryptoPro Certificate Migrator ===
# 
# 1. Просмотр сертификатов
# 2. Экспорт сертификатов  
# 3. Импорт сертификатов
# 4. Быстрая миграция (CurrentUser -> LocalMachine)
# 0. Выход
#
# Выберите действие (0-4):
```

Каждый пункт меню проведет вас через пошаговый процесс с выбором параметров.

### Быстрая миграция

Автоматический перенос всех сертификатов из пользовательского в машинное хранилище:

```powershell
# Через интерактивное меню (самый простой способ)
Start-CryptoProCertMigrator
# Выберите пункт 4

# Или вручную пошагово:
# 1. Экспорт из CurrentUser
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\TempMigration" -Password "TempPass123"

# 2. Импорт в LocalMachine (запустить от имени администратора)
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\TempMigration" -Password "TempPass123" -SkipExisting

# 3. Очистка временных файлов
Remove-Item "C:\TempMigration" -Recurse -Force
```

## 🔧 Дополнительные возможности

### Подробное логирование

Используйте параметр `-Verbose` для получения детальной информации:

```powershell
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -Verbose

# Покажет:
# VERBOSE: Starting certificate export operation
# VERBOSE: Scope: CurrentUser, ExportFolder: C:\Test, MinDaysRemaining: 0
# VERBOSE: Certificate store path: Cert:\CurrentUser\My
# VERBOSE: Found 5 total certificates in store
# VERBOSE: After date filter (>0 days): 5 certificates
# VERBOSE: Processing certificate 1/5: TestCert_12345678
# VERBOSE:   Subject: CN=Тестовый сертификат
# VERBOSE:   Thumbprint: 1234567890ABCDEF...
# VERBOSE:   Expires: 15.12.2025 10:30:00
# VERBOSE:   Target file: C:\Test\TestCert_12345678.pfx
# VERBOSE: Export successful. File size: 2048 bytes
```

### Получение справки

Каждая функция имеет подробную документацию:

```powershell
# Полная справка с примерами
Get-Help Export-CryptoProCertificates -Full

# Только примеры
Get-Help Import-CryptoProCertificates -Examples

# Краткая справка
Get-Help Get-CryptoProCertificates

# Список всех функций модуля
Get-Command -Module CPCertMigrator
```

## ⚙️ Требования

- **PowerShell 5.1+** (Windows PowerShell или PowerShell Core)
- **CryptoPro CSP** (любая версия)
- **Права администратора** (только для операций с LocalMachine)

## ❓ Часто задаваемые вопросы

### Как узнать какие сертификаты у меня есть?
```powershell
Get-CryptoProCertificates -Scope CurrentUser | Format-Table Subject, DaysRemaining, HasPrivateKey
```

### Как сделать резервную копию всех сертификатов?
```powershell
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup\$(Get-Date -Format 'yyyy-MM-dd')" -Password "BackupPassword"
```

### Как перенести сертификаты на другой компьютер?
1. Экспортируйте на старом компьютере
2. Скопируйте папку с PFX файлами на новый компьютер  
3. Импортируйте на новом компьютере

### Что делать если забыл пароль от PFX файлов?
К сожалению, без пароля восстановить сертификаты невозможно. Рекомендуется делать резервные копии с запоминающимися паролями.

### Нужны ли права администратора?
- **CurrentUser** - обычные права пользователя
- **LocalMachine** - права администратора обязательны

### Безопасно ли использовать модуль?
Да, модуль использует стандартные API Windows и не передает данные в интернет. Все операции выполняются локально.

## 🚀 Быстрые команды

```powershell
# Установка и запуск
Install-Module CPCertMigrator -Scope CurrentUser; Import-Module CPCertMigrator; Start-CryptoProCertMigrator

# Быстрый просмотр сертификатов
Get-CryptoProCertificates -Scope CurrentUser | ft Subject, DaysRemaining -AutoSize

# Быстрое резервное копирование
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "$env:USERPROFILE\Desktop\CertBackup" -Password "Backup$(Get-Date -Format 'MMdd')"
```

## 📞 Поддержка

- **Документация**: `Get-Help <FunctionName> -Full`
- **Примеры**: `Get-Help <FunctionName> -Examples`  
- **GitHub**: [Issues и обсуждения](https://github.com/zer-0-day/cp-cert-migrator)

## 👨‍💻 Автор

**zeroday** - PowerShell модуль для работы с сертификатами CryptoPro CSP

---
⭐ Если модуль оказался полезным, поставьте звездочку на GitHub!