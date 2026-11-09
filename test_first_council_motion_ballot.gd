extends SceneTree

# ==============================================================================
# Automated Test Suite: First Council Civic Motion Ballot UI & Hotkeys
# Blueprint Section 7 & 11 Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING FIRST COUNCIL MOTION BALLOT UI VERIFICATION ---")
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
	# TEST GROUP 1: UI Structure & Initial Hierarchy
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Council Overlay & Motion Ballot Construction")
	assert_test.call(main.council_overlay != null, "council_overlay instantiated")
	assert_test.call(main.council_title_label != null, "council_title_label instantiated")
	assert_test.call(main.council_speaker_label != null, "council_speaker_label instantiated")
	assert_test.call(main.council_statement_label != null, "council_statement_label instantiated")
	assert_test.call(main.council_motion_header_label != null, "council_motion_header_label instantiated")
	assert_test.call(main.council_motion_btn_container != null, "council_motion_btn_container instantiated")
	assert_test.call(main.council_motion_btn_1 != null, "council_motion_btn_1 instantiated")
	assert_test.call(main.council_motion_btn_2 != null, "council_motion_btn_2 instantiated")
	assert_test.call(main.council_motion_btn_3 != null, "council_motion_btn_3 instantiated")
	assert_test.call(main.council_tally_label != null, "council_tally_label instantiated")
	assert_test.call(main.council_hint_label != null, "council_hint_label instantiated")
	assert_test.call(main.council_overlay.visible == false, "council_overlay initially hidden in Briefing")

	# ------------------------------------------------------------------
	# TEST GROUP 2: First Council Phase Activation & Default Ballot State
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] First Council Activation & Default Ballot")
	gm.set_phase(gm.Phase.FIRST_COUNCIL)
	main._update_hud()
	assert_test.call(main.council_overlay.visible == true, "council_overlay visible during FIRST_COUNCIL")
	assert_test.call(gm.current_phase == gm.Phase.FIRST_COUNCIL, "Current phase is FIRST_COUNCIL")
	assert_test.call(gm.council_ballots.size() == 10, "10 council ballots registered for 10 residents")
	assert_test.call(gm.player_motion_vote == 1, "Default player motion vote is Motion 1")

	# Check button labels and tooltips
	assert_test.call(main.council_motion_btn_1.text.contains("Station Watch Beacons"), "Button 1 displays Station Watch Beacons")
	assert_test.call(main.council_motion_btn_1.text.contains("[YOUR VOTE]"), "Button 1 displays [YOUR VOTE] indicator")
	assert_test.call(main.council_motion_btn_2.text.contains("Emergency Scrap Subsidy"), "Button 2 displays Emergency Scrap Subsidy")
	assert_test.call(main.council_motion_btn_3.text.contains("Crop Blight Remediation"), "Button 3 displays Crop Blight Remediation")
	assert_test.call(main.council_motion_btn_1.tooltip_text.contains("Pump Station"), "Button 1 has descriptive tooltip")
	assert_test.call(main.council_motion_btn_2.tooltip_text.contains("+3 Scrap"), "Button 2 has descriptive tooltip")
	assert_test.call(main.council_motion_btn_3.tooltip_text.contains("25%"), "Button 3 has descriptive tooltip")

	# Check tally and status banner
	var counts: Array[int] = gm.get_council_motion_counts()
	assert_test.call(counts.size() == 3, "get_council_motion_counts() returns 3 motion buckets")
	var total_votes: int = counts[0] + counts[1] + counts[2]
	assert_test.call(total_votes == 10, "Total ballot votes sum to 10 residents")
	assert_test.call(main.council_tally_label.text.contains("Council Ballot Tally"), "Tally label shows active ballot count")
	assert_test.call(main.status_label.text.contains("Your Ballot: Motion 1"), "Status banner displays player ballot state")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Keyboard Hotkey Voting & Dynamic Switching
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Keyboard Hotkeys [1], [2], [3] & Dynamic Vote Switching")
	var initial_counts: Array[int] = gm.get_council_motion_counts().duplicate()

	# Press [2] -> Switch to Motion 2
	var key_2 := InputEventKey.new()
	key_2.pressed = true
	key_2.keycode = KEY_2
	main._unhandled_input(key_2)

	assert_test.call(gm.player_motion_vote == 2, "Pressing [2] changes player_motion_vote to 2")
	assert_test.call(main.council_motion_btn_2.text.contains("[YOUR VOTE]"), "Button 2 text now has [YOUR VOTE]")
	assert_test.call(not main.council_motion_btn_1.text.contains("[YOUR VOTE]"), "Button 1 no longer has [YOUR VOTE]")
	assert_test.call(main.status_label.text.contains("Motion 2"), "Status banner updated to Motion 2")

	# Press [3] -> Switch to Motion 3
	var key_3 := InputEventKey.new()
	key_3.pressed = true
	key_3.keycode = KEY_3
	main._unhandled_input(key_3)

	assert_test.call(gm.player_motion_vote == 3, "Pressing [3] changes player_motion_vote to 3")
	assert_test.call(main.council_motion_btn_3.text.contains("[YOUR VOTE]"), "Button 3 text now has [YOUR VOTE]")
	assert_test.call(not main.council_motion_btn_2.text.contains("[YOUR VOTE]"), "Button 2 no longer has [YOUR VOTE]")
	assert_test.call(main.status_label.text.contains("Motion 3"), "Status banner updated to Motion 3")

	# Press [1] -> Switch back to Motion 1
	var key_1 := InputEventKey.new()
	key_1.pressed = true
	key_1.keycode = KEY_1
	main._unhandled_input(key_1)

	assert_test.call(gm.player_motion_vote == 1, "Pressing [1] restores player_motion_vote to 1")
	assert_test.call(main.council_motion_btn_1.text.contains("[YOUR VOTE]"), "Button 1 restored to [YOUR VOTE]")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Interactive Mouse Button Clicking
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Interactive Mouse Button Click Handlers")
	main.council_motion_btn_2.emit_signal("pressed")
	assert_test.call(gm.player_motion_vote == 2, "Clicking Button 2 sets player_motion_vote to 2")
	assert_test.call(main.council_motion_btn_2.text.contains("[YOUR VOTE]"), "Button 2 displays [YOUR VOTE] after click")

	main.council_motion_btn_3.emit_signal("pressed")
	assert_test.call(gm.player_motion_vote == 3, "Clicking Button 3 sets player_motion_vote to 3")
	assert_test.call(main.council_motion_btn_3.text.contains("[YOUR VOTE]"), "Button 3 displays [YOUR VOTE] after click")

	main.council_motion_btn_1.emit_signal("pressed")
	assert_test.call(gm.player_motion_vote == 1, "Clicking Button 1 sets player_motion_vote to 1")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Motion Resolution & Gameplay Mechanics at Escalation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Winning Motion Execution at Escalation")
	# 1. Motion 1 (Station Watch Beacons)
	gm.council_motion_winner = 1
	gm.council_motion_applied = false
	gm.sensor_beacons_active = false
	gm._apply_council_motion()
	assert_test.call(gm.sensor_beacons_active == true, "Motion 1 activates sensor_beacons_active")

	# Test beacon logging during Escalation
	gm.current_phase = gm.Phase.ESCALATION
	gm.station_beacon_logs.clear()
	gm.record_beacon_access(player, "Pump Station", "Terminal")
	assert_test.call(gm.station_beacon_logs.size() == 1, "Beacon access recorded in station_beacon_logs")

	# 2. Motion 2 (Emergency Scrap Subsidy)
	gm.scrap = 2
	gm.council_motion_winner = 2
	gm.council_motion_applied = false
	gm._apply_council_motion()
	assert_test.call(gm.scrap == 5, "Motion 2 grants +3 Scrap subsidy (2 -> 5)")

	# 3. Motion 3 (Crop Blight Remediation)
	gm.crop_remediation_active = false
	gm.council_motion_winner = 3
	gm.council_motion_applied = false
	gm._apply_council_motion()
	assert_test.call(gm.crop_remediation_active == true, "Motion 3 activates crop_remediation_active")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Council Transition & UI Dismissal
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Phase Transition & Overlay Dismissal")
	gm.set_phase(gm.Phase.FIRST_COUNCIL)
	main._update_hud()
	assert_test.call(main.council_overlay.visible == true, "Council overlay visible in FIRST_COUNCIL")

	# Press Space to advance to Escalation
	var key_space := InputEventKey.new()
	key_space.pressed = true
	key_space.keycode = KEY_SPACE
	main._unhandled_input(key_space)

	assert_test.call(gm.current_phase == gm.Phase.ESCALATION, "Pressing [Space] advances to Phase.ESCALATION")
	assert_test.call(main.council_overlay.visible == false, "Council overlay hidden in Phase.ESCALATION")
	assert_test.call(gm.council_motion_resolved == true, "Council motion vote resolved on phase advance")
	assert_test.call(gm.council_motion_applied == true, "Council motion applied at start of Escalation")

	# ------------------------------------------------------------------
	# Summary
	# ------------------------------------------------------------------
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL FIRST COUNCIL MOTION BALLOT CHECKS PASSED! <<<")
		quit(0)
	else:
		printerr(">>> CHECKS FAILED! <<<")
		quit(1)
