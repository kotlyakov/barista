# SDD ledger — plan: docs/plans/2026-11-06-legacy-activation.md
Base c8bdde83b86975a0d5aa060e2e5a82323d1986c2; task044 isolated copy, no .git/artwork. Godot4.5.1. Full GitHub CI required.
Pre-flight:040.review snapshot uses unknown cold timestamps and retains tuning/grace;042 rejects them. Candidate imports only at safe legacy boundary and issues explicit source-bound receipt; existing review converter unchanged.
Ruling: finish active legacy Session before candidate conversion — exact current coffee/perk/payment is preserved without invented temperature — UI043 must support a brief legacy continuation until boundary.
Ruling: implement and verify full-refund candidate, keep D16 PROPOSED and live activation disabled — TASK044 acceptance explicitly requires owner choice of incompatible upgrades — one final approval remains before switching.

RED:2 начальных скрипта —missing converter/persistence. GREEN:13 phase fixtures/12 refund combinations/4 OS processes PASS. Full pre-review suite34/34 PASS.
Independent review исходной версии:5 Important,0 Critical. Строгое чтение всех source-slots; полный canonical compare кандидата; extra backup presence; сохранение selected SHOP perk; защита fresh-start при candidate-only evidence. Все5 воспроизведены RED в legacy_candidate_regression_test, затем исправлены одним проходом. Повторного ревью нет.
Final: minor (deferred):backup_v1 does not separately check get_buffer length/error after read; it does compare persisted bytes with the read buffer. Add explicit short-read detection before final live activation.
Initial local runner used TASK042 log prefix in task044 report directory; corrected to TASK044. RED observed in actual tool outputs, not claimed as retained red logfile.

Final: fixed5 Important groups — legacy_candidate_regression_test RED→GREEN; whole local suite35/35 PASS. Task044 candidate complete, actual activation WAITING_USER D16.
