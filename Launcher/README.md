# RollHelperLauncher MVP

Минимальный WPF-лаунчер на .NET 8 для универсальных пакетов RollHelper.

## Что уже делает

1. Загружает `release-manifest.json` по HTTP/HTTPS.
2. Показывает доступные пакеты без брендовой логики.
3. Скачивает выбранный ZIP.
4. При наличии `sha256` проверяет контрольную сумму.
5. Безопасно распаковывает пакет в версионную папку.
6. Читает `package.json` из корня ZIP.
7. Запускает описанный в пакете `entrypoint`.
8. Записывает все действия и ошибки в `launcher.log`.

## Где хранятся файлы

- Пакеты: `%LOCALAPPDATA%\Programs\RollHelper\Packages\<id>\<version>`
- Кэш: `%LOCALAPPDATA%\Programs\RollHelper\Cache`
- Лог: `%LOCALAPPDATA%\RollHelper\Logs\launcher.log`
- Конфигурация источника: `launcher.config.json` рядом с EXE

Если `launcher.config.json` отсутствует, используется:

`https://github.com/voffkazxc/RollHelper/releases/latest/download/release-manifest.json`

## Формат ZIP-пакета

`package.json` должен находиться непосредственно в корне ZIP. Рядом размещаются файлы пакета и его entrypoint.

Примеры манифестов находятся в папке `examples`.

## Сборка

```powershell
dotnet build .\RollHelperLauncher\RollHelperLauncher.csproj -c Release
```

Для переносимой одиночной сборки без установленного .NET:

```powershell
dotnet publish .\RollHelperLauncher\RollHelperLauncher.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

## Границы MVP

Лаунчер пока не устанавливает зависимости пакетов, не обновляет сам себя, не выполняет миграции конфигов и не делает автоматический откат. Эти возможности можно добавлять поверх текущего универсального формата пакетов.
