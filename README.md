# CPCertMigrator

**Экспорт и импорт сертификатов CryptoPro CSP** - просто и быстро

## 🎯 Что вы хотите сделать?

### 📤 [Сохранить сертификаты в файлы (экспорт)](#экспорт-сертификатов-в-файлы)
```powershell
Install-Module CPCertMigrator -Scope CurrentUser
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\МоиСертификаты" -Password "МойПароль123"
```

### 📥 [Восстановить сертификаты из файлов (импорт)](#импорт-сертификатов-из-файлов)
```powershell
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\МоиСертификаты" -Password "МойПароль123"
```

### 🔄 [Перенести сертификаты на другой компьютер](#перенос-на-другой-компьютер)
```powershell
# На старом компьютере - сохранить
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "D:\Сертификаты" -Password "ПарольДляПереноса"

# На новом компьютере - восстановить  
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "D:\Сертификаты" -Password "ПарольДляПереноса"
```

### 🎮 [Использовать простое меню (для новичков)](#простое-меню)
```powershell
Install-Module CPCertMigrator -Scope CurrentUser
Start-CryptoProCertMigrator
```

---

## 📋 Подробные инструкции

### Экспорт сертификатов в файлы

**Зачем:** Сохранить сертификаты в файлы для резервной копии или переноса

```powershell
# 1. Установите модуль (один раз)
Install-Module CPCertMigrator -Scope CurrentUser

# 2. Сохраните все сертификаты
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "C:\МоиСертификаты" -Password "МойПароль123"
```

**Что получите:** Папка с файлами .pfx, каждый содержит один сертификат

### Импорт сертификатов из файлов

**Зачем:** Восстановить сертификаты из сохраненных файлов

```powershell
# Восстановите сертификаты из папки
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "C:\МоиСертификаты" -Password "МойПароль123"
```

**Что получите:** Все сертификаты появятся в хранилище Windows

### Перенос на другой компьютер

**Зачем:** Перенести сертификаты с одного компьютера на другой

```powershell
# НА СТАРОМ КОМПЬЮТЕРЕ:
Export-CryptoProCertificates -Scope CurrentUser -ExportFolder "D:\ДляПереноса" -Password "ПарольПереноса"

# Скопируйте папку D:\ДляПереноса на новый компьютер

# НА НОВОМ КОМПЬЮТЕРЕ:
Install-Module CPCertMigrator -Scope CurrentUser
Import-CryptoProCertificates -Scope CurrentUser -ImportFolder "D:\ДляПереноса" -Password "ПарольПереноса"
```

### Простое меню

**Зачем:** Если не хотите запоминать команды

```powershell
# Запустите интерактивное меню
Start-CryptoProCertMigrator

# Выберите нужное действие:
# 1. Просмотр сертификатов
# 2. Экспорт сертификатов  
# 3. Импорт сертификатов
# 4. Быстрая миграция
```

Меню проведет вас через все шаги с подсказками.

## ⚙️ Требования

- **Windows** с установленным **CryptoPro CSP**
- **PowerShell** (уже есть в Windows)
- **Права администратора** не нужны (кроме машинного хранилища)

## �  Дополнительные возможности

### Посмотреть что у вас есть
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

**Как посмотреть что у меня есть?** - `Get-CryptoProCertificates -Scope CurrentUser`

## 📞 Помощь

```powershell
# Справка по любой команде
Get-Help Export-CryptoProCertificates -Examples
```

---
**Автор:** zeroday | ⭐ [Поставьте звездочку на GitHub](https://github.com/zer-0-day/cp-cert-migrator)