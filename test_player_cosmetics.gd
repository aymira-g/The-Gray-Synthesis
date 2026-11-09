extends SceneTree

const Main3DScene = preload("res://scenes/Main3D.tscn")
const SettingsMenuClass = preload("res://scripts/SettingsMenu3D.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING PLAYER COSMETICS VERIFICATION ---")
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

	var player = main.player_node
	var npc = main.residents[1]
	var settings = main.settings_menu
	var test_config_path := "user://test_player_cosmetics.cfg"
	settings.cosmetic_config_path = test_config_path
	settings._load_player_palette()

	var palette_options: Array = player.get_player_palette_options()
	assert_test.call(palette_options.size() == 4, "Four player-only outfit palettes are available")
	assert_test.call(settings.palette_selector.item_count == 4, "Settings menu lists all player palettes")
	assert_test.call(player.player_palette_id == "standard", "Missing preference selects the default Civic Teal palette")

	var initial_speed: float = player.walk_speed
	var initial_ability: String = player.hero_active_id
	var npc_torso_color: Color = npc.torso_node.material_override.albedo_color
	settings.palette_selector.item_selected.emit(1)
	assert_test.call(player.player_palette_id == "verdant", "Settings palette selection applies the chosen palette")
	assert_test.call(player.torso_node.material_override.albedo_color == Color(0.18, 0.42, 0.29), "Selected palette recolors only the player's torso")
	assert_test.call(player.hero_trim_node.material_override.albedo_color == Color(0.53, 0.90, 0.45), "Selected palette recolors the player's collar accent")
	assert_test.call(npc.torso_node.material_override.albedo_color == npc_torso_color, "Player palette does not change NPC appearance")
	assert_test.call(player.walk_speed == initial_speed and player.hero_active_id == initial_ability, "Cosmetics do not change movement or hero abilities")

	var selected_torso_color: Color = player.torso_node.material_override.albedo_color
	assert_test.call(not player.apply_player_palette("unknown"), "Unknown palette IDs are rejected")
	assert_test.call(player.torso_node.material_override.albedo_color == selected_torso_color, "Rejected palette leaves the current appearance unchanged")

	assert_test.call(settings.set_player_palette("archive"), "Archive palette can be selected and saved")
	var reloaded_settings = SettingsMenuClass.new()
	reloaded_settings.cosmetic_config_path = test_config_path
	main.ui_layer.add_child(reloaded_settings)
	reloaded_settings.setup(main.game_manager, main.audio_manager, main, player)
	assert_test.call(player.player_palette_id == "archive", "Saved palette preference is restored from settings")
	assert_test.call(String(reloaded_settings.palette_selector.get_item_metadata(reloaded_settings.palette_selector.selected)) == "archive", "Palette selector reflects the restored preference")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_config_path))
	main.free()
	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	quit(0 if stats["failed"] == 0 else 1)
