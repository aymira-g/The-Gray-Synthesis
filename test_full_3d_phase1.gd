extends SceneTree

# ==============================================================================
# The Gray Synthesis - Full 3D Phase 1 Automated Verification Suite
# ==============================================================================
# Verifies:
# 1. 10-Resident 3D Roster & Official Role Distribution (3 Eco, 3 Tech, 4 Civilians)
# 2. Full 3D Town Map & 4 Sectors Spatial Geometry
# 3. Task Pads & Escalation-Locked Landmarks (Generator/Beacon marked locked)
# 4. Secluded Bedrock Alcoves (Archive Secrecy: 4 identical, 1 active, 0 visual leaks)
# 5. 3D Waypoint Navigation Graph & Pathfinding around Obstacle Walls
# 6. 3D Sightlines, Anonymity & Evidence Parity Guardrails
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING FULL 3D PHASE 1 VERIFICATION SUITE ---")
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
	var map: Node3D = main.town_map
	var residents: Array = main.residents
	var player: CharacterBody3D = main.player_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: 10-Resident 3D Roster & Role Distribution
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] 10-Resident 3D Roster & Role Distribution")
	assert_test.call(residents.size() == 10, "Session contains exactly 10 3D residents")
	assert_test.call(player != null and player.is_player == true, "Resident 1 is player (is_player = true)")

	var bot_count := 0
	var eco_count := 0
	var tech_count := 0
	var civ_count := 0
	var all_have_collision := true
	var all_have_civic_tools := true

	for i in range(residents.size()):
		var r: CharacterBody3D = residents[i]
		if not r.is_player:
			bot_count += 1
		match r.secret_role:
			"ecology": eco_count += 1
			"technology": tech_count += 1
			"civilian": civ_count += 1
		if r.get_node_or_null("CollisionShape3D") == null:
			all_have_collision = false
		if r.tool_mesh == null:
			all_have_civic_tools = false

	assert_test.call(bot_count == 9, "Session contains exactly 9 AI bot residents")
	assert_test.call(all_have_collision, "All 10 residents have 3D capsule collision shapes")
	assert_test.call(all_have_civic_tools, "All 10 residents have visible civic job tool props")
	assert_test.call(eco_count == 3, "Role assignment distributed exactly 3 Ecology Operatives")
	assert_test.call(tech_count == 3, "Role assignment distributed exactly 3 Technology Operatives")
	assert_test.call(civ_count == 4, "Role assignment distributed exactly 4 Unaffiliated Civilians")

	# Operative kits properly assigned
	var operative_kits_valid := true
	for r in residents:
		if r.secret_role == "civilian":
			if r.operative_kit != "none": operative_kits_valid = false
		else:
			if r.operative_kit == "none": operative_kits_valid = false
	assert_test.call(operative_kits_valid, "Operatives assigned operative kits; civilians assigned 'none'")

	# Phase consistency & Briefing assembly
	assert_test.call(gm.current_phase == gm.Phase.BRIEFING, "Match starts officially in Phase.BRIEFING")
	main._update_hud()
	assert_test.call(main.clock_label.text.find("PHASE 1: TOWN BRIEFING") != -1, "HUD accurately displays 'PHASE 1: TOWN BRIEFING'")
	assert_test.call(main.status_label.text.find("TOWN BRIEFING") != -1, "HUD status banner displays Town Briefing instructions")

	# Test Briefing hold: bot controller holds position during briefing
	var bot_ctrl_test: Node = main.bot_controllers[0]
	bot_ctrl_test._physics_process(0.1)
	assert_test.call(bot_ctrl_test.resident.velocity == Vector3.ZERO, "Bots hold position during Briefing (no premature chore roaming)")

	# Advance to Open Town
	gm.advance_to_next_phase()
	assert_test.call(gm.current_phase == gm.Phase.OPEN_TOWN, "Advancing phase transitions to Phase.OPEN_TOWN")
	main._update_hud()
	assert_test.call(main.clock_label.text.find("PHASE 2: OPEN TOWN") != -1, "HUD accurately updates to 'PHASE 2: OPEN TOWN'")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Full 3D Town Map & 4 Sectors Spatial Geometry
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Full 3D Town Map & 4 Sectors Spatial Geometry")
	assert_test.call(map.get_region_name_at_3d(Vector3(0.0, 0.0, 0.0)) == "Town Square", "Coordinates (0, 0, 0) resolve to Town Square")
	assert_test.call(map.get_region_name_at_3d(Vector3(-6.0, 0.0, 24.0)) == "Pump & Generator Station", "Pump Station coordinates resolve to Pump & Generator Station")
	assert_test.call(map.get_region_name_at_3d(Vector3(-20.0, 0.0, -20.0)) == "Greenhouse & Fields", "Greenhouse coordinates resolve to Greenhouse & Fields")
	assert_test.call(map.get_region_name_at_3d(Vector3(20.0, 0.0, -20.0)) == "Salvage Yard", "Salvage coordinates resolve to Salvage Yard")
	assert_test.call(map.get_region_name_at_3d(Vector3(0.0, 0.0, 60.0)) == "Town Corridors", "Out of bounds coordinates resolve to Town Corridors")

	# Broad regional alert anchors
	var pump_anchor: Vector3 = map.get_region_alert_anchor_at_3d(Vector3(-6.0, 0.0, 24.0))
	assert_test.call(pump_anchor.distance_to(Vector3(-6.0, 0.0, 24.0)) > 2.0, "Regional alert anchor is distinct from specific pad location")
	assert_test.call(pump_anchor.x == 0.0 and pump_anchor.z == 24.0, "Pump & Generator regional anchor centered at broad sector midpoint (0, 24)")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Task Pads & Escalation-Locked Landmarks
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Task Pads & Escalation-Locked Landmarks")
	assert_test.call(map.task_pads.size() == 7, "Map contains exactly 7 registered landmarks/pads")

	var pump_pad: Dictionary = {}
	var gen_pad: Dictionary = {}
	var beacon_pad: Dictionary = {}
	for pad in map.task_pads:
		if pad["id"] == "pump": pump_pad = pad
		elif pad["id"] == "generator": gen_pad = pad
		elif pad["id"] == "beacon": beacon_pad = pad

	assert_test.call(not pump_pad.is_empty() and pump_pad.get("is_locked", false) == false, "Civic Pump pad is active and unlocked in Open Town")
	assert_test.call(not gen_pad.is_empty() and gen_pad.get("is_locked", false) == true, "Overdrive Generator is marked is_locked = true during Phase 1")
	assert_test.call(String(gen_pad.get("name", "")).find("Locked until Escalation") != -1, "Overdrive Generator label visibly displays '[Locked until Escalation]'")
	assert_test.call(not beacon_pad.is_empty() and beacon_pad.get("is_locked", false) == true, "Signal Beacon is marked is_locked = true during Phase 1")
	assert_test.call(String(beacon_pad.get("name", "")).find("Locked until Escalation") != -1, "Signal Beacon label visibly displays '[Locked until Escalation]'")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Secluded Bedrock Alcoves & Archive Secrecy
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Secluded Bedrock Alcoves & Archive Secrecy")
	assert_test.call(map.secret_alcoves.size() == 4, "Map contains exactly 4 secluded bedrock alcoves")

	var active_alcove_count := 0
	var all_labels_identical := true
	var no_archive_label_leak := true

	for alc in map.secret_alcoves:
		if alc["is_active"]:
			active_alcove_count += 1
		var node: Node3D = alc["node"]
		var lbl: Label3D = null
		for child in node.get_children():
			if child is Label3D:
				lbl = child
				break
		if lbl != null:
			if lbl.text != "Secluded Bedrock Alcove\n[Inspect: V]":
				all_labels_identical = false
			if lbl.text.to_lower().find("archive") != -1:
				no_archive_label_leak = false

	assert_test.call(active_alcove_count == 1, "Exactly 1 alcove is randomly activated per match")
	assert_test.call(map.active_alcove_id == String(gm.archive_active_spawn_id), "Active alcove synchronized with GameManager.archive_active_spawn_id")
	assert_test.call(all_labels_identical, "All 4 alcoves display identical neutral inspection text ('Secluded Bedrock Alcove')")
	assert_test.call(no_archive_label_leak, "Zero visual 'Archive' labels exist on the map (Archive secrecy preserved)")

	# ------------------------------------------------------------------
	# TEST GROUP 5: 3D Waypoint Navigation Graph & Pathfinding
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] 3D Waypoint Navigation Graph & Pathfinding")
	assert_test.call(map.waypoints.size() >= 16, "Waypoint graph contains at least 16 connected nodes across all 4 sectors")

	# Path from Town Square center to Pump Pad
	var path_to_pump: Array[Vector3] = map.find_path(Vector3(0.0, 0.0, 0.0), Vector3(-6.0, 0.0, 24.0))
	assert_test.call(path_to_pump.size() >= 3, "Path from Town Square to Pump Station traverses intermediate waypoints")
	# Check that path routes through North Corridor (Z = 14) avoiding North walls
	var routes_through_corridor := false
	for pt in path_to_pump:
		if pt.z >= 12.0 and pt.z <= 16.0 and absf(pt.x) <= 2.0:
			routes_through_corridor = true
	assert_test.call(routes_through_corridor, "Path routes cleanly through North Corridor opening around static walls")

	# Path between Greenhouse and Salvage Yard (separated by South_CenterDivider wall at X = 0)
	var path_gh_to_sy: Array[Vector3] = map.find_path(Vector3(-20.0, 0.0, -20.0), Vector3(20.0, 0.0, -20.0))
	assert_test.call(path_gh_to_sy.size() >= 4, "Path between Greenhouse and Salvage Yard traverses waypoint network")
	var routes_through_plaza := false
	for pt in path_gh_to_sy:
		if pt.z >= -10.0: # Traversed up through Plaza opening rather than clipping through center wall
			routes_through_plaza = true
	assert_test.call(routes_through_plaza, "Path routes through Town Square opening avoiding South center dividing wall")

	# Bot pathing simulation
	var bot_ctrl: Node = main.bot_controllers[0]
	assert_test.call(bot_ctrl != null, "BotController3D attached to bot resident")
	bot_ctrl.state = "PAUSE"
	bot_ctrl.pause_timer = 0.0
	bot_ctrl._process_pause(0.1) # triggers _pick_next_chore_destination
	assert_test.call(bot_ctrl.state == "MOVING", "Bot selects destination and enters MOVING state")
	assert_test.call(not bot_ctrl.path_points.is_empty(), "Bot path points populated via TownMap3D pathfinding")

	# ------------------------------------------------------------------
	# TEST GROUP 6: 3D Sightlines, Anonymity & Evidence Parity Guardrails
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] 3D Sightlines, Anonymity & Evidence Parity Guardrails")

	# Open line-of-sight in Town Square
	var los_open: bool = map.has_clear_sightline_3d(Vector3(-4.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0))
	assert_test.call(los_open == true, "Clear sightline across unobstructed Town Square")

	# Obstructed line-of-sight through South Center Wall (X = 0, Z = -24)
	var los_wall: bool = map.has_clear_sightline_3d(Vector3(-8.0, 0.0, -24.0), Vector3(8.0, 0.0, -24.0))
	assert_test.call(los_wall == false, "Sightline blocked through South Central Dividing Wall")

	# Obstructed line-of-sight through North Wall East (X = 18, Z = 10)
	var los_north_wall: bool = map.has_clear_sightline_3d(Vector3(18.0, 0.0, 4.0), Vector3(18.0, 0.0, 16.0))
	assert_test.call(los_north_wall == false, "Sightline blocked through North Wall East")

	# Faction ability witness and broad regional anchor check
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 210.0 # 03:30 (valid witness interval)
	player.position = Vector3(-6.0, 0.0, 24.0) # at Pump
	var witness_bot: CharacterBody3D = residents[1]
	witness_bot.position = Vector3(-6.0, 0.0, 18.0) # 6m away in open sightline
	witness_bot.is_incapacitated = false

	var witnessed: bool = gm.record_faction_ability_3d(player, map, [player, witness_bot])
	assert_test.call(witnessed == true, "Faction ability witnessed in open sightline at Pump Station")
	var spawned_ring: Dictionary = map.last_spawned_zone
	assert_test.call(spawned_ring.has("pos"), "Disturbance ring spawned on witnessed ability")
	var ring_pos: Vector3 = spawned_ring.get("pos", Vector3.ZERO)
	assert_test.call(ring_pos.distance_to(player.position) > 2.0, "Disturbance ring NOT centered on caster position (anonymity preserved)")
	assert_test.call(ring_pos.is_equal_approx(map.get_region_alert_anchor_at_3d(player.position)), "Disturbance ring placed at broad regional anchor (0, 24)")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL FULL 3D PHASE 1 CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.free()
	quit(0 if stats["failed"] == 0 else 1)
