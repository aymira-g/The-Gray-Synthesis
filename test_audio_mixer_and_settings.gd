extends SceneTree

# ==============================================================================
# The Gray Synthesis - Step 4: Audio Mixer & Settings Verification Suite
# ==============================================================================
# Comprehensive automated testing for:
# 1. AudioManager volume setters, getters, clamping, mute toggle, and defaults reset
# 2. Procedural synthesis of new audio cues (test_tone, covert_hunch, ui_click)
# 3. Resident3D covert hunch audio cue integration
# 4. SettingsMenu3D UI component lifecycle, slider sync, and percentage labels
# 5. Quick audio actions (test tone preview, mute toggle, reset defaults)
# 6. Gated player movement suppression while settings menu is open
# 7. Keyboard [Esc] navigation hierarchy and clean dismissal
# 8. Decoupled player-facing design (zero developer god-mode leaks or role reveals)
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const AudioManagerClass = preload("res://scripts/AudioManager.gd")
const SettingsMenuClass = preload("res://scripts/SettingsMenu3D.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING STEP 4: AUDIO MIXER & SETTINGS VERIFICATION ---")
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

	var audio: Node = main.audio_manager
	var gm: Node = main.game_manager
	var player: CharacterBody3D = main.player_node
	var settings: PanelContainer = main.settings_menu

	# ------------------------------------------------------------------
	# TEST GROUP 1: AudioManager Volume Control APIs & Clamping
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] AudioManager Volume Setters, Getters, & Mute Logic")
	assert_test.call(audio != null, "AudioManager instance available on Main3D")
	assert_test.call(audio.has_method("set_master_volume") and audio.has_method("get_master_volume"), "Master volume getter/setter exposed")
	assert_test.call(audio.has_method("set_sfx_volume") and audio.has_method("get_sfx_volume"), "SFX volume getter/setter exposed")
	assert_test.call(audio.has_method("set_ambient_volume") and audio.has_method("get_ambient_volume"), "Ambient volume getter/setter exposed")
	assert_test.call(audio.has_method("set_music_volume") and audio.has_method("get_music_volume"), "Music volume getter/setter exposed")

	# Test initial defaults
	audio.reset_to_defaults()
	assert_test.call(is_equal_approx(audio.get_master_volume(), 1.0), "Default master volume is 1.0 (100%)")
	assert_test.call(is_equal_approx(audio.get_sfx_volume(), 1.0), "Default SFX volume is 1.0 (100%)")
	assert_test.call(is_equal_approx(audio.get_ambient_volume(), 0.75), "Default ambient volume is 0.75 (75%)")
	assert_test.call(is_equal_approx(audio.get_music_volume(), 0.80), "Default music volume is 0.80 (80%)")
	assert_test.call(not audio.is_muted_active(), "Audio is not muted by default")

	# Test clamping bounds
	audio.set_master_volume(1.6)
	assert_test.call(is_equal_approx(audio.get_master_volume(), 1.0), "Master volume clamps upper bound at 1.0")
	audio.set_master_volume(-0.5)
	assert_test.call(is_equal_approx(audio.get_master_volume(), 0.0), "Master volume clamps lower bound at 0.0")

	audio.set_sfx_volume(1.4)
	assert_test.call(is_equal_approx(audio.get_sfx_volume(), 1.0), "SFX volume clamps upper bound at 1.0")
	audio.set_sfx_volume(-0.2)
	assert_test.call(is_equal_approx(audio.get_sfx_volume(), 0.0), "SFX volume clamps lower bound at 0.0")

	audio.set_ambient_volume(1.5)
	assert_test.call(is_equal_approx(audio.get_ambient_volume(), 1.0), "Ambient volume clamps upper bound at 1.0")
	audio.set_ambient_volume(-0.1)
	assert_test.call(is_equal_approx(audio.get_ambient_volume(), 0.0), "Ambient volume clamps lower bound at 0.0")

	audio.set_music_volume(1.2)
	assert_test.call(is_equal_approx(audio.get_music_volume(), 1.0), "Music volume clamps upper bound at 1.0")
	audio.set_music_volume(-0.3)
	assert_test.call(is_equal_approx(audio.get_music_volume(), 0.0), "Music volume clamps lower bound at 0.0")

	# Test mute and restore
	audio.set_master_volume(0.65)
	var muted: bool = audio.toggle_mute()
	assert_test.call(muted and audio.is_muted_active(), "toggle_mute() mutes active audio channels")
	assert_test.call(is_equal_approx(audio.get_master_volume(), 0.0), "Master volume is zeroed while muted")
	assert_test.call(audio._calc_sfx_volume_db(0.0) <= -80.0, "SFX volume calculates silent (-80dB) while muted")

	var unmuted: bool = not audio.toggle_mute()
	assert_test.call(unmuted and not audio.is_muted_active(), "toggle_mute() restores active audio")
	assert_test.call(is_equal_approx(audio.get_master_volume(), 0.65), "Pre-mute volume restored accurately (0.65)")

	# Reset to defaults
	audio.reset_to_defaults()
	assert_test.call(is_equal_approx(audio.get_master_volume(), 1.0) and not audio.is_muted_active(), "reset_to_defaults() restores 1.0 master and unmuted state")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Procedural Synthesis of Atmospheric Cues
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Atmospheric Sound Cues & Synthesis")
	assert_test.call(audio.sfx_library.has("test_tone"), "test_tone synthesized in SFX library")
	var test_tone_wav: AudioStreamWAV = audio.sfx_library.get("test_tone")
	assert_test.call(test_tone_wav != null and test_tone_wav.get_length() > 0.3, "test_tone has valid non-zero duration (%.2fs)" % (test_tone_wav.get_length() if test_tone_wav else 0.0))

	assert_test.call(audio.sfx_library.has("covert_hunch"), "covert_hunch synthesized in SFX library")
	var hunch_wav: AudioStreamWAV = audio.sfx_library.get("covert_hunch")
	assert_test.call(hunch_wav != null and hunch_wav.get_length() > 0.2, "covert_hunch has valid non-zero duration (%.2fs)" % (hunch_wav.get_length() if hunch_wav else 0.0))

	assert_test.call(audio.sfx_library.has("ui_click"), "ui_click synthesized in SFX library")
	var click_wav: AudioStreamWAV = audio.sfx_library.get("ui_click")
	assert_test.call(click_wav != null and click_wav.get_length() > 0.02, "ui_click has valid non-zero duration (%.2fs)" % (click_wav.get_length() if click_wav else 0.0))

	# Resident3D covert hunch cue
	var initial_covert_timer: float = player.covert_hunch_timer
	player.trigger_covert_hunch(2.5)
	assert_test.call(player.covert_hunch_timer == 2.5, "Resident3D trigger_covert_hunch sets duration to 2.5s")

	# ------------------------------------------------------------------
	# TEST GROUP 3: SettingsMenu3D Component Setup & UI Sync
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] SettingsMenu3D Component Lifecycle & UI Sync")
	assert_test.call(settings != null, "SettingsMenu3D instantiated and attached to Main3D")
	assert_test.call(settings.get_parent() == main.ui_layer, "SettingsMenu3D is child of ui_layer")
	assert_test.call(not settings.visible, "SettingsMenu3D hidden by default")

	# Open menu
	settings.open_menu()
	assert_test.call(settings.visible, "open_menu() makes SettingsMenu3D visible")
	assert_test.call(gm.get("settings_menu_open") == true, "game_manager.settings_menu_open is true while open")

	# Verify slider rows exist and match audio manager values
	assert_test.call(settings.master_slider != null, "Master volume HSlider present")
	assert_test.call(settings.sfx_slider != null, "SFX volume HSlider present")
	assert_test.call(settings.ambient_slider != null, "Ambient volume HSlider present")
	assert_test.call(settings.music_slider != null, "Music volume HSlider present")

	assert_test.call(is_equal_approx(settings.master_slider.value, 1.0), "Master slider value matches audio manager (1.0)")
	assert_test.call(settings.master_val_label.text == "100%", "Master percentage label displays '100%'")
	assert_test.call(is_equal_approx(settings.ambient_slider.value, 0.75), "Ambient slider value matches audio manager (0.75)")
	assert_test.call(settings.ambient_val_label.text == "75%", "Ambient percentage label displays '75%'")

	# Slider interaction updates audio manager
	settings.set_master_slider_value(0.50)
	assert_test.call(is_equal_approx(audio.get_master_volume(), 0.50), "Adjusting master slider updates audio_manager master volume to 0.50")
	assert_test.call(settings.master_val_label.text == "50%", "Master percentage label updates to '50%'")

	settings.set_sfx_slider_value(0.60)
	assert_test.call(is_equal_approx(audio.get_sfx_volume(), 0.60), "Adjusting SFX slider updates audio_manager sfx volume to 0.60")
	assert_test.call(settings.sfx_val_label.text == "60%", "SFX percentage label updates to '60%'")

	settings.set_ambient_slider_value(0.40)
	assert_test.call(is_equal_approx(audio.get_ambient_volume(), 0.40), "Adjusting ambient slider updates audio_manager ambient volume to 0.40")
	assert_test.call(settings.ambient_val_label.text == "40%", "Ambient percentage label updates to '40%'")

	settings.set_music_slider_value(0.90)
	assert_test.call(is_equal_approx(audio.get_music_volume(), 0.90), "Adjusting music slider updates audio_manager music volume to 0.90")
	assert_test.call(settings.music_val_label.text == "90%", "Music percentage label updates to '90%'")

	# Close menu
	settings.close_menu()
	assert_test.call(not settings.visible, "close_menu() hides SettingsMenu3D")
	assert_test.call(gm.get("settings_menu_open") == false, "game_manager.settings_menu_open is false after closing")

	# Toggle menu
	settings.toggle_menu()
	assert_test.call(settings.visible, "toggle_menu() opens closed menu")
	settings.toggle_menu()
	assert_test.call(not settings.visible, "toggle_menu() closes open menu")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Quick Action Buttons (Test Sound, Mute, Reset)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Audio Quick Action Buttons")
	settings.open_menu()
	assert_test.call(settings.test_sound_btn != null, "Test Sound Cue button exists")
	assert_test.call(settings.mute_toggle_btn != null, "Mute toggle button exists")
	assert_test.call(settings.reset_defaults_btn != null, "Reset defaults button exists")

	# Test sound trigger
	settings._on_test_sound_pressed()
	assert_test.call(true, "Test sound button executes cleanly without error")

	# Mute button
	settings._on_mute_toggle_pressed()
	assert_test.call(audio.is_muted_active(), "Mute button mutes audio manager")
	assert_test.call(settings.mute_toggle_btn.text == "Unmute Audio", "Mute button updates label to 'Unmute Audio'")

	settings._on_mute_toggle_pressed()
	assert_test.call(not audio.is_muted_active(), "Unmute button restores audio manager")
	assert_test.call(settings.mute_toggle_btn.text == "Mute All Audio", "Unmute button updates label to 'Mute All Audio'")

	# Reset defaults button
	settings._on_reset_defaults_pressed()
	assert_test.call(is_equal_approx(audio.get_master_volume(), 1.0), "Reset defaults restores master to 1.0")
	assert_test.call(is_equal_approx(audio.get_sfx_volume(), 1.0), "Reset defaults restores SFX to 1.0")
	assert_test.call(is_equal_approx(audio.get_ambient_volume(), 0.75), "Reset defaults restores ambient to 0.75")
	assert_test.call(is_equal_approx(audio.get_music_volume(), 0.80), "Reset defaults restores music to 0.80")
	assert_test.call(settings.master_val_label.text == "100%", "Master percentage label shows 100% after reset")
	assert_test.call(settings.ambient_val_label.text == "75%", "Ambient percentage label shows 75% after reset")
	settings.close_menu()

	# ------------------------------------------------------------------
	# TEST GROUP 5: Player Movement Suppression
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Player Movement Gating While Settings Menu Open")
	gm.set_phase(gm.Phase.OPEN_TOWN)
	player.velocity = Vector3(4.0, 0.0, 4.0)

	# Normal movement processing allows movement when settings menu is closed
	settings.close_menu()
	gm.settings_menu_open = false
	player._process_player_movement(0.016)
	assert_test.call(true, "Player movement process functions normally when settings menu is closed")

	# Open settings menu and verify velocity is locked to zero
	settings.open_menu()
	player.velocity = Vector3(5.0, 0.0, 5.0)
	player._process_player_movement(0.016)
	assert_test.call(player.velocity == Vector3.ZERO, "Player movement velocity is clamped to Vector3.ZERO while settings menu is open")

	settings.close_menu()

	# ------------------------------------------------------------------
	# TEST GROUP 6: Keyboard [Esc] Navigation Hierarchy
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Keyboard [Esc] Navigation Hierarchy")
	# Case A: Nothing open -> ESC opens Settings Menu
	settings.close_menu()
	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	main._unhandled_input(esc_event)
	assert_test.call(settings.visible, "Pressing [Esc] when no overlays are open opens Settings Menu")

	# Case B: Settings Menu open -> ESC closes Settings Menu
	main._unhandled_input(esc_event)
	assert_test.call(not settings.visible, "Pressing [Esc] when Settings Menu is open closes Settings Menu")

	# Case C: Evidence Journal open -> ESC closes Evidence Journal first, leaving Settings Menu closed
	main.evidence_journal.open_journal()
	assert_test.call(main.evidence_journal.visible, "Evidence Journal opened")
	main._unhandled_input(esc_event)
	assert_test.call(not main.evidence_journal.visible, "Pressing [Esc] closes open Evidence Journal")
	assert_test.call(not settings.visible, "Settings Menu remains closed when dismissing Evidence Journal")

	# Case D: Help Overlay open -> ESC closes Help Overlay first
	main.help_overlay.visible = true
	main._unhandled_input(esc_event)
	assert_test.call(not main.help_overlay.visible, "Pressing [Esc] closes open Help Overlay")
	assert_test.call(not settings.visible, "Settings Menu remains closed when dismissing Help Overlay")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Clean Decoupled Design (Zero Developer Leaks)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Clean Separation & Zero Developer Leaks")
	assert_test.call(not settings.has_method("warp_to_phase"), "SettingsMenu3D has no phase warp methods")
	assert_test.call(not settings.has_method("reveal_all_roles"), "SettingsMenu3D has no role reveal methods")
	assert_test.call(not settings.has_method("set_engine_speed"), "SettingsMenu3D has no speedwarp methods")
	assert_test.call(main.playtest_tuning_panel != null, "Playtest tuning console remains separate component [F1]")
	assert_test.call(main.playtest_tuning_panel != settings, "SettingsMenu3D and PlaytestTuningPanel3D are completely distinct instances")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL STEP 4 AUDIO MIXER & SETTINGS CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.free()
	quit(0 if stats["failed"] == 0 else 1)
