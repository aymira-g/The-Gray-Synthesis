extends SceneTree

# ==============================================================================
# The Gray Synthesis - 10-Hero Roster, Active [F] Abilities & Passives Test Suite
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

var total_checks: int = 0
var passed_checks: int = 0
var failed_checks: int = 0

func _assert(cond: bool, desc: String) -> void:
	total_checks += 1
	if cond:
		passed_checks += 1
		print("  [PASS] %s" % desc)
	else:
		failed_checks += 1
		printerr("  [FAIL] %s" % desc)

func _initialize() -> void:
	print("==================================================================")
	print("  TEST SUITE: 10-HERO ROSTER, [F] ACTIVES & PASSIVE TRAITS")
	print("==================================================================")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var gm: Node = main.game_manager
	var tm: Node3D = main.town_map
	var residents: Array = main.residents

	# Advance to OPEN_TOWN so active abilities and tasks are live
	gm.advance_to_next_phase()

	# --------------------------------------------------------------------------
	# 1. Verify GameConstants 10-Hero Roster Metadata & Uniqueness
	# --------------------------------------------------------------------------
	print("\n--- 1. GameConstants 10-Hero Roster Metadata & Uniqueness ---")
	_assert(C.HERO_ROSTER.size() == 10, "C.HERO_ROSTER defines exactly 10 heroes")

	var seen_ids := {}
	var seen_names := {}
	var seen_actives := {}
	var seen_passives := {}
	var job_counts := {}

	for idx in range(C.HERO_ROSTER.size()):
		var h: Dictionary = C.HERO_ROSTER[idx]
		var hid: String = h.get("hero_id", "")
		var hname: String = h.get("name", "")
		var hjob: String = h.get("civic_job", "")
		var act_id: String = h.get("active_id", "")
		var pas_id: String = h.get("passive_id", "")

		_assert(hid != "" and not seen_ids.has(hid), "Hero %d has unique id: %s" % [idx + 1, hid])
		_assert(hname != "" and not seen_names.has(hname), "Hero %d has unique name: %s" % [idx + 1, hname])
		_assert(act_id != "" and not seen_actives.has(act_id), "Hero %d (%s) has unique active_id: %s" % [idx + 1, hname, act_id])
		_assert(pas_id != "" and not seen_passives.has(pas_id), "Hero %d (%s) has unique passive_id: %s" % [idx + 1, hname, pas_id])
		_assert(String(h.get("active_desc", "")).length() > 10, "Hero %d (%s) has active ability description" % [idx + 1, hname])
		_assert(String(h.get("passive_desc", "")).length() > 10, "Hero %d (%s) has passive trait description" % [idx + 1, hname])
		_assert(String(h.get("lore", "")).length() > 10, "Hero %d (%s) has character lore" % [idx + 1, hname])
		_assert(C.get_hero_by_id(hid).get("name", "") == hname, "C.get_hero_by_id('%s') resolves %s" % [hid, hname])
		_assert(C.get_hero_by_index(idx).get("hero_id", "") == hid, "C.get_hero_by_index(%d) resolves %s" % [idx, hid])

		seen_ids[hid] = true
		seen_names[hname] = true
		seen_actives[act_id] = true
		seen_passives[pas_id] = true
		job_counts[hjob] = int(job_counts.get(hjob, 0)) + 1

	_assert(job_counts.get("Pump Technician", 0) == 2, "Roster has 2 Pump Technicians (Kaelen Vance, Mira Solis)")
	_assert(job_counts.get("Crop Tender", 0) == 2, "Roster has 2 Crop Tenders (Soren Moss, Linnea Reed)")
	_assert(job_counts.get("Salvage Quartermaster", 0) == 2, "Roster has 2 Salvage Quartermasters (Garrick Cole, Vespera Crane)")
	_assert(job_counts.get("Field Medic", 0) == 2, "Roster has 2 Field Medics (Dr. Aris Thorne, Clara Vale)")
	_assert(job_counts.get("Town Watch", 0) == 2, "Roster has 2 Town Watch (Bram Sterling, Nyx Calder)")

	# --------------------------------------------------------------------------
	# 2. Verify Live 3D Resident Instantiation & Zero Role Leakage
	# --------------------------------------------------------------------------
	print("\n--- 2. Live 3D Resident Hero Assignment & Zero Role Leakage ---")
	_assert(residents.size() == 10, "Main3D spawns 10 live 3D Hero residents")
	for i in range(10):
		var res = residents[i]
		var expected_h: Dictionary = C.get_hero_by_index(i)
		_assert(res.hero_id == expected_h["hero_id"], "Resident slot %d assigned hero_id '%s'" % [i + 1, expected_h["hero_id"]])
		_assert(res.resident_name == expected_h["name"], "Resident slot %d named '%s'" % [i + 1, expected_h["name"]])
		_assert(res.civic_job == expected_h["civic_job"], "Resident slot %d civic_job is '%s'" % [i + 1, expected_h["civic_job"]])
		_assert(res.hero_trim_node != null, "Resident slot %d (%s) has 3D HeroCollarTrim mesh" % [i + 1, res.resident_name])

	# --------------------------------------------------------------------------
	# 3. Test All 10 Unique Active [F] Abilities
	# --------------------------------------------------------------------------
	print("\n--- 3. Testing All 10 Unique Active [F] Abilities ---")

	# Hero 0: Kaelen Vance — Field Calibrator [F]
	var kaelen = residents[0]
	kaelen.civic_cooldown_left = 0.0
	kaelen.work_speed_timer = 0.0
	kaelen.position = Vector3(0.0, 0.0, 0.0) # Away from pads -> +40% work speed
	var k_used: bool = kaelen.try_civic_ability()
	_assert(k_used and kaelen.work_speed_timer >= 3.9, "Kaelen Vance [F] Field Calibrator grants +40% work speed (4.0s)")
	_assert(absf(kaelen.civic_cooldown_left - 14.0) < 0.1, "Kaelen Vance [F] cooldown set to 14.0s")

	# Hero 5: Mira Solis — Pressure Surge [F]
	var mira = residents[5]
	mira.civic_cooldown_left = 0.0
	mira.stamina = 60.0
	mira.position = Vector3(4.0, 0.0, 4.0)
	kaelen.position = Vector3(5.5, 0.0, 4.0) # 1.5m away (within 3.2m push radius)
	kaelen.knockback_velocity = Vector3.ZERO
	var m_used: bool = mira.try_civic_ability()
	_assert(m_used and absf(mira.stamina - 80.0) < 0.1, "Mira Solis [F] Pressure Surge restores +20 Stamina")
	_assert(mira.speed_buff_timer >= 3.4 and absf(mira.speed_buff_mult - 1.30) < 0.01, "Mira Solis [F] Pressure Surge grants +30% speed for 3.5s")
	_assert(kaelen.knockback_velocity.length() > 5.0, "Mira Solis [F] Pressure Surge hydro-pushes nearby resident within 3.2m")

	# Hero 1: Soren Moss — Mulch Mist [F]
	var soren = residents[1]
	soren.civic_cooldown_left = 0.0
	soren.position = Vector3(-10.0, 0.0, -10.0)
	var s_used: bool = soren.try_civic_ability()
	_assert(s_used and tm.is_inside_mulch_mist(soren.position), "Soren Moss [F] Mulch Mist spawns 4m stamina mist zone")

	# Hero 6: Linnea Reed — Blight Cleanse [F]
	var linnea = residents[6]
	linnea.civic_cooldown_left = 0.0
	linnea.stamina = 50.0
	var gh_pad: Dictionary = tm.get_pad_by_id("greenhouse")
	gh_pad["jammed_timer"] = 7.0
	linnea.position = gh_pad["position"] + Vector3(1.0, 0.0, 0.0)
	tm.spawn_field_zone_3d("root_snare", linnea.position, 4.0, 6.0, 99)
	var l_used: bool = linnea.try_civic_ability()
	_assert(l_used and absf(linnea.stamina - 75.0) < 0.1, "Linnea Reed [F] Blight Cleanse restores +25 Stamina")
	_assert(float(gh_pad.get("jammed_timer", 0.0)) == 0.0, "Linnea Reed [F] Blight Cleanse clears jammed station pad within 5m")
	_assert(not tm.is_slowed_by_root_snare(linnea.position, linnea.resident_id), "Linnea Reed [F] Blight Cleanse removes nearby root snare hazard")

	# Hero 2: Garrick Cole — Haul Rig Sprint [F]
	var garrick = residents[2]
	garrick.civic_cooldown_left = 0.0
	var g_used: bool = garrick.try_civic_ability()
	_assert(g_used and garrick.speed_buff_timer >= 3.4 and absf(garrick.speed_buff_mult - 1.45) < 0.01, "Garrick Cole [F] Haul Rig Sprint grants +45% move speed (3.5s)")
	_assert(absf(garrick.civic_cooldown_left - 12.0) < 0.1, "Garrick Cole [F] cooldown is 12.0s")

	# Hero 7: Vespera Crane — Scrap Overdrive [F]
	var vespera = residents[7]
	vespera.civic_cooldown_left = 0.0
	var v_used: bool = vespera.try_civic_ability()
	_assert(v_used and vespera.work_speed_timer >= 4.9, "Vespera Crane [F] Scrap Overdrive grants +40% work speed for 5.0s")
	_assert(vespera.speed_buff_timer >= 4.9 and absf(vespera.speed_buff_mult - 1.20) < 0.01, "Vespera Crane [F] Scrap Overdrive grants +20% move speed for 5.0s")

	# Hero 3: Dr. Aris Thorne — First Aid Patch [F]
	var aris = residents[3]
	aris.civic_cooldown_left = 0.0
	aris.stamina = 50.0
	garrick.stamina = 60.0
	aris.position = Vector3(0.0, 0.0, -5.0)
	garrick.position = Vector3(1.5, 0.0, -5.0) # 1.5m away
	var a_used: bool = aris.try_civic_ability()
	_assert(a_used and absf(aris.stamina - 85.0) < 0.1 and absf(garrick.stamina - 95.0) < 0.1, "Dr. Aris Thorne [F] First Aid Patch heals self and nearest ally (+35 Stamina)")

	# Hero 8: Clara Vale — Adrenaline Tonic [F]
	var clara = residents[8]
	clara.civic_cooldown_left = 0.0
	clara.stamina = 60.0
	clara.position = Vector3(8.0, 0.0, -5.0)
	var c_used: bool = clara.try_civic_ability()
	_assert(c_used and absf(clara.stamina - 85.0) < 0.1, "Clara Vale [F] Adrenaline Tonic restores +25 Stamina")
	_assert(clara.adrenaline_timer >= 3.4 and clara.get_effective_stamina_drain() == 0.0, "Clara Vale [F] Adrenaline Tonic eliminates sprint stamina drain for 3.5s")
	_assert(clara.speed_buff_timer >= 3.4 and absf(clara.speed_buff_mult - 1.25) < 0.01, "Clara Vale [F] Adrenaline Tonic grants +25% move speed for 3.5s")

	# Hero 4: Bram Sterling — Brace & Lantern [F]
	var bram = residents[4]
	bram.civic_cooldown_left = 0.0
	var b_used: bool = bram.try_civic_ability()
	_assert(b_used and bram.watch_shield_timer >= 4.4, "Bram Sterling [F] Brace & Lantern activates 4.5s Watch Shield")

	# Hero 9: Nyx Calder — Recon Pulse [F]
	var nyx = residents[9]
	nyx.civic_cooldown_left = 0.0
	var n_used: bool = nyx.try_civic_ability()
	_assert(n_used and nyx.recon_pulse_timer >= 4.9, "Nyx Calder [F] Recon Pulse activates 5.0s acoustic radar scan")
	_assert(nyx.speed_buff_timer >= 3.4 and absf(nyx.speed_buff_mult - 1.20) < 0.01, "Nyx Calder [F] Recon Pulse grants +20% move speed for 3.5s")

	# --------------------------------------------------------------------------
	# 4. Test All 10 Unique Passive Traits
	# --------------------------------------------------------------------------
	print("\n--- 4. Testing All 10 Unique Passive Traits ---")

	# Passive 0: Kaelen Vance — Hydro-Mastery (+20% channel speed on Pump & Generator)
	var pump_pad: Dictionary = tm.get_pad_by_id("pump")
	pump_pad["cooldown"] = 0.0
	pump_pad["jammed_timer"] = 0.0
	pump_pad["active_user"] = null
	kaelen.work_speed_timer = 0.0
	kaelen.position = pump_pad["position"]
	var started_p: bool = kaelen.try_start_channel()
	kaelen._physics_process(1.0)
	_assert(started_p and absf(kaelen.channel_progress - 1.20) < 0.05, "Kaelen Vance Passive (Hydro-Mastery): channels Pump at 1.20x speed")
	kaelen.cancel_channeling()

	# Passive 5: Mira Solis — Crisis Responder (+15% move speed when Town Water < 50%)
	mira.speed_buff_timer = 0.0
	mira.position = Vector3(0.0, 0.0, 0.0)
	gm.water = 60.0
	var mira_normal_mult: float = mira.get_speed_multiplier()
	gm.water = 40.0
	var mira_crisis_mult: float = mira.get_speed_multiplier()
	_assert(absf(mira_normal_mult - 1.0) < 0.01 and absf(mira_crisis_mult - 1.15) < 0.01, "Mira Solis Passive (Crisis Responder): +15% move speed when Water < 50%")
	gm.water = 50.0

	# Passive 1: Soren Moss — Deep Roots (+2.5 Stamina/s in Greenhouse sector)
	tm.active_zones.clear()
	soren.is_sprinting = false
	soren.stamina = 50.0
	soren.position = Vector3(-20.0, 0.0, -20.0) # Inside Greenhouse sector
	# Move Clara away so Apothecary's Aura doesn't overlap
	clara.position = Vector3(25.0, 0.0, 25.0)
	soren._physics_process(1.0)
	_assert(absf(soren.stamina - 72.5) < 0.2, "Soren Moss Passive (Deep Roots): regenerates 22.5 Stamina/s (20 + 2.5) in Greenhouse")

	# Passive 6: Linnea Reed — Seedbank Curator (+2% bonus Stability on Greenhouse Crops)
	gh_pad["cooldown"] = 0.0
	gh_pad["jammed_timer"] = 0.0
	gh_pad["active_user"] = null
	gm.stability = 50.0
	tm.finish_using_pad(gh_pad, linnea, false)
	_assert(absf(gm.stability - 59.0) < 0.1, "Linnea Reed Passive (Seedbank Curator): Greenhouse task yields +9% Stability (+7% base + 2% bonus)")

	# Passive 2: Garrick Cole — Heavy Frame (125 Max Stamina & -20% Shove Knockback)
	_assert(absf(garrick.max_stamina - 125.0) < 0.1, "Garrick Cole Passive (Heavy Frame): max_stamina is 125.0 (+25)")
	garrick.stamina = 100.0
	garrick.watch_shield_timer = 0.0
	garrick.receive_shove(Vector3(10.0, 0.0, 0.0), 35.0, kaelen, false)
	_assert(absf(garrick.knockback_velocity.length() - 8.0) < 0.1, "Garrick Cole Passive (Heavy Frame): reduces incoming knockback impulse by 20% (10.0 -> 8.0)")

	# Passive 7: Vespera Crane — Scavenger's Eye (+1 bonus Scrap on Salvage Run)
	var salv_pad: Dictionary = tm.get_pad_by_id("salvage")
	salv_pad["cooldown"] = 0.0
	salv_pad["jammed_timer"] = 0.0
	salv_pad["active_user"] = null
	gm.scrap = 2
	tm.finish_using_pad(salv_pad, vespera, false)
	_assert(gm.scrap == 5, "Vespera Crane Passive (Scavenger's Eye): Salvage Run yields +3 Scrap (+2 base + 1 bonus)")

	# Passive 3: Dr. Aris Thorne — Triage Veteran (5.5s knockdown recovery & +30% regen below 50% Stamina)
	aris.stamina = 20.0
	aris.is_sprinting = false
	aris.position = Vector3(0.0, 0.0, 0.0)
	clara.position = Vector3(25.0, 0.0, 25.0)
	aris._physics_process(1.0)
	_assert(absf(aris.stamina - 46.0) < 0.2, "Dr. Aris Thorne Passive (Triage Veteran): regenerates 26.0 Stamina/s (1.30x) when below 50% Stamina")
	aris.trigger_knockdown()
	_assert(absf(aris.exhaustion_timer - 5.5) < 0.1, "Dr. Aris Thorne Passive (Triage Veteran): Clinic recovery time reduced to 5.5s (-2.5s)")
	aris.recover_full_stamina()

	# Passive 8: Clara Vale — Apothecary's Aura (+2.0 Stamina/s to self and allies within 4m)
	clara.position = Vector3(0.0, 0.0, 0.0)
	kaelen.position = Vector3(2.0, 0.0, 0.0) # 2.0m from Clara
	kaelen.is_sprinting = false
	kaelen.stamina = 60.0
	kaelen._physics_process(1.0)
	_assert(absf(kaelen.stamina - 82.0) < 0.2, "Clara Vale Passive (Apothecary's Aura): ally within 4m regenerates +2.0 bonus Stamina/s (22.0/s)")

	# Passive 4: Bram Sterling — Sentinel's Reach (2.5s shove cooldown & 45 shove stamina damage)
	bram.shove_cooldown_left = 0.0
	bram.position = Vector3(10.0, 0.0, 10.0)
	soren.position = Vector3(11.5, 0.0, 10.0)
	soren.stamina = 100.0
	soren.watch_shield_timer = 0.0
	var b_shoved: bool = bram.try_civic_shove()
	_assert(b_shoved and absf(bram.shove_cooldown_left - 2.5) < 0.1, "Bram Sterling Passive (Sentinel's Reach): Shove cooldown reduced to 2.5s (-1.5s)")
	_assert(absf(soren.stamina - 55.0) < 0.1, "Bram Sterling Passive (Sentinel's Reach): Shove deals 45.0 Stamina damage (+10)")

	# Passive 9: Nyx Calder — Forensic Eye (1.75s Alcove Inspection instead of 2.5s)
	var alc: Dictionary = tm.secret_alcoves[0]
	nyx.is_inspecting = false
	nyx.is_channeling = false
	nyx.position = alc["pos"]
	var n_insp: bool = nyx.try_inspect_site()
	_assert(n_insp and absf(nyx.inspection_timer - 1.75) < 0.05, "Nyx Calder Passive (Forensic Eye): inspects secluded bedrock alcove in 1.75s (30% faster)")
	nyx.cancel_inspection()

	print("==================================================================")
	print("  RESULTS: %d PASSED, %d FAILED (Total: %d)" % [passed_checks, failed_checks, total_checks])
	print("==================================================================")
	quit(0 if failed_checks == 0 else 1)
