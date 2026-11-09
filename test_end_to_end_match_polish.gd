extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 4: End-to-End Match Experience & Polish Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING OPTION 4: END-TO-END MATCH EXPERIENCE VERIFICATION ---")
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

	var gm: Node = main.game_manager
	var player: CharacterBody3D = main.player_node
	var town_map: Node3D = main.town_map

	# ------------------------------------------------------------------
	# TEST GROUP 1: Phase Announcement Banners
	# ------------------------------------------------------------------
	print("[TEST GROUP 1] Dynamic Phase Announcement Banners")
	gm.current_phase = gm.Phase.BRIEFING
	main._on_phase_changed(gm.Phase.BRIEFING)
	assert_test.call(main.phase_banner != null and main.phase_banner.visible, "Phase banner visible on Briefing")
	assert_test.call(main.phase_banner_title.text.find("BRIEFING") != -1, "Briefing banner title displays 'PHASE 1: TOWN BRIEFING'")
	assert_test.call(main.phase_banner_subtitle.text.find("identity") != -1, "Briefing banner subtitle provides instructions")

	gm.current_phase = gm.Phase.OPEN_TOWN
	main._on_phase_changed(gm.Phase.OPEN_TOWN)
	assert_test.call(main.phase_banner_title.text.find("OPEN TOWN") != -1, "Open Town banner displays 'PHASE 2: OPEN TOWN'")

	gm.current_phase = gm.Phase.FIRST_COUNCIL
	main._on_phase_changed(gm.Phase.FIRST_COUNCIL)
	assert_test.call(main.phase_banner_title.text.find("FIRST COUNCIL") != -1, "First Council banner displays 'FIRST COUNCIL IN SESSION'")

	gm.current_phase = gm.Phase.ESCALATION
	main._on_phase_changed(gm.Phase.ESCALATION)
	assert_test.call(main.phase_banner_title.text.find("ESCALATION") != -1, "Escalation banner displays 'PHASE 4: TOWN ESCALATION'")

	gm.current_phase = gm.Phase.COURT
	main._on_phase_changed(gm.Phase.COURT)
	assert_test.call(main.phase_banner_title.text.find("CIVILIAN COURT") != -1, "Court banner displays 'CIVILIAN COURT IN SESSION'")

	gm.current_phase = gm.Phase.FINALE
	main._on_phase_changed(gm.Phase.FINALE)
	assert_test.call(main.phase_banner_title.text.find("FINALE") != -1, "Finale banner displays 'PHASE 6: FINALE COMMENCED'")

	# Banner timer decay
	assert_test.call(main.phase_banner_timer > 0.0, "Phase banner timer is active (%.1fs)" % main.phase_banner_timer)
	for i in range(40):
		main._update_phase_banner(0.1)
	assert_test.call(not main.phase_banner.visible, "Phase banner automatically hides after duration expires")

	# ------------------------------------------------------------------
	# TEST GROUP 2: First Council Interactive Deliberation & 3D Alibis
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] First Council Interactive Assembly & 3D Alibis")
	gm.current_phase = gm.Phase.FIRST_COUNCIL
	main._on_phase_changed(gm.Phase.FIRST_COUNCIL)
	assert_test.call(main.council_overlay != null and main.council_overlay.visible, "First Council overlay visible during First Council")
	assert_test.call(main.council_title_label.text.find("FIRST COUNCIL") != -1, "Council title label displays 'FIRST COUNCIL IN SESSION'")

	# Force advance speaker timer to trigger next speaker statement
	main.council_speaker_timer = 0.0
	main._update_first_council_assembly(0.1)
	assert_test.call(main.council_speaker_label.text.find("SPEAKER:") != -1, "Council speaker label displays active resident speaker")
	assert_test.call(main.council_statement_label.text.length() > 5, "Council statement label displays non-empty alibi statement")

	# Check that the speaking resident in 3D has speech bubble populated
	var current_speaker: CharacterBody3D = main.residents[0]
	assert_test.call(current_speaker.speech_label != null, "Council resident has 3D speech bubble label")
	assert_test.call(current_speaker.speech_label.text.length() > 0, "Council resident displays in-world alibi speech bubble: %s" % current_speaker.speech_label.text)

	# Transition to Escalation hides council overlay
	gm.current_phase = gm.Phase.ESCALATION
	main._on_phase_changed(gm.Phase.ESCALATION)
	assert_test.call(not main.council_overlay.visible, "Advancing to Escalation dismisses First Council overlay")

	# ------------------------------------------------------------------
	# TEST GROUP 3: In-World Channeling HUD Progress Bar
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Channeling HUD Progress Bar & Interaction Feedback")
	assert_test.call(main.channel_bar_container != null, "Channeling progress bar container present in UI")
	assert_test.call(not main.channel_bar_container.visible, "Channeling progress bar initially hidden when idle")

	# Start channeling pump pad
	main.camera_mode = "follow_player"
	player.position = Vector3(-6.0, 0.0, 24.0) # Pump pad position
	var pad: Dictionary = town_map.get_nearest_pad(player.position, 4.0)
	assert_test.call(not pad.is_empty(), "Found Pump Station pad at coordinates")

	player.active_pad = pad
	player.is_channeling = true
	player.channel_progress = 1.5 # half of 3.0s
	main._update_hud()

	assert_test.call(main.channel_bar_container.visible, "Channel bar becomes visible during active task channeling")
	assert_test.call(main.channel_action_label.text.find("Pump") != -1, "Channel action label identifies 'Pump' station")
	assert_test.call(main.channel_progress_bar.value >= 49.0, "Progress bar reflects 50%% channel progress (actual: %.1f)" % main.channel_progress_bar.value)

	# Finish channeling
	player.is_channeling = false
	player.channel_progress = 0.0
	main._update_hud()
	assert_test.call(not main.channel_bar_container.visible, "Finishing channel hides progress bar container")

	# Test alcove inspection progress
	player.is_inspecting = true
	player.inspection_timer = 1.25 # half of 2.5s
	main._update_hud()
	assert_test.call(main.channel_bar_container.visible, "Channel bar becomes visible during alcove inspection")
	assert_test.call(main.channel_action_label.text.find("Alcove") != -1, "Action label identifies 'Bedrock Alcove'")
	assert_test.call(main.channel_progress_bar.value >= 49.0, "Progress bar reflects 50% inspection progress")

	player.is_inspecting = false
	player.inspection_timer = 0.0
	main._update_hud()
	assert_test.call(not main.channel_bar_container.visible, "Finishing inspection hides progress bar")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Field Manual & In-Game Help Overlay [H]
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Field Manual & In-Game Help Overlay [H]")
	assert_test.call(main.help_overlay != null, "Help overlay exists in scene hierarchy")
	assert_test.call(not main.help_overlay.visible, "Help overlay initially hidden")

	# Press KEY_H to open
	var ev_h := InputEventKey.new()
	ev_h.pressed = true
	ev_h.keycode = KEY_H
	main._unhandled_input(ev_h)
	assert_test.call(main.help_overlay.visible, "Pressing [H] opens Field Manual & Help overlay")

	# Press KEY_H again to close
	main._unhandled_input(ev_h)
	assert_test.call(not main.help_overlay.visible, "Pressing [H] again toggles Help overlay closed")

	# Open with [H], close with [Escape]
	main._unhandled_input(ev_h)
	assert_test.call(main.help_overlay.visible, "Re-opened Help overlay")
	var ev_esc := InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.keycode = KEY_ESCAPE
	main._unhandled_input(ev_esc)
	assert_test.call(not main.help_overlay.visible, "Pressing [Escape] closes Help overlay")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Clock Urgency & Low-Resource Warnings
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Clock Urgency & Low-Resource Warnings")
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 180.0
	gm.water = 60.0
	gm.stability = 65.0
	main._update_hud()
	assert_test.call(main.clock_label.modulate == Color.WHITE, "Normal match clock uses standard white color")
	assert_test.call(main.resource_label.modulate == Color.WHITE, "Normal resources use standard white color")

	# Low time (< 30s) triggers urgency pulse
	gm.time_remaining = 20.0
	main._update_hud()
	assert_test.call(main.clock_label.modulate != Color.WHITE, "Clock modulates warning color during urgent countdown (< 30s)")

	# Low resources (< 25%) trigger warning color
	gm.water = 15.0
	main._update_hud()
	assert_test.call(main.resource_label.modulate == Color(1.0, 0.45, 0.45), "Resource label displays alert color when water < 25%")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Match Over Grand Role Reveal & Clean Reset
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Match Over Grand Role Reveal & Full Reset Loop")
	gm.current_phase = gm.Phase.MATCH_OVER
	main._on_phase_changed(gm.Phase.MATCH_OVER)
	assert_test.call(main.game_over_overlay.visible, "Game Over overlay visible on MATCH_OVER")
	assert_test.call(main.game_over_roster != null, "Game Over roster reveal label exists")
	assert_test.call(main.game_over_roster.text.find("CITIZEN ROSTER") != -1, "Roster reveal header present")

	# Verify all 10 residents are revealed with identities
	for i in range(1, 11):
		assert_test.call(main.game_over_roster.text.find("Resident %d" % i) != -1, "Resident %d dossier included in endgame roster" % i)

	assert_test.call(main.game_over_roster.text.find("[YOU]") != -1, "Player explicitly designated with '[YOU]' tag in reveal")

	# Press [R] to reset match
	var ev_r := InputEventKey.new()
	ev_r.pressed = true
	ev_r.keycode = KEY_R
	main._unhandled_input(ev_r)

	assert_test.call(gm.current_phase == gm.Phase.BRIEFING, "Pressing [R] restarts match in Briefing phase")
	assert_test.call(not main.game_over_overlay.visible, "Reset dismisses Game Over modal")
	assert_test.call(not main.help_overlay.visible, "Reset dismisses Help modal")
	assert_test.call(not main.council_overlay.visible, "Reset dismisses Council modal")
	assert_test.call(not main.channel_bar_container.visible, "Reset dismisses Channel progress bar")
	assert_test.call(player.position.distance_to(main.spawn_positions[0]) < 0.1, "Player returned to designated Council seat spawn")

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 4 END-TO-END MATCH CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
