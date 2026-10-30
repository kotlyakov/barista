# Передача — Android preview0.3.0, 30.10.2026

Новая ARM64 сборка сохранена: Barista-0.3.0-cafe-preview.apk, Library libfile_593b35c6f59081918ddbee576b8f5cf9, 29 894 802 bytes, SHA256 b39ea8a95ca8914e34da0b186eb3c2a787135d89265aad5c89fd97a4665ebf27. Source32ffa2231d66aef49b26a712d84256472e86f83c; CI export41024619007, original debug signature matches0.1.0. User key stayed local, never Git/CI. Full release evidence reports/releases/ANDROID_CAFE_0_3_0.md.

Главный результат: утверждённая графика09 в нативной игре, intro3s/skip, play/menu/progress, pause/mute/save, тренировка и recovery. Не создавать новый концепт. Оригиналы game/content/art/cafe и approvals/materials/VISUAL-002/v9; 7 source hashes неизменны.

21 Godot scripts PASS + Linux7-state render. **Actual Android15 x86_64 smoke PASS**, run41028363869, artifact12964722431: реальные тапы/drag/drop, оплата80, restart до/после сбора, без дубля денег, mood/history/mute сохраняются, pause/progress freezing. Android graphics работают с swangle/ANGLE GLES3.1; старый swiftshader_indirect ломает шейдеры Godot4.5.1 на эмуляторе. Не возвращать deprecated GPU mode и не менять wm size во время startup.

Android-runtime workflow сейчас намеренно привязан к build41024619007, artifact хранится7 дней; для нового кода обновлять source/run привязку. Немедленные screenshots после input могут содержать предыдущий кадр, не утверждать по именам PNG фактическое содержимое. Внутренние QA PNG не сохранялись как пользовательские документы.

Следующее: физический Pixel/ARM64, 10 попыток/рецепт и скоростное комбо, плавность и слуховая проверка. Не закрывать TASK-022 только по эмулятору. Новые конкретные музыка/вступление/индивидуальные герои не утверждены окончательно; общий вид09 утверждён. Игра — preview, не финальный релиз/магазин. PR29 остаётся draft; main не менялся. SDK/license accepted ранее, повторно не спрашивать. Сборка через CI теперь работает, отсутствие локального editor/SDK не является блоком.
