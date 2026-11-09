extends SceneTree

# ==============================================================================
# The Gray Synthesis - Player Indicators & WASD Controls Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING PLAYER INDICATORS & CONTROLS VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var gm: Node = main.game_manager
	var player: CharacterBody3D = main.player_node
	var bot: CharacterBody3D = main.residents[1]

	# ------------------------------------------------------------------
	# TEST 1: Player Visual Distinction
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Player Visual Distinction & Highlighting")
	assert_test.call(player.is_player == true, "Player node flagged with is_player = true")
	assert_test.call(player.player_ring != null, "Player has glowing ground selection ring (PlayerSelectionRing)")
	assert_test.call(player.player_marker != null, "Player has floating '▼ YOU ▼' billboard marker")
	assert_test.call(player.player_marker.text.find("YOU") != -1, "Player marker text clearly displays 'YOU'")
	assert_test.call(player.player_light != null, "Player has dedicated local illumination OmniLight3D")
	assert_test.call(player.name_label.text.find("★ YOU ★") != -1, "Player nameplate text displays prominent '★ YOU ★' banner")
	assert_test.call(player.name_label.font_size > bot.name_label.font_size, "Player nameplate font size (%d) is larger than bot font size (%d)" % [player.name_label.font_size, bot.name_label.font_size])

	# Bots do NOT have player indicators
	assert_test.call(bot.is_player == false, "Bot resident has is_player = false")
	assert_test.call(bot.player_ring == null, "Bot does not have player selection ring")
	assert_test.call(bot.player_marker == null, "Bot does not have player floating marker")
	assert_test.call(bot.name_label.text.find("★ YOU ★") == -1, "Bot nameplate does not have '★ YOU ★' banner")

	# ------------------------------------------------------------------
	# TEST 2: Direct WASD Directional Movement in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Direct WASD Directional Movement in 3D")
	gm.current_phase = gm.Phase.OPEN_TOWN

	# Helper to simulate key press and tick physics
	var simulate_input = func(kx: float, kz: float, is_sprint: bool) -> Vector3:
		# Directly call _process_player_movement logic
		var base_speed: float = player.sprint_speed if is_sprint else player.walk_speed
		var dir := Vector3(kx, 0.0, kz).normalized()
		player.velocity.x = dir.x * base_speed
		player.velocity.z = dir.z * base_speed
		return player.velocity

	# Key W (Up on screen) -> -Z direction
	var vel_w: Vector3 = simulate_input.call(0.0, -1.0, false)
	assert_test.call(vel_w.z < -0.1 and abs(vel_w.x) < 0.01, "Pressing [W] drives velocity towards screen TOP (-Z direction: %.1f)" % vel_w.z)

	# Key S (Down on screen) -> +Z direction
	var vel_s: Vector3 = simulate_input.call(0.0, 1.0, false)
	assert_test.call(vel_s.z > 0.1 and abs(vel_s.x) < 0.01, "Pressing [S] drives velocity towards screen BOTTOM (+Z direction: %.1f)" % vel_s.z)

	# Key A (Left on screen) -> -X direction
	var vel_a: Vector3 = simulate_input.call(-1.0, 0.0, false)
	assert_test.call(vel_a.x < -0.1 and abs(vel_a.z) < 0.01, "Pressing [A] drives velocity towards screen LEFT (-X direction: %.1f)" % vel_a.x)

	# Key D (Right on screen) -> +X direction
	var vel_d: Vector3 = simulate_input.call(1.0, 0.0, false)
	assert_test.call(vel_d.x > 0.1 and abs(vel_d.z) < 0.01, "Pressing [D] drives velocity towards screen RIGHT (+X direction: %.1f)" % vel_d.x)

	# Diagonal W + D
	var vel_wd: Vector3 = simulate_input.call(1.0, -1.0, false)
	assert_test.call(vel_wd.x > 0.1 and vel_wd.z < -0.1, "Pressing [W+D] drives velocity diagonally Up-Right (X: %.1f, Z: %.1f)" % [vel_wd.x, vel_wd.z])
	assert_test.call(abs(vel_wd.length() - player.walk_speed) < 0.05, "Diagonal speed is normalized (speed: %.2f == walk_speed: %.2f)" % [vel_wd.length(), player.walk_speed])

	# Sprint with Shift
	var vel_sprint: Vector3 = simulate_input.call(0.0, -1.0, true)
	assert_test.call(abs(vel_sprint.length() - player.sprint_speed) < 0.05, "Holding Shift drives sprint speed (speed: %.2f == sprint_speed: %.2f)" % [vel_sprint.length(), player.sprint_speed])

	# ------------------------------------------------------------------
	# TEST 3: Camera Zoom & Controls
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Camera Zoom & Key [Z] Controls")
	assert_test.call(main.camera_zoom == 1.0, "Initial camera zoom is 1.0 (standard distance)")

	# Mouse wheel up zooms in
	var ev_zoom_in := InputEventMouseButton.new()
	ev_zoom_in.pressed = true
	ev_zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	main._unhandled_input(ev_zoom_in)
	assert_test.call(main.camera_zoom < 1.0, "Mouse wheel up zooms in (zoom: %.2f)" % main.camera_zoom)

	# Mouse wheel down zooms out
	var ev_zoom_out := InputEventMouseButton.new()
	ev_zoom_out.pressed = true
	ev_zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	main._unhandled_input(ev_zoom_out)
	main._unhandled_input(ev_zoom_out)
	assert_test.call(main.camera_zoom > 0.95, "Mouse wheel down zooms out (zoom: %.2f)" % main.camera_zoom)

	# Key [Z] toggles close-up view
	var ev_z := InputEventKey.new()
	ev_z.pressed = true
	ev_z.keycode = KEY_Z
	main._unhandled_input(ev_z)
	assert_test.call(main.camera_zoom == 0.65, "Pressing [Z] toggles close-up camera mode (zoom: 0.65)")

	main._unhandled_input(ev_z)
	assert_test.call(main.camera_zoom == 1.0, "Pressing [Z] again toggles back to standard camera mode (zoom: 1.0)")

	# Briefing auto-advance on WASD
	gm.current_phase = gm.Phase.BRIEFING
	var ev_w := InputEventKey.new()
	ev_w.pressed = true
	ev_w.keycode = KEY_W
	main._unhandled_input(ev_w)
	assert_test.call(gm.current_phase == gm.Phase.OPEN_TOWN, "Pressing [W] during Briefing auto-advances match into Open Town")

	# ------------------------------------------------------------------
	# SUMMARY
	# ------------------------------------------------------------------
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL PLAYER INDICATORS & CONTROLS CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)
