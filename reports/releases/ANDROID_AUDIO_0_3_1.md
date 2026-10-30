# Android 0.3.1 — temporary audio mitigation and diagnostics

30.10.2026, TASK-028. **Underlying native crash remains open.**

Owner: latest APK exits after button/grinder taps. Targeted isolation answer: «Без звука работает». Earlier context identifies Pixel 7 Pro / Android17; current device OS not measured in this session.

The earlier Android smoke switched sound off before brewing. Re-ran unchanged0.3.0 with station audio enabled: run41072984713 SUCCESS, artifact12985387669, source32ffa2231d66aef49b26a712d84256472e86f83c. Actual Android15 x86_64 coffee/payment/restart passed. This narrows but does not reproduce the physical fault. Known missing-VIBRATE crash is already caught in Godot4.5.1 upstream; no speculative vibration or renderer changes applied.

## Diagnostic build

- `Barista-0.3.1-audio-diagnostic.apk`, package `org.kotlyakov.barista`, code4, ARM64, min24/target35.
- Size29,898,898 bytes; SHA256 `7890d8d11c74b32117b2197bf0dc73b203f1813582e3916b0a593291feccfc2d`.
- Source `b09bf205d29f80545b754000a521480808f81ba9`; build41074447113, artifact12985478844.
- Library `libfile_33dba36456f081918b04cbdaae0929ea`.
- Original local key, signer cert SHA256 `eee33a840769e0e2e4558e2fad925a5158e7d73104195d0b41b1991f241d6639`, matches0.1.0. No key in Git/CI.
- Official apksigner v2/v3, zipalign16KB, aapt/package/ABI/version and ZIP PASS. Log `artifacts/android-ci-0.3.1/final-verification.log`.

Android starts muted on **each launch**, including previously unmuted profiles. This diagnostic override does not overwrite saved preferences; explicit menu sound toggle enables it for diagnosis. This temporary behavior intentionally differs from normal sound-preference restoration. Menu labels reflect actual audio state.

Audio breadcrumbs flush before/after activation and native stream/play calls, bounded to64KiB/run. Next startup retains the previous run in memory for copying. The menu report adds OS/model/audio-driver and a bounded unprivileged Android app crash-buffer read; no READ_LOGS, storage or network permissions and no telemetry. Android may deny/omit the crash buffer; breadcrumbs still work. Copy immediately after the first restart following a crash; a further restart replaces the previous run.

Approved original room/actors and gameplay/economy unchanged. No progress reset. Install over existing APK with same package/key. These diagnostics and temporary menu entry are not a new final art/audio approval.

## Validation and remaining work

Observed RED assertion in `audio_diagnostics_test.gd`: safe startup absent. GREEN:22 local Godot scripts PASS, including prior-run recovery, explicit sound opt-in, restart safe mode and unchanged money/preferences. Existing pause/payment/recovery tests pass. Python smoke compiles; diff check PASS. SELF_REVIEW only for this small diagnostic change.

New Android smoke is pinned to this exact source/build; runtime41074761425 SUCCESS, artifact12986123767, test source42fa97c9ebae9ffdea54984dea4825d2562e43ae. It deliberately enables audio, adds20 extra grinder taps, checks complete payment/restart/pause flow and invokes the native report-copy path. Physical fault remains NOT_FIXED until device logs and retest support an actual repair.

Owner procedure: install0.3.1, play silently; to collect evidence enable sound, reproduce crash, reopen once, menu → «Скопировать отчёт», paste into chat. Next implementation must follow that trace, not guess at native audio/driver fixes.

Actual result.json: Android15 x86_64,1920×1080,20 extra grinder taps with effects enabled, payment80/balance80, restart before/after collection, pause/mute and report button PASS. `04-restored.png` visually shows Android clipboard preview beginning BARISTA AUDIO REPORT0.3.1, proving the report copied; underlying frame lags the menu as already documented for this emulator. Internal screenshots were not saved as user deliverables. Evidence local `/tmp/barista-diagnostic-runtime/`.
