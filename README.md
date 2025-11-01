# CPCertMigrator

**Экспорт и импорт сертификатов CryptoPro CSP** - просто и быстро

## �  Интерактивное меню (пример)

```
=== CryptoPro Certificate Migrator v1.8.3 ===

Статус: Пользователь
CurrentUser: 5 сертификатов
LocalMachine: 5 сертификатов
CryptoPro CSP: установлен

1. Просмотр сертификатов
2. Экспорт сертификатов
3. Импорт сертификатов
4. Быстрая миграция (CurrentUser -> LocalMachine)
5. Повторить проверку системы
0. Выход

```

**Способы запуска:**

**1. Готовый .exe файл (самый простой):**
```bash
# Скачайте CPCertMigrator.exe из релизов
# Просто запустите двойным кликом или из командной строки
CPCertMigrator.exe
```

**2. PowerShell модуль:**
```powershell
# Установка модуля
Install-Module CPCertMigrator -Scope CurrentUser

# Запуск меню
Start-CryptoProCertMigrator
```

## 📋 Краткое описание

CPCertMigrator - это инструмент для работы с сертификатами CryptoPro CSP. Доступен как готовый .exe файл или PowerShell модуль. Позволяет:

- **Экспортировать** сертификаты в защищенные PFX файлы
- **Импортировать** сертификаты из PFX файлов  
- **Переносить** сертификаты между компьютерами
- **Мигрировать** между пользовательским и машинным хранилищами
- **Просматривать** сертификаты с фильтрацией

> **💡 Совет:** Для работы с сертификатами компьютера (LocalMachine) нужны права администратора.

## 🚀 Быстрые примеры

### Экспорт сертификатов
```powershell
# Экспорт пользовательских сертификатов
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\CertBackup" -Password "MySecurePass"

# Экспорт машинных сертификатов (от имени администратора)
Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\CertBackup" -Password "MySecurePass"
```

### Импорт сертификатов
```powershell
# Импорт в пользовательское хранилище
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\CertBackup" -Password "MySecurePass"

# Импорт в машинное хранилище (от имени администратора)
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\CertBackup" -Password "MySecurePass"
```

### Просмотр сертификатов
```powershell
# Все сертификаты пользователя
Get-CryptoProCertificates -Scope CurrentUser

# С фильтрацией по организации
Get-CryptoProCertificates -Scope CurrentUser -SubjectFilter "МояОрганизация"
```

---

## 📋 Подробные инструкции

### Экспорт сертификатов в файлы

**Зачем:** Сохранить сертификаты в файлы для резервной копии или переноса

```powershell
# 1. Установить модуль
Install-Module CPCertMigrator -Scope CurrentUser

# 2. Либо обновить модуль
Update-Module CPCertMigrator -Scope CurrentUser

# 3. Сохранить сертификаты пользователя
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"

# 4. Или сохранить сертификаты компьютера (нужны права администратора)
Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\certFolder" -Password "SuperSecurePass"
```

**Результат:** Папка с файлами .pfx, каждый содержит один сертификат

### Импорт сертификатов из файлов

**Зачем:** Восстановить сертификаты из сохраненных файлов

```powershell
# Восстановить в хранилище пользователя
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"

# Или восстановить в хранилище компьютера (нужны права администратора)
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

**Результат:** Все сертификаты появятся в выбранном хранилище Windows

### Перенос на другой компьютер

**Зачем:** Перенести сертификаты с одного компьютера на другой

```powershell
# НА СТАРОМ КОМПЬЮТЕРЕ:
# Экспорт пользовательских сертификатов
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"

# Экспорт машинных сертификатов (от имени администратора)
Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\certFolder" -Password "SuperSecurePass"

# Скопировать папку C:\certFolder на новый компьютер

# НА НОВОМ КОМПЬЮТЕРЕ:
Install-Module CPCertMigrator -Scope CurrentUser

# Импорт в пользовательское хранилище
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"

# Импорт в машинное хранилище (от имени администратора)
Import-CryptoProCertificates -Scope LocalMachine -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

### Интерактивное меню

**Зачем:** Для простоты использования модуля

```powershell
# Запустите интерактивное меню
Start-CryptoProCertMigrator
```

Меню автоматически проверяет систему и показывает доступные операции.

## ⚙️ Требования

**Для .exe файла:**
- **Windows 10, Windows Server 2016 и выше** с установленным **CryptoPro CSP**
- **Права администратора** (только для операций с LocalMachine)

**Для PowerShell модуля:**
- **Windows 10, Windows Server 2016 и выше** с установленным **CryptoPro CSP**
- **PowerShell 5.1 и выше**
- **Права администратора** (только для LocalMachine)

## 🔧 Дополнительные возможности

### Посмотреть что есть
```powershell
# Сертификаты пользователя
Get-CryptoProCertificates -Scope CurrentUser

# Сертификаты компьютера (от имени администратора)
Get-CryptoProCertificates -Scope LocalMachine
```

### Предварительный просмотр (WhatIf)
```powershell
# Посмотреть что будет экспортировано из пользовательского хранилища
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -WhatIf

# Посмотреть что будет экспортировано из машинного хранилища
Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\Test" -Password "Pass" -WhatIf
```

### Фильтрация
```powershell
# Только сертификаты определенной организации (пользовательские)
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass" -SubjectFilter "МояОрганизация"

# Только сертификаты определенной организации (машинные)
Export-CryptoProCertificates -Scope LocalMachine -ExportFolder "C:\Backup" -Password "Pass" -SubjectFilter "МояОрганизация"
```

### Подробная информация
```powershell
# Добавьте -Verbose для детального лога
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass" -Verbose
```


## ❓ Частые вопросы

**Что лучше использовать - .exe или PowerShell модуль?** - .exe файл проще в использовании (не требует установки PowerShell модуля), но PowerShell модуль дает больше возможностей для автоматизации

**Забыл пароль от файлов** - без пароля восстановить нельзя, используйте запоминающиеся пароли

**Нужны права администратора?** - только для LocalMachine (машинное хранилище). Для CurrentUser (пользовательское) - нет

**В чем разница между CurrentUser и LocalMachine?** - CurrentUser доступен только текущему пользователю, LocalMachine - всем пользователям компьютера

**Безопасно ли?** - да, все операции локальные, данные не передаются в интернет

## 📞 Помощь

```powershell
# Справка по любой команде
Get-Help Export-CryptoProCertificates -Examples
```

## 🔍 Как работает модуль

### Что используется для экспорта и импорта ЭЦП

**Источник данных:**
- **Windows Certificate Store** - стандартное хранилище сертификатов Windows
- Путь: `Cert:\CurrentUser\My` или `Cert:\LocalMachine\My`
- Личное хранилище сертификатов пользователя или компьютера

**Механизм экспорта:**
```powershell
Export-PfxCertificate -FilePath $filePath -Password $password
```
- Использует встроенный PowerShell cmdlet
- Экспортирует в формат **PFX (PKCS#12)**
- Включает сертификат + приватный ключ

**Механизм импорта:**
```powershell
Import-PfxCertificate -FilePath $file -CertStoreLocation $store -Exportable
```
- Использует встроенный PowerShell cmdlet
- Импортирует из формата **PFX (PKCS#12)**
- Флаг `-Exportable` позволяет повторный экспорт

### Интеграция с CryptoPro CSP

- **CryptoPro CSP** регистрируется как Cryptographic Service Provider в Windows
- Сертификаты CryptoPro **автоматически доступны** через стандартные Windows API
- **Приватные ключи** хранятся в контейнерах CryptoPro
- Модуль использует **стандартные Windows механизмы**, поэтому совместим с любыми CSP

### Что экспортируется

✅ **X.509 сертификат** (публичная часть)  
✅ **Приватный ключ** (из контейнера CryptoPro)  
✅ **Цепочка сертификатов** (если есть)  
✅ **Метаданные** (FriendlyName, etc.)

❌ **НЕ экспортируется:** настройки CryptoPro CSP, лицензии, системные настройки

### Преимущества

- **Стандартность** - использует встроенные Windows API
- **Совместимость** - работает с любыми CSP, не только CryptoPro  
- **Надежность** - проверенные Microsoft cmdlets
- **Безопасность** - стандартная защита паролем PFX
- **Переносимость** - PFX файлы работают на любых системах

---
**Автор:** zeroday | ⭐ [Поставьте звездочку на GitHub](https://github.com/zer-0-day/cp-cert-migrator) 