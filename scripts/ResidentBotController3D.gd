extends Node

# ==============================================================================
# The Gray Synthesis - 3D Resident Bot Controller
# ==============================================================================
# Autonomous AI controller attached to bot Resident3D nodes.
# Uses TownMap3D's waypoint navigation graph to pathfind around static walls,
# patrol between town sectors, and simulate civic chores during Open Town.
# ==============================================================================

const MOVE_SPEED: float = 5.2
const C = preload("res://scripts/GameConstants.gd")
const TEMPERAMENTS: Array[String] = ["DUTIFUL", "INVESTIGATOR", "OPPORTUNIST", "BOLD"]

var resident: CharacterBody3D
var town_map: Node3D
var game_manager: Node
var bot_rng := RandomNumberGenerator.new()
var bot_seed: int = -1
var temperament: String = "DUTIFUL"
var personal_memory: Dictionary = {
	"private_evidence": [],
	"public_evidence": [],
	"known_partners": [],
	"suspicion": {},
	"suspicion_drift": {},
	"rumor_network": {},
	"trust_scores": {},
	"social_summary": "calm"
}

var state: String = "PAUSE" # "PAUSE", "MOVING", "WORKING", "COVERT_WORKING"
var pause_timer: float = 1.0
var work_timer: float = 0.0
var target_pad_id: String = ""
var target_pos: Vector3 = Vector3.ZERO
var path_points: Array[Vector3] = []
var tasks_visited_count: int = 0
var stuck_sample_timer: float = 0.0
var stuck_sample_pos: Vector3 = Vector3.ZERO

# Advanced Operative Bot Undercover AI State
var is_undercover_operative: bool = false
var undercover_cooldown: float = 12.0
var covert_mission_type: String = "NONE" # "NONE", "ALCOVE", "SABOTAGE"
var covert_action_timer: float = 0.0
var covert_target_alcove: Dictionary = {}
var covert_target_pad: Dictionary = {}
var alcoves_checked: Array[String] = []
var covert_sabotages_performed: int = 0
var covert_alcoves_inspected: int = 0

# List of target pads to cycle through based on civic jobs
const CHORE_TARGETS: Array[String] = [
	"pump", "greenhouse", "salvage", "clinic", "common_works", "generator"
]

func set_bot_seed(seed_value: int) -> void:
	bot_seed = seed_value
	bot_rng.seed = seed_value
	var profile_rng := RandomNumberGenerator.new()
	profile_rng.seed = seed_value
	temperament = TEMPERAMENTS[profile_rng.randi_range(0, TEMPERAMENTS.size() - 1)]

func setup(res: CharacterBody3D, map: Node3D, gm: Node, initial_delay: float) -> void:
	resident = res
	town_map = map
	game_manager = gm
	if bot_seed < 0:
		bot_rng.randomize()
		set_bot_seed(int(bot_rng.randi()))
	state = "PAUSE"
	pause_timer = initial_delay
	tasks_visited_count = 0
	stuck_sample_timer = 0.0
	stuck_sample_pos = res.position if res != null else Vector3.ZERO
	if resident != null:
		routine_step = (resident.resident_id + (2 if resident.resident_id % 2 == 0 else 0))
		is_undercover_operative = (resident.secret_role == "ecology" or resident.secret_role == "technology")
		undercover_cooldown = _covert_cooldown_range("initial")
		covert_mission_type = "NONE"
		alcoves_checked.clear()
		covert_sabotages_performed = 0
		covert_alcoves_inspected = 0
		refresh_personal_memory()

func reset_bot(initial_delay: float) -> void:
	state = "PAUSE"
	pause_timer = initial_delay
	bot_rng.seed = bot_seed
	path_points.clear()
	target_pad_id = ""
	stuck_sample_timer = 0.0
	if resident != null:
		stuck_sample_pos = resident.position
		routine_step = (resident.resident_id + (2 if resident.resident_id % 2 == 0 else 0))
		resident.velocity = Vector3.ZERO
		is_undercover_operative = (resident.secret_role == "ecology" or resident.secret_role == "technology")
		undercover_cooldown = _covert_cooldown_range("initial")
		covert_mission_type = "NONE"
		covert_target_alcove = {}
		covert_target_pad = {}
		alcoves_checked.clear()
		covert_sabotages_performed = 0
		covert_alcoves_inspected = 0
		refresh_personal_memory()
		if resident.action_label != null:
			resident.action_label.text = ""

func refresh_personal_memory() -> Dictionary:
	var private_entries: Array[Dictionary] = []
	var public_entries: Array[Dictionary] = []
	var partners: Array[String] = []
	var suspicion: Dictionary = {}
	var rumor_network: Dictionary = {}
	var trust_scores: Dictionary = {}
	var previous_suspicion: Dictionary = personal_memory.get("suspicion", {})
	var suspicion_drift: Dictionary = {}

	if resident != null and game_manager != null:
		var journal: Dictionary = game_manager.get_player_journal(int(resident.resident_id))
		for bucket in ["observed", "traces"]:
			for item_variant in journal.get(bucket, []):
				if not item_variant is Dictionary:
					continue
				var item: Dictionary = item_variant.duplicate(true)
				if String(item.get("id", "")).begins_with("claim:"):
					continue
				private_entries.append(item)

		for item_variant in game_manager.tabled_evidence:
			if not item_variant is Dictionary:
				continue
			var item: Dictionary = item_variant.duplicate(true)
			public_entries.append(item)

		if resident.is_operative() and town_map != null:
			for partner_entry in game_manager.get_partner_names_for(resident, town_map.all_residents):
				partners.append(String(partner_entry).split(" — Public Job:")[0])

	var seen_evidence: Dictionary = {}
	var public_conflicts: Dictionary = {}
	for conflict in game_manager.alibi_conflicts:
		if conflict is Dictionary and conflict.get("resident", "") != "":
			public_conflicts[String(conflict.get("resident", ""))] = true
	for item in private_entries + public_entries:
		var evidence_id: String = String(item.get("id", ""))
		if evidence_id != "" and seen_evidence.has(evidence_id):
			continue
		if evidence_id != "":
			seen_evidence[evidence_id] = true
		if String(item.get("tier", "")) == C.EVIDENCE_CLAIM or evidence_id.begins_with("claim:"):
			continue
		var subject: String = String(item.get("subject", ""))
		if subject != "":
			var subject_score: float = float(suspicion.get(subject, 0.0))
			var text_lower: String = String(item.get("text", "")).to_lower()
			if "tamper" in text_lower or "sabotage" in text_lower or "caught" in text_lower:
				subject_score += 1.75
			elif "frequency" in text_lower or "alibi" in text_lower:
				subject_score += 1.0
			else:
				subject_score += 0.75
			if public_conflicts.has(subject):
				subject_score += 0.75
			suspicion[subject] = subject_score
			var rumor_vote: float = 0.25
			if "tamper" in text_lower or "sabotage" in text_lower or "caught" in text_lower:
				rumor_vote = 0.65
			elif "frequency" in text_lower:
				rumor_vote = 0.45
			if public_conflicts.has(subject):
				rumor_vote += 0.35
			rumor_network[subject] = float(rumor_network.get(subject, 0.0)) + rumor_vote
			trust_scores[subject] = float(trust_scores.get(subject, 0.0)) - rumor_vote * 0.85
	for partner_name in partners:
		if partner_name != "":
			trust_scores[partner_name] = float(trust_scores.get(partner_name, 0.0)) + 0.35
		if partner_name in suspicion:
			suspicion.erase(partner_name)
	for subject_name in suspicion.keys():
		var drifted: float = max(0.0, float(suspicion[subject_name]) * 0.82 - 0.15)
		if drifted <= 0.05:
			suspicion.erase(subject_name)
		else:
			suspicion[subject_name] = round(drifted * 100.0) / 100.0
		var previous_score: float = float(previous_suspicion.get(subject_name, 0.0))
		var drift_delta: float = round((float(suspicion.get(subject_name, 0.0)) - previous_score) * 100.0) / 100.0
		if abs(drift_delta) > 0.01:
			suspicion_drift[subject_name] = drift_delta
	for subject_name in rumor_network.keys():
		var network_score: float = float(rumor_network[subject_name])
		var trust_score: float = float(trust_scores.get(subject_name, 0.0))
		if network_score <= 0.05:
			rumor_network.erase(subject_name)
		elif trust_score < -0.9:
			trust_scores[subject_name] = -1.0
		elif trust_score > 1.0:
			trust_scores[subject_name] = 1.0
		else:
			trust_scores[subject_name] = round(trust_score * 100.0) / 100.0
		if network_score > 0.0:
			rumor_network[subject_name] = round(network_score * 100.0) / 100.0
	var social_summary: String = _summarize_social_state(trust_scores, suspicion, suspicion_drift)
	personal_memory = {
		"private_evidence": private_entries,
		"public_evidence": public_entries,
		"known_partners": partners,
		"suspicion": suspicion,
		"suspicion_drift": suspicion_drift,
		"rumor_network": rumor_network,
		"trust_scores": trust_scores,
		"suspicion_summary": _summarize_suspicion(suspicion),
		"social_summary": social_summary
	}
	return personal_memory.duplicate(true)

func _summarize_suspicion(suspicion: Dictionary) -> String:
	if suspicion.is_empty():
		return "calm"
	var sorted_subjects: Array = []
	for subject_name in suspicion.keys():
		sorted_subjects.append({"name": subject_name, "score": float(suspicion[subject_name])})
	sorted_subjects.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	if sorted_subjects.size() == 0:
		return "calm"
	var top_subject: String = String(sorted_subjects[0].get("name", ""))
	var top_score: float = float(sorted_subjects[0].get("score", 0.0))
	if top_score >= 2.5:
		return "high suspicion around %s" % top_subject
	if top_score >= 1.25:
		return "watching %s" % top_subject
	return "kept a low profile around %s" % top_subject

func _summarize_social_state(trust_scores: Dictionary, suspicion: Dictionary, suspicion_drift: Dictionary = {}) -> String:
	if trust_scores.is_empty() and suspicion.is_empty():
		return "calm"
	var lowest_name: String = ""
	var lowest_score: float = 1.0
	for subject_name in trust_scores.keys():
		var score: float = float(trust_scores[subject_name])
		if score < lowest_score:
			lowest_score = score
			lowest_name = String(subject_name)
	if lowest_name != "":
		if suspicion_drift.has(lowest_name):
			var drift: float = float(suspicion_drift[lowest_name])
			if drift > 0.0:
				return "distrust strengthening around %s" % lowest_name
			if drift < 0.0:
				return "distrust cooling around %s" % lowest_name
		return "distrust forming around %s" % lowest_name
	if suspicion.is_empty():
		return "steady trust network"
	var top_subject: String = ""
	var top_score: float = -1.0
	for subject_name in suspicion.keys():
		var score: float = float(suspicion[subject_name])
		if score > top_score:
			top_score = score
			top_subject = String(subject_name)
	if suspicion_drift.has(top_subject):
		var drift: float = float(suspicion_drift[top_subject])
		if drift > 0.0:
			return "rumor churn rising around %s" % top_subject
		if drift < 0.0:
			return "rumor churn fading around %s" % top_subject
	return "rumor churn around %s" % top_subject

func _physics_process(delta: float) -> void:
	if resident == null or town_map == null:
		return
	if is_undercover_operative != resident.is_operative():
		is_undercover_operative = resident.is_operative()
	if game_manager != null and not game_manager.is_active_play_phase():
		resident.velocity = Vector3.ZERO
		state = "PAUSE"
		pause_timer = 1.0
		if resident.action_label != null:
			resident.action_label.text = "Assembled for Briefing"
		return
	if resident.is_incapacitated:
		resident.velocity = Vector3.ZERO
		state = "PAUSE"
		pause_timer = 2.0
		return

	match state:
		"PAUSE":
			_process_pause(delta)
		"MOVING":
			_process_moving(delta)
		"WORKING":
			_process_working(delta)
		"COVERT_WORKING":
			_process_covert_working(delta)

var routine_step: int = 0

const SECTOR_CHORE_ROUTINES: Dictionary = {
	"Pump Technician": [
		{"type": "pad", "id": "pump", "action": "Maintaining Pump Station"},
		{"type": "inspect", "pos": Vector3(-14.0, 0.0, 26.0), "label": "Inspecting Water Reservoir"},
		{"type": "inspect", "pos": Vector3(10.0, 0.0, 24.0), "label": "Checking Turbine Coils"},
		{"type": "inspect", "pos": Vector3(-6.0, 0.0, 20.0), "label": "Calibrating Pipe Valves"}
	],
	"Crop Tender": [
		{"type": "pad", "id": "greenhouse", "action": "Tending Hydroponic Crops"},
		{"type": "inspect", "pos": Vector3(-22.0, 0.0, -16.0), "label": "Pruning Vegetable Vines"},
		{"type": "inspect", "pos": Vector3(-18.0, 0.0, -24.0), "label": "Sampling Soil Moisture"},
		{"type": "inspect", "pos": Vector3(-16.0, 0.0, -18.0), "label": "Checking Botanical Lights"}
	],
	"Salvage Quartermaster": [
		{"type": "pad", "id": "salvage", "action": "Sorting Scrap Metal"},
		{"type": "inspect", "pos": Vector3(16.0, 0.0, -24.0), "label": "Operating Workbench Vise"},
		{"type": "inspect", "pos": Vector3(24.0, 0.0, -16.0), "label": "Cataloging Supply Crates"},
		{"type": "inspect", "pos": Vector3(18.0, 0.0, -14.0), "label": "Inspecting Gantry Crane"}
	],
	"Field Medic": [
		{"type": "pad", "id": "clinic", "action": "Providing Clinic Care"},
		{"type": "inspect", "pos": Vector3(-2.1, 0.0, -10.0), "label": "Restocking Medical Supplies"},
		{"type": "pad", "id": "common_works", "action": "Assisting Foundation Works"},
		{"type": "inspect", "pos": Vector3(2.1, 0.0, -10.0), "label": "Sterilizing Recovery Cots"}
	],
	"Town Watch": [
		{"type": "inspect", "pos": Vector3(0.0, 0.0, 14.0), "label": "Guarding North Gate"},
		{"type": "inspect", "pos": Vector3(-14.0, 0.0, 4.0), "label": "Securing West Perimeter"},
		{"type": "inspect", "pos": Vector3(-8.0, 0.0, -8.0), "label": "Patrolling SW Gate"},
		{"type": "inspect", "pos": Vector3(8.0, 0.0, -8.0), "label": "Patrolling SE Gate"},
		{"type": "inspect", "pos": Vector3(14.0, 0.0, 4.0), "label": "Securing East Perimeter"}
	]
}

# ------------------------------------------------------------------------------
# Observation & Line-of-Sight Sensing
# ------------------------------------------------------------------------------
func is_observed_by_others(exclude_faction: String = "") -> bool:
	return not get_active_observers(exclude_faction).is_empty()

func get_active_observers(exclude_faction: String = "") -> Array:
	var observers: Array = []
	if town_map == null or resident == null:
		return observers
	var res_pos: Vector3 = resident.global_position if resident.is_inside_tree() else resident.position
	var all_res: Array = town_map.all_residents if town_map.get("all_residents") != null else []
	for other in all_res:
		if other == null or other == resident or other.is_incapacitated:
			continue
		if exclude_faction != "" and other.secret_role == exclude_faction:
			continue
		var other_pos: Vector3 = other.global_position if other.is_inside_tree() else other.position
		# In 3D world, witness visibility range is 26.0 meters
		if res_pos.distance_to(other_pos) > 26.0:
			continue
		if town_map.has_method("has_clear_sightline_3d"):
			if town_map.has_clear_sightline_3d(other_pos, res_pos):
				observers.append(other)
	return observers

# ------------------------------------------------------------------------------
# Pause & Destination Selection
# ------------------------------------------------------------------------------
func _process_pause(delta: float) -> void:
	resident.velocity = Vector3.ZERO
	pause_timer -= delta
	if is_undercover_operative and undercover_cooldown > 0.0:
		undercover_cooldown -= delta

	if pause_timer <= 0.0:
		if is_undercover_operative and undercover_cooldown <= 0.0 and game_manager != null and game_manager.current_phase == game_manager.Phase.OPEN_TOWN:
			if _try_start_covert_mission():
				return
		_pick_next_chore_destination()

func _try_start_covert_mission() -> bool:
	refresh_personal_memory()
	if is_observed_by_others(resident.secret_role):
		undercover_cooldown = _covert_cooldown_range("observed")
		return false

	var res_pos: Vector3 = resident.global_position if resident.is_inside_tree() else resident.position

	# 1. Archive Bedrock Alcove Priority
	var should_seek_alcove := false
	if game_manager != null and not game_manager.archive_opened and town_map != null and not town_map.secret_alcoves.is_empty():
		for alc in town_map.secret_alcoves:
			if not alcoves_checked.has(String(alc["id"])):
				should_seek_alcove = true
				break

	if should_seek_alcove:
		var best_alc: Dictionary = {}
		var best_dist: float = 999999.0
		var alcove_candidates: Array[Dictionary] = []
		for alc in town_map.secret_alcoves:
			var alc_id: String = String(alc["id"])
			if alcoves_checked.has(alc_id):
				continue
			alcove_candidates.append(alc)
		if temperament == "BOLD" and alcove_candidates.size() > 1:
			best_alc = alcove_candidates[bot_rng.randi_range(0, alcove_candidates.size() - 1)]
		else:
			for alc in alcove_candidates:
				var d: float = res_pos.distance_to(alc["pos"])
				if temperament == "INVESTIGATOR":
					d -= _memory_region_affinity(String(alc.get("region", town_map.get_region_name_at_3d(alc["pos"])))) * 8.0
				elif temperament == "OPPORTUNIST":
					d -= bot_rng.randf_range(0.0, 3.0)
				if d < best_dist:
					best_dist = d
					best_alc = alc

		if not best_alc.is_empty():
			covert_mission_type = "ALCOVE"
			covert_target_alcove = best_alc
			target_pos = best_alc["pos"]
			path_points = town_map.find_path(res_pos, target_pos)
			if path_points.is_empty():
				path_points = [target_pos]
			state = "MOVING"
			target_pad_id = ""
			if resident.action_label != null:
				resident.action_label.text = "Patrolling secluded bounds"
			return true

	# 2. Covert Station Sabotage
	if town_map != null and not town_map.task_pads.is_empty():
		var available_pads: Array[Dictionary] = []
		for pad_variant in town_map.task_pads:
			var pad: Dictionary = pad_variant
			var is_locked: bool = bool(pad.get("is_locked", false))
			var cooldown: float = float(pad.get("cooldown", 0.0))
			if not is_locked and cooldown <= 0.0:
				available_pads.append(pad)

		if not available_pads.is_empty():
			var chosen_pad: Dictionary = _choose_covert_pad(available_pads, res_pos)
			covert_mission_type = "SABOTAGE"
			covert_target_pad = chosen_pad
			target_pos = chosen_pad["position"]
			path_points = town_map.find_path(res_pos, target_pos)
			if path_points.is_empty():
				path_points = [target_pos]
			state = "MOVING"
			target_pad_id = ""
			if resident.action_label != null:
				resident.action_label.text = "Inspecting station conduits"
			return true

	return false

func _pick_next_chore_destination() -> void:
	if town_map == null or town_map.task_pads.is_empty():
		return

	refresh_personal_memory()
	var res_pos: Vector3 = resident.global_position if resident.is_inside_tree() else resident.position
	var job_name: String = String(resident.civic_job)

	var routine: Array = SECTOR_CHORE_ROUTINES.get(job_name, SECTOR_CHORE_ROUTINES["Town Watch"])
	var chore_def: Dictionary = _choose_profile_chore(routine, res_pos)
	routine_step += 1

	var target_coord: Vector3 = Vector3.ZERO
	var chore_type: String = String(chore_def.get("type", "inspect"))

	if chore_type == "pad":
		var pad_id: String = String(chore_def.get("id", ""))
		var pad: Dictionary = town_map.get_pad_by_id(pad_id)
		if not pad.is_empty() and not pad.get("is_locked", false):
			if pad.get("active_user") == null or pad.get("active_user") == resident:
				target_pad_id = pad_id
				var angle: float = float(resident.resident_id) * 1.396
				var offset_dist: float = 1.1 + (float(resident.resident_id % 3) * 0.35)
				target_coord = pad["position"] + Vector3(cos(angle) * offset_dist, 0.0, sin(angle) * offset_dist)
				if resident.action_label != null:
					resident.action_label.text = String(chore_def.get("action", "Tending Station"))
			else:
				chore_def = routine[routine_step % routine.size()]
				routine_step += 1
				chore_type = String(chore_def.get("type", "inspect"))

	if chore_type == "inspect":
		target_pad_id = ""
		var base_pos: Vector3 = chore_def.get("pos", Vector3.ZERO)
		var angle: float = float(resident.resident_id) * 1.2
		var jitter := Vector3(cos(angle) * 0.75, 0.0, sin(angle) * 0.75)
		target_coord = base_pos + jitter
		if resident.action_label != null:
			resident.action_label.text = String(chore_def.get("label", "Patrolling"))

	target_pos = target_coord
	path_points = town_map.find_path(res_pos, target_pos)
	if path_points.is_empty():
		path_points = [target_pos]

	state = "MOVING"

func _choose_profile_chore(routine: Array, res_pos: Vector3) -> Dictionary:
	var routine_chore: Dictionary = routine[routine_step % routine.size()]
	if temperament != "DUTIFUL" and routine_step % 2 == 0:
		return routine_chore
	match temperament:
		"DUTIFUL":
			var crisis_pad := _get_urgent_crisis_pad()
			return _make_pad_chore(crisis_pad) if not crisis_pad.is_empty() else routine_chore
		"INVESTIGATOR":
			var inspections := _collect_inspection_chore_candidates()
			if not inspections.is_empty():
				var evidence_regions: Array[Dictionary] = []
				for candidate in inspections:
					var candidate_region: String = town_map.get_region_name_at_3d(candidate.get("pos", Vector3.ZERO))
					if _memory_region_affinity(candidate_region) > 0.0:
						evidence_regions.append(candidate)
				var search_candidates: Array[Dictionary] = evidence_regions if not evidence_regions.is_empty() else inspections
				var best: Dictionary = search_candidates[bot_rng.randi_range(0, search_candidates.size() - 1)]
				var best_score: float = -INF
				for candidate in search_candidates:
					var score: float = -res_pos.distance_to(candidate.get("pos", Vector3.ZERO)) * 0.05
					score += bot_rng.randf_range(0.0, 0.5)
					if score > best_score:
						best_score = score
						best = candidate
				return best
		"OPPORTUNIST":
			var opportunistic_pad := _choose_best_pad(_get_available_task_pads(), res_pos, true)
			if not opportunistic_pad.is_empty():
				return _make_pad_chore(opportunistic_pad)
		"BOLD":
			var bold_pads := _get_available_task_pads()
			if not bold_pads.is_empty():
				return _make_pad_chore(bold_pads[bot_rng.randi_range(0, bold_pads.size() - 1)])
	return routine_chore

func _collect_inspection_chore_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for job_routine_variant in SECTOR_CHORE_ROUTINES.values():
		for chore_variant in job_routine_variant:
			var chore: Dictionary = chore_variant
			if String(chore.get("type", "")) == "inspect":
				candidates.append(chore)
	return candidates

func _get_available_task_pads() -> Array[Dictionary]:
	var pads: Array[Dictionary] = []
	if town_map == null:
		return pads
	for pad_variant in town_map.task_pads:
		var pad: Dictionary = pad_variant
		if bool(pad.get("is_locked", false)) or float(pad.get("cooldown", 0.0)) > 0.0 or float(pad.get("jammed_timer", 0.0)) > 0.0:
			continue
		if pad.get("active_user") != null and pad.get("active_user") != resident:
			continue
		pads.append(pad)
	return pads

func _get_urgent_crisis_pad() -> Dictionary:
	if game_manager == null or town_map == null:
		return {}
	if game_manager.water <= 45.0:
		return _get_available_crisis_pad("pump")
	if game_manager.stability <= 45.0:
		return _get_available_crisis_pad("greenhouse")
	if game_manager.scrap <= 2:
		return _get_available_crisis_pad("salvage")
	return {}

func _get_available_crisis_pad(pad_id: String) -> Dictionary:
	var pad: Dictionary = town_map.get_pad_by_id(pad_id)
	if pad.is_empty() or bool(pad.get("is_locked", false)) or float(pad.get("cooldown", 0.0)) > 0.0 or float(pad.get("jammed_timer", 0.0)) > 0.0:
		return {}
	if pad.get("active_user") != null and pad.get("active_user") != resident:
		return {}
	return pad

func _social_bias_for_target(subject_name: String) -> float:
	if subject_name == "":
		return 0.0
	var trust_map: Dictionary = personal_memory.get("trust_scores", {})
	var rumor_map: Dictionary = personal_memory.get("rumor_network", {})
	var trust_score: float = float(trust_map.get(subject_name, 0.0))
	var rumor_score: float = float(rumor_map.get(subject_name, 0.0))
	return (trust_score * 2.2) - (rumor_score * 0.65)

func _choose_best_pad(pads: Array[Dictionary], res_pos: Vector3, add_variation: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for pad in pads:
		var pad_id: String = String(pad.get("id", ""))
		var score: float = 1.0 - res_pos.distance_to(pad.get("position", Vector3.ZERO)) * 0.025
		if pad_id == "common_works":
			score += 2.5
		var pad_user = pad.get("active_user")
		if pad_user != null:
			var pad_user_name: String = ""
			if pad_user is Dictionary:
				pad_user_name = String(pad_user.get("resident_name", ""))
			elif pad_user != resident:
				pad_user_name = String(pad_user.get("resident_name", ""))
			if pad_user_name != "":
				score += _social_bias_for_target(pad_user_name) * 0.75
		if game_manager != null:
			match pad_id:
				"pump":
					score += maxf(0.0, (65.0 - game_manager.water) * 0.08)
				"greenhouse":
					score += maxf(0.0, (65.0 - game_manager.stability) * 0.08)
				"salvage":
					score += maxf(0.0, (6.0 - float(game_manager.scrap)) * 0.35)
				"common_works":
					score += maxf(0.0, (60.0 - game_manager.common_works) * 0.025)
		if add_variation:
			score += bot_rng.randf_range(0.0, 1.0)
		if score > best_score:
			best_score = score
			best = pad
	return best

func _make_pad_chore(pad: Dictionary) -> Dictionary:
	var pad_title: String = String(pad.get("base_title", pad.get("name", "station")))
	return {
		"type": "pad",
		"id": String(pad.get("id", "")),
		"action": "Working at %s" % pad_title
	}

func _memory_region_affinity(region_name: String) -> float:
	var score: float = 0.0
	var seen_evidence: Dictionary = {}
	for evidence_variant in personal_memory.get("private_evidence", []) + personal_memory.get("public_evidence", []):
		var evidence: Dictionary = evidence_variant
		var evidence_id: String = String(evidence.get("id", ""))
		if evidence_id != "" and seen_evidence.has(evidence_id):
			continue
		seen_evidence[evidence_id] = true
		if String(evidence.get("tier", "")) == C.EVIDENCE_CLAIM or evidence_id.begins_with("claim:"):
			continue
		if String(evidence.get("region", "")) == region_name:
			score += 1.0
	return score

func _choose_covert_pad(pads: Array[Dictionary], res_pos: Vector3) -> Dictionary:
	if temperament == "BOLD":
		return pads[bot_rng.randi_range(0, pads.size() - 1)]
	var best_score: float = -INF
	var best: Dictionary = {}
	for pad in pads:
		var score: float = -res_pos.distance_to(pad.get("position", Vector3.ZERO)) * 0.03
		var pad_region: String = town_map.get_region_name_at_3d(pad.get("position", Vector3.ZERO))
		match temperament:
			"INVESTIGATOR":
				score += _memory_region_affinity(pad_region) * 3.0
			"OPPORTUNIST":
				if game_manager != null:
					match String(pad.get("id", "")):
						"pump":
							score += maxf(0.0, (60.0 - game_manager.water) * 0.12)
						"greenhouse":
							score += maxf(0.0, (60.0 - game_manager.stability) * 0.12)
						"salvage":
							score += maxf(0.0, (5.0 - float(game_manager.scrap)) * 0.6)
			"DUTIFUL":
				score -= 2.0
		score += bot_rng.randf_range(0.0, 0.75)
		if score > best_score:
			best_score = score
			best = pad
	return best

func _covert_cooldown_range(event_type: String) -> float:
	match temperament:
		"DUTIFUL":
			if event_type == "initial":
				return bot_rng.randf_range(18.0, 26.0)
			if event_type == "completed":
				return bot_rng.randf_range(32.0, 44.0)
			if event_type == "aborted":
				return bot_rng.randf_range(20.0, 28.0)
			return bot_rng.randf_range(7.0, 11.0)
		"INVESTIGATOR":
			if event_type == "initial":
				return bot_rng.randf_range(11.0, 17.0)
			if event_type == "completed":
				return bot_rng.randf_range(17.0, 27.0)
			if event_type == "aborted":
				return bot_rng.randf_range(16.0, 24.0)
			return bot_rng.randf_range(5.0, 9.0)
		"OPPORTUNIST":
			if event_type == "initial":
				return bot_rng.randf_range(8.0, 14.0)
			if event_type == "completed":
				return bot_rng.randf_range(14.0, 24.0)
			if event_type == "aborted":
				return bot_rng.randf_range(14.0, 20.0)
			return bot_rng.randf_range(4.0, 8.0)
		"BOLD":
			if event_type == "initial":
				return bot_rng.randf_range(5.0, 10.0)
			if event_type == "completed":
				return bot_rng.randf_range(10.0, 18.0)
			if event_type == "aborted":
				return bot_rng.randf_range(12.0, 16.0)
			return bot_rng.randf_range(3.0, 6.0)
	return bot_rng.randf_range(8.0, 16.0)

func _next_pause_duration() -> float:
	match temperament:
		"DUTIFUL":
			return bot_rng.randf_range(0.8, 1.3)
		"INVESTIGATOR":
			return bot_rng.randf_range(0.9, 1.6)
		"OPPORTUNIST":
			return bot_rng.randf_range(0.45, 0.9)
		"BOLD":
			return bot_rng.randf_range(0.25, 0.65)
	return bot_rng.randf_range(0.5, 1.0)

# ------------------------------------------------------------------------------
# Movement & Watchdog
# ------------------------------------------------------------------------------
func _process_moving(delta: float) -> void:
	var res_pos: Vector3 = resident.global_position if resident.is_inside_tree() else resident.position

	# Check for adverse witnesses when approaching covert destination
	if covert_mission_type != "NONE":
		var to_goal: float = res_pos.distance_to(target_pos)
		if to_goal < 6.0:
			var observers: Array = get_active_observers(resident.secret_role)
			if not observers.is_empty():
				for obs in observers:
					if game_manager != null and town_map != null:
						var location_label: String = covert_target_alcove.get("name", "secluded alcove") if covert_mission_type == "ALCOVE" else covert_target_pad.get("name", "station")
						game_manager.record_observed_sighting_3d(
							resident, res_pos, town_map, town_map.all_residents,
							"was seen lurking near %s" % location_label
						)
				_abort_covert_mission("Spotted near objective")
				return

	if path_points.is_empty():
		_reach_destination()
		return

	var next_point: Vector3 = path_points[0]
	var to_target: Vector3 = next_point - res_pos
	to_target.y = 0.0
	var dist: float = to_target.length()

	stuck_sample_timer += delta
	if stuck_sample_timer >= 1.0:
		stuck_sample_timer = 0.0
		var progress: float = res_pos.distance_to(stuck_sample_pos)
		stuck_sample_pos = res_pos
		if progress < 0.8:
			path_points.pop_front()
			if path_points.is_empty():
				_reach_destination()
				return
			next_point = path_points[0]
			to_target = next_point - res_pos
			to_target.y = 0.0
			dist = to_target.length()

	if dist < 1.4:
		path_points.pop_front()
		if path_points.is_empty():
			_reach_destination()
			return
		next_point = path_points[0]
		to_target = next_point - res_pos
		to_target.y = 0.0

	var dir := to_target.normalized()
	resident.velocity = dir * MOVE_SPEED

	if dir.length_squared() > 0.01 and resident.mesh_root != null:
		var target_yaw := atan2(-dir.x, -dir.z)
		resident.mesh_root.rotation.y = lerp_angle(resident.mesh_root.rotation.y, target_yaw, delta * 10.0)

func _reach_destination() -> void:
	if covert_mission_type == "ALCOVE":
		_start_covert_alcove_search()
	elif covert_mission_type == "SABOTAGE":
		_start_covert_sabotage()
	else:
		_start_working()

# ------------------------------------------------------------------------------
# Covert Working & Sabotage Execution
# ------------------------------------------------------------------------------
func _start_covert_alcove_search() -> void:
	resident.velocity = Vector3.ZERO
	state = "COVERT_WORKING"
	covert_action_timer = 2.5
	if resident.has_method("trigger_covert_hunch"):
		resident.trigger_covert_hunch(2.5)
	if resident.action_label != null:
		resident.action_label.text = "Inspecting secluded bedrock..."

func _start_covert_sabotage() -> void:
	resident.velocity = Vector3.ZERO
	state = "COVERT_WORKING"
	covert_action_timer = 2.2
	if resident.has_method("trigger_covert_hunch"):
		resident.trigger_covert_hunch(2.2)
	if resident.action_label != null:
		resident.action_label.text = "Tampering with conduits..."

func _process_covert_working(delta: float) -> void:
	resident.velocity = Vector3.ZERO
	covert_action_timer -= delta

	var observers: Array = get_active_observers(resident.secret_role)
	if not observers.is_empty():
		for obs in observers:
			if game_manager != null and town_map != null:
				var act := "tampering with the station" if covert_mission_type == "SABOTAGE" else "searching a secluded bedrock alcove"
				game_manager.record_observed_sighting_3d(resident, resident.position, town_map, town_map.all_residents, "was caught %s" % act)
		_abort_covert_mission("Caught in the act")
		return

	if covert_action_timer <= 0.0:
		_finish_covert_action()

func _finish_covert_action() -> void:
	if covert_mission_type == "ALCOVE":
		_finish_alcove_search()
	elif covert_mission_type == "SABOTAGE":
		_finish_sabotage()

	covert_mission_type = "NONE"
	covert_target_alcove = {}
	covert_target_pad = {}
	undercover_cooldown = _covert_cooldown_range("completed")
	state = "PAUSE"
	pause_timer = _next_pause_duration()
	if resident.action_label != null:
		resident.action_label.text = ""

func _finish_alcove_search() -> void:
	if town_map == null or covert_target_alcove.is_empty():
		return
	var alc_id: String = String(covert_target_alcove.get("id", ""))
	if not alcoves_checked.has(alc_id):
		alcoves_checked.append(alc_id)
	covert_alcoves_inspected += 1

	var _res_entry: Dictionary = town_map.complete_site_inspection(resident, covert_target_alcove)

	if game_manager != null and game_manager.archive_opened and game_manager.archive_finder_id == resident.resident_id:
		if game_manager.archive_choice == C.ARCHIVE_CHOICE_NONE:
			var choice := C.ARCHIVE_CHOICE_ENTRUST_ECO if resident.secret_role == "ecology" else C.ARCHIVE_CHOICE_ENTRUST_TECH
			game_manager.resolve_player_archive_choice(choice)

func _finish_sabotage() -> void:
	if town_map == null or covert_target_pad.is_empty() or game_manager == null:
		return
	var pad: Dictionary = covert_target_pad
	var pad_id: String = String(pad.get("id", ""))
	var pad_pos: Vector3 = pad.get("position", Vector3.ZERO)
	var region_name: String = town_map.get_region_name_at_3d(pad_pos)
	covert_sabotages_performed += 1

	# Jam station pad
	pad["cooldown"] = 14.0

	# Resource drain
	match pad_id:
		"pump":
			game_manager.water = maxf(0.0, game_manager.water - 3.0)
		"salvage":
			game_manager.scrap = maxi(0, game_manager.scrap - 1)
		"greenhouse":
			game_manager.stability = maxf(0.0, game_manager.stability - 2.0)
			game_manager.water = maxf(0.0, game_manager.water - 1.0)
		"clinic", "common_works", "generator":
			game_manager.stability = maxf(0.0, game_manager.stability - 3.0)

	var stamp: String = game_manager._match_clock_text() if game_manager.has_method("_match_clock_text") else "04:15"
	var trace_txt: String = "Tampered conduit and mechanical sabotage detected at %s." % pad.get("name", "Station")
	game_manager._add_private_evidence(resident.resident_id, C.EVIDENCE_TRACE, trace_txt, region_name, stamp)

	town_map.spawn_field_zone_3d("disturbance_ring", pad_pos, 2.8, 5.0, 0, region_name)

func _abort_covert_mission(_reason: String = "") -> void:
	covert_mission_type = "NONE"
	covert_target_alcove = {}
	covert_target_pad = {}
	undercover_cooldown = _covert_cooldown_range("aborted")
	state = "PAUSE"
	pause_timer = _next_pause_duration()
	resident.velocity = Vector3.ZERO
	path_points.clear()
	if resident.action_label != null:
		resident.action_label.text = "Returning to civic patrol"

# ------------------------------------------------------------------------------
# Standard Civic Chores
# ------------------------------------------------------------------------------
func _start_working() -> void:
	resident.velocity = Vector3.ZERO
	state = "WORKING"
	tasks_visited_count += 1

	var started: bool = resident.try_start_channel()
	if started:
		work_timer = 2.5
		return

	work_timer = bot_rng.randf_range(1.5, 2.5)

func _process_working(delta: float) -> void:
	resident.velocity = Vector3.ZERO
	work_timer -= delta
	if resident.is_channeling:
		return

	state = "PAUSE"
	pause_timer = _next_pause_duration()
	if resident.action_label != null and resident.popup_timer <= 0.0:
		resident.action_label.text = ""

func _shuffle_with_rng(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = bot_rng.randi_range(0, index)
		var item: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = item
