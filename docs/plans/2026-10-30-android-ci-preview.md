# TASK-027: новый Android preview с прежней подписью

Goal: собрать фактический APK 0.3.0 единой кофейни.
Architecture: GitHub Actions использует официальный Godot 4.5.1 и SDK build-tools 35.0.0, выпускает unsigned ARM64. Ключ остаётся локально; официальный apksigner из SDK подписывает доставленный APK.

- [ ] Подготовить CI export, проверить YAML и опубликовать изменения в существующей feature-ветке.
- [ ] Дождаться фактического экспорта, получить APK и официальный signing toolkit, сверить source SHA и версии.
- [ ] Подписать прежним ключом вне Git; проверить signature/cert digest, ZIP/alignment/manifest/ABI и сохранить новый APK для скачивания.
- [ ] Обновить задачи, handoff, отчёт; явно разделить проверки файла и runtime на телефоне.

No final art/audio approval is implied. Android SDK licence already accepted by Артур. Private repo/audience preserved.
