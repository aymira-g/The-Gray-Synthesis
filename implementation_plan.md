# Implementation Plan: Integrated 3D Gameplay Slice (Technical Spike)

## 1. Objective & Scope
Build a **focused, self-contained 3D gameplay slice** (`res://scenes/Slice3D_Integration.tscn`) to prove the four foundational technical interfaces between Godot 3D and the existing match architecture before committing to a full conversion:

1. **Player 3D Control & Camera:** `CharacterBody3D` player with responsive isometric movement, capsule collision, and follow camera.
2. **Task Interaction & Live State Mutation:** Real task execution via `GameManager.execute_task()`:
   - Channelling `TaskPadA` ("pump") mutates live `GameManager.water` (+8 Water, -1 Scrap or +4 Water if 0 Scrap).
   - Channelling `TaskPadB` ("greenhouse") mutates live `GameManager.stability` (+7 Stability).
   - Channelling `TaskPadC` ("salvage") mutates live `GameManager.scrap` (+2 Scrap).
3. **Bot 3D Navigation:** `CharacterBody3D` AI bot autonomously navigating around a 3D obstacle wall to reach `TaskPadB` and execute `"greenhouse"`.
4. **3D Physics Sightline & Evidence-Parity Witness Detection:**
   - Real 3D physics raycast (`intersect_ray()`) through explicit 3D entry points in `GameManager.gd`.
   - **Strict Evidence Parity:** `record_observed_sighting_3d()` enforces the exact same rules as the 2D version:
     - Active phase and time-window restrictions (Open Town 04:00–03:00 interval, Escalation, Finale).
     - Distance attenuation with Beacon sightline buffs (`C.WITNESS_RADIUS * buff`).
     - Exclusion of self, null, and incapacitated residents (`observer.is_incapacitated`).
     - Storing observed clues exclusively in each observer's private journal (`_add_private_evidence`).

All existing 2D methods, tests, and milestones remain 100% intact and passing.

---

## 2. Technical Architecture & File Plan

### A. Real Task Execution API
- Uses the authentic `GameManager.execute_task(task_type: String, resident_name: String, is_player: bool, is_overclocked: bool)` method:
  - `"pump"`: `+8 Water`, `-1 Scrap` (or `+4 Water` with 0 scrap).
  - `"greenhouse"`: `+7 Stability`.
  - `"salvage"`: `+2 Scrap`.
- No mock or invented task names; live match state and event logs update identically to the core game.

### B. Additive 3D Entry Points in `GameManager.gd` (Strict Evidence Parity)
- Existing 2D methods (`record_observed_sighting()` and `record_faction_ability()`) remain untouched.
- Dedicated 3D methods added to `GameManager.gd`:
  - `record_observed_sighting_3d(subject: Node, location: Vector3, town_map_3d: Node, residents: Array, event_label: String = "was seen") -> void`:
    1. Phase check: In `Phase.OPEN_TOWN`, requires `time_remaining <= 240.0 and time_remaining >= 180.0`. Valid throughout `Phase.ESCALATION` and `Phase.FINALE`.
    2. Loop observers: skips `null`, `observer == subject`, or `observer.is_incapacitated`.
    3. 3D distance check: `observer.global_position.distance_to(location) <= C.WITNESS_RADIUS * get_beacon_sightline_buff(allegiance)`.
    4. 3D sightline query: `town_map_3d.has_clear_sightline_3d(observer.global_position, location)`.
    5. Private storage: writes strictly to `evidence_journals[observer_id]["observed"]`.
  - `record_faction_ability_3d(caster: Node3D, town_map_3d: Node, all_residents: Array) -> bool`:
    1. Requires `current_phase == Phase.OPEN_TOWN`.
    2. Calls `record_observed_sighting_3d(caster, caster_pos, town_map_3d, all_residents, "used a special ability near")`.
    3. Checks 3D sightlines against non-incapacitated residents within buffed radius.
    4. If witnessed: logs public disturbance and calls `town_map_3d.spawn_field_zone_3d("disturbance_ring", region_anchor, ...)` positioned at broad regional anchor (`get_region_alert_anchor_at_3d()`) to preserve caster anonymity.
    5. **Hardened Privacy Guardrail:** If the map lacks `get_region_alert_anchor_at_3d()`, the ring is omitted entirely—it **never** falls back to `caster_pos`.

---

## 3. Files Implemented

1. [`scripts/GameManager.gd`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/scripts/GameManager.gd):
   - Added `record_observed_sighting_3d` and `record_faction_ability_3d` preserving strict 2D evidence parity, broad regional disturbance anchors, hardened zero-leak fallback guardrails, and backward compatibility.
2. [`scripts/PlayerController3D.gd`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/scripts/PlayerController3D.gd):
   - `CharacterBody3D` with isometric movement, sprint/stamina, capsule collision, task channeling via `[E]`, and ability casting via `[C]`.
3. [`scripts/BotController3D.gd`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/scripts/BotController3D.gd):
   - `CharacterBody3D` AI bot with 3D waypoints around obstacle wall, arrival detection, 2.0s task channeling, and task execution.
4. [`scripts/Slice3D_Integration.gd`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/scripts/Slice3D_Integration.gd):
   - Scene controller managing 3D environment, dusk lighting, obstacle geometry, task pads, 3D sightline checking (`PhysicsDirectSpaceState3D.intersect_ray` + fast AABB fallback), `get_region_alert_anchor_at_3d()`, camera tracking, and on-screen HUD.
5. [`scenes/Slice3D_Integration.tscn`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/scenes/Slice3D_Integration.tscn):
   - Standalone playable 3D scene.
6. [`test_slice_3d_integration.gd`](file:///e:/game/windows%20game/The%20Gray%20Synthesis/test_slice_3d_integration.gd):
   - 38-check automated test suite covering all 4 technical interfaces, regional disturbance ring anonymity verification, no-anchor omission guardrail, and the full evidence parity matrix.

---

## 4. Verification Results

- **Slice 3D Integration Test Suite (`test_slice_3d_integration.gd`):** **38 / 38 PASSED (100%)**
  - Group 1 (Movement & Collision): 5/5 passed.
  - Group 2 (Real Task Execution & Mutation): 9/9 passed.
  - Group 3 (Bot Autonomous Navigation): 6/6 passed.
  - Group 4 (3D Physics Sightline, Regional Anonymity & Evidence Parity Matrix): 18/18 passed.
- **Scene Headless Smoke Test:** `Slice3D_Integration.tscn` ran for 180 frames with return code 0 and zero errors.
- **Milestone 7 Verification Suite (`test_milestone_7_verification.gd`):** **64 / 64 PASSED (100%)**
- **Milestone 6 Verification Suite (`test_milestone_6_verification.gd`):** **52 / 52 PASSED (100%)**
- **Exported Release Binary:** Built `build/The Gray Synthesis.exe` cleanly and ran 120-frame smoke test with exit code 0.

---

## 5. Next Development Plan: Multiplayer-Feel Bot Simulation

### Objective
Improve the local 3D match so its AI residents create more varied, socially engaging play for a human player. This is an offline simulation milestone, not online multiplayer. Extend the existing bot state machine and match systems; do not replace them.

### Behavioral and information-safety principles
- Assign role-neutral temperaments to bots so civilians and operatives can share the same visible movement and pause styles. Role-specific goals may influence private decisions, but should not make role obvious through routine behavior.
- Each bot may reason only from its private role/partner knowledge, its own observations and evidence, and information explicitly made public by the game. Never use another resident's private journal to make a bot decision.
- Court testimony must be explainable from information available to that voter. Do not frame public resource trends as personal observations.
- Use reproducible per-bot randomness for focused tests. Seeded decisions should be repeatable; do not claim that a whole match is deterministic unless all relevant update order and randomness are controlled.

### Stage 1: Verify information flow, add profiles and personal memory (Implemented)
1. Trace what `table_player_clues(id, true, true)` actually exposes during First Council. Confirm whether it can reveal evidence against a known operative partner before changing its behavior.
2. Add a small set of role-neutral temperaments (for example: Dutiful, Investigator, Opportunist, and Bold), assigned independently of secret role. Make profile assignment stable for a match and reset it correctly on rematch.
3. Add a per-bot seeded RNG seam for profile assignment and bot decisions that need randomness.
4. Build bot suspicion/memory from that bot's own journal, valid partner knowledge for operatives, and explicitly public Council records only. Keep personal memory separate from shared match state.
5. If the First Council audit confirms partner leakage, adjust clue tabling narrowly and add regression coverage for both safe sharing and partner-protective withholding.

**Stage 1 acceptance checks**
- Reinitializing with the same test seed reproduces a bot's profile and tested choices.
- Profile assignment is independent of faction assignment; no temperament is exclusive to operatives or civilians.
- A bot cannot gain clues from another resident's private journal.
- Council clue-sharing tests establish exactly which evidence is public and prevent exposing known partners where that is not intended.
- Existing bot deception and match-flow tests continue to pass.

**Stage 1 implementation note:** The First Council audit confirmed that bots previously tabled all private clues, including sightings naming known faction partners. Bot clue tabling now withholds those partner-identifying clues while retaining unrelated evidence. Bot controllers now have seeded temperaments, per-bot RNG, and provenance-separated personal/public evidence memory. Temperaments are foundation data only at this stage; profile-driven movement and covert choices are Stage 2.

### Stage 2: Let profiles shape movement and covert decisions (Implemented)
- Bias existing chore selection, patrol routes, pause cadence, and objective interest by temperament without replacing navigation or the existing bot state machine.
- Let profiles influence operative covert-action timing and target choice, while keeping visible behavior sufficiently similar across roles to avoid obvious role tells.
- Add civilian inspection or crisis-response behavior only where supported by existing task and observation APIs.
- Defer hero `[F]` ability use until bots can invoke the same validated ability handlers as the player; avoid duplicating ability effects in AI code.

**Stage 2 acceptance checks**
- Controlled tests show meaningful, repeatable profile differences in choices, not merely cosmetic labels.
- Bots still navigate, complete chores, and execute existing covert actions correctly.
- Profile-driven behavior does not expose role through a deterministic movement pattern.
- Profile detours do not permanently replace civic-job chores; Investigator bots still reach station tasks.
- Bots exclude jammed pads from task selection and keep floating task labels on one line.

**Stage 2 implementation note:** Personal memories refresh after hero-draft changes, on entry to Open Town, before bot destination/covert decisions, at First Council, and before Court decisions. Council now emits one concise AI evidence-sharing event rather than logging each bot as "You." Temperaments affect chore selection, investigation destinations, pause cadence, and operative covert timing/target choice; non-Dutiful profiles alternate detours with their civic routines. Task selection skips both cooldown and jammed pads, and bot action labels use single-line pad titles. Hero `[F]` ability use remains deferred for a separate validated pass.

### Stage 3: Improve observation-based Court reasoning (Implemented)
- Update civilian bot voting to weigh that voter's own observations and public Council evidence alongside public crisis conditions.
- Treat evidence types according to their provenance and reliability; a trace or contradiction is not equivalent to a witnessed action.
- Generate Court reasons only from information that supports the chosen explanation. Retain resource-based reasoning when the bot has no relevant evidence.
- Vary deliberation timing by temperament while preserving player controls, timeout behavior, and fast-forward.

**Stage 3 acceptance checks**
- Tests prove private evidence affects only its owner's reasoning unless it is explicitly tabled publicly.
- Votes and spoken reasons reflect the information actually available to that civilian.
- Seeded decision tests are repeatable, and tests cover both evidence-led and resource-led votes.
- Existing Court, role-privacy, end-to-end, and bot-deception suites continue to pass.

**Stage 3 implementation note:** Civilian bots now evaluate only admissible evidence (their own private journal entries + publicly tabled Council evidence). Ideological clues and sector disruptions are weighted by provenance tier (`EVIDENCE_FACT` > `EVIDENCE_TRACE`), unverified claims contribute 0 score, and public alibi conflicts corroborate only ideological clues naming that resident without psychic role-reading. Testimony quotes strictly match the winning vote factor (fixing the vote-vs-reason discrepancy). Podium deliberation time scales safely by temperament (`BOLD` 1.2s -> `OPPORTUNIST` 1.8s -> `DUTIFUL` 2.7s -> `INVESTIGATOR` 3.5s) while preserving `[Space]` fast-forward and timeout guarantees.

### Suggested verification
Add a focused `test_bot_personalities_and_memory.gd` suite for profile distribution, seeded reproducibility, knowledge boundaries, clue provenance, and Court reasoning. Run it alongside `test_option4_bot_deception.gd`, the First Council and Court tests, and the full regression runner before considering the milestone complete.

### Stage 4: Court readability and social suspicion pass (Implemented)
- Improve the Court podium so each ballot reads like a believable piece of testimony rather than a generic summary.
- Surface the actual source of each argument: private observation, public tabled clue, resource fallback, or corroborated public contradiction.
- Add bot suspicion drift and trust decay that evolve across the match without leaking private role knowledge.
- Tune public events and bot speech so the social deduction layer feels alive but still readable to the player.
- Preserve all current Court contracts and bot safety guardrails while making the emotional cadence more convincing.

**Stage 4 acceptance checks**
- Every bot vote includes a reason traceable to data the bot had access to.
- Court logs clearly distinguish personal witness testimony from Council-public evidence and resource fallback.
- Suspicion changes over time in response to public contradictions and observed actions, without exposing secret roles or private journals.
- The match remains playable and legible during rapid multi-bot turn sequences.
- Existing regression suites continue to pass.

**Stage 4 implementation note:** This is the first polish milestone after the evidence-driven Court AI. The goal is not a structural rewrite: it is an experience pass to make the AI feel human, social, and readable while keeping the rules tight and reproducible.

**Stage 4 completion note:** Court ballots now carry source-tagged, readable reasons. Bot memories summarize suspicion and trust, track suspicion drift between refreshes, and let social behavior respond to known trust and rumor state without exposing private journals or secret roles.

### Stage 5: Public Court consensus and social influence (Implemented)
- Let later civilian voters respond modestly to earlier public Court ballots, creating visible social momentum during sequential deliberation.
- Scale that influence by each bot's temperament and its own trust in the earlier voters; keep the influence bounded so direct evidence and major resource crises remain decisive.
- Explain consensus-driven reasoning with a distinct Court source label and preserve the existing public/private evidence boundary.

**Stage 5 acceptance checks**
- Later votes can shift in response to prior public ballots and their explanations identify that influence.
- Temperament and personal trust produce bounded, measurable differences in social influence.
- A bot's own ballot is excluded, untrusted voters exert less influence, and no secret-role or other resident's private-journal lookup is required.
- Court voting, timeout, fast-forward, role privacy, and full regression tests continue to pass.

**Stage 5 implementation note:** Public civilian ballots now contribute at most six points per faction to later bot votes. DUTIFUL bots follow consensus most, followed by OPPORTUNIST, INVESTIGATOR, and BOLD; personal trust scales each speaker's influence. Court reasons identify this source as `COURT CONSENSUS`.
