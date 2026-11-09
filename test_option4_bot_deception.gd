extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 4: Advanced Bot Deception & Undercover AI Verification
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")
const BotControllerClass = preload("res://scripts/ResidentBotController3D.gd")

func _init() -> void:
	print("\n==================================================================")
	print("--- STARTING OPTION 4: ADVANCED BOT DECEPTION & UNDERCOVER AI ---")
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
	var residents: Array = main.residents
	var player: CharacterBody3D = main.player_node

	# Separate civilians and operatives
	var civilian_bot: CharacterBody3D = null
	var operative_bot: CharacterBody3D = null

	for res in residents:
		if res == player:
			continue
		if res.secret_role == "civilian" and civilian_bot == null:
			civilian_bot = res
		elif (res.secret_role == "ecology" or res.secret_role == "technology") and operative_bot == null:
			operative_bot = res

	var civ_bc: Node = civilian_bot.bot_controller
	var op_bc: Node = operative_bot.bot_controller

	# ------------------------------------------------------------------
	# TEST GROUP 1: Operative Classification & Undercover Initialization
	# ------------------------------------------------------------------
	print("[TEST GROUP 1] Operative Classification & Undercover Initialization")
	civ_bc._physics_process(0.016)
	op_bc._physics_process(0.016)

	assert_test.call(civ_bc != null and civ_bc is BotControllerClass, "Civilian bot has valid BotController3D")
	assert_test.call(op_bc != null and op_bc is BotControllerClass, "Operative bot has valid BotController3D")
	assert_test.call(civ_bc.is_undercover_operative == false, "Civilian bot is NOT flagged as undercover operative")
	assert_test.call(op_bc.is_undercover_operative == true, "Operative bot IS flagged as undercover operative")
	assert_test.call(op_bc.covert_mission_type == "NONE", "Operative initial covert mission is 'NONE'")
	assert_test.call(op_bc.alcoves_checked.is_empty(), "Operative starts with 0 alcoves checked")
	assert_test.call(op_bc.undercover_cooldown >= 0.0, "Operative has positive undercover cooldown")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Observation & Line-of-Sight Sensing
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Observation & Line-of-Sight Sensing")
	# Position all other residents far in the Greenhouse corner so only civilian_bot is within range
	for r in residents:
		if r != operative_bot and r != civilian_bot:
			r.position = Vector3(-35.0, 0.0, -35.0)

	# Place operative and observer in Town Square with clear sightline
	operative_bot.position = Vector3(0.0, 0.0, 0.0)
	civilian_bot.position = Vector3(0.0, 0.0, 5.0)

	var is_seen: bool = op_bc.is_observed_by_others(operative_bot.secret_role)
	assert_test.call(is_seen == true, "Operative detects civilian observer in line-of-sight")

	# Move civilian behind static dividing wall in Salvage Yard
	civilian_bot.position = Vector3(28.0, 0.0, -14.0)
	var is_hidden: bool = not op_bc.is_observed_by_others(operative_bot.secret_role)
	assert_test.call(is_hidden == true, "Operative detects privacy when witnesses are behind static walls")

	# Operative postpones covert action when observed
	civilian_bot.position = Vector3(0.0, 0.0, 5.0) # bring back into view
	op_bc.undercover_cooldown = 0.0
	var started_when_seen: bool = op_bc._try_start_covert_mission()
	assert_test.call(started_when_seen == false, "Operative refuses to start covert mission while observed")
	assert_test.call(op_bc.undercover_cooldown > 0.0, "Undercover cooldown reset/postponed after being watched")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Stealth Bedrock Alcove Routing & Pathfinding
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Stealth Bedrock Alcove Routing & Pathfinding")
	# Hide civilian behind wall so operative is unobserved
	civilian_bot.position = Vector3(28.0, 0.0, -14.0)
	player.position = Vector3(-20.0, 0.0, -20.0) # Player in Greenhouse
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.archive_opened = false

	op_bc.undercover_cooldown = 0.0
	op_bc.state = "PAUSE"
	op_bc.pause_timer = 0.0
	var stealth_started: bool = op_bc._try_start_covert_mission()
	assert_test.call(stealth_started == true, "Operative successfully initiates stealth mission when unobserved")
	assert_test.call(op_bc.covert_mission_type == "ALCOVE", "Covert mission type set to 'ALCOVE'")
	assert_test.call(not op_bc.covert_target_alcove.is_empty(), "Operative targeted a valid bedrock alcove")
	assert_test.call(op_bc.path_points.size() > 0, "Navigation graph generated valid path to the alcove")
	assert_test.call(op_bc.state == "MOVING", "Bot state transitioned to 'MOVING'")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Covert Alcove Inspection & Archive Key Discovery
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Covert Alcove Inspection & Archive Key Discovery")
	# Force operative to reach the alcove destination
	var target_alc: Dictionary = op_bc.covert_target_alcove
	operative_bot.position = target_alc["pos"]
	op_bc.path_points.clear()
	op_bc._reach_destination()

	assert_test.call(op_bc.state == "COVERT_WORKING", "Bot state transitioned to 'COVERT_WORKING' at alcove")
	assert_test.call(op_bc.covert_action_timer > 0.0, "Covert action timer initialized (> 0.0s)")

	# Set this alcove as the active Archive key cache
	map.active_alcove_id = String(target_alc["id"])
	gm.archive_active_spawn_id = String(target_alc["id"])
	for alc in map.secret_alcoves:
		alc["is_active"] = (alc["id"] == target_alc["id"])

	# Simulate completion of covert alcove inspection
	op_bc.covert_action_timer = 0.0
	op_bc._process_covert_working(0.016)

	assert_test.call(op_bc.alcoves_checked.has(String(target_alc["id"])), "Alcove recorded in checked alcoves list")
	assert_test.call(op_bc.covert_alcoves_inspected >= 1, "Operative alcoves inspected counter incremented")
	assert_test.call(gm.archive_opened == true, "Archive unsealed by operative bot discovering key")
	assert_test.call(gm.archive_finder_name == operative_bot.resident_name, "GameManager records operative bot as archive finder")
	assert_test.call(gm.archive_choice != C.ARCHIVE_CHOICE_NONE, "Operative bot autonomously enacted a faction strategic choice")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Covert Station Sabotage & Physical Trace Generation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Covert Station Sabotage & Physical Trace Generation")
	# Reset bot to perform sabotage mission
	op_bc.state = "PAUSE"
	op_bc.undercover_cooldown = 0.0
	var pump_pad: Dictionary = map.get_pad_by_id("pump")
	pump_pad["cooldown"] = 0.0
	var initial_water: float = gm.water

	# Directly trigger sabotage mission
	op_bc.covert_mission_type = "SABOTAGE"
	op_bc.covert_target_pad = pump_pad
	operative_bot.position = pump_pad["position"]
	op_bc._start_covert_sabotage()

	assert_test.call(op_bc.state == "COVERT_WORKING", "Bot transitioned to 'COVERT_WORKING' for sabotage")
	assert_test.call(operative_bot.action_label.text.find("Tampering") != -1, "Action label reflects tampering conduits")

	# Finish sabotage
	op_bc.covert_action_timer = 0.0
	op_bc._process_covert_working(0.016)

	assert_test.call(op_bc.covert_sabotages_performed >= 1, "Operative sabotages performed counter incremented")
	assert_test.call(float(pump_pad["cooldown"]) >= 10.0, "Sabotaged station jammed with cooldown (>= 10.0s)")
	assert_test.call(gm.water < initial_water, "Pump Station sabotage drained town Water reserves")

	# Verify physical trace was dropped in sector journal
	var op_journal: Dictionary = gm.get_player_journal(operative_bot.resident_id)
	var traces: Array = op_journal.get("traces", [])
	var trace_found := false
	for tr in traces:
		if tr.get("text", "").find("Tampered conduit") != -1:
			trace_found = true
			break
	assert_test.call(trace_found == true, "Physical trace [VERIFIED TRACE] generated from covert sabotage")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Adverse Witness Detection & Covert Mission Abort
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Adverse Witness Detection & Covert Mission Abort")
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 210.0

	op_bc.covert_mission_type = "SABOTAGE"
	op_bc.covert_target_pad = pump_pad
	operative_bot.position = pump_pad["position"]
	op_bc.state = "COVERT_WORKING"
	op_bc.covert_action_timer = 2.0

	# Civilian walks in with clear line-of-sight
	civilian_bot.position = operative_bot.position + Vector3(0.0, 0.0, 4.0)

	var witness_journal_count: int = gm.get_player_journal(civilian_bot.resident_id).get("observed", []).size()
	op_bc._process_covert_working(0.016)

	assert_test.call(op_bc.covert_mission_type == "NONE", "Operative immediately aborted covert mission upon being spotted")
	assert_test.call(op_bc.state == "PAUSE", "Operative retreated to 'PAUSE' state")
	assert_test.call(op_bc.undercover_cooldown > 10.0, "Undercover cooldown reset after abort")

	var updated_witness_journal: Array = gm.get_player_journal(civilian_bot.resident_id).get("observed", [])
	assert_test.call(updated_witness_journal.size() > witness_journal_count, "Witness resident recorded an observed sighting [EVIDENCE_FACT]")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Periodic Sightings & Deceptive Alibi Contradiction
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Periodic Sightings & Deceptive Alibi Contradiction")
	# Force match time to alibi interval (04:00 - 03:00)
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 210.0 # 03:30 on clock

	# Place operative in Salvage Yard
	operative_bot.position = Vector3(20.0, 0.0, -20.0) # Salvage Yard
	civilian_bot.position = Vector3(16.0, 0.0, -20.0) # Civilian witness nearby in Salvage Yard

	# Trigger periodic sighting update
	main.sighting_sample_timer = 3.0
	main._update_open_town_sightings(0.1)

	# Verify civilian has an observation sighting placing operative in Salvage Yard
	var civ_j: Dictionary = gm.get_player_journal(civilian_bot.resident_id)
	var saw_in_salvage := false
	for entry in civ_j.get("observed", []):
		if entry.get("subject", "") == operative_bot.resident_name and entry.get("region", "") == "Salvage Yard":
			saw_in_salvage = true
			break
	assert_test.call(saw_in_salvage == true, "Civilian recorded sighting placing operative in Salvage Yard during 04:00-03:00")

	# Assign operative a civic cover job of Pump Technician (whose home is Pump & Generator Station)
	operative_bot.civic_job = "Pump Technician"

	# Prepare First Council to generate statements and detect contradictions
	gm.prepare_first_council(residents, map)

	var op_statement: Dictionary = gm.alibi_statements.get(int(operative_bot.resident_id), {})
	assert_test.call(op_statement.get("region", "") == "Pump & Generator Station", "Operative bot falsely claimed home civic sector (Pump & Generator Station)")

	# Sighting in Salvage Yard vs claim of Pump Station creates an Alibi Contradiction
	var found_conflict := false
	for cf in gm.alibi_conflicts:
		if cf.get("resident", "") == operative_bot.resident_name:
			found_conflict = true
			break
	assert_test.call(found_conflict == true, "Alibi contradiction successfully detected and logged in GameManager.alibi_conflicts")

	# ------------------------------------------------------------------
	# TEST GROUP 8: Court Testimony Dialogue Adaptation for Accused Operatives
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 8] Court Testimony Dialogue Adaptation")
	gm.current_phase = gm.Phase.COURT
	gm.court_ceremony_active = true
	gm.court_civilians.clear()
	gm.court_civilians.append(operative_bot)
	gm.court_voter_index = 0
	main.active_podium_speaker = operative_bot

	operative_bot.position = Vector3(0.0, 0.25, 0.8)
	main._update_court_ceremony(0.1)

	# If the speaker has an alibi conflict, verify speech is defensive
	var court_label_text: String = main.court_speech_label.text
	var accused_defense: bool = (court_label_text.find("fabricating evidence") != -1 or court_label_text.find("error") != -1 or court_label_text.find("assigned post") != -1)
	assert_test.call(accused_defense == true, "Operative delivers flustered defensive testimony when accused of alibi contradiction")

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 4 BOT DECEPTION & UNDERCOVER AI CHECKS PASSED! <<<")
	else:
		print(">>> SOME OPTION 4 CHECKS FAILED! <<<")

	main.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
