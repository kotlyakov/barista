# Android café preview 0.3.0 — 30.10.2026

Фактический ARM64 APK новой единой кофейни собран в GitHub Actions и подписан локально прежним debug-ключом. Общая графика стойки и временных персонажей 09 сохранена; intro/menu/progress и звуки остаются рабочей версией.

- Пакет: org.kotlyakov.barista; versionName 0.3.0, code 3; minSdk 24, targetSdk 35; ARM64.
- Source commit: 32ffa2231d66aef49b26a712d84256472e86f83c. Build run: 41024619007.
- Unsigned archive artifact: 12963425517. APK export + 21 Godot scripts реально прошли в CI.
- Godot 4.5.1; official editor SHA-256 02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd; official templates 1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86.
- Android command-line tools 22.0 / build 15859902; build-tools 35.0.0, platform-tools 37.0.1; Temurin 17.0.21+9.
- Итоговый APK: artifacts/Barista-0.3.0-cafe-preview.apk; 29 894 802 bytes.
- SHA-256: b39ea8a95ca8914e34da0b186eb3c2a787135d89265aad5c89fd97a4665ebf27.
- Signature: v2/v3 PASS. Сертификат SHA-256 eee33a840769e0e2e4558e2fad925a5158e7d73104195d0b41b1991f241d6639 совпадает с предыдущим APK 0.1.0. Пользовательский ключ не передавался в Git/CI.
- Official SDK checks: zipalign -P 16; aapt package/version/SDK; ZIP integrity; ABI set; no key files. tools/check_apk.py PASS.
- Новый APK сохранён: libfile_593b35c6f59081918ddbee576b8f5cf9.

Проверка в x86_64 Android эмуляторе выполнена отдельно через android-runtime. Там отдельный org.kotlyakov.barista.emulator и временная подпись, не заменяющая подпись телефона. Итоговый run 41028363869 завершился SUCCESS; подробности ниже. Это не проверка ARM64/Pixel и не калибровка производительности/комбо.

Code review review_android_build: ключи не утекают; указаны риски таймингов автоматического UI-теста и срока жизни привязанного artifact. Текущий runtime workflow намеренно привязан к этой конкретной сборке; через 7 дней артефакт может истечь, повторную проверку связывать с новым build run.

Первая попытка Android runtime (run 41025139663) не дошла до приложения: emulator 37.2.13 требовал userdata 12 GB при 9,8 GB свободного места и завершился FATAL; затем action ждал adb до timeout. Это не сбой APK. Установлен явный AVD disk-size 2048M и зафиксирован emulator build 16740729; повторная попытка идёт отдельным run. В smoke по замечаниям review убраны фиксированные ожидания intro/немедленная проверка mute, добавлена проверка точного source commit pinned-артефакта.

## Подтверждённый Android runtime
Run **41028363869 SUCCESS**, evidence artifact **12964722431** (3 206 691 bytes). Android15/API35, x86_64, 1920×1080; emulator37.2.13 build16740729, GPU swangle/ANGLE OpenGLES3.1. Result.json ссылается на тот же source32ffa223 / build41024619007.

Реальными ADB touch/swipe проверены: установка и запуск, выбор усиления/начало смены, ровно нужное количество тапов по трём приборам без дублей/пропусков, drop стакана, PAYMENT, перезапуск до сбора, начисление ровно80 монет, второй перезапуск без повторной оплаты, сохранение mood/history и mute, меню/прогресс не двигают активные часы. Процесс остаётся жив; SCRIPT ERROR/FATAL EXCEPTION не обнаружены.

Снимки и журналы загружены для внутренней проверки: room/rigs реально рисуются, шейдерных ошибок в финальном логе нет. Кадры снимаются сразу после input и могут показывать предыдущий кадр (например, menu вместо только что открытого progress); не считать каждое имя PNG подтверждением его содержимого. Полный визуальный снимок progress без людей ранее подтверждён отдельным Linux render.

Причины неудачных предварительных запусков разобраны по реальным журналам: userdata12GB не помещалась; старый swiftshader_indirect давал SceneShader/CanvasShader GL_MAX_FRAGMENT_UNIFORM_VECTORS; принудительная смена wm size провоцировала Activity recreation во время старта. Переключение на поддерживаемый swangle и естественное разрешение AVD позволило пройти полный тест без изменения APK/игровой графики. Официальные режимы: https://developer.android.com/studio/run/emulator-acceleration ; совпадающая ошибка старого SwiftShader: https://github.com/godotengine/godot/issues/109550 .

Это проверка **x86_64 эмулятора**, не физического ARM64/Pixel. Прежний внешний блок отсутствия любой Android runtime-проверки снят; 10 попыток/рецепт на реальном телефоне, субъективная плавность и окончательное аудио остаются TASK-022/017.
