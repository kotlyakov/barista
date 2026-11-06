# Ledger — docs/plans/2026-11-05-v042-integration.md

Base:19a8d2111844af0ff9cc0a1efc36f7722bc6ed89. Branch:task/TASK-038-free-cup.

Pre-flight:038→039→040 share cup snapshot/recipe/temperature;039 consumes evaluate;040 introduces saved model.
Ruling: free model lives in brewing/cup.gd, existing brewing/brew.gd remains v1 until039/040 integration — current Session/Store/UI require stage/grace/locked and cannot consume a new snapshot safely — cost: temporary two models, removed after migration.
Ruling: local workspace is an isolated partial source snapshot resolved from GitHub API at exact SHA; no authenticated local Git clone or binary artwork — domain checks run locally, complete regression runs in remote CI with all assets — cost: full UI evidence depends on CI.

TASK038 in progress; Godot4.5.1 official archive SHA256 02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd verified.

Review: independent reviewer found release-only constructor side effect and empty-cup JSON numeric-array equality. Both corrected: select_recipe runs before assert; empty detection uses numeric counters. Empty cups for all three recipes reproduced RED (3 failures)→GREEN.
Final: minor (deferred): pin literal C history outputs beyond wait independence; existing J examples cover shared factors but not C output independently.
Final: minor (deferred): reject impossible single-tap snapshots with unequal first/last/heat timestamps; ordinary snapshots are valid and unchanged.
Final: Ruling: empty-cup evaluation can return a score but is never deliverable (can_take=false); delivery caller must guard it in039 — separates snapshot validity from delivery eligibility — cost: misuse of evaluate alone could display a meaningless empty-cup score.
Final: Ruling: Android/UI/migration not reviewed in038 because unmodified v1 remains active; their gates remain040/043 — cost: domain PASS is not full feature acceptance.

Task038 complete: commit c6eec7fd; full native-check42162175312 and docs-check42162175246 SUCCESS. New files do not replace old callers.
Pre-flight039: service consumes Cup.snapshot/Evaluation.evaluate; Store/UI still v1.
Ruling039: use orders/service.gd as the v2 Session model until040 handles actual profile migration; current Session/UI stay v1 — prevents mixed-schema writes — cost: temporary separate model.
Ruling039: relationship start calibration is written before coding in v042-balance.md; neutral begins at J60 (spec reaction boundary), rather than earlier unapproved J40 proposal — author balance choice, not an owner approval — cost: balance may require recalibration.

Task039 test ruling: a single dry-ground tap has small positive Q/C by accepted formula, not C=0. Corrected the four-zero-C fixture to all three stations N+10, rather than changing production formula to satisfy a wrong test.

TASK039 review: pause-carry bug fixed with3 assertions RED→GREEN; independently timed guest A/B stale-recipient and early duplicate rejection tests added.
Ruling039: Service.restore is internal/trusted roundtrip; untrusted file validation and disk atomicity remain040 and must precede UI hookup — prevents a claim that saving support is complete — cost: v2 cannot yet accept arbitrary disk snapshots safely.
Minor038 C-output suggestion is covered by039 literal C/L history tests. Single-tap timestamp hardening remains deferred to Store040.
