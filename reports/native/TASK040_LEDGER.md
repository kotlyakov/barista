# TASK-040 ledger

Base38b819cab18ec30345800ec3da52cc5785defed1. Branch task/TASK-040-safe-saves.

Preflight:Service internal restore becomes externally validated; validator must not importService (cycle). V1 Store/Repository/UI remain unchanged. New persistence modules use Service v2.
Ruling: v2 storage and repository are separate from v1 until UI integration, preserving real saves.
Ruling: legacy conversion is a REVIEW-ONLY import to v2-review, never implicit activation of old paid effects/unknown heat. Production repository refuses old profile until migration policy is settled; this fulfills the no-silent-conversion gate without inventing owner approval. Cold temperature is an explicit review assumption, raw legacy data retained.
Ruling: transaction tests cover currently implemented domain actions (delivery/collect/spawn/expiry); future purchase/gift/day actions join same commit/rollback boundary when implemented041/042.

Review fix pass: critical JSON timestamp rounding reproduced with74.99999999999999; full_precision and validation of serialized payload added. Generation included in checksum and checked by Repository to reject stale writers. Reciprocal visit/payment/history/cup links forbid re-serving completed visits and impossible payouts. In-memory rollback preserves carry; real restore returns cup. Pause flushes partial active time. Import evidence prevents fresh-zero profile when original v1 is missing. Optional v1 payout fields validated before int conversion. All findings have executable regressions; true process restart smoke added.
Ruling: one synchronous Godot main-thread writer; generation check rejects stale sequential Repository instances. Simultaneous independent OS-process writes are unsupported (no claim of interprocess CAS/locking).
Ruling: production legacy activation remains closed; imported data/old effects live only under v2-review and immutable v1 backups until policy/UI tasks.

TASK040 complete:2f3685c8, native42166465973/docs42166465887 SUCCESS;35 scripts/9 legacy-render states,25 local domain/process scripts PASS. Final activation explicitly split to044 after042; next041.
