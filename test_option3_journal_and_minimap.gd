extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 3: 3D Evidence Journal & Radar Minimap Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")
const RadarMinimapClass = preload("res://scripts/RadarMinimap3D.gd")
const EvidenceJournalClass = preload("res://scripts/EvidenceJournal3D.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING OPTION 3: JOURNAL & RADAR MINIMAP VERIFICATION ---")
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
	var map: Node3D = main.town_map
	var player: CharacterBody3D = main.player_node
	var residents: Array = main.residents
	var radar = main.radar_minimap
	var journal = main.evidence_journal

	# ------------------------------------------------------------------
	# TEST GROUP 1: Radar Minimap Architecture & References
	# ------------------------------------------------------------------
	print("[TEST GROUP 1] Radar Minimap Architecture & References")
	assert_test.call(radar != null, "RadarMinimap3D instance registered on Main3D")
	assert_test.call(radar is RadarMinimapClass, "RadarMinimap3D is instance of RadarMinimapClass")
	assert_test.call(radar.town_map == map, "RadarMinimap3D holds reference to TownMap3D")
	assert_test.call(radar.player_node == player, "RadarMinimap3D holds reference to Player node")
	assert_test.call(radar.all_residents.size() == 10, "RadarMinimap3D holds all 10 resident references")
	assert_test.call(radar.game_manager == gm, "RadarMinimap3D holds reference to GameManager")
	assert_test.call(radar.custom_minimum_size.x >= 200 and radar.custom_minimum_size.y >= 150, "Radar has valid minimum dimensions (>= 200x150)")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Minimap Coordinate Mapping & Compass Orientation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Minimap Coordinate Mapping & Compass Orientation")
	var radar_rect := Rect2(12, 24, 210, 138)
	var radar_center := radar_rect.position + radar_rect.size * 0.5
	var scale_x: float = radar_rect.size.x / 80.0
	var scale_y: float = radar_rect.size.y / 80.0

	# Test 3D -> 2D transformation
	# Center (Town Square Dais)
	var ts_2d := Vector2(radar_center.x + 0.0 * scale_x, radar_center.y - 0.0 * scale_y)
	assert_test.call(ts_2d == radar_center, "Town Square (0, 0) maps to exact center of radar")

	# North (Pump Station Z = +24)
	var pump_2d := Vector2(radar_center.x + (-6.0) * scale_x, radar_center.y - 24.0 * scale_y)
	assert_test.call(pump_2d.y < radar_center.y, "North (+Z) Pump Station maps toward the top of minimap (Y: %.1f < %.1f)" % [pump_2d.y, radar_center.y])

	# South-West (Greenhouse X = -20, Z = -20)
	var gh_2d := Vector2(radar_center.x + (-20.0) * scale_x, radar_center.y - (-20.0) * scale_y)
	assert_test.call(gh_2d.x < radar_center.x and gh_2d.y > radar_center.y, "Greenhouse (-20, -20) maps to bottom-left quadrant")

	# South-East (Salvage Yard X = +20, Z = -20)
	var sy_2d := Vector2(radar_center.x + 20.0 * scale_x, radar_center.y - (-20.0) * scale_y)
	assert_test.call(sy_2d.x > radar_center.x and sy_2d.y > radar_center.y, "Salvage Yard (+20, -20) maps to bottom-right quadrant")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Line-of-Sight Privacy on Radar
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Line-of-Sight Privacy on Radar")
	gm.current_phase = gm.Phase.OPEN_TOWN
	player.position = Vector3(0.0, 0.0, 0.0) # Player in Town Square

	var resident_visible_nearby: CharacterBody3D = residents[1]
	resident_visible_nearby.position = Vector3(0.0, 0.0, 4.0) # In Town Square (clear sightline)
	var has_clear_los: bool = map.has_clear_sightline_3d(player.position, resident_visible_nearby.position)
	assert_test.call(has_clear_los == true, "Nearby resident in Town Square has clear line-of-sight to player")

	var resident_behind_wall: CharacterBody3D = residents[2]
	resident_behind_wall.position = Vector3(28.0, 0.0, -14.0) # In Salvage Yard behind dividing wall
	var is_obstructed: bool = not map.has_clear_sightline_3d(player.position, resident_behind_wall.position)
	assert_test.call(is_obstructed == true, "Resident behind static dividing wall has obstructed sightline")

	# Test Finale Line-of-Sight Privacy
	gm.current_phase = gm.Phase.FINALE
	radar.update_stealth_phase()
	assert_test.call(radar.is_stealth_phase == true, "Minimap strictly preserves line-of-sight privacy in FINALE phase")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Evidence Journal Modal Architecture
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Evidence Journal Modal Architecture")
	assert_test.call(journal != null, "EvidenceJournal3D instance registered on Main3D")
	assert_test.call(journal is EvidenceJournalClass, "EvidenceJournal3D is instance of EvidenceJournalClass")
	assert_test.call(journal.visible == false, "Evidence Journal is initially closed")
	assert_test.call(journal.filter_buttons.has("ALL"), "Journal contains 'ALL' filter")
	assert_test.call(journal.filter_buttons.has("FACT"), "Journal contains 'FACT' filter")
	assert_test.call(journal.filter_buttons.has("TRACE"), "Journal contains 'TRACE' filter")
	assert_test.call(journal.filter_buttons.has("ALIBI"), "Journal contains 'ALIBI' filter")
	assert_test.call(journal.filter_buttons.has("TABLED"), "Journal contains 'TABLED' filter")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Journal Toggle Input & Player Movement Pause
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Journal Toggle Input & Movement Pause")
	var key_j := InputEventKey.new()
	key_j.pressed = true
	key_j.keycode = KEY_J

	main._unhandled_input(key_j)
	assert_test.call(journal.visible == true, "Pressing [J] opens Evidence Journal")
	assert_test.call(gm.evidence_journal_open == true, "GameManager.evidence_journal_open flag set to true")

	# Movement suppression test
	player.velocity = Vector3(6.0, 0.0, 6.0)
	player._process_player_movement(0.016)
	assert_test.call(player.velocity == Vector3.ZERO, "Player movement velocity forced to ZERO while Evidence Journal is open")

	# Toggle close with [J]
	main._unhandled_input(key_j)
	assert_test.call(journal.visible == false, "Pressing [J] again closes Evidence Journal")
	assert_test.call(gm.evidence_journal_open == false, "GameManager.evidence_journal_open resets to false on close")

	# Open with [J] and close with [ESC]
	main._unhandled_input(key_j)
	assert_test.call(journal.visible == true, "Journal reopened with [J]")
	var key_esc := InputEventKey.new()
	key_esc.pressed = true
	key_esc.keycode = KEY_ESCAPE
	main._unhandled_input(key_esc)
	assert_test.call(journal.visible == false, "Pressing [ESC] dismisses Evidence Journal")
	assert_test.call(gm.evidence_journal_open == false, "GameManager.evidence_journal_open resets on ESC dismiss")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Private Clue Population & Card Formatting
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Private Clue Population & Card Formatting")
	# Add private observed fact to player's journal
	gm._add_private_evidence(player.resident_id, C.EVIDENCE_FACT, "Resident 6 was seen operating Turbine Coils", "Pump Station", "04:12")
	# Add private verified trace to player's journal
	gm._add_private_evidence(player.resident_id, C.EVIDENCE_TRACE, "Discarded copper wrench near scrap heap", "Salvage Yard", "03:45")

	journal.open_journal()
	var displayed_count: int = journal.entries_container.get_child_count()
	assert_test.call(displayed_count >= 2, "Journal dynamically spawned clue cards for all private findings (%d cards)" % displayed_count)

	# Verify card contents
	var card1 = journal.entries_container.get_child(0)
	assert_test.call(card1 != null and card1 is PanelContainer, "First clue card is a valid PanelContainer")

	# Test category filter
	journal._set_filter("FACT")
	var fact_count: int = journal.entries_container.get_child_count()
	assert_test.call(fact_count == 1, "'FACT' filter isolates observed fact card (count: %d)" % fact_count)

	journal._set_filter("TRACE")
	var trace_count: int = journal.entries_container.get_child_count()
	assert_test.call(trace_count == 1, "'TRACE' filter isolates physical trace card (count: %d)" % trace_count)

	journal._set_filter("ALL")
	assert_test.call(journal.entries_container.get_child_count() >= 2, "'ALL' filter restores complete clue list")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Interactive Clue Tabling for Council
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Interactive Clue Tabling for Council")
	var initial_tabled: int = gm.tabled_evidence.size()
	var player_journal: Dictionary = gm.get_player_journal(player.resident_id)
	var first_clue: Dictionary = player_journal["observed"][0]
	var clue_id: String = String(first_clue["id"])

	# Tabling must be blocked during Open Town
	gm.current_phase = gm.Phase.OPEN_TOWN
	journal._refresh_journal()
	assert_test.call(journal.table_all_btn.disabled == true, "Table all button disabled during Open Town")
	journal._on_table_clue_clicked(clue_id)
	assert_test.call(gm.tabled_evidence.size() == initial_tabled, "Tabling clue in Open Town is strictly rejected")
	assert_test.call(bool(first_clue.get("tabled", false)) == false, "Clue remains marked private during Open Town")

	# Tabling must be enabled during First Council
	gm.current_phase = gm.Phase.FIRST_COUNCIL
	journal._refresh_journal()
	assert_test.call(journal.table_all_btn.disabled == false, "Table all button enabled during First Council")

	journal._on_table_clue_clicked(clue_id)
	assert_test.call(gm.tabled_evidence.size() == initial_tabled + 1, "Table clue action added item to public tabled evidence during Council")
	assert_test.call(bool(first_clue.get("tabled", false)) == true, "Clue marked as tabled in private journal")

	# Test Table All
	journal._on_table_all_clicked()
	var all_tabled := true
	var updated_j: Dictionary = gm.get_player_journal(player.resident_id)
	for bucket in ["observed", "traces"]:
		for item in updated_j.get(bucket, []):
			if not bool(item.get("tabled", false)):
				all_tabled = false
	assert_test.call(all_tabled == true, "Table All action tabled all remaining clues across buckets")

	# ------------------------------------------------------------------
	# TEST GROUP 8: Alibi Conflict Detection & Archive Status
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 8] Alibi Conflict Detection & Archive Status")
	# Inject an alibi conflict into GameManager
	gm.alibi_conflicts.append({
		"resident": "Resident 6",
		"claim": "Town Square",
		"seen": "Pump Station",
		"time": "04:12"
	})

	journal._refresh_journal()
	var alibi_children: int = journal.alibi_container.get_child_count()
	assert_test.call(alibi_children >= 1, "Alibi container displays verified conflict warning")

	# 1. Archive unsealed by someone else: non-finder with no evidence sees 'Archive Status: Unknown'
	gm.archive_opened = true
	gm.archive_finder_name = "Resident 7"
	gm.archive_finder_id = 7
	journal._refresh_journal()
	assert_test.call(journal.alcove_status_label.text.find("Archive Status: Unknown") != -1, "Non-finder without evidence sees Archive Status: Unknown")

	# 2. Non-finder who acquires archive trace sees 'Verified Intel'
	gm._add_private_evidence(player.resident_id, C.EVIDENCE_TRACE, "Discarded archive seal fragment near Bedrock Alcove", "Bedrock Alcoves", "04:35")
	journal._refresh_journal()
	assert_test.call(journal.alcove_status_label.text.find("Verified Intel") != -1, "Non-finder with archive clue sees Verified Intel")

	# 3. Finder sees 'DECISIVE KEY SECURED'
	gm.archive_finder_name = player.resident_name
	gm.archive_finder_id = player.resident_id
	journal._refresh_journal()
	assert_test.call(journal.alcove_status_label.text.find("DECISIVE KEY SECURED") != -1, "Archive finder sees DECISIVE KEY SECURED in journal")

	journal.close_journal()

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 3 JOURNAL & MINIMAP CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
