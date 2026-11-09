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
	settings._load_player_cosmetics()

	var palette_options: Array = player.get_player_palette_options()
	assert_test.call(palette_options.size() == 4, "Four player-only outfit palettes are available")
	assert_test.call(player.get_player_accessory_options().size() == 3, "Three player-only accessories are available")
	assert_test.call(settings.palette_selector.item_count == 4, "Settings menu lists all player palettes")
	assert_test.call(settings.accessory_selector.item_count == 3, "Settings menu lists all player accessories")
	assert_test.call(settings.preview_model != null, "Settings menu renders a live 3D character preview")
	assert_test.call(player.player_palette_id == "standard", "Missing preference selects the default Civic Teal palette")

	var initial_speed: float = player.walk_speed
	var initial_ability: String = player.hero_active_id
	var npc_torso_color: Color = npc.torso_node.material_override.albedo_color
	settings.palette_selector.select(1)
	settings._on_cosmetic_selection_changed(1)
	settings.accessory_selector.select(1)
	settings._on_cosmetic_selection_changed(1)
	assert_test.call(player.player_palette_id == "standard", "Changing selectors previews without immediately changing the player")
	assert_test.call(settings.preview_model.get_node("Torso").material_override.albedo_color == Color(0.18, 0.42, 0.29), "Live preview shows the selected palette")
	assert_test.call(settings.preview_model.get_node("PlayerCosmeticAccessories/FieldScarf") != null, "Live preview shows the selected accessory")
	settings.apply_cosmetics_btn.pressed.emit()
	assert_test.call(player.player_palette_id == "verdant", "Apply Outfit commits the selected palette")
	assert_test.call(player.player_accessory_id == "field_scarf", "Apply Outfit commits the selected accessory")
	assert_test.call(player.torso_node.material_override.albedo_color == Color(0.18, 0.42, 0.29), "Selected palette recolors only the player's torso")
	assert_test.call(player.hero_trim_node.material_override.albedo_color == Color(0.53, 0.90, 0.45), "Selected palette recolors the player's collar accent")
	assert_test.call(player.mesh_root.get_node("PlayerCosmeticAccessories/FieldScarf") != null, "Field Scarf is attached to the player character")
	assert_test.call(npc.torso_node.material_override.albedo_color == npc_torso_color, "Player palette does not change NPC appearance")
	assert_test.call(player.walk_speed == initial_speed and player.hero_active_id == initial_ability, "Cosmetics do not change movement or hero abilities")

	settings.palette_selector.select(2)
	settings._on_cosmetic_selection_changed(2)
	settings.accessory_selector.select(2)
	settings._on_cosmetic_selection_changed(2)
	settings.cancel_cosmetics_btn.pressed.emit()
	assert_test.call(settings._pending_palette_id == "verdant" and settings._pending_accessory_id == "field_scarf", "Cancel restores the committed outfit selection")
	assert_test.call(settings.preview_model.get_node("PlayerCosmeticAccessories/FieldScarf") != null, "Cancel restores the previous preview")

	settings.accessory_selector.select(2)
	settings._on_cosmetic_selection_changed(2)
	assert_test.call(settings.preview_model.get_node("PlayerCosmeticAccessories/SignalBadge") != null, "Live preview supports the Signal Badge accessory")
	settings.apply_cosmetics_btn.pressed.emit()
	assert_test.call(player.mesh_root.get_node("PlayerCosmeticAccessories/SignalBadge") != null, "Signal Badge is attached when applied")

	var selected_torso_color: Color = player.torso_node.material_override.albedo_color
	assert_test.call(not player.apply_player_palette("unknown"), "Unknown palette IDs are rejected")
	assert_test.call(player.torso_node.material_override.albedo_color == selected_torso_color, "Rejected palette leaves the current appearance unchanged")

	assert_test.call(settings.set_player_palette("archive"), "Archive palette can be selected and saved")
	var reloaded_settings = SettingsMenuClass.new()
	reloaded_settings.cosmetic_config_path = test_config_path
	main.ui_layer.add_child(reloaded_settings)
	reloaded_settings.setup(main.game_manager, main.audio_manager, main, player)
	assert_test.call(player.player_palette_id == "archive", "Saved palette preference is restored from settings")
	assert_test.call(player.player_accessory_id == "signal_badge", "Saved accessory preference is restored from settings")
	assert_test.call(String(reloaded_settings.palette_selector.get_item_metadata(reloaded_settings.palette_selector.selected)) == "archive", "Palette selector reflects the restored preference")
	assert_test.call(String(reloaded_settings.accessory_selector.get_item_metadata(reloaded_settings.accessory_selector.selected)) == "signal_badge", "Accessory selector reflects the restored preference")

	if FileAccess.file_exists(test_config_path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(test_config_path))
		assert_test.call(remove_error == OK, "Temporary cosmetic preferences are cleaned up")
	main.free()
	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	quit(0 if stats["failed"] == 0 else 1)
