# TASK-028 — Android audio crash investigation

Owner report: latest APK exits on buttons and grinder taps. Owner's isolation test: **without sound it works**. Earlier context identifies Pixel 7 Pro / Android 17; current OS version not independently measured.

1. Re-test unchanged 0.3.0 with station effects enabled. Previous smoke muted them before brewing. Actual run41072984713 passed on Android15 x86_64; this does not reproduce the physical fault.
2. Ship explicitly temporary diagnostic preview0.3.1/code4: Android launches silent without overwriting preferences; sound may be enabled deliberately from menu. Preserve original graphics, gameplay, saves, package and signing key.
3. Flush bounded audio breadcrumbs before/after native playback calls. Recover prior run on next launch. Add menu copy-report including unprivileged app crash-buffer read; request no logging or storage permissions.
4. Test silent launch, explicit opt-in and diagnostic recovery; run existing native suite, export APK, sign original key and run Android touch/extra-tap/report scenario against exact new source.
5. Owner can play silently. For root-cause investigation, enable sound, reproduce, reopen and copy report. Do not call the underlying native audio fault fixed until logs and physical retest support it.

Regression observed RED: audio_diagnostics_test assertion `diagnostic build needs a safe audio startup`; after implementation 22 scripts PASS locally. This is mitigation and instrumentation, not a speculative engine fix.
