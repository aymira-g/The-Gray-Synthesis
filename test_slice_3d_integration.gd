extends SceneTree

const SceneClass = preload("res://scenes/Slice3D_Integration.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING INTEGRATED 3D GAMEPLAY SLICE VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	var slice: Node3D = SceneClass.instantiate()
	root.add_child(slice)
	slice._ready()

	var gm: Node = slice.game_manager
	var player: CharacterBody3D = slice.player_node
	var bot: CharacterBody3D = slice.bot_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: Player 3D Movement & Collision
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Player 3D Movement & Collision")
	assert_test.call(player is CharacterBody3D, "Player extends CharacterBody3D")
	assert_test.call(player.get_node_or_null("CollisionShape3D") != null, "Player has 3D collision shape")
	assert_test.call(slice.get_node_or_null("ObstacleWall") != null, "Static ObstacleWall exists in 3D environment")

	# Test stamina mechanics
	player.stamina = 100.0
	assert_test.call(player.stamina == 100.0, "Player starts with full 100 stamina")

	# Test static obstacle collision boundary
	var wall_box: AABB = slice.obstacle_aabbs[0]
	assert_test.call(wall_box.has_point(Vector3(0.0, 1.5, 5.0)), "ObstacleWall AABB occupies expected spatial volume at X = 0")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Real Task Execution & Live Match State Mutation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Real Task Execution & Resource Mutation (API Parity)")

	# 2a: Channelling Pump with 1 Scrap -> +8 Water, -1 Scrap
	gm.water = 50.0
	gm.scrap = 3
	var res_pump: String = String(slice.execute_pad_channel("pump", "Player", true))
	assert_test.call(gm.water == 58.0, "Executing 'pump' task with scrap adds +8 Water (50 -> 58)")
	assert_test.call(gm.scrap == 2, "Executing 'pump' task consumes 1 Scrap (3 -> 2)")
	assert_test.call(res_pump.find("+8 Water") != -1, "Task summary confirms '+8 Water, -1 Scrap'")

	# 2b: Channelling Pump with 0 Scrap -> +4 Water, 0 Scrap
	gm.scrap = 0
	slice.execute_pad_channel("pump", "Player", true)
	assert_test.call(gm.water == 62.0, "Executing 'pump' task with 0 scrap patches pump for +4 Water (58 -> 62)")
	assert_test.call(gm.scrap == 0, "Executing 'pump' task with 0 scrap does not drop scrap below 0")

	# 2c: Channelling Greenhouse -> +7 Stability
	gm.stability = 50.0
	var res_gh: String = String(slice.execute_pad_channel("greenhouse", "Player", true))
	assert_test.call(gm.stability == 57.0, "Executing 'greenhouse' task adds +7 Stability (50 -> 57)")
	assert_test.call(res_gh.find("+7 Town Stability") != -1, "Task summary confirms '+7 Town Stability'")

	# 2d: Channelling Salvage -> +2 Scrap
	gm.scrap = 1
	var res_salvage: String = String(slice.execute_pad_channel("salvage", "Player", true))
	assert_test.call(gm.scrap == 3, "Executing 'salvage' task adds +2 Scrap (1 -> 3)")
	assert_test.call(res_salvage.find("+2 Scrap") != -1, "Task summary confirms '+2 Scrap'")

	# ------------------------------------------------------------------
	# TEST GROUP 3: 3D Bot Navigation & Autonomous Task Work
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] 3D Bot Navigation & Autonomous Task Execution")
	assert_test.call(bot is CharacterBody3D, "Bot extends CharacterBody3D")
	assert_test.call(bot.waypoints.size() == 3, "Bot has 3D waypoints routing around obstacle wall")

	# Position bot at Waypoint 2 (Greenhouse Pad) and process channeling
	bot.position = Vector3(8.0, 0.0, 10.0)
	bot.current_wp_idx = 2
	bot.patrol_forward = true
	bot._start_task_channel()
	assert_test.call(bot.is_channeling == true, "Bot enters channeling state on arrival at Greenhouse pad")

	# Advance channel timer by 2.0s
	var stab_before: float = gm.stability
	bot._process_channeling(2.1)
	assert_test.call(bot.is_channeling == false, "Bot finishes channeling after duration expires")
	assert_test.call(bot.tasks_completed_count == 1, "Bot task completion count incremented")
	assert_test.call(gm.stability == (stab_before + 7.0), "Bot autonomous channel mutated live GameManager stability (+7)")

	# ------------------------------------------------------------------
	# TEST GROUP 4: 3D Physics Sightline & Strict Evidence Parity Matrix
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] 3D Physics Sightline & Strict Evidence Parity Matrix")

	# Setup GameManager in Open Town during valid 04:00-03:00 interval
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 210.0 # 03:30 (strictly valid!)
	gm.evidence_journals.clear()
	gm.witnessed_disturbances = 0

	# Case 4a: Open Sightline (Both in front of ObstacleWall at Z = -4.0)
	player.position = Vector3(-6.0, 0.0, -4.0)
	bot.position = Vector3(6.0, 0.0, -4.0)
	bot.is_incapacitated = false

	var los_open: bool = slice.has_clear_sightline_3d(player.position, bot.position)
	assert_test.call(los_open == true, "3D raycast confirms OPEN sightline when unobscured by wall")

	# Player triggers faction ability in open sightline
	var witnessed_open: bool = gm.record_faction_ability_3d(player, slice, [player, bot])
	assert_test.call(witnessed_open == true, "record_faction_ability_3d() returns witnessed = true in open sightline")
	assert_test.call(gm.witnessed_disturbances == 1, "witnessed_disturbances incremented to 1")

	# Verify private journal entry in observer's journal (resident_id = 2)
	var bot_journal: Dictionary = gm.get_player_journal(2)
	var observed_facts: Array = bot_journal.get("observed", [])
	assert_test.call(observed_facts.size() >= 1, "Observed fact recorded in witness's private journal")
	assert_test.call(observed_facts[0]["text"].find("used a special ability near") != -1, "Recorded clue text matches sighting format")
	assert_test.call(gm.get_player_journal(1).get("observed", []).is_empty(), "Caster player received no private witness clues")

	# Verify broad regional anchor for 3D disturbance ring (preserves caster anonymity)
	var spawned_zone: Dictionary = slice.last_spawned_zone
	assert_test.call(spawned_zone.has("pos"), "3D disturbance ring was spawned upon witnessed ability")
	var zone_pos: Vector3 = spawned_zone.get("pos", Vector3.ZERO)
	assert_test.call(zone_pos.distance_to(player.position) > 2.0, "3D disturbance ring is NOT centered on caster's exact position (anonymity preserved)")
	var expected_anchor: Vector3 = slice.get_region_alert_anchor_at_3d(player.position)
	assert_test.call(zone_pos.is_equal_approx(expected_anchor), "3D disturbance ring is placed at broad regional anchor")

	# Guardrail check: map lacking get_region_alert_anchor_at_3d must NEVER fall back to caster_pos
	var dummy_map := DummyMapNoAnchor.new()
	gm.record_faction_ability_3d(player, dummy_map, [player, bot])
	assert_test.call(dummy_map.spawned_pos == null, "Map lacking get_region_alert_anchor_at_3d() omits ring (never leaks caster position)")
	dummy_map.free()

	# Case 4b: Wall-Blocked Sightline (Separated by ObstacleWall at X = 0, Z = 6.0)
	player.position = Vector3(-5.0, 0.0, 6.0)
	bot.position = Vector3(5.0, 0.0, 6.0)
	gm.evidence_journals.clear()
	var dist_before: int = gm.witnessed_disturbances

	var los_blocked: bool = slice.has_clear_sightline_3d(player.position, bot.position)
	assert_test.call(los_blocked == false, "3D raycast confirms BLOCKED sightline when obstructed by 3D ObstacleWall")

	var witnessed_blocked: bool = gm.record_faction_ability_3d(player, slice, [player, bot])
	assert_test.call(witnessed_blocked == false, "record_faction_ability_3d() returns witnessed = false behind wall")
	assert_test.call(gm.witnessed_disturbances == dist_before, "No disturbance triggered when obstructed by wall")
	var bot_journal_blocked: Dictionary = gm.get_player_journal(2)
	assert_test.call(bot_journal_blocked.get("observed", []).is_empty(), "Zero clues recorded in witness journal when line-of-sight is blocked")

	# Case 4c: Out of Range Check (> C.WITNESS_RADIUS)
	gm.evidence_journals.clear()
	player.position = Vector3(0.0, 0.0, -10.0)
	bot.position = Vector3(0.0, 0.0, 100.0) # 110m away (> 270px/m radius)
	gm.record_observed_sighting_3d(player, player.position, slice, [player, bot], "was spotted")
	assert_test.call(gm.get_player_journal(2).get("observed", []).is_empty(), "Zero clues recorded when observer is beyond WITNESS_RADIUS")

	# Case 4d: Incapacitated Observer Check
	gm.evidence_journals.clear()
	player.position = Vector3(-4.0, 0.0, -4.0)
	bot.position = Vector3(4.0, 0.0, -4.0)
	bot.is_incapacitated = true
	gm.record_observed_sighting_3d(player, player.position, slice, [player, bot], "was spotted")
	assert_test.call(gm.get_player_journal(2).get("observed", []).is_empty(), "Incapacitated observer records zero clues")
	bot.is_incapacitated = false

	# Case 4e: Open Town Time Window Restriction Check
	gm.evidence_journals.clear()
	gm.time_remaining = 310.0 # 05:10 (outside the 04:00-03:00 interval!)
	gm.record_observed_sighting_3d(player, player.position, slice, [player, bot], "was spotted")
	assert_test.call(gm.get_player_journal(2).get("observed", []).is_empty(), "Sighting outside 04:00-03:00 interval in Open Town records zero clues")

	# Case 4f: Escalation Phase Sightline Check (Valid across the phase)
	gm.evidence_journals.clear()
	gm.current_phase = gm.Phase.ESCALATION
	gm.time_remaining = 120.0
	gm.record_observed_sighting_3d(player, player.position, slice, [player, bot], "patrolled near")
	assert_test.call(gm.get_player_journal(2).get("observed", []).size() == 1, "Sighting during Escalation phase successfully recorded")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL INTEGRATED 3D GAMEPLAY SLICE CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)

class DummyMapNoAnchor extends Node:
	var spawned_pos = null
	func has_clear_sightline_3d(_a: Vector3, _b: Vector3) -> bool:
		return true
	func get_region_name_at_3d(_p: Vector3) -> String:
		return "Outskirts"
	func spawn_field_zone_3d(_type: String, pos: Vector3, _radius: float, _duration: float, _team: int, _region: String) -> void:
		spawned_pos = pos
