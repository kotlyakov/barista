# Native cafe 09 implementation plan

> **For agentic workers:** Use superpowers:executing-plans. Owner explicitly requested autonomous execution through serious blockers; no repeat planning approval.

**Goal:** Replace technical station rectangles with the approved cafe 09 and expose the same complete native game loop.
**Architecture:** Preserve Session/Repository domain. Draw approved PNG with clipped foreground polygons. Export the existing SVG rigs into native textures, animate poses in Godot. Exactly one active customer; wait for outgoing actor to leave before next appears.
**Tech Stack:** Godot 4.5.1, GDScript, Python/Node stdlib tooling.
**Spec:** docs/GAME_SPEC.md; docs/APPROVED_VISUAL_REFERENCE.md.

## Global Constraints
- Native Android landscape, offline, one active order. Preserve transactional saves and input deduplication.
- Source VISUAL-002/v9 is immutable; temporary characters remain temporary. No new approval inferred.
- TASK-016 final integration remains gated. TASK-024 is a playable visual work build.
- Real phone runtime/calibration remains TASK-022.

## Review Focus
- Tap zones align with approved equipment, and modal panels never leak actions.
- Background/pause cancels cup drag and freezes animation and domain clock.
- Relaunch in PAYMENT renders same customer/payment, without replaying transaction.
- Queue animation cannot create second order or alter RNG/save semantics.
- Portrait and wider screens preserve scene geometry and input coordinates.

### Task 1: Approved art provenance and native rigs
- [ ] Export original vector layers with deterministic script; preserve original shapes; source SHA manifest.
- [ ] Implement native pose clock, facing turn before exit, movement and face crossfades.
- [ ] Test departure reaches right-facing orientation before moving; queue has no simultaneous actors.
Interfaces: cafe presentation reads Session state only; no economy writes.

### Task 2: Native cafe and all state feedback
- [ ] Add failing test asserting station hit areas at approved positions and foreground resources.
- [ ] Wire view and input to approved coordinates, rounded bars, cup/steam, coins, emotions.
- [ ] Keep existing shop/perk/summary accessible, improve drafts and mark unapproved scope.
- [ ] Run `GODOT=... python3 tools/check_native.py`: all scripts PASS. Existing ui_flow_test must still brew/deliver/save/collect.
- [ ] Capture actual rendered Godot screenshots, inspect layering and text.
- [ ] Independent review, fix Important with regression checks, docs validator, commit/push PR.
