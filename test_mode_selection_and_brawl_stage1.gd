extends SceneTree

const ModeSelectScene = preload("res://scenes/ModeSelect.tscn")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("==================================================================")
	print("--- STARTING MODE SELECTION & BRAWL STAGE 1 VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}
	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	assert_test.call(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Main3D.tscn", "Project launches directly into Town Match")
	assert_test.call(ResourceLoader.exists("res://scenes/ModeSelect.tscn"), "Developer preview selector remains available as a standalone scene")

	var mode_select := ModeSelectScene.instantiate()
	root.add_child(mode_select)
	current_scene = mode_select
	await process_frame
	assert_test.call(mode_select.town_match_button != null and mode_select.brawl_button != null, "Mode selection offers Town Match and One-Lane Brawl")

	mode_select.brawl_button.pressed.emit()
	await process_frame
	await process_frame
	var arena = current_scene
	assert_test.call(arena != null and arena.scene_file_path == "res://scenes/BrawlArena3D.tscn", "Brawl selection launches the standalone arena scene")
	if arena != null and arena.has_method("_toggle_pause"):
		assert_test.call(arena.get_node_or_null("Arena/CenterLane") != null, "Brawl graybox has a marked single lane")
		assert_test.call(arena.get_node_or_null("Arena/BlueTurret") != null and arena.get_node_or_null("Arena/RedTurret") != null, "Brawl graybox has one turret per team")
		assert_test.call(arena.get_node_or_null("Arena/BlueCore") != null and arena.get_node_or_null("Arena/RedCore") != null, "Brawl graybox has one core per team")
		assert_test.call(arena.player != null and arena.camera != null, "Brawl stage has a controllable player and follow camera")

		arena.player.move_from_input(Vector2.RIGHT)
		assert_test.call(arena.player.velocity.x > 0.0, "Brawl player movement responds to directional input")
		var escape_event := InputEventKey.new()
		escape_event.pressed = true
		escape_event.keycode = KEY_ESCAPE
		arena._unhandled_input(escape_event)
		assert_test.call(arena.pause_overlay.visible and paused, "Escape pause overlay freezes the arena")
		arena._unhandled_input(escape_event)
		assert_test.call(not arena.pause_overlay.visible and not paused, "Resume restores arena play")
		arena.return_to_modes_button.pressed.emit()
		await process_frame
		await process_frame
		mode_select = current_scene
		assert_test.call(mode_select != null and mode_select.scene_file_path == "res://scenes/ModeSelect.tscn", "Brawl can return to mode selection")
	else:
		assert_test.call(false, "Brawl scene initialized correctly")

	if mode_select != null and mode_select.town_match_button != null:
		mode_select.town_match_button.pressed.emit()
		await process_frame
		await process_frame
		var town_scene = current_scene
		assert_test.call(town_scene != null and town_scene.scene_file_path == "res://scenes/Main3D.tscn", "Town Match selection launches the existing main scene")
		if town_scene != null and town_scene.settings_menu != null:
			assert_test.call(town_scene.settings_menu.get("return_to_modes_btn") == null, "Town Match settings have no route to the developer selector")
		else:
			assert_test.call(false, "Town Match settings initialized correctly")

	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if current_scene != null:
		current_scene.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
