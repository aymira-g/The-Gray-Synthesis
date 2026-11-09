extends SceneTree

# ==============================================================================
# The Gray Synthesis - Full 3D Phase 3 Automated Verification Suite
# ==============================================================================
# Verifies:
# 1. Project Configuration: default main scene set to Main3D.tscn
# 2. First Council Assembly & Observations in 3D
# 3. 3D Civilian Court Ceremony (podium walk, 3D speech bubble, sequential voting, fast forward)
# 4. 4-0 Court Mandate Instant Victory & Podium Celebration in 3D
# 5. Split Court Strategic Deliberation Window (Confrontation vs Peace) & Input Handling
# 6. 3D Confrontation Finale (Generator Overdrive Tug-of-War pad channeling)
# 7. 3D Peace Finale (Common Works Holdout & Charter Ratification)
# 8. Full Match Lifecycle Restart Loop (Key R -> start_new_match)
# 9. Camera Director Interpolation Modes (wide_council, court_podium, follow_player, celebration)
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING FULL 3D PHASE 3 VERIFICATION SUITE ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	# ------------------------------------------------------------------
	# TEST GROUP 1: Project Configuration & 3D Main Scene Default
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Project Configuration & 3D Main Scene Default")
	var project_file := FileAccess.open("res://project.godot", FileAccess.READ)
	assert_test.call(project_file != null, "project.godot file exists and is readable")
	var project_text: String = ""
	if project_file != null:
		project_text = project_file.get_as_text()
		project_file.close()

	assert_test.call(project_text.find("run/main_scene=\"res://scenes/Main3D.tscn\"") != -1, "project.godot default main scene is permanently set to res://scenes/Main3D.tscn")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var gm: Node = main.game_manager
	var map: Node3D = main.town_map
	var residents: Array = main.residents
	var player: CharacterBody3D = main.player_node

	assert_test.call(main != null, "Main3D instantiated and initialized successfully")
	assert_test.call(residents.size() == 10, "10 3D residents spawned in Town Square")
	assert_test.call(player != null, "Player node assigned to Resident 1")
	assert_test.call(gm != null, "GameManager present in 3D hierarchy")

	# ------------------------------------------------------------------
	# TEST GROUP 2: First Council Assembly & Observations in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] First Council Assembly & Observations in 3D")
	# Advance from Briefing to Open Town
	gm.set_phase(gm.Phase.OPEN_TOWN)
	assert_test.call(main.camera_mode == "follow_player", "Open Town switches camera to follow_player")

	# Move player and a bot away from center
	player.position = Vector3(15.0, 0.0, 15.0)
	residents[1].position = Vector3(-15.0, 0.0, 15.0)

	# Transition to First Council
	gm.set_phase(gm.Phase.FIRST_COUNCIL)

	assert_test.call(main.camera_mode == "wide_council", "First Council switches camera to wide_council")
	var p_dist: float = player.position.distance_to(main.spawn_positions[0])
	assert_test.call(p_dist < 0.01, "Player gathered back at council ring spawn position (dist: %.2f)" % p_dist)
	var r1_dist: float = residents[1].position.distance_to(main.spawn_positions[1])
	assert_test.call(r1_dist < 0.01, "Bot gathered back at council ring spawn position (dist: %.2f)" % r1_dist)

	# Facing inward towards center
	var to_center: Vector3 = (Vector3.ZERO - player.position).normalized()
	var expected_rot: float = atan2(-to_center.x, -to_center.z)
	assert_test.call(abs(player.mesh_root.rotation.y - expected_rot) < 0.05, "Resident faces inward toward Council podium center")

	# Verify prepare_first_council with TownMap3D coordinates
	assert_test.call(gm.alibi_statements.size() > 0, "Alibi statements generated with 3D town map")
	assert_test.call(gm.tabled_evidence.size() > 0, "Tabled evidence populated for First Council")
	assert_test.call(main.status_label.text.find("FIRST COUNCIL") != -1, "HUD displays First Council prompt")

	# Skip to Escalation via Enter key event
	var ev_enter := InputEventKey.new()
	ev_enter.pressed = true
	ev_enter.keycode = KEY_ENTER
	main._unhandled_input(ev_enter)
	assert_test.call(gm.current_phase == gm.Phase.ESCALATION, "Pressing [Enter] in First Council advances to Escalation")
	assert_test.call(main.camera_mode == "follow_player", "Escalation switches camera back to follow_player")

	# ------------------------------------------------------------------
	# TEST GROUP 3: 3D Civilian Court Ceremony & Podium Walk
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] 3D Civilian Court Ceremony & Podium Walk")
	# Enter Court phase via set_phase
	gm.set_phase(gm.Phase.COURT)

	assert_test.call(gm.court_ceremony_active == true, "Court ceremony marked active in GameManager")
	assert_test.call(main.court_overlay.visible == true, "Court HUD overlay visible")
	assert_test.call(main.camera_mode == "court_podium", "Court phase sets camera mode to court_podium")
	assert_test.call(gm.court_civilians.size() == 4, "Court gathered 4 Unaffiliated Civilians")

	# First voter walking to podium
	main._update_court_ceremony(0.016)
	var civ0: CharacterBody3D = gm.court_civilians[0]
	assert_test.call(main.active_podium_speaker == civ0, "civ0 is active podium speaker")
	assert_test.call(civ0.position.distance_to(Vector3(0.0, 0.25, 0.8)) < 0.05, "civ0 physically at podium (Vector3(0.0, 0.25, 0.8))")
	assert_test.call(abs(civ0.mesh_root.rotation.y - PI) < 0.05, "civ0 at podium faces south toward council ring assembly")

	# 3D Speech bubble displayed
	var non_player_civ: CharacterBody3D = civ0 if not civ0.is_player else gm.court_civilians[1]
	non_player_civ.show_speech_bubble("Testing town priorities speech bubble", 4.0)
	assert_test.call(non_player_civ.speech_label != null and non_player_civ.speech_label.text != "", "3D resident displays speech bubble over head: %s" % non_player_civ.speech_label.text)

	# Cast Voter 0's ballot
	var civ0_seat: Vector3 = civ0.spawn_position
	gm.cast_sequential_court_ballot(civ0, "Ecology", "Protect aquifers", false)
	assert_test.call(gm.court_voter_index == 1, "Court voter index advanced to 1")
	assert_test.call(gm.court_split_summary == "1-0", "Running ballot tally is 1-0")

	# Voter 1 walks to podium, Voter 0 returns to seat
	main._update_court_ceremony(0.016)
	var civ1: CharacterBody3D = gm.court_civilians[1]
	assert_test.call(main.active_podium_speaker == civ1, "civ1 transitioned to active podium speaker")
	assert_test.call(civ1.position.distance_to(Vector3(0.0, 0.25, 0.8)) < 0.05, "civ1 walked to podium")
	assert_test.call(civ0.position.distance_to(civ0_seat) < 0.05, "civ0 returned to designated council seat")

	# Fast Forward key test
	gm.court_fast_forward = false
	var ev_space := InputEventKey.new()
	ev_space.pressed = true
	ev_space.keycode = KEY_SPACE
	main._unhandled_input(ev_space)
	assert_test.call(gm.court_fast_forward == true, "Pressing [Space] during bot court turn triggers court_fast_forward")

	# ------------------------------------------------------------------
	# TEST GROUP 4: 4-0 Court Mandate Instant Victory in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] 4-0 Court Mandate Instant Victory in 3D")
	# Reinitialize fresh court on Main3D
	gm.set_phase(gm.Phase.COURT)

	# Cast 4 unanimous Technology votes
	for i in range(4):
		var civ_voter: CharacterBody3D = gm.get_active_court_voter()
		gm.cast_sequential_court_ballot(civ_voter, "Technology", "Grid stability mandate", false)

	assert_test.call(gm.court_is_unanimous == true, "4 unanimous Tech votes produce court_is_unanimous = true")
	assert_test.call(gm.court_unanimous_winner == "technology", "court_unanimous_winner = 'technology'")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "4-0 mandate immediately transitions to MATCH_OVER")
	assert_test.call(main.camera_mode == "podium_celebration", "Camera director enters podium_celebration mode")
	assert_test.call(main.game_over_overlay.visible == true, "Game Over overlay visible")
	assert_test.call(main.game_over_title.text.find("TECHNOLOGY VICTORY") != -1, "Game Over title announces Technology Victory Mandate")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Split Court Strategic Deliberation Window & Input
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Split Court Strategic Deliberation Window & Input")
	# Fresh court with 3-1 split
	gm.set_phase(gm.Phase.COURT)

	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 1", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 2", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 3", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Technology", "Vote 4", false)

	assert_test.call(gm.strategic_decision_active == true, "3-1 split activates strategic_decision_active")
	main._update_hud()
	assert_test.call(main.strategic_overlay.visible == true, "Strategic Deliberation overlay visible")
	assert_test.call(main.strategic_text_label.text.find("CIVILIAN COURT SPLIT: 3-1") != -1, "Strategic overlay displays 3-1 split summary")

	# Test input: Key 1 selects Confrontation
	var ev_1 := InputEventKey.new()
	ev_1.pressed = true
	ev_1.keycode = KEY_1
	main._unhandled_input(ev_1)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_CONFRONTATION, "Pressing [1] sets strategic choice to Confrontation")

	# Test input: Key 2 selects Peace
	var ev_2 := InputEventKey.new()
	ev_2.pressed = true
	ev_2.keycode = KEY_2
	main._unhandled_input(ev_2)
	assert_test.call(gm.player_strategic_choice == C.STRATEGIC_CHOICE_PEACE, "Pressing [2] sets strategic choice to Peace")

	# Test input: Key 1 back to Confrontation, then Key N confirms
	main._unhandled_input(ev_1)
	var ev_n := InputEventKey.new()
	ev_n.pressed = true
	ev_n.keycode = KEY_N
	main._unhandled_input(ev_n)

	assert_test.call(gm.strategic_decision_active == false, "Strategic decision resolved after [N]")
	assert_test.call(gm.current_phase == gm.Phase.FINALE, "Game transitioned to Phase.FINALE")
	assert_test.call(gm.finale_route == C.FINALE_ROUTE_CONFRONTATION, "Finale route set to Confrontation")
	assert_test.call(main.strategic_overlay.visible == false, "Strategic overlay hidden")
	assert_test.call(main.finale_overlay.visible == true, "Finale HUD overlay visible")

	# ------------------------------------------------------------------
	# TEST GROUP 6: 3D Confrontation Finale (Generator Overdrive Tug-of-War)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] 3D Confrontation Finale (Generator Tug-of-War)")
	# Generator Overdrive pad is at Vector3(6.0, 0.05, 24.0)
	var gen_pad: Dictionary = map.get_pad_by_id("generator")
	assert_test.call(not gen_pad.is_empty(), "TownMap3D contains generator pad")
	assert_test.call(gen_pad.get("position").distance_to(Vector3(6.0, 0.05, 24.0)) < 0.1, "Generator pad position matches Sector 4 coordinates")

	# Unlock generator for testing
	map.update_escalation_unlocks()

	# Give player Ecology Operative role for testing tug
	player.secret_role = "ecology"
	gm.generator_tug_meter = 50.0

	# Channel generator pad
	player.position = Vector3(6.0, 0.05, 24.0)
	var started_gen: bool = player.try_start_channel()
	assert_test.call(started_gen == true, "Player starts channeling Overdrive Generator during Finale")
	assert_test.call(player.active_pad.get("id") == "generator", "Player active_pad is 'generator'")

	# Finish channeling generator pad as Ecology
	var meter_before: float = gm.generator_tug_meter
	map.finish_using_pad(player.active_pad, player, true)
	gm._process(0.016)
	assert_test.call(gm.generator_tug_meter < meter_before, "Ecology channeling generator pulled meter towards 0%% (before: %.1f, after: %.1f)" % [meter_before, gm.generator_tug_meter])

	# Test Technology operative pull
	player.secret_role = "technology"
	var meter_mid: float = gm.generator_tug_meter
	map.finish_using_pad(player.active_pad, player, true)
	gm._process(0.016)
	assert_test.call(gm.generator_tug_meter > meter_mid, "Technology channeling generator pulled meter towards 100%% (before: %.1f, after: %.1f)" % [meter_mid, gm.generator_tug_meter])

	# Pull to 0% triggers Overdrive Ecology victory
	player.secret_role = "ecology"
	gm.generator_tug_meter = 2.0
	map.finish_using_pad(player.active_pad, player, true)
	gm._process(0.016)
	assert_test.call(gm.generator_tug_meter <= 0.0, "Meter reached 0%%")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "Reaching 0%% immediately ends match")
	assert_test.call(gm.match_ending_title.find("ECOLOGY VICTORY") != -1, "Match ending title announces Ecology Overdrive Victory")

	# ------------------------------------------------------------------
	# TEST GROUP 7: 3D Peace Finale (Common Works Crisis Holdout)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] 3D Peace Finale (Common Works Crisis Holdout)")
	gm.current_phase = gm.Phase.FINALE
	gm.finale_route = C.FINALE_ROUTE_PEACE
	gm.charter_ratified = true
	gm.holdout_active = false
	gm.holdout_completed = true
	gm.holdout_failed = false
	gm.common_works = 100.0
	gm.water = 50.0
	gm.stability = 50.0
	gm.time_remaining = 0.5
	main._on_phase_changed(gm.Phase.FINALE)

	# Tick past time remaining
	gm._process(1.0)
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "Peace finale expires to MATCH_OVER")
	assert_test.call(gm.match_ending_title.find("CHARTER RATIFIED") != -1, "Peace finale with Common Works >= 99.9%% ratifies Charter")
	assert_test.call(main.camera_mode == "podium_celebration", "Camera director switches to podium_celebration on Peace victory")

	# ------------------------------------------------------------------
	# TEST GROUP 8: Match Over Restart Loop (Key R)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 8] Match Over Restart Loop (Key R)")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "Currently in MATCH_OVER phase")

	# Send Key R event
	var ev_r := InputEventKey.new()
	ev_r.pressed = true
	ev_r.keycode = KEY_R
	main._unhandled_input(ev_r)

	assert_test.call(gm.current_phase == gm.Phase.BRIEFING, "Pressing [R] restarts match in BRIEFING phase")
	assert_test.call(gm.time_remaining > 0.0, "Time remaining reset to match duration")
	assert_test.call(player.position.distance_to(main.spawn_positions[0]) < 0.01, "Player reset to spawn position")
	assert_test.call(main.game_over_overlay.visible == false, "Game Over overlay dismissed")
	assert_test.call(main.camera_mode == "wide_council", "Camera director reset to wide_council for Briefing")

	# ------------------------------------------------------------------
	# TEST GROUP 9: Camera Director Interpolation Modes
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 9] Camera Director Interpolation Modes")
	var get_cam_pos = func() -> Vector3:
		return main.camera.global_position if main.camera.is_inside_tree() else main.camera.position

	# 9.1: wide_council mode
	main.camera_mode = "wide_council"
	main._update_camera_director(1.0)
	assert_test.call(get_cam_pos.call().distance_to(Vector3(0.0, 16.0, 10.0)) < 1.0, "wide_council camera approaches (0, 16.0, 10.0)")

	# 9.2: court_podium mode
	main.camera_mode = "court_podium"
	main._update_camera_director(1.0)
	assert_test.call(get_cam_pos.call().distance_to(Vector3(0.0, 3.2, 5.6)) < 1.0, "court_podium camera approaches (0, 3.2, 5.6)")

	# 9.3: podium_celebration mode
	main.camera_mode = "podium_celebration"
	main._update_camera_director(1.0)
	assert_test.call(get_cam_pos.call().distance_to(Vector3(0.0, 7.5, 12.0)) < 1.0, "podium_celebration camera approaches (0, 7.5, 12.0)")

	# 9.4: follow_player mode
	main.camera_mode = "follow_player"
	player.position = Vector3(10.0, 0.0, -10.0)
	main._update_camera_director(1.0)
	var expected_follow: Vector3 = player.position + Vector3(0.0, 17.5, 9.5)
	assert_test.call(get_cam_pos.call().distance_to(expected_follow) < 2.0, "follow_player camera tracks player position with isometric offset")

	# ------------------------------------------------------------------
	# SUMMARY
	# ------------------------------------------------------------------
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL FULL 3D PHASE 3 CHECKS PASSED SUCCESSFULLY! <<<")
	else:
		print(">>> SOME PHASE 3 CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)
