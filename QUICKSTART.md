# Быстрый старт

## 🚀 Публикация в PowerShell Gallery за 5 минут

### 1. Настройка (один раз)

```bash
# 1. Получите API ключ с https://www.powershellgallery.com/account/apikeys
# 2. Добавьте секрет PSGALLERY_API_KEY в GitHub Settings → Secrets
# 3. Убедитесь, что файлы на месте:
ls -la
# CPCertMigrator.psd1 ✓
# CPCertMigrator.psm1 ✓  
# .github/workflows/publish.yml ✓
```

### 2. Публикация

```bash
# Подготовьте релиз
git add .
git commit -m "Release v1.1.0"
git push origin main

# Создайте тег и опубликуйте
git tag v1.1.0
git push origin v1.1.0
```

### 3. Проверка

- GitHub Actions автоматически запустится
- Через 5-10 минут модуль появится в PowerShell Gallery
- Проверьте: https://www.powershellgallery.com/packages/CPCertMigrator

## 🔧 Локальное тестирование

```powershell
# Тест модуля
.\Test-Local.ps1

# Ручной тест
Import-Module .\CPCertMigrator.psd1 -Force
Start-CryptoProCertMigrator
```

## 📋 Чеклист перед релизом

- [ ] Код протестирован локально
- [ ] Версия в манифесте корректная  
- [ ] README обновлен
- [ ] Все изменения закоммичены
- [ ] API ключ настроен в GitHub Secrets
- [ ] Тег создан в правильном формате (v1.2.3)

Готово! 🎉