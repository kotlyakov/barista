# Передача — единая нативная кофейня, 30.10.2026

Точный принятый вид 09 находится в game/content/art/cafe и approvals/materials/VISUAL-002/v9. Продолжен локальный нативный перенос 1eacef7; новый поток Артура в docs/OWNER_FLOW_20261030.md. Не начинать дизайн заново. Intro/play/menu/progress реализованы в game/ui/main.gd, звук-кандидат cafe_audio.gd.

Локально 21/21 Godot scripts PASS, включая intro boundary/skip, menu/progress/background pause, старые сохранения mute, disk rollback, кофе/выдача/оплата/перезапуск, тренировка, двухшаговый recovery. Независимое code review получено, важные замечания исправлены. Native render запрашивается в CI; до фактических PNG не писать visual PASS.

Editor/Android SDK в текущей среде отсутствуют. Для тестов /tmp/barista-godot-4.5.1 — debug export runtime из старого Linux executable. Это не editor и не умеет Android export. artifacts/Barista-0.2.0-cafe-preview.apk старый, не выдавать за новую сборку. Debug keystore есть в artifacts и в прежней Library, не пересоздавать и не пушить. Физического Android нет, TASK-022 не закрыт.

Конкретная новая музыка/вступление/финальные герои не получили отдельного финального утверждения; общий вид стойки/бариста/временных клиентов утверждён. Устройства и звуковую проверку не подменять headless suite. Продолжить с CI screens, затем восстановить SDK/editor и выпустить APK той же подписью.
