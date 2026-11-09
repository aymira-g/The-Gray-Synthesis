extends SceneTree

# ==============================================================================
# Automated Test Suite: Archive Discovery Dilemma Modal UI & Hotkeys
# Blueprint Section 6 & 11 Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING ARCHIVE DISCOVERY DILEMMA MODAL UI VERIFICATION ---")
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

	# ------------------------------------------------------------------
	# TEST GROUP 1: Overlay UI Construction & Initial Visibility
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Modal Overlay Initialization")
	assert_test.call(main.archive_dilemma_overlay != null, "archive_dilemma_overlay instantiated on Main3D")
	assert_test.call(main.archive_dilemma_options_container != null, "archive_dilemma_options_container instantiated")
	assert_test.call(main.archive_dilemma_title != null, "archive_dilemma_title instantiated")
	assert_test.call(main.archive_dilemma_desc != null, "archive_dilemma_desc instantiated")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay initially hidden")
	assert_test.call(gm.archive_dilemma_open == false, "GameManager.archive_dilemma_open initially false")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Operative Player Dilemma Presentation & Hotkey [1] Loyal
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Operative Dilemma: Loyal Choice [1]")
	# Configure player as Ecology Operative
	player.secret_role = "ecology"
	gm.archive_opened = false
	gm.archive_finder_id = -1
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE

	# Trigger archive opening by player
	var res_dict = gm.open_archive(player, { "site_id": "alcove_2" })
	assert_test.call(gm.archive_opened == true, "Archive opened successfully")
	assert_test.call(gm.archive_finder_id == int(player.resident_id), "Player recorded as archive finder")
	assert_test.call(gm.archive_dilemma_open == true, "archive_dilemma_open set to true for player finder")

	# Update HUD to trigger overlay refresh
	main._update_hud()
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma modal overlay is visible")
	var op_buttons = main.archive_dilemma_options_container.get_children()
	assert_test.call(op_buttons.size() == 2, "Operative dilemma presents exactly 2 choices (Loyal vs Whistleblower)")
	assert_test.call(op_buttons[0].text.contains("Stay Loyal"), "Option 1 is Stay Loyal to Faction")
	assert_test.call(op_buttons[1].text.contains("Whistleblower"), "Option 2 is Whistleblower")
	assert_test.call(main.status_label.text.contains("Operative Dilemma"), "Status banner displays Operative Dilemma instructions")

	# Movement suppression test while dilemma is active
	player.velocity = Vector3(5.0, 0.0, 5.0)
	player._process_player_movement(0.016)
	assert_test.call(player.velocity == Vector3.ZERO, "Player movement velocity suppressed to ZERO while dilemma is open")

	# Hotkey [1] Test -> Resolves Loyal
	var key_1 := InputEventKey.new()
	key_1.pressed = true
	key_1.keycode = KEY_1
	main._unhandled_input(key_1)

	assert_test.call(gm.archive_dilemma_open == false, "archive_dilemma_open set to false after choice [1]")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay hidden after resolution")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_LOYAL, "Archive choice recorded as ARCHIVE_CHOICE_LOYAL")
	assert_test.call(gm.archive_loyal_faction == "ecology", "Loyal faction recorded as ecology")
	assert_test.call(gm.archive_choice_details.contains("+12%"), "Choice details confirm +12% speed bonus")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Operative Player Dilemma: Whistleblower Choice [2]
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Operative Dilemma: Whistleblower Choice [2]")
	player.secret_role = "technology"
	gm.archive_opened = false
	gm.archive_finder_id = -1
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.archive_whistleblower_active = false

	gm.open_archive(player, { "site_id": "alcove_1" })
	main._update_hud()
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma modal reopened for Tech operative")

	# Press Hotkey [2] -> Whistleblower
	var key_2 := InputEventKey.new()
	key_2.pressed = true
	key_2.keycode = KEY_2
	main._unhandled_input(key_2)

	assert_test.call(gm.archive_dilemma_open == false, "archive_dilemma_open closed after choice [2]")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay hidden after Whistleblower choice")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_WHISTLEBLOWER, "Archive choice recorded as ARCHIVE_CHOICE_WHISTLEBLOWER")
	assert_test.call(gm.archive_whistleblower_active == true, "Whistleblower flag set to true")
	assert_test.call(gm.archive_choice_details.contains("Whistleblower"), "Choice details confirm Whistleblower status")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Civilian Player Dilemma Options & [3] Reserve for CW
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Civilian Dilemma: Reserve for Common Works [3]")
	player.secret_role = "civilian"
	gm.archive_opened = false
	gm.archive_finder_id = -1
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.archive_reserved_for_cw = false
	gm.common_works_eco = 20.0
	gm.common_works_tech = 20.0
	gm.common_works_struct = 20.0

	gm.open_archive(player, { "site_id": "alcove_3" })
	main._update_hud()
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma modal opened for Civilian finder")

	var civ_buttons = main.archive_dilemma_options_container.get_children()
	assert_test.call(civ_buttons.size() == 3, "Civilian dilemma presents exactly 3 choices (Eco, Tech, Common Works)")
	assert_test.call(civ_buttons[0].text.contains("Ecology"), "Civilian Option 1 entrusts to Ecology")
	assert_test.call(civ_buttons[1].text.contains("Technology"), "Civilian Option 2 entrusts to Technology")
	assert_test.call(civ_buttons[2].text.contains("Common Works"), "Civilian Option 3 reserves for Common Works")
	assert_test.call(main.status_label.text.contains("Civilian Dilemma"), "Status banner displays Civilian Dilemma instructions")

	# Hotkey [3] Test -> Reserve for Common Works
	var key_3 := InputEventKey.new()
	key_3.pressed = true
	key_3.keycode = KEY_3
	main._unhandled_input(key_3)

	assert_test.call(gm.archive_dilemma_open == false, "archive_dilemma_open closed after choice [3]")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay hidden after choice [3]")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_RESERVE_CW, "Archive choice recorded as ARCHIVE_CHOICE_RESERVE_CW")
	assert_test.call(gm.archive_reserved_for_cw == true, "archive_reserved_for_cw set to true")
	assert_test.call(is_equal_approx(gm.common_works_eco, 35.0), "Common Works Eco gained +15% (20% -> 35%)")
	assert_test.call(is_equal_approx(gm.common_works_tech, 35.0), "Common Works Tech gained +15% (20% -> 35%)")
	assert_test.call(is_equal_approx(gm.common_works_struct, 35.0), "Common Works Structural gained +15% (20% -> 35%)")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Civilian Dilemma Options [1] & [2] (Entrust Eco / Tech)
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Civilian Dilemma: Entrust Eco [1] and Tech [2]")
	# Test Entrust Eco via Click
	gm.archive_opened = false
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.archive_entrust_faction = ""
	gm.open_archive(player, { "site_id": "alcove_2" })
	main._update_hud()
	civ_buttons = main.archive_dilemma_options_container.get_children()
	civ_buttons[0].emit_signal("pressed")

	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_ENTRUST_ECO, "Clicking option 1 sets ARCHIVE_CHOICE_ENTRUST_ECO")
	assert_test.call(gm.archive_entrust_faction == "ecology", "archive_entrust_faction set to ecology")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay dismissed after click")

	# Test Entrust Tech via Hotkey [2]
	gm.archive_opened = false
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.archive_entrust_faction = ""
	gm.open_archive(player, { "site_id": "alcove_2" })
	main._update_hud()
	main._unhandled_input(key_2)

	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_ENTRUST_TECH, "Hotkey [2] sets ARCHIVE_CHOICE_ENTRUST_TECH")
	assert_test.call(gm.archive_entrust_faction == "technology", "archive_entrust_faction set to technology")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Overlay dismissed after hotkey [2]")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Phase Transition Preservation & Timeout Auto-Resolution
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Phase Transition Preservation & Timeout Safety")
	# 1. Open Town -> First Council transition MUST PRESERVE the pending choice!
	player.secret_role = "civilian"
	gm.archive_opened = false
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.open_archive(player, { "site_id": "alcove_2" })
	main._update_hud()
	assert_test.call(gm.archive_dilemma_open == true, "Dilemma active before phase shift")
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma modal visible in Open Town")

	# Transition to FIRST_COUNCIL (e.g. Open Town clock runs out)
	main._on_phase_changed(gm.Phase.FIRST_COUNCIL)
	assert_test.call(gm.archive_dilemma_open == true, "Pending archive dilemma PRESERVED across phase shift to First Council")
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma modal remains active and visible in First Council")

	# Resolve choice [1] during First Council
	main._unhandled_input(key_1)
	assert_test.call(gm.archive_dilemma_open == false, "Dilemma resolved successfully during First Council")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Modal hidden after decision in First Council")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_ENTRUST_ECO, "Archive choice registered from First Council input")

	# 2. Timeout Auto-Resolution for Operative Finder
	player.secret_role = "ecology"
	gm.archive_opened = false
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.open_archive(player, { "site_id": "alcove_1" })
	main._update_hud()
	assert_test.call(main.archive_dilemma_timer > 0.0, "Dilemma countdown timer initialized")

	# Advance timer past expiry
	main._update_archive_dilemma(26.0)
	assert_test.call(gm.archive_dilemma_open == false, "Dilemma closed automatically on timer expiration")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_LOYAL, "Operative dilemma auto-resolved to default: Stay Loyal")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Modal hidden after timeout auto-resolve")

	# 3. Timeout Auto-Resolution for Civilian Finder
	player.secret_role = "civilian"
	gm.archive_opened = false
	gm.archive_choice = C.ARCHIVE_CHOICE_NONE
	gm.archive_reserved_for_cw = false
	gm.open_archive(player, { "site_id": "alcove_3" })
	main._update_hud()

	main._update_archive_dilemma(26.0)
	assert_test.call(gm.archive_dilemma_open == false, "Civilian dilemma closed automatically on timer expiration")
	assert_test.call(gm.archive_choice == C.ARCHIVE_CHOICE_RESERVE_CW, "Civilian dilemma auto-resolved to default: Reserve Common Works")
	assert_test.call(gm.archive_reserved_for_cw == true, "Common works flag set on civilian timeout")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Modal hidden after civilian timeout")

	# 4. Match Over & Match Restart Safety
	gm.archive_dilemma_open = true
	main._update_hud()
	assert_test.call(main.archive_dilemma_overlay.visible == true, "Dilemma visible before match conclusion")
	main._on_phase_changed(gm.Phase.MATCH_OVER)
	assert_test.call(gm.archive_dilemma_open == false, "Dilemma auto-resolved on MATCH_OVER")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Modal hidden on MATCH_OVER")

	gm.archive_dilemma_open = true
	main._update_hud()
	main.start_new_match()
	assert_test.call(gm.archive_dilemma_open == false, "Dilemma resolved on start_new_match()")
	assert_test.call(main.archive_dilemma_overlay.visible == false, "Modal hidden on start_new_match()")

	# ------------------------------------------------------------------
	# Summary
	# ------------------------------------------------------------------
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL ARCHIVE DISCOVERY DILEMMA MODAL CHECKS PASSED! <<<")
		quit(0)
	else:
		printerr(">>> CHECKS FAILED! <<<")
		quit(1)
