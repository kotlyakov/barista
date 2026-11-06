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
