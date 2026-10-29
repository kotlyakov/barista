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

## Android — technical preview 0.1.0 собран

Preset `Android`, пакет `org.kotlyakov.barista`, arm64-v8a, minSdk 24 / targetSdk 35, стандартный экспорт без Gradle. Godot export templates 4.5.1, JDK 17, Android SDK Platform 35 и build-tools 35.0.0. Реальная сборка и проверка APK выполнены после сообщения Артура «Принимаю»; лицензия SDK принята.

```sh
GODOT=/path/to/Godot_v4.5.1-stable_linux.x86_64 \
ANDROID_SDK_ROOT=/path/to/android-sdk \
bash tools/build_android.sh
```

Android Sdk Path/Java SDK Path/debug keystore настраиваются локально в Editor Settings. Ключи/пароли/настройки не хранить в Git. После очистки среды восстановить сохранённую debug-подпись из приватной Library (см. state/PROJECT_STATE.json), чтобы обновление APK оставалось совместимым.

Установка/запуск на телефоне пока NOT_RUN. Software Android 35 emulator без KVM не загрузился за 180 секунд. APK и headless проверки не закрывают TASK-020/022; финальные визуал/звук ещё не интегрированы.

Официальные источники: https://godotengine.org/download/archive/4.5.1-stable/ и https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html .

## Полная автоматическая проверка нативного прототипа

```sh
GODOT=/path/to/Godot_v4.5.1-stable_linux.x86_64 python3 tools/check_native.py
```

15 исполняемых GDScript-сценариев: приготовление, одиночный ввод, выдача/оплата, повреждение снимков, откат транзакции, touch UI, чаевые, выбор клиентов/RNG, сутки/смена, тренировка, магазин и временные усиления. Проверяется реальный Godot; Python запускает его, а не повторяет доменную логику. Любой ERROR и таймаут считаются ошибкой, даже если движок вернул код 0.

Сохранения в `user://saves`: два файла slot0/slot1, схема 1, payload с SHA-256, запись через отдельный временный файл и rename. Боевые speed thresholds пусты до TASK-022. Имена/рисунки шести гостей — нейтральные заглушки до отдельного утверждения. Зона профиля пока фиксированный UTC-offset с первого запуска; IANA/DST ещё не реализованы.

Android command-line tools **22.0** скачаны с официального сайта и сверены с SHA-256 `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583`. При установке platform-tools/build-tools 35.0.0/platform 35 получен реальный запрос `License android-sdk-license — Accept? (y/N)`. Это исторический запрос до ответа Артура; после сообщения «Принимаю» лицензия принята и установка/экспорт выполнены. Локальный путь среды: `/workspace/tools/android-sdk/cmdline-tools/22.0/bin/sdkmanager`; в других средах он не является обязательным.

Финальные регрессии добавили два сценария: всего **15**. Локальный запуск и обновлённый Linux Debug проходят; CI native-check должен быть проверен на окончательном remote SHA.

## Android — технический APK собран 29.10.2026

Предыдущая отметка NOT_RUN относится к состоянию до ответа Артура. После сообщения «Принимаю» лицензия Android SDK принята; SDK 35/build-tools 35.0.0/platform-tools 37.0.1 установлены. Ключ debug-подписи и Editor Settings настроены локально, вне Git.

Проверенная команда для этой или аналогично настроенной среды:

```sh
GODOT=/path/to/Godot_v4.5.1-stable_linux.x86_64 \
ANDROID_SDK_ROOT=/path/to/android-sdk \
bash tools/build_android.sh
```

Результат: `artifacts/Barista-0.1.0-tech-preview.apk`, подпись/манифест/ABI/16 KB выравнивание и ZIP проверяются автоматически. Скрипт не принимает новые лицензии и не создаёт релизный ключ. Настроить Android Sdk Path/Java SDK Path/debug keystore в локальных Editor Settings перед запуском. Preset Android — ARM64; Android Emulator — отдельный x86_64 пакет для QA.

Отчёт с SHA-256 и ограничениями: `reports/releases/ANDROID_TECH_0_1_0.md`. Установка/запуск на Android пока NOT_RUN: программный эмулятор без KVM не загрузился за 180 с. Готовый APK и headless тесты не заменяют проверку на телефоне.
