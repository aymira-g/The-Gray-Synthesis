extends SceneTree

const C = preload("res://scripts/GameConstants.gd")
const GM = preload("res://scripts/GameManager.gd")
const ResClass = preload("res://scripts/Resident.gd")
const TownMapClass = preload("res://scripts/TownMap.gd")
const PCClass = preload("res://scripts/PlayerController.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING MILESTONE 6 VERIFICATION SUITE ---")
	print("==================================================================")
	
	var stats := {"passed": 0, "failed": 0}

	# Helper to track assertion
	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	# ------------------------------------------------------------------
	# TEST 1: Strategic Decision Selection Flow & Keyboard Priority
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Strategic Decision Flow & Keyboard Shortcuts")
	var gm := GM.new()
	var mock_player := ResClass.new()
	mock_player.resident_name = "Player"
	mock_player.resident_id = 1
	mock_player.secret_role = "ecology"
	mock_player.is_player = true
	gm.session_residents = [mock_player]

	gm.start_strategic_decision()
	assert_test.call(gm.strategic_decision_active == true, "Strategic window opens active")
	assert_test.call(gm.strategic_decision_resolved == false, "Strategic window initially unresolved")

	# Cast choice 1 (Confrontation) - must NOT immediately resolve
	gm.cast_player_strategic_choice(C.STRATEGIC_CHOICE_CONFRONTATION)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_CONFRONTATION, "Player strategic choice set to Confrontation")
	assert_test.call(gm.strategic_decision_active == true, "Strategic window remains active after choice 1")
	assert_test.call(gm.strategic_decision_resolved == false, "Strategic decision is NOT prematurely resolved")

	# Switch choice to Peace - must update without resolving
	gm.cast_player_strategic_choice(C.STRATEGIC_CHOICE_PEACE)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_PEACE, "Player strategic choice successfully switched to Peace")
	assert_test.call(gm.strategic_decision_resolved == false, "Strategic decision still unresolved after reconsidering")

	# Explicit commit
	gm.resolve_strategic_decision()
	assert_test.call(gm.strategic_decision_resolved == true, "Explicit resolve_strategic_decision locks decision")
	assert_test.call(gm.strategic_decision_active == false, "Strategic window closed after explicit resolve")

	# Test 1b: PlayerController keyboard routing during Strategic Decision in Phase.COURT
	var pc := PCClass.new()
	pc.resident = mock_player
	pc.game_manager = gm
	gm.current_phase = gm.Phase.COURT
	gm.court_preview_mode = "2-2"
	gm.start_strategic_decision()

	# Key [1] should select Confrontation and NOT trigger Court preview mode switch
	var ev1 := InputEventKey.new()
	ev1.pressed = true
	ev1.echo = false
	ev1.keycode = KEY_1
	pc._input(ev1)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_CONFRONTATION, "Key [1] sets strategic choice to Confrontation")
	assert_test.call(gm.court_preview_mode == "2-2", "Key [1] does NOT trigger Court preview change")
	assert_test.call(gm.strategic_decision_active == true, "Strategic window remains active after Key [1]")

	# Key [2] should switch to Peace and NOT trigger Court preview mode switch
	var ev2 := InputEventKey.new()
	ev2.pressed = true
	ev2.echo = false
	ev2.keycode = KEY_2
	pc._input(ev2)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_PEACE, "Key [2] switches strategic choice to Peace")
	assert_test.call(gm.court_preview_mode == "2-2", "Key [2] does NOT trigger Court preview change")

	# Key [N] should commit and resolve the decision, NOT advance phase or restart decision
	var ev_n := InputEventKey.new()
	ev_n.pressed = true
	ev_n.echo = false
	ev_n.keycode = KEY_N
	pc._input(ev_n)
	assert_test.call(gm.strategic_decision_resolved == true, "Key [N] resolves strategic decision without restarting")
	assert_test.call(gm.current_phase == gm.Phase.FINALE, "Resolving strategic decision transitions to Finale")

	# ------------------------------------------------------------------
	# TEST 2: Peace Route Holdout Gating & Late Ratification Fallback
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Peace Route Holdout Gating & Late Ratification Fallback")
	gm = GM.new()
	gm.drain_enabled = false
	gm.session_residents = [mock_player]
	gm.finale_route = C.FINALE_ROUTE_PEACE
	gm.current_phase = gm.Phase.FINALE
	gm.common_works = 100.0
	gm.water = 80.0
	gm.stability = 80.0
	gm.charter_ratified = false
	gm.holdout_active = false
	gm.holdout_completed = false
	gm.time_remaining = 0.5

	# Simulate time expiring while charter was never ratified
	gm._process(1.0)
	assert_test.call(gm.finale_route == C.FINALE_ROUTE_CONFRONTATION, "Unratified peace route falls back to Confrontation when Finale timer expires")
	assert_test.call(gm.confrontation_overtime == true, "Confrontation overtime enabled on fallback")
	assert_test.call(gm.time_remaining == 60.0, "60s sudden death overtime awarded")
	assert_test.call(gm.holdout_failed == true, "Holdout marked failed")
	assert_test.call(is_equal_approx(gm.water, 65.0), "Water penalty applied (-15 Water: 80 -> 65)")
	assert_test.call(is_equal_approx(gm.stability, 65.0), "Stability penalty applied (-15 Stability: 80 -> 65)")
	assert_test.call(gm.holdout_completed == false, "Holdout completed remains false")

	# Test 2b: Charter ratified late, Finale timer ends before holdout finishes
	gm = GM.new()
	gm.drain_enabled = false
	gm.session_residents = [mock_player]
	gm.finale_route = C.FINALE_ROUTE_PEACE
	gm.current_phase = gm.Phase.FINALE
	gm.common_works = 100.0
	gm.water = 80.0
	gm.stability = 80.0
	gm.charter_ratified = true
	gm.holdout_active = true
	gm.holdout_timer = 45.0  # Still 45s of holdout remaining
	gm.holdout_completed = false
	gm.time_remaining = 1.0

	# Process 2 seconds: match timer expires while holdout still active!
	gm._process(2.0)
	assert_test.call(gm.finale_route == C.FINALE_ROUTE_CONFRONTATION, "Late ratification fallback triggered when Finale timer expires before holdout finishes")
	assert_test.call(gm.confrontation_overtime == true, "Confrontation overtime active after late ratification timeout")
	assert_test.call(gm.holdout_completed == false, "Holdout not completed")

	# Test 2c: If _evaluate_match_outcome() runs without completed holdout, it must NOT award Gray Synthesis
	gm._evaluate_match_outcome()
	assert_test.call(not gm.match_ending_title.begins_with("GRAY SYNTHESIS"), "Unfinished holdout never awards Gray Synthesis")

	# Test 2d: Legitimate Peace Completion
	gm = GM.new()
	gm.drain_enabled = false
	gm.session_residents = [mock_player]
	gm.finale_route = C.FINALE_ROUTE_PEACE
	gm.current_phase = gm.Phase.FINALE
	gm.common_works = 100.0
	gm.water = 50.0
	gm.stability = 50.0
	gm.charter_ratified = true
	gm.holdout_active = true
	gm.holdout_timer = 0.5
	gm.holdout_completed = false
	gm.time_remaining = 120.0

	# Process 1 second: holdout completes successfully
	gm._process(1.0)
	assert_test.call(gm.holdout_completed == true, "Successful holdout sets holdout_completed = true")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "Successful holdout transitions directly to MATCH_OVER")
	assert_test.call(gm.match_ending_title.begins_with("GRAY SYNTHESIS"), "Gray Synthesis awarded when ratified holdout completes with resources intact")

	# ------------------------------------------------------------------
	# TEST 3: Beacon Speed Buff Scope (Generator Only)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Beacon Speed Buff Scope (Restricted to Generator)")
	gm = GM.new()
	gm.current_phase = gm.Phase.FINALE
	gm.time_remaining = 120.0
	gm.beacon_eco_freq = 75.0
	gm.beacon_tech_freq = 25.0 # Eco holds beacon majority

	var eco_res := ResClass.new()
	eco_res.resident_name = "EcoBot"
	eco_res.secret_role = "ecology"
	eco_res.game_manager = gm

	# Helper to simulate 1 second of channeling via _physics_process
	var test_ch_speed = func(pad_type: String) -> float:
		eco_res.channel_progress = 0.0
		eco_res.is_channeling = true
		eco_res.active_pad = {"task_type": pad_type, "channel_duration": 10.0, "pos": Vector2.ZERO}
		eco_res.desired_velocity = Vector2.ZERO
		eco_res._physics_process(1.0)
		return eco_res.channel_progress

	var gen_progress: float = test_ch_speed.call("generator_objective")
	var cw_progress: float = test_ch_speed.call("cw_pad")
	gm.finale_route = C.FINALE_ROUTE_PEACE
	gm.holdout_active = true
	var haz_progress: float = test_ch_speed.call("hazard_clear")

	assert_test.call(is_equal_approx(gen_progress, 1.15), "Generator channeling gets Beacon +15% speed buff (progress = 1.15)")
	assert_test.call(is_equal_approx(cw_progress, 1.0), "Common Works channeling does NOT receive Beacon speed buff (progress = 1.0)")
	assert_test.call(is_equal_approx(haz_progress, 1.0), "Hazard clearing does NOT receive Beacon speed buff (progress = 1.0)")

	# ------------------------------------------------------------------
	# TEST 4: Beacon +35% Sightline Bonus in Witness System
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Beacon +35% Sightline Bonus in Witness System across Phases")
	gm = GM.new()
	var town_map := TownMapClass.new()
	gm.time_remaining = 200.0 # Open Town alibi window (180s - 240s)
	gm.current_phase = gm.Phase.OPEN_TOWN

	var caster := ResClass.new()
	caster.resident_name = "Caster"
	caster.secret_role = "civilian"
	caster.global_position = Vector2(0, 0)

	var eco_observer := ResClass.new()
	eco_observer.resident_id = 2
	eco_observer.resident_name = "EcoObserver"
	eco_observer.secret_role = "ecology"
	# Distance 300px: Greater than base 260px WITNESS_RADIUS, but less than 260 * 1.35 = 351px
	eco_observer.global_position = Vector2(300, 0)

	var tech_observer := ResClass.new()
	tech_observer.resident_id = 3
	tech_observer.resident_name = "TechObserver"
	tech_observer.secret_role = "technology"
	tech_observer.global_position = Vector2(300, 0)

	var all_res := [caster, eco_observer, tech_observer]
	gm.session_residents = all_res

	# Case 4a: Beacon neutral (0% Eco, 0% Tech) -> Neither observer sees caster at 300px
	gm.beacon_eco_freq = 0.0
	gm.beacon_tech_freq = 0.0
	assert_test.call(is_equal_approx(gm.get_beacon_sightline_buff("ecology"), 1.0), "Neutral beacon grants 1.0x sightline")
	assert_test.call(is_equal_approx(gm.get_beacon_sightline_buff("technology"), 1.0), "Neutral beacon grants 1.0x sightline")
	gm.record_observed_sighting(caster, caster.global_position, town_map, all_res, "was seen")
	assert_test.call(not gm.evidence_journals.has(2), "Eco observer at 300px cannot see caster without Beacon majority")
	assert_test.call(not gm.evidence_journals.has(3), "Tech observer at 300px cannot see caster without Beacon majority")

	# Case 4b: Eco tunes Beacon to majority (50% Eco vs 0% Tech)
	gm.beacon_eco_freq = 50.0
	gm.beacon_tech_freq = 0.0
	assert_test.call(is_equal_approx(gm.get_beacon_sightline_buff("ecology"), 1.35), "Eco beacon majority grants 1.35x (+35%) sightline buff to Ecology")
	assert_test.call(is_equal_approx(gm.get_beacon_sightline_buff("technology"), 1.0), "Eco beacon majority gives 1.0x sightline to Technology")

	gm.record_observed_sighting(caster, caster.global_position, town_map, all_res, "was seen")
	assert_test.call(gm.evidence_journals.has(2) and gm.evidence_journals[2]["observed"].size() > 0, "Eco observer at 300px successfully witnesses caster with +35% sightline (351px range)")
	assert_test.call(not gm.evidence_journals.has(3), "Tech observer at 300px without beacon majority does NOT witness caster")

	# Case 4c: Escalation Phase Sightings (Beacon actively controlled in Escalation)
	gm.evidence_journals.clear()
	gm.current_phase = gm.Phase.ESCALATION
	gm.time_remaining = 150.0
	gm.beacon_eco_freq = 0.0
	gm.beacon_tech_freq = 50.0 # Tech holds beacon majority in Escalation
	gm.record_observed_sighting(caster, caster.global_position, town_map, all_res, "accessed Buried Generator")
	assert_test.call(gm.evidence_journals.has(3) and gm.evidence_journals[3]["observed"].size() > 0, "Tech observer at 300px witnesses action in Escalation with Beacon majority")
	assert_test.call(not gm.evidence_journals.has(2), "Eco observer at 300px without beacon majority does NOT witness action in Escalation")

	# Case 4d: Finale Phase Sightings (Beacon actively controlled in Finale)
	gm.evidence_journals.clear()
	gm.current_phase = gm.Phase.FINALE
	gm.time_remaining = 90.0
	gm.beacon_eco_freq = 60.0
	gm.beacon_tech_freq = 20.0 # Eco holds beacon majority in Finale
	gm.record_observed_sighting(caster, caster.global_position, town_map, all_res, "channeled Generator Overdrive")
	assert_test.call(gm.evidence_journals.has(2) and gm.evidence_journals[2]["observed"].size() > 0, "Eco observer at 300px witnesses action in Finale with Beacon majority")
	assert_test.call(not gm.evidence_journals.has(3), "Tech observer at 300px without beacon majority does NOT witness action in Finale")

	# ------------------------------------------------------------------
	# TEST 5: Confrontation Generator Tug-of-War Aggregation & Boundaries
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Generator Tug-of-War Same-Frame Aggregation")
	gm = GM.new()
	gm.current_phase = gm.Phase.FINALE
	gm.time_remaining = 120.0
	gm.finale_route = C.FINALE_ROUTE_CONFRONTATION
	gm.generator_tug_meter = 50.0

	# Opposing channels finish on the same frame: +5.0 and -5.0
	gm.pending_generator_deltas.append(5.0)
	gm.pending_generator_deltas.append(-5.0)
	gm._process(0.016)
	assert_test.call(is_equal_approx(gm.generator_tug_meter, 50.0), "Opposing channels on same frame cancel out (meter remains 50.0%)")

	# Tech pushes past 100% threshold
	gm.pending_generator_deltas.append(60.0)
	gm._process(0.016)
	assert_test.call(gm.generator_tug_meter >= 100.0, "Tech overdrive reaches 100.0% sudden death boundary")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "Reaching 100.0% immediately triggers MATCH_OVER")
	assert_test.call(gm.match_ending_title.begins_with("TECHNOLOGY VICTORY — GENERATOR OVERDRIVE"), "100% meter awards Technology Overdrive Victory")

	# ------------------------------------------------------------------
	# TEST 6: Court 4-0 Mandate Skips Finale
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Court 4-0 Mandate Skips Finale")
	gm = GM.new()
	var civs: Array[Node] = []
	for i in range(4):
		var civ := ResClass.new()
		civ.resident_name = "Civ%d" % (i + 1)
		civ.secret_role = "civilian"
		civs.append(civ)
	gm.set_court_preview_mode("4-0_eco", civs)
	assert_test.call(gm.court_is_unanimous == true, "4-0 mode sets court_is_unanimous = true")
	gm.current_phase = gm.Phase.COURT
	gm.advance_to_next_phase()
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "4-0 unanimous court advances directly to MATCH_OVER (skips Finale)")
	assert_test.call(gm.match_ending_title.begins_with("4-0 COURT MANDATE: ECOLOGY VICTORY"), "4-0 Ecology Court Mandate awarded")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL MILESTONE 6 VERIFICATION CHECKS PASSED SUCCESSFULLY! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)
