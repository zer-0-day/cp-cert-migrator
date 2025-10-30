# Инструкция по публикации в PowerShell Gallery

## Подготовка репозитория

### 1. Настройка GitHub Secrets

1. Получите API ключ PowerShell Gallery:
   - Зайдите на https://www.powershellgallery.com/
   - Войдите в аккаунт
   - Перейдите в Account → API Keys
   - Создайте новый ключ с правами на публикацию

2. Добавьте секрет в GitHub:
   - Откройте ваш репозиторий на GitHub
   - Settings → Secrets and variables → Actions
   - New repository secret
   - Name: `PSGALLERY_API_KEY`
   - Secret: ваш API ключ из PowerShell Gallery

### 2. Структура файлов

Убедитесь, что в корне репозитория есть:
```
CPCertMigrator/
├── .github/workflows/publish.yml  # GitHub Action
├── CPCertMigrator.psd1            # Манифест модуля
├── CPCertMigrator.psm1            # Код модуля
├── README.md                      # Документация
├── LICENSE                        # Лицензия MIT
├── .gitignore                     # Исключения Git
└── PUBLISH.md                     # Эта инструкция
```

## Процесс публикации

### Автоматическая публикация (рекомендуется)

1. **Подготовьте релиз:**
   ```bash
   # Убедитесь, что все изменения закоммичены
   git add .
   git commit -m "Prepare release v1.1.0"
   git push origin main
   ```

2. **Создайте тег версии:**
   ```bash
   # Создайте тег в формате v1.2.3
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. **Автоматический процесс:**
   - GitHub Action автоматически запустится
   - Обновит версию в манифесте
   - Проверит, что версия не существует в PSGallery
   - Упакует модуль
   - Опубликует в PowerShell Gallery

### Ручная публикация через GitHub UI

1. Перейдите в Actions → "Publish to PowerShell Gallery"
2. Нажмите "Run workflow"
3. Укажите тег версии (например, v1.1.0)
4. Нажмите "Run workflow"

## Мониторинг публикации

### Проверка статуса

1. **В GitHub Actions:**
   - Actions → последний запуск workflow
   - Проверьте логи каждого шага
   - Скачайте артефакт nupkg для диагностики

2. **В PowerShell Gallery:**
   - https://www.powershellgallery.com/packages/CPCertMigrator
   - Новая версия появится через 5-10 минут

### Проверка установки

```powershell
# Поиск модуля
Find-Module CPCertMigrator

# Установка
Install-Module CPCertMigrator -Scope CurrentUser

# Проверка версии
Get-Module CPCertMigrator -ListAvailable
```

## Версионирование

### Семантическое версионирование (SemVer)

Используйте формат `v1.2.3`:
- **Major (1.x.x)** - breaking changes
- **Minor (x.2.x)** - новая функциональность
- **Patch (x.x.3)** - исправления багов

### Примеры тегов

```bash
# Исправление бага
git tag v1.1.1

# Новая функция
git tag v1.2.0

# Breaking change
git tag v2.0.0
```

## Устранение проблем

### Частые ошибки

1. **"Version already exists"**
   ```bash
   # Создайте новый тег с увеличенной версией
   git tag v1.1.1
   git push origin v1.1.1
   ```

2. **"Missing PSGALLERY_API_KEY"**
   - Проверьте настройку секрета в GitHub
   - Убедитесь, что имя точно `PSGALLERY_API_KEY`

3. **"Manifest not found"**
   - Убедитесь, что файл называется `CPCertMigrator.psd1`
   - Проверьте, что файл в корне репозитория

### Отладка

1. **Локальная проверка манифеста:**
   ```powershell
   Test-ModuleManifest .\CPCertMigrator.psd1
   ```

2. **Проверка упаковки:**
   ```powershell
   # Установите PSResourceGet
   Install-Module Microsoft.PowerShell.PSResourceGet -Force
   
   # Упакуйте локально
   Compress-PSResource -Path . -DestinationPath ./out
   ```

3. **Просмотр логов GitHub Actions:**
   - Actions → выберите запуск → разверните шаги
   - Скачайте артефакт для анализа

## Обновление модуля

### Процесс обновления

1. Внесите изменения в код
2. Обновите документацию
3. Закоммитьте изменения
4. Создайте новый тег версии
5. Дождитесь автоматической публикации

### Пример полного цикла

```bash
# 1. Внесите изменения
vim CPCertMigrator.psm1

# 2. Обновите README если нужно
vim README.md

# 3. Закоммитьте
git add .
git commit -m "Add new feature: certificate validation"

# 4. Отправьте в main
git push origin main

# 5. Создайте тег релиза
git tag v1.2.0
git push origin v1.2.0

# 6. Проверьте GitHub Actions
# 7. Проверьте PowerShell Gallery через 10 минут
```

## Полезные ссылки

- [PowerShell Gallery](https://www.powershellgallery.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PowerShell Module Manifest](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [Semantic Versioning](https://semver.org/)