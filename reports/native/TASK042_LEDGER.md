# SDD ledger — plan: docs/plans/2026-11-06-career-economy.md
Base bdec52fc9f88189c75f5710732fc2d8545498c5b; изолированная task042 копия, Git-операции через подключённый GitHub. Локально нет .git и artwork, как в041. Полный CI обязателен.
Pre-flight:042 consumes041.shift/040.Repository/038.Cup. Current Schema hardcodes50..108/12s and needs explicitly computed bounds and gift-zero receipts; allowed paths расширены координатором до persistence/brewing/shift и метаданных ДО изменения.
Ruling: новая экономика включается явно отдельно от041 для сохранения старых v2-снимков; legacy/review и несовместимые покупки не активируются до044 — потеря прогресса недопустима — UI должен вызвать enable_development для нового профиля.
Ruling: числа каталога — авторская стартовая калибровка с измерениями, не новое APPROVED — после плейтеста потребуется настройка.

RED:3 новые скрипта до кода вывели FAIL missing economy. GREEN:все3 PASS после реализации. Добавлен career_balance_test:72 сочетания/реальная игра/4 процесса PASS.
Локальная проверка документов честно FAIL: отсутствуют7 материаловVISUAL002/v9 в частичном снимке. Не подменять материалы; полный docs CI запускается на GitHub.
В первом локальном baseline-run два UI-зависимых теста зависли на отсутствующих ресурсах и были остановлены; перечень локального domain-run теперь исключает ровно10 UI/audio скриптов, включая progress_purchase. Полный native CI проверяет их все с artwork.
Калибровка seed73 day1:0.12 и0.28с/тап дают19 хороших/1484 собранных монет;0.8с/тап —6 выдано,4 хороших,11 ушло,434 монеты;плохие/не собирать —19 выплат истекли,0монет. Это реальный Service,не формулаHTML;автоигрок не заменяет плейтест на телефоне.

Final independent review:7 Important groups — goal/fame plausibility, active gift replay, critic/choice markers, malformed shift safety, original receipt deadline, review-mode enable gate, paid-vs-gift income lower bound. Each reproduced RED in career_economy_regression_test, original logs kept locally. One fix pass in progress, no re-review.
Scope correction:roster favorite_weight argument requires game/customers/; omitted in original allowed_paths expansion, coordinator corrected before final commit; no concurrent writer.
Final: minor (deferred):parity validation of forecast in external snapshots; runtime-generated forecasts alternate correctly.
Final: minor (deferred):aroma description says minimum6s, refers to base interval; jitter lower4.5s. UI text to clarify before043.

Final: fixed all7 Important groups — career_economy_regression_test RED→GREEN, suite32/32 PASS. Gift count separate from paid receipts restores lower-bound check. No re-review.
Coverage extended after review to216 combinations across all3 module pairs, exact independent event prices, drive tap/maintenance pins, friend flow and discount numerical assertions; PASS.
