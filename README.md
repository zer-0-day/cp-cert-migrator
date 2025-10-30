# CPCertMigrator

**Экспорт и импорт сертификатов CryptoPro CSP** - просто и быстро

## 🎯 Возможности

### 📤 [Экспорт сертификатов в директорию для импорта](#экспорт-сертификатов-в-файлы)
```powershell
Install-Module CPCertMigrator -Scope CurrentUser
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"
```

### 📥 [Импорт сертификатов из директории экспорта](#импорт-сертификатов-из-файлов)
```powershell
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

### 🔄 [Перенос сертификатов и контейнеров](#перенос-на-другой-компьютер)
```powershell
# Сохранить
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"

# Восстановить  
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

### 🎮 [Консольное меню](#простое-меню)
```powershell
Install-Module CPCertMigrator -Scope CurrentUser
Start-CryptoProCertMigrator
```

### 🔍 [Как это работает технически?](#как-работает-модуль)

---

## 📋 Подробные инструкции

### Экспорт сертификатов в файлы

**Зачем:** Сохранить сертификаты в файлы для резервной копии или переноса

```powershell
# 1. Установить модуль
Install-Module CPCertMigrator -Scope CurrentUser

# 2. Либо обновить модуль
Update-Module CPCertMigrator -Scope CurrentUser

# 3. Сохранить все сертификаты
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"
```

**Результат:** Папка с файлами .pfx, каждый содержит один сертификат

### Импорт сертификатов из файлов

**Зачем:** Восстановить сертификаты из сохраненных файлов

```powershell
# Восстановить сертификаты из папки
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

**Результат:** Все сертификаты появятся в хранилище Windows

### Перенос на другой компьютер

**Зачем:** Перенести сертификаты с одного компьютера на другой

```powershell
# НА СТАРОМ КОМПЬЮТЕРЕ:
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\certFolder" -Password "SuperSecurePass"

# Скопировать папку C:\certFolder на новый компьютер

# НА НОВОМ КОМПЬЮТЕРЕ:
Install-Module CPCertMigrator -Scope CurrentUser
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\certFolder" -Password "SuperSecurePass"
```

### Простое меню

**Зачем:** Для простоты использования модуля

```powershell
# Запустите интерактивное меню
Start-CryptoProCertMigrator

# Выберите нужное действие:
# 1. Просмотр сертификатов
# 2. Экспорт сертификатов  
# 3. Импорт сертификатов
# 4. Быстрая миграция
```

Меню с подсказками.

## ⚙️ Требования

- **Windows 10, Windows Server 2016 и выше ** с установленным **CryptoPro CSP**
- **PowerShell 5.1 и выше**
- **Права администратора** (только для LocalMachine)

## �� Дополнительные возможности

### Посмотреть что есть
```powershell
# Список всех сертификатов
Get-CryptoProCertificates -Scope CurrentUser
```

### Предварительный просмотр (WhatIf)
```powershell
# Посмотреть что будет экспортировано (без выполнения)
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Test" -Password "Pass" -WhatIf
```

### Фильтрация
```powershell
# Только сертификаты определенной организации
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass" -SubjectFilter "МояОрганизация"
```

### Подробная информация
```powershell
# Добавьте -Verbose для детального лога
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\Backup" -Password "Pass" -Verbose
```


## ❓ Частые вопросы

**Забыл пароль от файлов** - без пароля восстановить нельзя, используйте запоминающиеся пароли

**Нужны права администратора?** - нет, кроме машинного хранилища (LocalMachine)

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