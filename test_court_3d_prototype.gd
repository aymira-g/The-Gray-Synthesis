extends SceneTree

const SceneClass = preload("res://scenes/Court3D_Prototype.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING 3D COURT SCENE PROTOTYPE VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	# Instantiate the 3D prototype scene
	var scene: Node3D = SceneClass.instantiate()
	root.add_child(scene)
	scene._ready()

	# ------------------------------------------------------------------
	# TEST GROUP 1: Environment & Atmospheric Lighting
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Environment & Lighting")
	assert_test.call(scene.world_env != null, "WorldEnvironment created")
	assert_test.call(scene.world_env.environment.volumetric_fog_enabled == true, "Volumetric atmospheric dust/fog enabled")
	assert_test.call(scene.world_env.environment.glow_enabled == true, "Bloom/glow enabled for emissive lamps")
	assert_test.call(scene.sun_light != null and scene.sun_light.shadow_enabled == true, "Dusk directional sun with shadows active")
	assert_test.call(scene.podium_spotlight != null, "Central podium spotlight exists")
	assert_test.call(scene.town_beacon_light != null, "Emergency beacon light active")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Architecture & Town Square Landmarks
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Town Square Architecture & Blockouts")
	assert_test.call(scene.buildings_node != null, "Buildings root container created")
	assert_test.call(scene.council_ring_node != null, "Council Ring node created")
	assert_test.call(scene.podium_node != null, "Speaker podium rostrum created")
	assert_test.call(scene.tally_board_3d != null, "3D running tally board created")

	# ------------------------------------------------------------------
	# TEST GROUP 3: 10 Residents & Faction Secrecy Verification
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] 10 Residents & Faction Secrecy")
	assert_test.call(scene.resident_nodes.size() == 10, "10 resident character nodes assembled")

	var all_auras_hidden := true
	for r in scene.resident_nodes:
		var aura: MeshInstance3D = r.get_node_or_null("InspectorAura")
		if aura != null and aura.visible:
			all_auras_hidden = false
			break
	assert_test.call(all_auras_hidden == true, "Secret faction auras are strictly HIDDEN by default (Preserves visual secrecy)")

	# Verify civic tool props attached
	var civ_tools_present := true
	for r in scene.resident_nodes:
		var tool_found := false
		for c in r.get_children():
			if c is MeshInstance3D and c.name != "Torso" and c.name != "Head" and c.name != "InspectorAura":
				tool_found = true
				break
		if not tool_found:
			civ_tools_present = false
			break
	assert_test.call(civ_tools_present == true, "Public civic tool silhouettes attached to all residents")

	# Test [Tab] Inspector toggle
	var ev_tab := InputEventKey.new()
	ev_tab.pressed = true
	ev_tab.keycode = KEY_TAB
	scene._input(ev_tab)
	assert_test.call(scene.show_inspector_overlay == true, "Pressing [Tab] toggles inspector overlay active")
	var aura_vis_count := 0
	for r in scene.resident_nodes:
		var a: MeshInstance3D = r.get_node_or_null("InspectorAura")
		if a != null and a.visible:
			aura_vis_count += 1
	assert_test.call(aura_vis_count == 10, "Inspector overlay reveals faction auras on all 10 residents for dev preview")

	# Toggle off again
	scene._input(ev_tab)
	assert_test.call(scene.show_inspector_overlay == false, "Pressing [Tab] again re-hides faction auras")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Scripted Scenario Presets
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Scripted Scenarios")

	# Preset 1: 3-1 Split
	scene.start_scenario(1)
	assert_test.call(scene.current_scenario_id == 1, "Preset 1 selected")
	assert_test.call(scene.scenarios[1]["votes"].size() == 4, "Preset 1 has 4 scripted votes")
	assert_test.call(scene.scenarios[1]["verdict"].find("3-1") != -1, "Preset 1 declares 3-1 split verdict")

	# Preset 2: 4-0 Ecology
	scene.start_scenario(2)
	assert_test.call(scene.current_scenario_id == 2, "Preset 2 selected")
	assert_test.call(scene.scenarios[2]["verdict"].find("UNANIMOUS 4-0") != -1, "Preset 2 declares 4-0 unanimous verdict")

	# Preset 3: 4-0 Technology
	scene.start_scenario(3)
	assert_test.call(scene.current_scenario_id == 3, "Preset 3 selected")
	assert_test.call(scene.scenarios[3]["verdict"].find("TECHNOLOGY VICTORY") != -1, "Preset 3 declares 4-0 tech verdict")

	# Preset 4: 2-2 Deadlock
	scene.start_scenario(4)
	assert_test.call(scene.current_scenario_id == 4, "Preset 4 selected")
	assert_test.call(scene.scenarios[4]["verdict"].find("2-2") != -1, "Preset 4 declares 2-2 deadlock verdict")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Sequential Walk-Up & Podium Choreography
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Sequential Walk-Up & Podium Choreography")
	scene.start_scenario(1) # Back to preset 1
	assert_test.call(scene.step_state == "idle", "Ceremony starts in idle state")

	# Step 0: Voter 1 walks to podium
	scene._begin_voter_turn(0)
	assert_test.call(scene.step_state == "walking_to_podium", "Voter 1 enters walking_to_podium state")
	assert_test.call(scene.active_voter_node == scene.resident_nodes[0], "Active voter is Civilian 1")

	# Simulate arrival at podium
	scene._on_reached_podium(0)
	assert_test.call(scene.step_state == "speaking", "Voter reaches podium and enters speaking state")
	var bubble: Label3D = scene.active_voter_node.get_node_or_null("SpeechBubble")
	assert_test.call(bubble != null and bubble.visible == true, "3D speech bubble visible with spoken quote")
	assert_test.call(bubble.text.find("aquifer") != -1, "Speech bubble contains aquifer crisis quote")
	assert_test.call(scene.recorded_votes.size() == 1, "Vote recorded in live tally")
	assert_test.call(scene.recorded_votes[0]["vote"] == "Ecology", "Vote recorded as Ecology")

	# Voter returns to seat
	scene._finish_voter_speech()
	assert_test.call(scene.step_state == "walking_back", "Voter enters walking_back state")
	scene._on_returned_to_seat()
	assert_test.call(scene.current_step_index == 1, "Ceremony step advanced to Voter 2")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Camera Modes
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Camera Modes")
	assert_test.call(scene.current_cam_mode == scene.CamMode.DIRECTOR, "Initial camera mode is DIRECTOR")

	var ev_c := InputEventKey.new()
	ev_c.pressed = true
	ev_c.keycode = KEY_C
	scene._input(ev_c)
	assert_test.call(scene.current_cam_mode == scene.CamMode.TOP_DOWN, "Pressing [C] cycles to TOP_DOWN MOBA mode")

	scene._input(ev_c)
	assert_test.call(scene.current_cam_mode == scene.CamMode.FREE_ORBIT, "Pressing [C] cycles to FREE_ORBIT mode")

	scene._input(ev_c)
	assert_test.call(scene.current_cam_mode == scene.CamMode.DIRECTOR, "Pressing [C] cycles back to DIRECTOR mode")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> 3D COURT SCENE PROTOTYPE VERIFIED SUCCESSFULLY! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)
