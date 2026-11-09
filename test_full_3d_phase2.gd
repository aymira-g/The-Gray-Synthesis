extends SceneTree

# ==============================================================================
# The Gray Synthesis - Full 3D Phase 2 Automated Verification Suite
# ==============================================================================
# Verifies:
# 1. 3D Task Channeling & Live GameManager Resource Mutation (Pump, Greenhouse, Salvage, CW)
# 2. Bot Autonomous Channeling & Chore Loop in 3D
# 3. Secluded Bedrock Alcoves Inspection & Archive Secrecy (Key extraction vs Weathered trace)
# 4. Civic Shove, Stamina Damage, Channel Interrupt & Non-Lethal Clinic Recovery
# 5. All 5 Civic Kits in 3D (Pump Technician, Crop Tender, Salvage, Medic, Watch)
# 6. All 6 Operative Faction Kits in 3D (Tracker, Grower, Warden, Runner, Mechanic, Saboteur)
# 7. Escalation Unlocks: Overdrive Generator & Signal Beacon Tuning & +35% Sightline Buffs
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING FULL 3D PHASE 2 VERIFICATION SUITE ---")
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

	# Advance past Briefing into Open Town
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 240.0 # 04:00

	# ------------------------------------------------------------------
	# TEST GROUP 1: 3D Task Channeling & Live Resource Mutation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] 3D Task Channeling & Live Resource Mutation")
	gm.water = 50.0
	gm.stability = 50.0
	gm.scrap = 3

	# Test 1.1: Pump Pad Channeling (+8 Water, -1 Scrap)
	player.position = Vector3(-6.0, 0.05, 24.0) # at Pump pad
	var started_pump: bool = player.try_start_channel()
	assert_test.call(started_pump == true, "Player successfully starts channeling Pump Station pad")
	assert_test.call(player.is_channeling == true, "Player enters is_channeling state")
	assert_test.call(player.active_pad.get("id") == "pump", "Player active_pad set to 'pump'")

	# Simulate 2.1s of channeling (Pump requires 2.0s)
	player._physics_process(2.1)
	assert_test.call(player.is_channeling == false, "Player finishes channeling after duration expires")
	assert_test.call(gm.water == 58.0, "Live GameManager water increased by +8 (50 -> 58)")
	assert_test.call(gm.scrap == 2, "Live GameManager scrap consumed by 1 (3 -> 2)")

	# Test 1.2: Greenhouse Pad Channeling (+7 Stability)
	player.position = Vector3(-20.0, 0.05, -20.0) # at Greenhouse pad
	var started_gh: bool = player.try_start_channel()
	assert_test.call(started_gh == true, "Player starts channeling Greenhouse Crop Bed")
	player._physics_process(2.1)
	assert_test.call(player.is_channeling == false, "Player completes Crop Bed channel")
	assert_test.call(gm.stability == 57.0, "Live GameManager stability increased by +7 (50 -> 57)")

	# Test 1.3: Salvage Yard Pad Channeling (+2 Scrap)
	player.position = Vector3(20.0, 0.05, -20.0) # at Salvage pad
	var started_sy: bool = player.try_start_channel()
	assert_test.call(started_sy == true, "Player starts channeling Salvage Scrap Heap")
	player._physics_process(2.1)
	assert_test.call(player.is_channeling == false, "Player completes Salvage channel")
	assert_test.call(gm.scrap == 4, "Live GameManager scrap increased by +2 (2 -> 4)")

	# Test 1.4: Common Works Foundation Channeling (+Progress, -1 Scrap)
	player.position = Vector3(-12.0, 0.05, 0.0) # at Common Works pad
	var started_cw: bool = player.try_start_channel()
	assert_test.call(started_cw == true, "Player starts channeling Common Works Foundation")
	player._physics_process(3.1) # Common works takes 3.0s
	assert_test.call(player.is_channeling == false, "Player completes Common Works channel")
	assert_test.call(gm.common_works > 0.0, "Common Works live progress increased")
	assert_test.call(gm.scrap == 3, "Common Works consumed 1 Scrap (4 -> 3)")

	# Test 1.5: Movement interrupts channeling
	player.position = Vector3(-6.0, 0.05, 24.0)
	var pump_pad: Dictionary = map.get_nearest_pad(player.position)
	pump_pad["cooldown"] = 0.0 # reset cooldown for test
	player.try_start_channel()
	assert_test.call(player.is_channeling == true, "Channeling initiated before move interrupt check")
	player.position = Vector3(0.0, 0.05, 0.0) # moved 24m away
	player._physics_process(0.1)
	assert_test.call(player.is_channeling == false, "Moving away from pad cancels channeling immediately")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Bot Autonomous Channeling in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Bot Autonomous Channeling in 3D")
	var bot_res: CharacterBody3D = residents[1]
	var bot_ctrl: Node = bot_res.get_node_or_null("BotController3D")
	assert_test.call(bot_ctrl != null, "BotController3D active on bot resident")

	# Place bot at Greenhouse pad with reset cooldown
	bot_res.position = Vector3(-20.0, 0.05, -20.0)
	var gh_pad: Dictionary = map.get_nearest_pad(bot_res.position)
	gh_pad["cooldown"] = 0.0
	gh_pad["active_user"] = null

	var pre_bot_stab: float = gm.stability
	bot_ctrl._start_working()
	assert_test.call(bot_res.is_channeling == true, "Bot successfully begins active pad channel via try_start_channel()")
	assert_test.call(bot_ctrl.state == "WORKING", "BotController enters WORKING state")

	# Process channeling to completion
	bot_res._physics_process(2.2)
	assert_test.call(bot_res.is_channeling == false, "Bot finishes channeling")
	assert_test.call(gm.stability == pre_bot_stab + 7.0, "Bot autonomous channeling mutated live GameManager stability (+7)")

	bot_ctrl._process_working(0.1)
	assert_test.call(bot_ctrl.state == "PAUSE", "Bot transitions to PAUSE after completing task")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Secluded Bedrock Alcoves & Archive Secrecy
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Secluded Bedrock Alcoves & Archive Secrecy")
	var active_alc: Dictionary = {}
	var inactive_alc: Dictionary = {}
	for alc in map.secret_alcoves:
		if alc["is_active"]:
			active_alc = alc
		else:
			if inactive_alc.is_empty():
				inactive_alc = alc

	assert_test.call(not active_alc.is_empty() and not inactive_alc.is_empty(), "Identified active alcove and inactive alcove")

	# Test 3.1: Inactive alcove inspection -> private weathered bedrock trace
	player.position = inactive_alc["pos"]
	var inspect_started: bool = player.try_inspect_site()
	assert_test.call(inspect_started == true, "Player starts inspecting inactive secluded alcove")
	assert_test.call(player.is_inspecting == true, "Player is_inspecting = true")
	player._physics_process(2.6) # 2.5s duration
	assert_test.call(player.is_inspecting == false, "Inspection completes")
	var journal_traces: Array = gm.evidence_journals.get(player.resident_id, {}).get("traces", [])
	var found_weathered := false
	for entry in journal_traces:
		if String(entry.get("text", "")).find("Weathered bedrock alcove inspected") != -1:
			found_weathered = true
	assert_test.call(found_weathered == true, "Private journal recorded weathered bedrock trace for inactive alcove")
	assert_test.call(gm.archive_opened == false, "Inactive alcove does not open Archive")

	# Test 3.2: Active alcove inspection -> unseals Archive failsafe key
	player.position = active_alc["pos"]
	player.try_inspect_site()
	player._physics_process(2.6)
	assert_test.call(gm.archive_opened == true, "Active secluded alcove unsealed Archive failsafe key")
	assert_test.call(gm.archive_finder_id == player.resident_id, "Archive finder ID recorded as Player")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Civic Shove, Stamina Damage & Clinic Recovery
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Civic Shove, Stamina Damage & Clinic Recovery")
	var victim: CharacterBody3D = residents[2]
	victim.position = Vector3(0.0, 0.05, 0.0)
	victim.stamina = 100.0
	victim.is_incapacitated = false

	player.position = Vector3(1.2, 0.05, 0.0) # 1.2m away
	player.shove_cooldown_left = 0.0

	# Test 4.1: Civic Shove dealt
	var shoved: bool = player.try_civic_shove()
	assert_test.call(shoved == true, "Player successfully performed Civic Shove")
	assert_test.call(victim.stamina == 65.0, "Victim took 35 stamina damage (100 -> 65)")
	assert_test.call(victim.knockback_velocity.length() > 2.0, "Knockback impulse applied to victim")
	assert_test.call(player.shove_cooldown_left > 0.0, "Shove cooldown triggered on player")

	# Test 4.2: Shove interrupts channeling
	victim.stamina = 100.0
	victim.position = Vector3(-6.0, 0.05, 24.0)
	var pump_p: Dictionary = map.get_nearest_pad(victim.position)
	pump_p["cooldown"] = 0.0
	victim.try_start_channel()
	assert_test.call(victim.is_channeling == true, "Victim channeling before shove")
	victim.receive_shove(Vector3(5, 0, 0), 35.0, player, false)
	assert_test.call(victim.is_channeling == false, "Incoming shove interrupted victim channeling")

	# Test 4.3: Stamina exhaustion triggering knockdown and Clinic relocation
	victim.stamina = 20.0
	victim.receive_shove(Vector3(5, 0, 0), 35.0, player, false) # 20 - 35 <= 0
	assert_test.call(victim.is_incapacitated == true, "Victim is_incapacitated = true on exhaustion")
	assert_test.call(victim.exhaustion_timer == C.RESPAWN_DURATION, "Exhaustion recovery timer set to 8.0s")
	assert_test.call(victim.position.distance_to(Vector3(0.0, 0.05, -10.0)) < 0.5, "Exhausted resident relocated to Town Square Clinic")

	# Test 4.4: 8s recovery at Clinic
	victim._physics_process(8.1)
	assert_test.call(victim.is_incapacitated == false, "Victim recovered after 8s exhaustion timer")
	assert_test.call(victim.stamina == victim.max_stamina, "Victim stamina fully restored to 100 on recovery")

	# ------------------------------------------------------------------
	# TEST GROUP 5: 5 Civic Kits in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] 5 Civic Kits in 3D")
	player.civic_cooldown_left = 0.0

	# 5.1: Pump Technician (Field Calibrator)
	player.civic_job = "Pump Technician"
	player.position = Vector3(0.0, 0.05, 0.0) # away from pad -> +40% work speed
	player.try_civic_ability()
	assert_test.call(player.work_speed_timer == 4.0, "Pump Technician grants 4.0s work speed buff")

	# 5.2: Crop Tender (Mulch Mist)
	player.civic_job = "Crop Tender"
	player.civic_cooldown_left = 0.0
	player.try_civic_ability()
	assert_test.call(map.is_inside_mulch_mist(player.position) == true, "Crop Tender spawns Mulch Mist zone in 3D")

	# 5.3: Salvage Quartermaster (Haul Rig Sprint)
	player.civic_job = "Salvage Quartermaster"
	player.civic_cooldown_left = 0.0
	player.try_civic_ability()
	assert_test.call(player.speed_buff_timer > 0.0 and player.speed_buff_mult == 1.45, "Salvage Quartermaster grants +45% move speed burst")

	# 5.4: Field Medic (First Aid Patch)
	player.civic_job = "Field Medic"
	player.civic_cooldown_left = 0.0
	player.stamina = 50.0
	player.try_civic_ability()
	assert_test.call(player.stamina == 85.0, "Field Medic restores +35 stamina to self")

	# 5.5: Town Watch (Brace & Lantern Shield)
	player.civic_job = "Town Watch"
	player.civic_cooldown_left = 0.0
	player.try_civic_ability()
	assert_test.call(player.watch_shield_timer == 4.5, "Town Watch grants 4.5s Watch Shield")
	# Shield blocks next incoming shove
	var pre_block_stam: float = player.stamina
	player.receive_shove(Vector3(1, 0, 0), 35.0, victim, false)
	assert_test.call(player.stamina == pre_block_stam, "Watch Shield blocked shove stamina damage")
	assert_test.call(player.watch_shield_timer == 0.0, "Watch Shield consumed on block")

	# ------------------------------------------------------------------
	# TEST GROUP 6: 6 Operative Faction Kits in 3D
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] 6 Operative Faction Kits in 3D")

	# 6.1: Tracker (Scent Trail Snapshot)
	player.secret_role = "ecology"
	player.operative_kit = "tracker"
	player.faction_cooldown_left = 0.0
	var tracker_used: bool = player.try_faction_ability()
	assert_test.call(tracker_used == true, "Tracker Scent Trail ability executed successfully")

	# 6.2: Grower (Root Snare / Briar Patch)
	player.operative_kit = "grower"
	player.faction_cooldown_left = 0.0
	player.position = Vector3(10.0, 0.05, 10.0)
	player.try_faction_ability()
	assert_test.call(map.is_slowed_by_root_snare(player.position, 99) == true, "Grower spawns Root Snare slowing 3D zone")
	victim.position = player.position
	victim.speed_buff_timer = 0.0
	assert_test.call(is_equal_approx(victim.get_speed_multiplier(), 0.55), "Victim crossing Root Snare has speed multiplied by 0.55 (-45% slow)")

	# 6.3: Warden (Thorn Guard Canopy)
	player.operative_kit = "warden"
	player.faction_cooldown_left = 0.0
	player.position = Vector3(-10.0, 0.05, -10.0)
	player.try_faction_ability()
	assert_test.call(map.is_protected_by_thorn_guard(player.position) == true, "Warden spawns Thorn Guard protective 3D canopy")
	# Shoving someone inside Thorn Guard reflects 20 stamina damage
	var attacker: CharacterBody3D = residents[3]
	attacker.stamina = 100.0
	attacker.position = player.position
	var target_protected: CharacterBody3D = residents[4]
	target_protected.position = player.position
	target_protected.receive_shove(Vector3(1, 0, 0), 35.0, attacker, false)
	assert_test.call(attacker.stamina == 80.0, "Thorn Guard reflected 20 stamina damage to attacker")

	# 6.4: Runner (Exosuit Burst)
	player.secret_role = "technology"
	player.operative_kit = "runner"
	player.faction_cooldown_left = 0.0
	player.try_faction_ability()
	assert_test.call(player.speed_buff_timer > 0.0 and player.speed_buff_mult == 1.35, "Runner Exosuit Burst grants speed buff")

	# 6.5: Mechanic (Overclock Rig)
	player.operative_kit = "mechanic"
	player.faction_cooldown_left = 0.0
	player.position = Vector3(-6.0, 0.05, 24.0) # at Pump
	var p_pad: Dictionary = map.get_nearest_pad(player.position)
	p_pad["cooldown"] = 10.0
	player.try_faction_ability()
	assert_test.call(p_pad["cooldown"] == 0.0, "Mechanic Overclock Rig cleared pad cooldown")
	assert_test.call(p_pad["overclocked"] == true, "Mechanic Overclock Rig flagged pad as overclocked (+50% next output)")

	# 6.6: Saboteur (Shock Tool)
	player.operative_kit = "saboteur"
	player.faction_cooldown_left = 0.0
	player.position = Vector3(-6.0, 0.05, 24.0) # at Pump
	player.try_faction_ability()
	assert_test.call(p_pad["jammed_timer"] == 8.0, "Saboteur jammed nearby pad for 8.0s")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Escalation Unlocks & Signal Beacon Frequency Tuning
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Escalation Unlocks & Signal Beacon Frequency Tuning")

	var gen_p: Dictionary = {}
	var bcn_p: Dictionary = {}
	for pad in map.task_pads:
		if pad["id"] == "generator": gen_p = pad
		elif pad["id"] == "beacon": bcn_p = pad

	assert_test.call(gen_p.get("is_locked") == true, "Generator pad initially locked in Open Town")
	assert_test.call(bcn_p.get("is_locked") == true, "Beacon pad initially locked in Open Town")

	# Advance to Escalation
	gm.current_phase = gm.Phase.ESCALATION
	map.update_escalation_unlocks()
	assert_test.call(gen_p.get("is_locked") == false, "Generator unlocked upon entering Escalation")
	assert_test.call(bcn_p.get("is_locked") == false, "Signal Beacon unlocked upon entering Escalation")
	assert_test.call(String(gen_p.get("label_node").text).find("Hold E") != -1, "Generator label updated to prompt channeling")
	assert_test.call(String(bcn_p.get("label_node").text).find("Hold E") != -1, "Beacon label updated to prompt tuning")

	# Tune Beacon for Ecology (+25% frequency)
	player.secret_role = "ecology"
	player.position = Vector3(0.0, 0.05, 28.0) # at Beacon
	bcn_p["cooldown"] = 0.0
	player.try_start_channel()
	player._physics_process(2.1)
	assert_test.call(gm.beacon_eco_freq == 25.0, "Beacon tuned to Ecology Biosphere Frequency (25%)")
	assert_test.call(gm.get_beacon_sightline_buff("ecology") == 1.35, "Ecology majority frequency grants +35% sightline buff (1.35x)")
	assert_test.call(gm.get_beacon_sightline_buff("technology") == 1.0, "Opposing technology receives standard 1.0x sightline")

	# Test Generator Priming in Escalation (Tech: +25% Governor, Eco: +25% Damper)
	player.secret_role = "technology"
	player.position = Vector3(6.0, 0.05, 24.0) # at Generator
	gen_p["cooldown"] = 0.0
	player.try_start_channel()
	player._physics_process(2.1)
	assert_test.call(gm.generator_tech_primed == 25.0, "Technology operative primed Generator Governor (+25% Tech)")

	player.secret_role = "ecology"
	gen_p["cooldown"] = 0.0
	player.try_start_channel()
	player._physics_process(2.1)
	assert_test.call(gm.generator_eco_stabilized == 25.0, "Ecology operative installed Biosphere Damper (+25% Eco)")

	# Test Town Clinic Pad Channeling (Restores stamina)
	player.position = Vector3(0.0, 0.05, -10.0) # at Clinic
	player.stamina = 40.0
	var clinic_p: Dictionary = map.get_nearest_pad(player.position)
	clinic_p["cooldown"] = 0.0
	player.try_start_channel()
	player._physics_process(2.1)
	assert_test.call(player.stamina == player.max_stamina, "Channeling Town Clinic pad restored player stamina to 100")

	# ------------------------------------------------------------------
	# TEST GROUP 8: 3D Line-of-Sight & Anonymity Witness Parity
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 8] 3D Line-of-Sight & Anonymity Witness Parity")
	gm.current_phase = gm.Phase.OPEN_TOWN
	gm.time_remaining = 210.0
	player.position = Vector3(-6.0, 0.05, 24.0)
	var witness_res: CharacterBody3D = residents[5]
	witness_res.position = Vector3(-6.0, 0.05, 18.0) # 6m away in same sector
	witness_res.is_incapacitated = false

	var witnessed_open: bool = gm.record_faction_ability_3d(player, map, [player, witness_res])
	assert_test.call(witnessed_open == true, "Ability witnessed in clear 3D sightline")
	var dist_ring: Dictionary = map.last_spawned_zone
	assert_test.call(dist_ring.get("zone_type") == "disturbance_ring", "Disturbance ring zone spawned")
	assert_test.call(dist_ring.get("pos").distance_to(player.position) > 2.0, "Disturbance ring NOT placed on caster exact coordinates")
	assert_test.call(dist_ring.get("pos").is_equal_approx(map.get_region_alert_anchor_at_3d(player.position)), "Disturbance ring centered at broad regional anchor (0, 24)")

	# Obstructed by North Wall East (X = 18, crossing Z = 10 wall)
	player.position = Vector3(18.0, 0.05, 16.0)
	witness_res.position = Vector3(18.0, 0.05, 4.0)
	var witnessed_blocked: bool = gm.record_faction_ability_3d(player, map, [player, witness_res])
	assert_test.call(witnessed_blocked == false, "Ability NOT witnessed when sightline obstructed by static wall")


	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL FULL 3D PHASE 2 CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.free()
	quit(0 if stats["failed"] == 0 else 1)
