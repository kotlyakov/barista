# Нативный проект и проверенные команды

Godot **4.5.1.stable.official.f62fdbde1**, GDScript, Compatibility renderer, горизонтальный viewport 1600×900 с масштабированием canvas_items. OpenJDK **17.0.20**. Без внешних игровых зависимостей.

Из корня репозитория (GODOT — путь к установленному официальному Godot 4.5.1):

```sh
"$GODOT" --headless --path game --editor --import
"$GODOT" --headless --path game --script res://tests/smoke.gd
"$GODOT" --headless --path game --script res://tests/brewing_test.gd
"$GODOT" --path game
mkdir -p artifacts
"$GODOT" --headless --path game --export-debug "Linux Debug"
./artifacts/barista-debug.x86_64 --headless --quit-after 3
python3 tools/validate_project.py
```

Проверено 29.10.2026 в Linux: импорт, main scene, экспорт и запуск Linux Debug. Это технические заглушки, не финальное оформление и не Android-проверка.

## Android — NOT_RUN

Preset `Android`, пакет `org.kotlyakov.barista`, arm64-v8a, стандартный экспорт без Gradle. Использовать официальные export templates 4.5.1, JDK 17, Android SDK Platform 35 и build-tools 35.0.0. SDK в текущем исполнителе не установлен. Команда для подготовленной среды (пока НЕ проверена):

```sh
"$GODOT" --headless --path game --export-debug Android
```

Настроить Android Sdk Path и Java SDK Path в локальных Editor Settings. Ключи/пароли/локальные настройки не хранить в Git. Артефакты и логи — в игнорируемой `artifacts/`. Установка и smoke на телефоне остаются обязательными перед приёмкой Android; наличие Linux-сборки не закрывает TASK-020.

Официальные источники конфигурации: https://godotengine.org/download/archive/4.5.1-stable/ и https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html .
