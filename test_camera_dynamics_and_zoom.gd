extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 3: Camera Dynamics & Zoom Polish Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING OPTION 3: CAMERA DYNAMICS & ZOOM VERIFICATION ---")
	print("==================================================================\n")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, description: String):
		if condition:
			print("  [PASS] %s" % description)
			stats["passed"] += 1
		else:
			print("  [FAIL] *** %s ***" % description)
			stats["failed"] += 1

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var camera: Camera3D = main.camera
	var player: CharacterBody3D = main.player_node
	var gm: Node = main.game_manager

	# ------------------------------------------------------------------
	# TEST GROUP 1: Velocity Look-Ahead Lead in Movement Direction
	# ------------------------------------------------------------------
	print("[TEST GROUP 1] Velocity Look-Ahead Lead in Isometric Movement")
	main.camera_mode = "follow_player"
	player.velocity = Vector3.ZERO
	main._update_camera_director(1.0)
	assert_test.call(main.look_ahead_lead.length() < 0.05, "Stationary player has zero look-ahead lead")

	# Move North (-Z)
	player.velocity = Vector3(0.0, 0.0, -6.0)
	for i in range(15):
		main._update_camera_director(0.05)
	assert_test.call(main.look_ahead_lead.z < -1.0, "Moving North leads camera forward in -Z (lead: %.2f)" % main.look_ahead_lead.z)
	assert_test.call(absf(main.look_ahead_lead.x) < 0.05, "North movement has minimal X lateral drift")

	# Move South (+Z)
	player.velocity = Vector3(0.0, 0.0, 6.0)
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(main.look_ahead_lead.z > 1.0, "Moving South leads camera forward in +Z (lead: %.2f)" % main.look_ahead_lead.z)

	# Move East (+X)
	player.velocity = Vector3(6.0, 0.0, 0.0)
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(main.look_ahead_lead.x > 1.0, "Moving East leads camera forward in +X (lead: %.2f)" % main.look_ahead_lead.x)

	# Move West (-X)
	player.velocity = Vector3(-6.0, 0.0, 0.0)
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(main.look_ahead_lead.x < -1.0, "Moving West leads camera forward in -X (lead: %.2f)" % main.look_ahead_lead.x)

	# Stop moving -> returns smoothly to center
	player.velocity = Vector3.ZERO
	for i in range(30):
		main._update_camera_director(0.05)
	assert_test.call(main.look_ahead_lead.length() < 0.25, "Stopping smoothly recenters look-ahead lead (length: %.2f)" % main.look_ahead_lead.length())

	# ------------------------------------------------------------------
	# TEST GROUP 2: Sprint Pull-Back Framing
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Sprint Pull-Back Dynamic Zoom")
	player.velocity = Vector3(0.0, 0.0, 6.0)
	player.is_sprinting = false
	for i in range(20):
		main._update_camera_director(0.05)
	assert_test.call(absf(main.sprint_zoom_mult - 1.0) < 0.05, "Standard walk speed maintains 1.0x sprint zoom mult (val: %.2f)" % main.sprint_zoom_mult)

	player.velocity = Vector3(0.0, 0.0, 9.2)
	player.is_sprinting = true
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(main.sprint_zoom_mult > 1.05, "Sprinting smoothly pulls back camera distance (sprint zoom mult: %.2f)" % main.sprint_zoom_mult)

	player.is_sprinting = false
	player.velocity = Vector3.ZERO
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(main.sprint_zoom_mult < 1.03, "Stopping sprint smoothly recovers standard camera distance (val: %.2f)" % main.sprint_zoom_mult)

	# ------------------------------------------------------------------
	# TEST GROUP 3: Trauma-Based Camera Shake with Quadratic Decay
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Trauma-Based Camera Shake Decay System")
	main.camera_trauma = 0.0
	main.add_camera_trauma(0.6)
	assert_test.call(absf(main.camera_trauma - 0.6) < 0.01, "add_camera_trauma(0.6) accurately accumulates trauma: %.2f" % main.camera_trauma)

	# Trauma clamping
	main.add_camera_trauma(0.8)
	assert_test.call(main.camera_trauma <= 1.0, "Trauma is clamped at maximum 1.0 (current: %.2f)" % main.camera_trauma)

	# Shake offset generated during process
	main._update_camera_director(0.02)
	assert_test.call(main.current_shake_offset.length() > 0.0, "Non-zero trauma generates 3D shake translation offset")
	assert_test.call(main.current_shake_rotation.length() > 0.0, "Non-zero trauma generates 3D shake rotational tilt")

	# Decay over time
	var initial_trauma: float = float(main.camera_trauma)
	main._update_camera_director(0.25)
	assert_test.call(main.camera_trauma < initial_trauma, "Trauma decays over time (from %.2f to %.2f)" % [initial_trauma, main.camera_trauma])

	# Decays to zero
	for i in range(20):
		main._update_camera_director(0.1)
	assert_test.call(main.camera_trauma == 0.0, "Trauma decays completely to 0.0")
	assert_test.call(main.current_shake_offset == Vector3.ZERO, "Zero trauma resets translational shake offset to Vector3.ZERO")
	assert_test.call(main.current_shake_rotation == Vector3.ZERO, "Zero trauma resets rotational shake to Vector3.ZERO")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Gameplay Impact Trauma Triggers
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] High-Impact Gameplay Trauma Triggers")
	main.camera_trauma = 0.0
	player.receive_shove(Vector3(0, 0, 5), 35.0, null, false)
	assert_test.call(main.camera_trauma > 0.3, "Civic shove on player directly triggers camera trauma (trauma: %.2f)" % main.camera_trauma)

	main.camera_trauma = 0.0
	player.trigger_knockdown()
	assert_test.call(main.camera_trauma >= 0.5, "Player knockdown triggers heavy camera shake (trauma: %.2f)" % main.camera_trauma)

	# Escalation phase siren trauma
	main.camera_trauma = 0.0
	main._on_phase_changed(gm.Phase.ESCALATION)
	assert_test.call(main.camera_trauma >= 0.35, "Escalation klaxon triggers camera trauma (trauma: %.2f)" % main.camera_trauma)

	# Finale phase alarm trauma
	main.camera_trauma = 0.0
	main._on_phase_changed(gm.Phase.FINALE)
	assert_test.call(main.camera_trauma >= 0.45, "Finale alarm triggers substantial camera trauma (trauma: %.2f)" % main.camera_trauma)

	# Archive unseal trauma
	main.camera_trauma = 0.0
	main._prev_archive_opened = false
	gm.archive_opened = true
	main._on_state_updated()
	assert_test.call(main.camera_trauma >= 0.35, "Archive unseal event triggers camera trauma (trauma: %.2f)" % main.camera_trauma)

	# ------------------------------------------------------------------
	# TEST GROUP 5: Dynamic FOV Transitions across Modes
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Smooth Dynamic FOV Transitions")
	# Wide Council mode
	main.camera_mode = "wide_council"
	for i in range(25):
		main._update_camera_director(0.05)
	assert_test.call(absf(camera.fov - 76.0) < 1.0, "Wide Council mode targets panoramic 76° FOV (actual: %.1f°)" % camera.fov)

	# Court Podium testimony mode
	main.camera_mode = "court_podium"
	for i in range(30):
		main._update_camera_director(0.05)
	assert_test.call(absf(camera.fov - 56.0) < 1.0, "Court Podium mode contracts to cinematic 56° FOV (actual: %.1f°)" % camera.fov)

	# Follow Player mode
	main.camera_mode = "follow_player"
	player.is_sprinting = false
	player.velocity = Vector3.ZERO
	for i in range(30):
		main._update_camera_director(0.05)
	assert_test.call(absf(camera.fov - 70.0) < 1.0, "Follow Player mode standardizes to 70° FOV (actual: %.1f°)" % camera.fov)

	# Follow Player sprint FOV boost
	player.is_sprinting = true
	player.velocity = Vector3(0, 0, 9.2)
	for i in range(30):
		main._update_camera_director(0.05)
	assert_test.call(camera.fov > 71.5, "Sprint velocity dynamically expands FOV to ~72.5° (actual: %.1f°)" % camera.fov)

	# ------------------------------------------------------------------
	# TEST GROUP 6: Smooth Interactive Zoom Interpolation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Smooth Interactive Zoom Interpolation")
	main.camera_zoom = 1.0
	main.smooth_camera_zoom = 1.0

	var ev_zoom_in := InputEventMouseButton.new()
	ev_zoom_in.pressed = true
	ev_zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	main._unhandled_input(ev_zoom_in)

	assert_test.call(main.camera_zoom < 1.0, "Mouse wheel up updates camera_zoom target immediately (val: %.2f)" % main.camera_zoom)
	assert_test.call(main.smooth_camera_zoom > main.camera_zoom, "Smooth camera zoom trails target smoothly before lerp completes")

	for i in range(20):
		main._update_camera_director(0.05)
	assert_test.call(absf(main.smooth_camera_zoom - main.camera_zoom) < 0.01, "Smooth camera zoom converges to target (val: %.2f)" % main.smooth_camera_zoom)

	# Key [Z] close-up toggle
	var ev_z := InputEventKey.new()
	ev_z.pressed = true
	ev_z.keycode = KEY_Z
	main._unhandled_input(ev_z)
	assert_test.call(main.camera_zoom == 0.65, "Pressing [Z] sets camera zoom target to 0.65")
	for i in range(20):
		main._update_camera_director(0.05)
	assert_test.call(absf(main.smooth_camera_zoom - 0.65) < 0.01, "Smooth camera zoom glides to close-up 0.65 (val: %.2f)" % main.smooth_camera_zoom)

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 3 CAMERA DYNAMICS & ZOOM CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
