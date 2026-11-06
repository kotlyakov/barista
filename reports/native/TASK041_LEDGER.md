# TASK-041 ledger

Base e369e45eed1fff2353212326fd96d4718557a055; branch task/TASK-041-endless-shifts.
Preflight: optional career shift in Service v2; Schema/Repository must be extended together. V1 Shift/Session/UI remain unchanged. Existing standalone v2 tests remain valid without enable_career().
Ruling: use shift/career_shift.gd and explicit enable_career/start_shift(expected_day)/finish_summary(summary_id), retaining standalone compatibility until043.
Ruling: actual collected earnings only in day summary; no invented new-day premium before042. End-of-day terminal figures/payments are cleared only on summary transition; normal departure still owns its slot.
Ruling: one immediate visitor at start, saved deterministic bounded arrival stream afterward. A full cafe does not accumulate an infinite queue or consume RNG. At300s closing wins over a simultaneous arrival.

Review fix pass:3 Important findings covered by regressions: closing has no preparation without a waiting recipient; carry returns at315s/payment-only mode; persisted summary must be the latest allocated summary ID; after-hours arrivals and empty closing rejected. Minor impossible earnings fixed with zero/min/max receipt bounds and consistency with known terminal receipts (currently50..108, combo disabled). New regressions observed6 failures before fixes, then all3 new scripts PASS.
Ruling: bounds for receipts and12s payment duration describe current approved base prices;042 must extend these schema constraints when adding gifts/effects/pricing.

TASK041 complete:b1bd9e49, native42213214816/docs42213214840 SUCCESS;38 scripts/9 legacy renders,28 local scripts PASS. Next042.
