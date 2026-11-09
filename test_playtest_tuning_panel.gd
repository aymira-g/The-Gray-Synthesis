extends SceneTree

# ==============================================================================
# Automated Test Suite: Milestone 8 Playtest & Developer Tuning Console
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const PlaytestTuningPanelClass = preload("res://scripts/PlaytestTuningPanel3D.gd")
const Resident3DClass = preload("res://scripts/Resident3D.gd")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING MILESTONE 8 PLAYTEST & TUNING CONSOLE VERIFICATION ---")
	print("==================================================================")

	var stats := { "passed": 0, "failed": 0 }
	var assert_test = func(condition: bool, message: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] %s" % message)
		else:
			stats["failed"] += 1
			printerr("  [FAIL] *** %s ***" % message)

	var main = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var gm = main.game_manager
	var map = main.town_map
	var player = main.player_node
	var panel = main.playtest_tuning_panel

	# ------------------------------------------------------------------
	# TEST GROUP 1: Panel Architecture & Input Toggles
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Panel Architecture & Input Toggles")
	assert_test.call(panel != null, "PlaytestTuningPanel3D instance registered on Main3D")
	assert_test.call(panel is PlaytestTuningPanelClass, "Panel is instance of PlaytestTuningPanelClass")
	assert_test.call(panel.visible == false, "Tuning panel initially closed")

	# Toggle with [F1]
	var key_f1 := InputEventKey.new()
	key_f1.pressed = true
	key_f1.keycode = KEY_F1
	main._unhandled_input(key_f1)
	assert_test.call(panel.visible == true, "Pressing [F1] opens tuning panel")
	assert_test.call(gm.dev_panel_open == true, "GameManager.dev_panel_open set to true")

	# Movement suppression test
	player.velocity = Vector3(5.0, 0.0, 5.0)
	player._process_player_movement(0.016)
	assert_test.call(player.velocity == Vector3.ZERO, "Player movement velocity suppressed to ZERO while dev panel is open")

	# Toggle with backtick [~]
	var key_tick := InputEventKey.new()
	key_tick.pressed = true
	key_tick.keycode = KEY_QUOTELEFT
	main._unhandled_input(key_tick)
	assert_test.call(panel.visible == false, "Pressing [`] closes tuning panel")
	assert_test.call(gm.dev_panel_open == false, "GameManager.dev_panel_open resets to false on close")

	# Open with [F1] and close with [ESC]
	main._unhandled_input(key_f1)
	assert_test.call(panel.visible == true, "Panel reopened with [F1]")
	var key_esc := InputEventKey.new()
	key_esc.pressed = true
	key_esc.keycode = KEY_ESCAPE
	main._unhandled_input(key_esc)
	assert_test.call(panel.visible == false, "Pressing [ESC] dismisses tuning panel")
	assert_test.call(gm.dev_panel_open == false, "GameManager.dev_panel_open resets on ESC dismiss")

	panel.open_panel()

	# ------------------------------------------------------------------
	# TEST GROUP 2: Engine Time Scale & Match Clock Warps
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Engine Time Scale & Match Clock Warps")
	panel._set_engine_speed(2.0)
	assert_test.call(is_equal_approx(Engine.time_scale, 2.0), "Engine time scale accelerated to 2.0x")

	panel._set_engine_speed(5.0)
	assert_test.call(is_equal_approx(Engine.time_scale, 5.0), "Engine time scale accelerated to 5.0x")

	panel._set_engine_speed(1.0)
	assert_test.call(is_equal_approx(Engine.time_scale, 1.0), "Engine time scale restored to 1.0x normal")

	# Clock adjustment tests
	gm.time_remaining = 120.0
	panel._adjust_clock(-30.0)
	assert_test.call(is_equal_approx(gm.time_remaining, 90.0), "Adjust clock -30s updated time_remaining to 90.0s")

	panel._adjust_clock(30.0)
	assert_test.call(is_equal_approx(gm.time_remaining, 120.0), "Adjust clock +30s updated time_remaining back to 120.0s")

	panel._set_clock(10.0)
	assert_test.call(is_equal_approx(gm.time_remaining, 10.0), "Set clock to 10s updated time_remaining directly to 10.0s")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Direct Phase Navigation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Direct Phase Navigation")
	panel._warp_to_phase(gm.Phase.OPEN_TOWN)
	assert_test.call(gm.current_phase == gm.Phase.OPEN_TOWN, "Warp to Open Town transitioned phase to OPEN_TOWN")

	panel._warp_to_phase(gm.Phase.FIRST_COUNCIL)
	assert_test.call(gm.current_phase == gm.Phase.FIRST_COUNCIL, "Warp to First Council transitioned phase to FIRST_COUNCIL")

	panel._warp_to_phase(gm.Phase.ESCALATION)
	assert_test.call(gm.current_phase == gm.Phase.ESCALATION, "Warp to Escalation transitioned phase to ESCALATION")

	panel._warp_to_phase(gm.Phase.COURT)
	assert_test.call(gm.current_phase == gm.Phase.COURT, "Warp to Civilian Court transitioned phase to COURT")
	assert_test.call(gm.court_ceremony_active == true, "Civilian court ceremony active after court warp")

	panel._warp_to_finale(C.FINALE_ROUTE_CONFRONTATION)
	assert_test.call(gm.current_phase == gm.Phase.FINALE, "Warp to Finale Confrontation transitioned phase to FINALE")
	assert_test.call(gm.finale_route == C.FINALE_ROUTE_CONFRONTATION, "Finale route set to CONFRONTATION")

	panel._warp_to_finale(C.FINALE_ROUTE_PEACE)
	assert_test.call(gm.current_phase == gm.Phase.FINALE, "Warp to Finale Peace transitioned phase to FINALE")
	assert_test.call(gm.finale_route == C.FINALE_ROUTE_PEACE, "Finale route set to PEACE")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Live Crisis & Resource Mutations
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Live Crisis & Resource Mutations")
	panel._set_water(20.0)
	assert_test.call(is_equal_approx(gm.water, 20.0), "Water set directly to crisis level 20%")

	panel._adjust_water(15.0)
	assert_test.call(is_equal_approx(gm.water, 35.0), "Water adjusted +15% to 35%")

	panel._set_stability(20.0)
	assert_test.call(is_equal_approx(gm.stability, 20.0), "Stability set directly to crisis level 20%")

	panel._adjust_stability(15.0)
	assert_test.call(is_equal_approx(gm.stability, 35.0), "Stability adjusted +15% to 35%")

	var initial_scrap: int = gm.scrap
	panel._adjust_scrap(5)
	assert_test.call(gm.scrap == initial_scrap + 5, "Scrap increased by 5 units")

	panel._set_works(99.9)
	assert_test.call(is_equal_approx(gm.common_works, 99.9), "Common Works set to 99.9% for peace finale testing")

	panel._set_drain_scale(0.0)
	assert_test.call(is_equal_approx(gm.crisis_drain_scale, 0.0), "Crisis drain scale set to 0.0x (frozen decay)")

	panel._set_drain_scale(1.5)
	assert_test.call(is_equal_approx(gm.crisis_drain_scale, 1.5), "Crisis drain scale set to 1.5x (intense decay)")

	panel._set_tug_meter(85.0)
	assert_test.call(is_equal_approx(gm.generator_tug_meter, 85.0), "Generator tug meter set to 85.0% for Technology test")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Roster & Secret Roles God-View
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Roster & Secret Roles God-View")
	panel._switch_tab("ROSTER")
	assert_test.call(panel.alcove_info_label.text.find("Active Archive Alcove:") != -1, "Active bedrock alcove correctly identified")

	# Teleport to active alcove
	var act_id: String = gm.archive_active_spawn_id
	var expected_pos := Vector3.ZERO
	for alc in map.secret_alcoves:
		if alc.get("id") == act_id:
			expected_pos = alc.get("pos", Vector3.ZERO)
			break

	panel._teleport_to_active_alcove()
	var p_pos: Vector3 = player.global_position if player.is_inside_tree() else player.position
	var dist_to_alc: float = p_pos.distance_to(expected_pos)
	assert_test.call(dist_to_alc < 2.0, "Player successfully teleported to active bedrock alcove (dist: %.2f)" % dist_to_alc)

	# Force unseal as player
	panel._force_unseal_archive_player()
	assert_test.call(gm.archive_opened == true, "Archive opened successfully via dev console")
	assert_test.call(gm.archive_finder_id == player.resident_id, "Player recorded as archive finder")

	# Teleport to another resident
	var target_bot = main.residents[3]
	var t_pos: Vector3 = target_bot.global_position if target_bot.is_inside_tree() else target_bot.position
	panel._teleport_player_to(t_pos)
	p_pos = player.global_position if player.is_inside_tree() else player.position
	var dist_to_bot: float = p_pos.distance_to(t_pos)
	assert_test.call(dist_to_bot < 2.0, "Player teleported to target resident position")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Gameplay Pacing & Live Tuning Knobs
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Gameplay Pacing & Live Tuning Knobs")
	panel._switch_tab("TUNING")

	panel._set_channel_scale(0.5)
	assert_test.call(is_equal_approx(Resident3DClass.task_channel_scale, 0.5), "Task channel duration scaled to 0.5x (fast channel)")

	panel._set_court_bot_delay(1.5)
	assert_test.call(is_equal_approx(gm.court_bot_deliberation_delay, 1.5), "Court bot deliberation delay set to 1.5s (brisk testimony)")

	panel._set_shove_cooldown(2.0)
	assert_test.call(is_equal_approx(Resident3DClass.shove_cooldown_override, 2.0), "Civic shove cooldown set to 2.0s")

	panel._set_stamina_drain(0.0)
	assert_test.call(is_equal_approx(player.stamina_drain, 0.0), "Player stamina drain set to 0.0 (infinite sprint)")

	# Reset tuning to defaults
	panel._set_channel_scale(1.0)
	panel._set_court_bot_delay(2.5)
	panel._set_shove_cooldown(4.0)
	panel._set_stamina_drain(28.0)
	panel._set_drain_scale(1.0)
	assert_test.call(is_equal_approx(Resident3DClass.task_channel_scale, 1.0), "Task channel scale restored to 1.0 default")
	assert_test.call(is_equal_approx(gm.court_bot_deliberation_delay, 2.5), "Court bot delay restored to 2.5s default")
	assert_test.call(is_equal_approx(Resident3DClass.shove_cooldown_override, 4.0), "Shove cooldown restored to 4.0s default")
	assert_test.call(is_equal_approx(gm.crisis_drain_scale, 1.0), "Crisis drain scale restored to 1.0 default")

	panel.close_panel()

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL MILESTONE 8 PLAYTEST & TUNING CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
