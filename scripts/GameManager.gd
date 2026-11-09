class_name GameManager
extends Node

const C = preload("res://scripts/GameConstants.gd")

signal state_updated
signal phase_changed(new_phase: int)
signal event_logged(message: String, color: Color)
signal sandbox_reset
signal sandbox_finished

enum Phase {
	LOBBY = 0,
	BRIEFING = 1,
	OPEN_TOWN = 2,
	FIRST_COUNCIL = 3,
	ESCALATION = 4,
	COURT = 5,
	FINALE = 6,
	MATCH_OVER = 7
}

const PHASE_DURATIONS: Dictionary = {
	Phase.LOBBY: 0.0,
	Phase.BRIEFING: 25.0,
	Phase.OPEN_TOWN: 360.0,
	Phase.FIRST_COUNCIL: 45.0,
	Phase.ESCALATION: 300.0,
	Phase.COURT: 45.0,
	Phase.FINALE: 210.0,
	Phase.MATCH_OVER: 0.0
}

const MAX_WATER: float = 100.0
const MAX_STABILITY: float = 100.0
const MAX_SCRAP: int = 20
const MAX_COMMON_WORKS: float = 100.0

const BASE_WATER_DRAIN: float = 0.35
const BASE_STABILITY_DRAIN: float = 0.30
const LOW_WATER_STABILITY_DRAIN: float = 0.50

var current_phase: int = Phase.LOBBY
var time_remaining: float = 0.0
var match_elapsed: float = 0.0
var water: float = 75.0
var stability: float = 80.0
var scrap: int = 6
var common_works: float = 0.0
var common_works_eco: float = 0.0
var common_works_tech: float = 0.0
var common_works_struct: float = 0.0

var generator_tech_primed: float = 0.0
var generator_eco_stabilized: float = 0.0
var generator_civilian_calibrated: bool = false
var beacon_eco_freq: float = 0.0
var beacon_tech_freq: float = 0.0

var archive_active_spawn_id: String = ""
var archive_opened: bool = false
var archive_open_time: String = ""
var archive_finder_id: int = -1
var archive_finder_name: String = ""
var archive_finder_role: String = ""
var archive_dilemma_open: bool = false
var archive_choice: String = C.ARCHIVE_CHOICE_NONE
var archive_choice_details: String = ""
var archive_whistleblower_active: bool = false
var archive_loyal_faction: String = ""
var archive_entrust_faction: String = ""
var archive_reserved_for_cw: bool = false

# Milestone 6: Endgame Routes, Strategic Choice & Finale Resolution
var finale_route: String = C.FINALE_ROUTE_NONE
var strategic_decision_active: bool = false
var strategic_timer: float = 15.0
var strategic_decision_resolved: bool = false
var player_strategic_choice: String = C.STRATEGIC_CHOICE_NONE
var eco_faction_decision: String = C.STRATEGIC_CHOICE_NONE
var tech_faction_decision: String = C.STRATEGIC_CHOICE_NONE
var strategic_votes_eco: Dictionary = {}
var strategic_votes_tech: Dictionary = {}

var archive_entrusted_civ_voted_match: bool = false
var generator_tug_meter: float = 50.0
var confrontation_overtime: bool = false
var pending_generator_deltas: Array[float] = []

var charter_modal_open: bool = false
var charter_power: String = C.CHARTER_POWER_LOW
var charter_land: String = C.CHARTER_LAND_OPEN
var charter_med: String = C.CHARTER_MED_AUTOMATED
var charter_eco_ratified: bool = false
var charter_tech_ratified: bool = false
var charter_ratified: bool = false

var holdout_active: bool = false
var holdout_completed: bool = false
var holdout_timer: float = 90.0
var holdout_duration: float = 90.0
var holdout_failed: bool = false
var active_hazards: Array[Dictionary] = []
var hazard_spawn_timer: float = 14.0

var whistleblower_personal_win: bool = false
var whistleblower_summary: String = ""
var loyal_personal_win: bool = false
var civilian_commendation: String = ""

var drain_enabled: bool = true
var is_sandbox_finished: bool = false

# Lobby preferences for solo testing
var player_role_pref: String = "random" # "random", "ecology", "technology", "civilian"
var player_kit_pref_idx: int = 0 # 0=Random, 1=Tracker/Runner, 2=Grower/Mechanic, 3=Warden/Saboteur
var player_job_idx: int = 0 # 0..4 indexing C.CIVIC_JOB_NAMES
var dossier_open: bool = false
var evidence_journal_open: bool = false
var settings_menu_open: bool = false

# Match outcome strings
var match_ending_title: String = ""
var match_ending_subtitle: String = ""
var match_ending_color: Color = Color.WHITE
var court_preview_mode: String = "2-2" # "2-2", "3-1_eco", "3-1_tech", "4-0_eco", "4-0_tech"
var court_is_unanimous: bool = false
var court_unanimous_winner: String = ""
var court_preview_votes: Array[Dictionary] = []
var court_alignment_summary: String = ""
var court_split_summary: String = "0-0"

# Sequential Court ceremony state (Milestone 7)
var court_ceremony_active: bool = false
var court_voter_index: int = 0 # 0..3 indexing the 4 civilians
var court_turn_timer: float = 6.0
var court_turn_duration: float = 6.0
var court_civilians: Array[Node] = []
var court_ballot_records: Array[Dictionary] = [] # [{name, job, vote, reason, defaulted, resident_id}]
var court_active_speaker_name: String = ""
var court_active_speaker_reason: String = ""
var court_fast_forward: bool = false
var court_bot_deliberation_delay: float = 2.5

# Milestone 8 Playtest & Tuning overrides
var dev_panel_open: bool = false
var crisis_drain_scale: float = 1.0

# Telemetry for summary
var total_tasks_completed: int = 0
var player_tasks_completed: int = 0
var bot_tasks_completed: int = 0
var shoves_used: int = 0
var civic_abilities_used: int = 0
var faction_abilities_used: int = 0
var witnessed_disturbances: int = 0
var knockdowns_triggered: int = 0
var peak_common_works: float = 0.0
var critical_seconds: float = 0.0

var recent_events: Array[Dictionary] = []
var session_residents: Array = []

# Milestone 4 evidence is private by resident until its owner tables it at Council.
var evidence_journals: Dictionary = {}
var tabled_evidence: Array[Dictionary] = []
var region_samples: Dictionary = {}
var alibi_statements: Dictionary = {}
var alibi_conflicts: Array[Dictionary] = []
var player_alibi_region: String = ""
var player_alibi_selected: bool = false
var council_ballots: Array[int] = []
var player_motion_vote: int = 1
var council_motion_winner: int = 0
var council_motion_resolved: bool = false
var council_motion_applied: bool = false
var sensor_beacons_active: bool = false
var crop_remediation_active: bool = false
var station_beacon_logs: Array[Dictionary] = []

func _ready() -> void:
	enter_lobby()

func enter_lobby() -> void:
	current_phase = Phase.LOBBY
	time_remaining = 0.0
	match_elapsed = 0.0
	water = 75.0
	stability = 80.0
	scrap = 6
	common_works = 0.0
	common_works_eco = 0.0
	common_works_tech = 0.0
	common_works_struct = 0.0
	generator_tech_primed = 0.0
	generator_eco_stabilized = 0.0
	generator_civilian_calibrated = false
	beacon_eco_freq = 0.0
	beacon_tech_freq = 0.0
	archive_opened = false
	archive_open_time = ""
	archive_finder_id = -1
	archive_finder_name = ""
	archive_finder_role = ""
	archive_dilemma_open = false
	archive_choice = C.ARCHIVE_CHOICE_NONE
	archive_choice_details = ""
	archive_whistleblower_active = false
	archive_loyal_faction = ""
	archive_entrust_faction = ""
	archive_reserved_for_cw = false
	is_sandbox_finished = false
	dossier_open = false
	evidence_journal_open = false
	total_tasks_completed = 0
	player_tasks_completed = 0
	bot_tasks_completed = 0
	shoves_used = 0
	civic_abilities_used = 0
	faction_abilities_used = 0
	witnessed_disturbances = 0
	knockdowns_triggered = 0
	peak_common_works = 0.0
	critical_seconds = 0.0
	court_preview_votes.clear()
	court_alignment_summary = ""
	recent_events.clear()
	_reset_evidence_state()
	_reset_milestone_6_state()
	session_residents.clear()
	log_event("Lobby ready: Choose Role [1-4], Operative Kit [5], Civic Job [6], then Start [Space].", Color(0.75, 0.88, 1.0))
	phase_changed.emit(current_phase)
	state_updated.emit()

func cycle_player_kit_pref() -> void:
	player_kit_pref_idx = (player_kit_pref_idx + 1) % 4
	state_updated.emit()

func get_player_kit_pref_label() -> String:
	match player_kit_pref_idx:
		0:
			return "[5] Operative Kit: Random (1 of 3)"
		1:
			return "[5] Operative Kit: Tracker (Eco) / Runner (Tech)"
		2:
			return "[5] Operative Kit: Grower (Eco) / Mechanic (Tech)"
		3:
			return "[5] Operative Kit: Warden (Eco) / Saboteur (Tech)"
	return "[5] Operative Kit: Random"

func cycle_player_civic_job(residents: Array) -> void:
	if residents.is_empty():
		return
	player_job_idx = (player_job_idx + 1) % C.CIVIC_JOB_NAMES.size()
	var new_job: String = C.CIVIC_JOB_NAMES[player_job_idx]
	var old_job: String = residents[0].civic_job
	if new_job == old_job:
		return
	# Swap with the first bot (in slots 1..4) that currently has new_job so 2x5 job balance stays exact
	for i in range(1, residents.size()):
		if residents[i] != null and residents[i].civic_job == new_job:
			residents[i].civic_job = old_job
			break
	residents[0].civic_job = new_job
	state_updated.emit()

func start_match(residents: Array) -> void:
	water = 75.0
	stability = 80.0
	scrap = 6
	common_works = 0.0
	common_works_eco = 0.0
	common_works_tech = 0.0
	common_works_struct = 0.0
	generator_tech_primed = 0.0
	generator_eco_stabilized = 0.0
	generator_civilian_calibrated = false
	beacon_eco_freq = 0.0
	beacon_tech_freq = 0.0
	archive_opened = false
	archive_open_time = ""
	archive_finder_id = -1
	archive_finder_name = ""
	archive_finder_role = ""
	archive_dilemma_open = false
	archive_choice = C.ARCHIVE_CHOICE_NONE
	archive_choice_details = ""
	archive_whistleblower_active = false
	archive_loyal_faction = ""
	archive_entrust_faction = ""
	archive_reserved_for_cw = false

	# Pick 1 of 4 secluded cache spawns for the match
	var spawns: Array = C.ARCHIVE_CACHE_SPAWNS.duplicate()
	spawns.shuffle()
	archive_active_spawn_id = String(spawns[0]["id"])

	match_elapsed = 0.0
	is_sandbox_finished = false
	total_tasks_completed = 0
	player_tasks_completed = 0
	bot_tasks_completed = 0
	shoves_used = 0
	civic_abilities_used = 0
	faction_abilities_used = 0
	witnessed_disturbances = 0
	knockdowns_triggered = 0
	peak_common_works = 0.0
	critical_seconds = 0.0
	recent_events.clear()
	_reset_evidence_state()
	_reset_milestone_6_state()
	session_residents = residents
	evidence_journal_open = false
	for res in residents:
		if res != null:
			evidence_journals[int(res.resident_id)] = {"observed": [], "traces": []}
			region_samples[int(res.resident_id)] = {}

	assign_roles(residents)
	set_phase(Phase.BRIEFING)
	dossier_open = true
	log_event("Match started: 3 Ecology, 3 Technology, 4 Civilians + unique kits assigned.", Color(0.65, 0.95, 0.78))
	sandbox_reset.emit()

func assign_roles(residents: Array) -> void:
	var pool: Array[String] = [
		"ecology", "ecology", "ecology",
		"technology", "technology", "technology",
		"civilian", "civilian", "civilian", "civilian"
	]

	if player_role_pref != "random" and pool.has(player_role_pref) and not residents.is_empty():
		var idx := pool.find(player_role_pref)
		pool.remove_at(idx)
		pool.shuffle()
		residents[0].secret_role = player_role_pref
		for i in range(1, residents.size()):
			residents[i].secret_role = pool[i - 1]
	else:
		pool.shuffle()
		for i in range(residents.size()):
			residents[i].secret_role = pool[i]

	# Assign the 3 Ecology Kits and 3 Technology Kits (1 unique kit per operative)
	var eco_kits: Array[String] = C.ECOLOGY_KITS.duplicate()
	var tech_kits: Array[String] = C.TECHNOLOGY_KITS.duplicate()
	eco_kits.shuffle()
	tech_kits.shuffle()

	if not residents.is_empty() and player_kit_pref_idx > 0:
		var p_role: String = residents[0].secret_role
		if p_role == "ecology":
			var forced_eco: String = C.ECOLOGY_KITS[mini(player_kit_pref_idx - 1, 2)]
			eco_kits.erase(forced_eco)
			eco_kits.push_front(forced_eco)
		elif p_role == "technology":
			var forced_tech: String = C.TECHNOLOGY_KITS[mini(player_kit_pref_idx - 1, 2)]
			tech_kits.erase(forced_tech)
			tech_kits.push_front(forced_tech)

	var e_i := 0
	var t_i := 0
	for res in residents:
		if res == null:
			continue
		match res.secret_role:
			"ecology":
				res.operative_kit = eco_kits[mini(e_i, eco_kits.size() - 1)]
				e_i += 1
			"technology":
				res.operative_kit = tech_kits[mini(t_i, tech_kits.size() - 1)]
				t_i += 1
			_:
				res.operative_kit = "none"

func get_partner_names_for(resident: Node, all_residents: Array) -> Array[String]:
	var partners: Array[String] = []
	if resident == null:
		return partners
	var role: String = resident.get("secret_role")
	if role != "ecology" and role != "technology":
		return partners
	for other in all_residents:
		if other != null and other != resident and other.get("secret_role") == role:
			var o_kit: String = other.get("operative_kit")
			var kit_info: Dictionary = C.OPERATIVE_KIT_INFO.get(o_kit, {})
			var kit_title: String = kit_info.get("kit_title", "Operative")
			partners.append("%s — Public Job: %s • Operative Kit: %s" % [other.get("resident_name"), other.get("civic_job"), kit_title])
	return partners

func get_role_display_name(role: String) -> String:
	match role:
		"ecology":
			return "ECOLOGY OPERATIVE"
		"technology":
			return "TECHNOLOGY OPERATIVE"
		"civilian":
			return "UNAFFILIATED CIVILIAN"
	return "RESIDENT"

func get_phase_name(phase: int = current_phase) -> String:
	match phase:
		Phase.LOBBY:
			return "PRE-MATCH LOBBY"
		Phase.BRIEFING:
			return "PHASE 1: TOWN BRIEFING"
		Phase.OPEN_TOWN:
			return "PHASE 2: OPEN TOWN"
		Phase.FIRST_COUNCIL:
			return "PHASE 3: FIRST COUNCIL"
		Phase.ESCALATION:
			return "PHASE 4: ESCALATION"
		Phase.COURT:
			return "PHASE 5: CIVILIAN COURT"
		Phase.FINALE:
			return "PHASE 6: FINALE"
		Phase.MATCH_OVER:
			return "MATCH COMPLETE"
	return "UNKNOWN"

func is_active_play_phase() -> bool:
	return current_phase == Phase.OPEN_TOWN or current_phase == Phase.ESCALATION or current_phase == Phase.FINALE

func is_faction_kit_unlocked_openly() -> bool:
	return current_phase == Phase.ESCALATION or current_phase == Phase.FINALE

func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	time_remaining = PHASE_DURATIONS.get(new_phase, 0.0)
	is_sandbox_finished = (new_phase == Phase.MATCH_OVER)

	match new_phase:
		Phase.BRIEFING:
			dossier_open = true
			log_event("Town Briefing: Review your private dossier [B]. Press [Space] or [N] when ready.", Color(0.78, 0.88, 1.0))
		Phase.OPEN_TOWN:
			dossier_open = false
			log_event("Open Town (6:00): Civic kits [F] active. Early [C] use risks witness clues!", Color(0.65, 0.92, 0.75))
		Phase.FIRST_COUNCIL:
			dossier_open = false
			log_event("First Council (0:45): All residents gathered at the Council Ring.", Color(0.98, 0.86, 0.48))
		Phase.ESCALATION:
			_apply_council_motion()
			dossier_open = false
			log_event("Escalation (5:00): Crisis drain x1.25! Operative kits [C] unlocked for open contest!", Color(1.0, 0.68, 0.45))
		Phase.COURT:
			dossier_open = false
			log_event("Civilian Court (0:45): The 4 Unaffiliated Civilians step forward to align.", Color(0.95, 0.82, 1.0))
			start_sequential_court_ceremony()
		Phase.FINALE:
			dossier_open = false
			charter_modal_open = false
			if finale_route == C.FINALE_ROUTE_CONFRONTATION:
				generator_tug_meter = clampf(50.0 + 0.25 * (generator_tech_primed - generator_eco_stabilized), 20.0, 80.0)
				time_remaining = PHASE_DURATIONS[Phase.FINALE]
				log_event("Finale (Confrontation): Battle for Buried Generator begins! Meter at %d%%." % int(generator_tug_meter), Color(1.0, 0.60, 0.45))
			elif finale_route == C.FINALE_ROUTE_PEACE:
				time_remaining = PHASE_DURATIONS[Phase.FINALE]
				charter_eco_ratified = false
				charter_tech_ratified = false
				charter_ratified = false
				holdout_active = false
				holdout_completed = false
				holdout_failed = false
				active_hazards.clear()
				log_event("Finale (Peace): Ratify Charter at West (Eco) & East (Tech) Common Works consoles.", Color(0.65, 0.95, 0.75))
			else:
				log_event("Finale (3:30): Final struggle over town systems and the Common Works!", Color(1.0, 0.58, 0.52))
		Phase.MATCH_OVER:
			dossier_open = false
			charter_modal_open = false
			strategic_decision_active = false
			_evaluate_match_outcome()
			sandbox_finished.emit()

	phase_changed.emit(current_phase)
	state_updated.emit()

func advance_to_next_phase() -> void:
	match current_phase:
		Phase.LOBBY:
			return
		Phase.BRIEFING:
			set_phase(Phase.OPEN_TOWN)
		Phase.OPEN_TOWN:
			set_phase(Phase.FIRST_COUNCIL)
		Phase.FIRST_COUNCIL:
			_resolve_council_vote()
			set_phase(Phase.ESCALATION)
		Phase.ESCALATION:
			set_phase(Phase.COURT)
		Phase.COURT:
			if court_is_unanimous:
				set_phase(Phase.MATCH_OVER)
			else:
				start_strategic_decision()
		Phase.FINALE:
			if finale_route == C.FINALE_ROUTE_PEACE and (not charter_ratified or holdout_active or not holdout_completed):
				trigger_failed_peace_fallback()
				return
			set_phase(Phase.MATCH_OVER)
		Phase.MATCH_OVER:
			enter_lobby()

func _reset_evidence_state() -> void:
	evidence_journals.clear()
	tabled_evidence.clear()
	region_samples.clear()
	alibi_statements.clear()
	alibi_conflicts.clear()
	player_alibi_region = ""
	player_alibi_selected = false
	council_ballots.clear()
	player_motion_vote = 1
	council_motion_winner = 0
	council_motion_resolved = false
	council_motion_applied = false
	sensor_beacons_active = false
	crop_remediation_active = false
	station_beacon_logs.clear()

func _reset_milestone_6_state() -> void:
	finale_route = C.FINALE_ROUTE_NONE
	strategic_decision_active = false
	strategic_timer = 15.0
	strategic_decision_resolved = false
	player_strategic_choice = C.STRATEGIC_CHOICE_NONE
	eco_faction_decision = C.STRATEGIC_CHOICE_NONE
	tech_faction_decision = C.STRATEGIC_CHOICE_NONE
	strategic_votes_eco.clear()
	strategic_votes_tech.clear()
	archive_entrusted_civ_voted_match = false
	generator_tug_meter = 50.0
	confrontation_overtime = false
	pending_generator_deltas.clear()
	charter_modal_open = false
	charter_power = C.CHARTER_POWER_LOW
	charter_land = C.CHARTER_LAND_OPEN
	charter_med = C.CHARTER_MED_AUTOMATED
	charter_eco_ratified = false
	charter_tech_ratified = false
	charter_ratified = false
	holdout_active = false
	holdout_completed = false
	holdout_timer = 90.0
	holdout_duration = 90.0
	holdout_failed = false
	active_hazards.clear()
	hazard_spawn_timer = 14.0
	whistleblower_personal_win = false
	whistleblower_summary = ""
	loyal_personal_win = false
	civilian_commendation = ""

func _match_clock_text(seconds_left: float = time_remaining) -> String:
	var mins: int = int(seconds_left) / 60
	var secs: int = int(seconds_left) % 60
	return "%02d:%02d" % [mins, secs]

func get_current_phase_clock_text() -> String:
	return _match_clock_text()

func record_region_sample(resident: Node, region_name: String) -> void:
	if current_phase != Phase.OPEN_TOWN or time_remaining > 240.0 or time_remaining < 180.0 or resident == null:
		return
	var id: int = int(resident.resident_id)
	if not region_samples.has(id):
		region_samples[id] = {}
	var counts: Dictionary = region_samples[id]
	counts[region_name] = int(counts.get(region_name, 0)) + 1
	region_samples[id] = counts

func record_resident_region_sample(resident_id: int, region_name: String) -> void:
	if current_phase != Phase.OPEN_TOWN or time_remaining > 240.0 or time_remaining < 180.0:
		return
	if not region_samples.has(resident_id):
		region_samples[resident_id] = {}
	var counts: Dictionary = region_samples[resident_id]
	counts[region_name] = int(counts.get(region_name, 0)) + 1
	region_samples[resident_id] = counts

func record_observed_sighting(subject: Node, location: Vector2, town_map: Node2D, residents: Array, event_label: String = "was seen") -> void:
	if subject == null or town_map == null:
		return
	var region_name: String = town_map.get_region_name_at(location)
	var remaining: float = time_remaining

	# Validate active phase for recording sightings:
	# 1) Open Town: strictly recorded during the 04:00-03:00 alibi countdown interval
	# 2) Escalation and Finale: recorded across the phase for tactical site awareness & Beacon sightlines
	var is_valid_phase: bool = false
	if current_phase == Phase.OPEN_TOWN:
		if remaining <= 240.0 and remaining >= 180.0:
			is_valid_phase = true
	elif current_phase == Phase.ESCALATION or current_phase == Phase.FINALE:
		is_valid_phase = true

	if not is_valid_phase:
		return

	for observer in residents:
		if observer == null or observer == subject or observer.is_incapacitated:
			continue
		var obs_allegiance: String = get_resident_alignment(observer)
		var base_radius: float = 26.0 if (observer is Node3D) else C.WITNESS_RADIUS
		var max_dist: float = base_radius * get_beacon_sightline_buff(obs_allegiance)
		if observer.global_position.distance_to(location) > max_dist:
			continue
		if not town_map.has_clear_sightline(observer.global_position, location):
			continue
		_add_private_evidence(
			int(observer.resident_id), C.EVIDENCE_FACT,
			"%s %s in %s at %s." % [subject.resident_name, event_label, region_name, _match_clock_text()],
			region_name, _match_clock_text(), subject.resident_name, remaining
		)

func record_observed_sighting_3d(subject: Node, location: Vector3, town_map_3d: Node, residents: Array, event_label: String = "was seen") -> void:
	if subject == null or town_map_3d == null:
		return
	var region_name: String = town_map_3d.get_region_name_at_3d(location) if town_map_3d.has_method("get_region_name_at_3d") else "Town Corridors"
	var remaining: float = time_remaining

	# Validate active phase for recording sightings:
	# 1) Open Town: strictly recorded during the 04:00-03:00 alibi countdown interval
	# 2) Escalation and Finale: recorded across the phase for tactical site awareness & Beacon sightlines
	var is_valid_phase: bool = false
	if current_phase == Phase.OPEN_TOWN:
		if remaining <= 240.0 and remaining >= 180.0:
			is_valid_phase = true
	elif current_phase == Phase.ESCALATION or current_phase == Phase.FINALE:
		is_valid_phase = true

	if not is_valid_phase:
		return

	for observer in residents:
		if observer == null or observer == subject or observer.is_incapacitated:
			continue
		var obs_allegiance: String = get_resident_alignment(observer)
		var base_radius: float = 26.0 if (observer is Node3D) else C.WITNESS_RADIUS
		var max_dist: float = base_radius * get_beacon_sightline_buff(obs_allegiance)
		var obs_pos: Vector3 = (observer.global_position if observer.is_inside_tree() else observer.position) if (observer is Node3D) else Vector3.ZERO
		if obs_pos.distance_to(location) > max_dist:
			continue
		if town_map_3d.has_method("has_clear_sightline_3d"):
			if not town_map_3d.has_clear_sightline_3d(obs_pos, location):
				continue
		_add_private_evidence(
			int(observer.resident_id), C.EVIDENCE_FACT,
			"%s %s in %s at %s." % [subject.resident_name, event_label, region_name, _match_clock_text()],
			region_name, _match_clock_text(), subject.resident_name, remaining
		)

func _add_private_evidence(resident_id: int, tier: String, message: String, region_name: String, clock_text: String, subject_name: String = "", clock_value: float = -1.0) -> Dictionary:
	if not evidence_journals.has(resident_id):
		evidence_journals[resident_id] = {"observed": [], "traces": []}
	var journal: Dictionary = evidence_journals[resident_id]
	var bucket: String = "traces" if tier == C.EVIDENCE_TRACE else "observed"
	var existing: Array = journal[bucket]
	for saved in existing:
		if String(saved.get("tier", "")) == tier and String(saved.get("text", "")) == message:
			return saved
	var item := {
		"id": "%d:%d" % [resident_id, Time.get_ticks_usec()],
		"tier": tier,
		"text": message,
		"region": region_name,
		"time": clock_text,
		"subject": subject_name,
		"clock_value": clock_value,
		"owner_id": resident_id,
		"tabled": false
	}
	var entries: Array = journal[bucket]
	entries.append(item)
	journal[bucket] = entries
	evidence_journals[resident_id] = journal
	state_updated.emit()
	return item

func add_personal_observed_fact(resident_id: int, message: String, region_name: String, clock_text: String = "") -> void:
	var stamp: String = clock_text if clock_text != "" else _match_clock_text()
	_add_private_evidence(resident_id, C.EVIDENCE_FACT, message, region_name, stamp, "", time_remaining)

func add_private_trace(resident_id: int, message: String, region_name: String, clock_text: String) -> Dictionary:
	return _add_private_evidence(resident_id, C.EVIDENCE_TRACE, message, region_name, clock_text)

func add_public_observed_fact(message: String, region_name: String, clock_text: String = "") -> void:
	var stamp: String = clock_text if clock_text != "" else _match_clock_text()
	for id_variant in evidence_journals.keys():
		_add_private_evidence(int(id_variant), C.EVIDENCE_FACT, message, region_name, stamp)
	log_event("[OBSERVED FACT] " + message, Color(1.0, 0.78, 0.36))

func get_player_journal(resident_id: int) -> Dictionary:
	return evidence_journals.get(resident_id, {"observed": [], "traces": []})

func table_player_clues(resident_id: int, table_all: bool = false, ignore_phase: bool = false, protected_subject_names: Array[String] = [], announce: bool = true) -> int:
	if not ignore_phase and current_phase != Phase.FIRST_COUNCIL:
		return 0
	var journal: Dictionary = get_player_journal(resident_id)
	var added: int = 0
	for bucket in ["observed", "traces"]:
		var entries: Array = journal.get(bucket, [])
		for item in entries:
			if bool(item.get("tabled", false)):
				continue
			var subject: String = String(item.get("subject", ""))
			var text: String = String(item.get("text", ""))
			var protects_partner: bool = false
			for protected_name in protected_subject_names:
				if protected_name == "":
					continue
				if subject == protected_name or text.contains(protected_name):
					protects_partner = true
					break
			if protects_partner:
				continue
			item["tabled"] = true
			tabled_evidence.append(item.duplicate(true))
			added += 1
			if not table_all:
				break
		journal[bucket] = entries
		if not table_all and added > 0:
			break
	evidence_journals[resident_id] = journal
	if added > 0 and announce:
		log_event("You tabled %d evidence item%s at First Council." % [added, "" if added == 1 else "s"], Color(0.55, 0.90, 1.0))
	if added > 0:
		update_alibi_conflicts(session_residents)
	state_updated.emit()
	return added

func table_clue_by_id(resident_id: int, item_id: String, ignore_phase: bool = false) -> bool:
	if not ignore_phase and current_phase != Phase.FIRST_COUNCIL:
		return false
	var journal: Dictionary = get_player_journal(resident_id)
	for bucket in ["observed", "traces"]:
		var entries: Array = journal.get(bucket, [])
		for item in entries:
			if String(item.get("id", "")) != item_id or bool(item.get("tabled", false)):
				continue
			item["tabled"] = true
			tabled_evidence.append(item.duplicate(true))
			journal[bucket] = entries
			evidence_journals[resident_id] = journal
			update_alibi_conflicts(session_residents)
			state_updated.emit()
			return true
	return false

func prepare_first_council(residents: Array, town_map: Node) -> void:
	tabled_evidence.clear()
	alibi_statements.clear()
	alibi_conflicts.clear()
	council_ballots.clear()
	council_motion_resolved = false
	player_motion_vote = 1
	player_alibi_selected = false
	var player_id: int = int(residents[0].resident_id) if not residents.is_empty() else -1
	var bot_evidence_count: int = 0

	# Reset private 'tabled' flags for player's journal so no clues are locked out
	if player_id != -1 and evidence_journals.has(player_id):
		var p_j: Dictionary = evidence_journals[player_id]
		for bucket in ["observed", "traces"]:
			for item in p_j.get(bucket, []):
				item["tabled"] = false

	for resident in residents:
		if resident == null:
			continue
		var id: int = int(resident.resident_id)
		var counts: Dictionary = region_samples.get(id, {})
		var r_pos: Variant = (resident.global_position if resident.is_inside_tree() else resident.position) if (resident is Node3D or resident is Node2D) else Vector2.ZERO
		var claim_region: String = town_map.get_region_name_at(r_pos)
		var best_count: int = -1
		for region in counts.keys():
			if int(counts[region]) > best_count:
				best_count = int(counts[region])
				claim_region = String(region)
		if resident.is_player:
			player_alibi_region = claim_region
		# Operative bots deliberately use their civic cover job's home sector as their claim
		if not resident.is_player and resident.secret_role != "civilian":
			var civic_home := _get_civic_home_region(resident.civic_job)
			if civic_home != "":
				claim_region = civic_home
		alibi_statements[id] = {"resident": resident.resident_name, "region": claim_region, "text": "Between 04:00 and 03:00, I was in %s." % claim_region}
		# Bots share clues, but operatives withhold evidence identifying known partners.
		if id != player_id:
			var protected_names: Array[String] = []
			if resident.secret_role == "ecology" or resident.secret_role == "technology":
				for other in residents:
					if other != null and other != resident and other.secret_role == resident.secret_role:
						protected_names.append(String(other.resident_name))
			bot_evidence_count += table_player_clues(id, true, true, protected_names, false)
	if bot_evidence_count > 0:
		log_event("AI residents shared evidence at First Council.", Color(0.55, 0.90, 1.0))
	# Claims are public at Council and clearly labeled as unverified.
	for resident in residents:
		if resident == null:
			continue
		var statement: Dictionary = alibi_statements.get(int(resident.resident_id), {})
		var claim_item := {
			"id": "claim:%d" % int(resident.resident_id),
			"tier": C.EVIDENCE_CLAIM,
			"text": "%s states: %s" % [resident.resident_name, statement.get("text", "")],
			"region": statement.get("region", ""),
			"time": "04:00-03:00",
			"subject": resident.resident_name,
			"clock_value": 210.0,
			"owner_id": int(resident.resident_id),
			"tabled": true
		}
		tabled_evidence.append(claim_item)
		for journal_id_variant in evidence_journals.keys():
			var journal: Dictionary = evidence_journals[int(journal_id_variant)]
			var observed: Array = journal.get("observed", [])
			observed.append(claim_item.duplicate(true))
			journal["observed"] = observed
			evidence_journals[int(journal_id_variant)] = journal
	for resident in residents:
		if resident != null and not resident.is_player:
			var bot_controller: Node = resident.get("bot_controller")
			if bot_controller != null and bot_controller.has_method("refresh_personal_memory"):
				bot_controller.refresh_personal_memory()
	# Ballots for bots are stable and resource-weighted; the player casts a ballot separately.
	for resident in residents:
		if resident == null:
			continue
		if resident.is_player:
			council_ballots.append(0)
		else:
			council_ballots.append(_bot_motion_ballot(resident))
	update_alibi_conflicts(residents)
	state_updated.emit()

func _bot_motion_ballot(resident: Node) -> int:
	var low_water: float = maxf(0.0, (55.0 - water) / 30.0)
	var low_scrap: float = maxf(0.0, (6.0 - float(scrap)) / 5.0)
	var low_stability: float = maxf(0.0, (60.0 - stability) / 30.0)
	var scores: Array[float] = [0.15 + low_water, 0.15 + low_scrap + (0.35 if common_works < 50.0 else 0.0), 0.15 + low_stability]
	# Slight preference diversity makes the 9-bot ballot responsive instead of unanimous.
	if resident.secret_role == "ecology":
		scores[2] += 0.10
	elif resident.secret_role == "technology":
		scores[1] += 0.10
	return scores.find(scores.max()) + 1

func cast_player_motion_vote(motion_id: int) -> void:
	player_motion_vote = clampi(motion_id, 1, 3)
	var player_index: int = council_ballots.find(0)
	if player_index >= 0:
		council_ballots[player_index] = player_motion_vote
	else:
		# Locate player in session_residents to allow changing vote during deliberations
		for i in range(session_residents.size()):
			if session_residents[i] != null and session_residents[i].is_player:
				if i < council_ballots.size():
					council_ballots[i] = player_motion_vote
				break
	state_updated.emit()

func get_council_motion_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for ballot in council_ballots:
		if ballot >= 1 and ballot <= 3:
			counts[ballot - 1] += 1
		elif ballot == 0 and player_motion_vote >= 1 and player_motion_vote <= 3:
			counts[player_motion_vote - 1] += 1
	return counts

func get_council_motion_info(motion_id: int) -> Dictionary:
	match motion_id:
		1:
			return {
				"id": 1,
				"title": "Station Watch Beacons",
				"desc": "Deploys surveillance sensors at Pump Station & Greenhouse. Logs station accesses during Escalation into all evidence journals.",
				"effect": "Station surveillance & alibi logging"
			}
		2:
			return {
				"id": 2,
				"title": "Emergency Scrap Subsidy",
				"desc": "Requisitions emergency industrial reserves, adding +3 Scrap to town stockpiles immediately at Escalation.",
				"effect": "+3 Scrap to town reserves"
			}
		3:
			return {
				"id": 3,
				"title": "Crop Blight Remediation",
				"desc": "Mandates emergency soil conditioning, reducing town stability drain by 25% during Escalation.",
				"effect": "-25% Stability crisis decay"
			}
	return {}

func set_player_alibi_region(region_name: String, player_id: int, residents: Array) -> void:
	player_alibi_region = region_name
	player_alibi_selected = true
	var player_name: String = "Resident 1"
	for resident in residents:
		if resident != null and int(resident.resident_id) == player_id:
			player_name = resident.resident_name
	alibi_statements[player_id] = {"resident": player_name, "region": region_name, "text": "Between 04:00 and 03:00, I was in %s." % region_name}
	var new_claim: String = "%s states: Between 04:00 and 03:00, I was in %s." % [player_name, region_name]
	for journal_id_variant in evidence_journals.keys():
		var journal: Dictionary = evidence_journals[int(journal_id_variant)]
		var observed: Array = journal.get("observed", [])
		for item in observed:
			if String(item.get("id", "")) == "claim:%d" % player_id:
				item["text"] = new_claim
				item["region"] = region_name
		journal["observed"] = observed
		evidence_journals[int(journal_id_variant)] = journal
	for item in tabled_evidence:
		if String(item.get("id", "")) == "claim:%d" % player_id:
			item["text"] = new_claim
			item["region"] = region_name
	update_alibi_conflicts(residents)
	state_updated.emit()

func update_alibi_conflicts(residents: Array) -> void:
	alibi_conflicts.clear()
	for resident in residents:
		if resident == null:
			continue
		var statement: Dictionary = alibi_statements.get(int(resident.resident_id), {})
		if statement.is_empty():
			continue
		for entry in tabled_evidence:
			if String(entry.get("tier", "")) != C.EVIDENCE_FACT:
				continue
			if String(entry.get("subject", "")) != resident.resident_name:
				continue
			var clock_value: float = float(entry.get("clock_value", -1.0))
			if clock_value <= 180.0 or clock_value > 240.0:
				continue
			if String(entry.get("region", "")) != String(statement.get("region", "")):
				alibi_conflicts.append({"resident": resident.resident_name, "claim": statement.get("region", ""), "seen": entry.get("region", ""), "time": entry.get("time", "")})
				break

func _get_civic_home_region(job: String) -> String:
	match job:
		"Pump Technician":
			return "Pump & Generator Station"
		"Crop Tender":
			return "Greenhouse & Fields"
		"Salvage Quartermaster":
			return "Salvage Yard"
		"Field Medic":
			return "Town Square"
		"Town Watch":
			return "Town Square"
	return "Town Square"

func _resolve_council_vote() -> void:
	if council_motion_resolved:
		return
	if council_ballots.size() != 10:
		while council_ballots.size() < 10:
			council_ballots.append(2)
	cast_player_motion_vote(player_motion_vote)
	var counts: Array[int] = [0, 0, 0]
	for ballot in council_ballots:
		if ballot >= 1 and ballot <= 3:
			counts[ballot - 1] += 1
	var max_count: int = maxi(counts[0], maxi(counts[1], counts[2]))
	var tied: Array[int] = []
	for i in range(3):
		if counts[i] == max_count:
			tied.append(i + 1)
	if tied.size() == 1:
		council_motion_winner = tied[0]
	else:
		if water <= 40.0 and tied.has(1):
			council_motion_winner = 1
		elif scrap <= 2 and tied.has(2):
			council_motion_winner = 2
		elif stability <= 40.0 and tied.has(3):
			council_motion_winner = 3
		elif tied.has(player_motion_vote):
			council_motion_winner = player_motion_vote
		else:
			council_motion_winner = tied[0]
	council_motion_resolved = true
	log_event("Council vote: Motion 1 %d | Motion 2 %d | Motion 3 %d. Motion %d wins." % [counts[0], counts[1], counts[2], council_motion_winner], Color(0.90, 0.84, 0.56))
	state_updated.emit()

func _apply_council_motion() -> void:
	if council_motion_winner <= 0 or council_motion_applied:
		return
	council_motion_applied = true
	match council_motion_winner:
		1:
			sensor_beacons_active = true
			log_event("Station Watch Beacons active at Pump Station and Greenhouse.", Color(0.92, 0.78, 0.42))
		2:
			var gained: int = mini(3, MAX_SCRAP - scrap)
			scrap += gained
			log_event("Emergency Scrap Subsidy added +%d Scrap." % gained, Color(0.92, 0.78, 0.42))
		3:
			crop_remediation_active = true
			log_event("Crop Blight Remediation reduces Escalation stability drain by 25%%.", Color(0.65, 0.92, 0.58))

func record_beacon_access(resident: Node, region_name: String, site_name: String) -> void:
	if not sensor_beacons_active or current_phase != Phase.ESCALATION or resident == null:
		return
	var stamp: String = _match_clock_text()
	var message: String = "%s accessed %s at %s." % [resident.resident_name, site_name, region_name]
	station_beacon_logs.append({"resident": resident.resident_name, "region": region_name, "site": site_name, "time": stamp})
	for id_variant in evidence_journals.keys():
		_add_private_evidence(int(id_variant), C.EVIDENCE_FACT, message, region_name, stamp)
	log_event("[OBSERVED FACT] [BEACON LOG] " + message, Color(1.0, 0.78, 0.36))

func record_inspection_complete(resident: Node, target: Dictionary, _trace: Dictionary, town_map: Node2D, residents: Array) -> void:
	if resident == null:
		return
	log_event("Site inspection completed at %s." % String(target.get("label", "site")), Color(0.48, 0.90, 1.0))
	if town_map != null:
		record_observed_sighting(resident, target.get("pos", resident.global_position), town_map, residents, "inspected a site in")
	state_updated.emit()

func set_court_preview_mode(mode: String, residents: Array) -> void:
	court_preview_mode = mode
	prepare_court_preview(residents)
	state_updated.emit()

func prepare_court_preview(residents: Array) -> void:
	court_preview_votes.clear()
	court_is_unanimous = false
	court_unanimous_winner = ""

	var pattern: Array[String] = ["Ecology", "Technology", "Ecology", "Technology"]
	match court_preview_mode:
		"2-2":
			pattern = ["Ecology", "Technology", "Ecology", "Technology"]
		"3-1_eco":
			pattern = ["Ecology", "Ecology", "Technology", "Ecology"]
		"3-1_tech":
			pattern = ["Technology", "Technology", "Ecology", "Technology"]
		"4-0_eco":
			pattern = ["Ecology", "Ecology", "Ecology", "Ecology"]
			court_is_unanimous = true
			court_unanimous_winner = "ecology"
		"4-0_tech":
			pattern = ["Technology", "Technology", "Technology", "Technology"]
			court_is_unanimous = true
			court_unanimous_winner = "technology"

	var eco_votes := 0
	var tech_votes := 0
	var civ_idx := 0
	for res in residents:
		if res != null and res.get("secret_role") == "civilian":
			var pick: String = pattern[mini(civ_idx, pattern.size() - 1)]
			civ_idx += 1
			if pick == "Ecology":
				eco_votes += 1
			else:
				tech_votes += 1
			court_preview_votes.append({
				"name": res.get("resident_name"),
				"job": res.get("civic_job"),
				"vote": pick
			})

	# Milestone 6: Derive Archive Entrusted civilian bonus directly from their simulated ballot
	archive_entrusted_civ_voted_match = false
	if archive_entrust_faction != "":
		for entry in court_preview_votes:
			if entry.get("name") == archive_finder_name:
				if String(entry.get("vote", "")).to_lower() == archive_entrust_faction.to_lower():
					archive_entrusted_civ_voted_match = true
				break

	var total_eco := 3 + eco_votes
	var total_tech := 3 + tech_votes
	if court_is_unanimous:
		court_alignment_summary = "UNANIMOUS %d-%d MANDATE  ->  Immediate %s Victory (Skips Finale!)" % [
			max(eco_votes, tech_votes), min(eco_votes, tech_votes),
			"Ecology" if court_unanimous_winner == "ecology" else "Technology"
		]
	else:
		court_alignment_summary = "TEST SPLIT %d-%d  ->  Finale Alignment: %d Ecology vs. %d Technology" % [
			eco_votes, tech_votes, total_eco, total_tech
		]

func start_sequential_court_ceremony() -> void:
	court_ceremony_active = true
	court_voter_index = 0
	court_turn_timer = court_turn_duration
	court_civilians.clear()
	court_ballot_records.clear()
	court_preview_votes.clear()
	court_is_unanimous = false
	court_unanimous_winner = ""
	court_split_summary = "0-0"
	court_active_speaker_name = ""
	court_active_speaker_reason = ""
	court_fast_forward = false

	# Collect all 4 civilians from session_residents
	for res in session_residents:
		if res != null and res.get("secret_role") == "civilian":
			court_civilians.append(res)

	if not court_civilians.is_empty():
		court_active_speaker_name = court_civilians[0].resident_name

	log_event("Civilian Court in session! Sequential voting commences.", Color(0.95, 0.82, 1.0))
	state_updated.emit()

func get_active_court_voter() -> Node:
	if court_civilians.is_empty() or court_voter_index < 0 or court_voter_index >= court_civilians.size():
		return null
	return court_civilians[court_voter_index]

func get_player_timeout_default_vote() -> String:
	# Explicit deterministic formula:
	# Water <= Stability -> Ecology (Aquifer Preservation Priority)
	# Water > Stability -> Technology (Grid Restoration Priority)
	return "Ecology" if water <= stability else "Technology"

func evaluate_civilian_bot_vote(bot: Node, decision_rng: RandomNumberGenerator = null) -> Dictionary:
	var eco_score: float = 0.0
	var tech_score: float = 0.0
	var eco_reasons: Array[Dictionary] = []
	var tech_reasons: Array[Dictionary] = []

	# 1. Town Crisis State (Primary Faction Decider)
	if water <= 40.0 or water < (stability - 15.0):
		eco_score += 30.0
		eco_reasons.append({"weight": 30.0, "reason": "The aquifer is near depletion (%.0f%% Water). We cannot risk overloading the soil and crops." % water})
	elif stability <= 40.0 or stability < (water - 15.0) or scrap <= 2:
		tech_score += 30.0
		tech_reasons.append({"weight": 30.0, "reason": "Our grid is fracturing (%.0f%% Stability). Without machine power, our filters and heat will fail." % stability})
	elif water < stability:
		eco_score += 15.0
		eco_reasons.append({"weight": 15.0, "reason": "Water reserves are falling behind (%.0f Water vs %.0f Stability). Conservation is our immediate need." % [water, stability]})
	elif stability < water:
		tech_score += 15.0
		tech_reasons.append({"weight": 15.0, "reason": "Town infrastructure is strained (%.0f Stability vs %.0f Water). Restoring power is our best hope." % [stability, water]})

	# Only the voter's own journal and evidence tabled publicly at Council are admissible.
	var bot_id: int = int(bot.resident_id) if bot != null else -1
	var voter_journal: Dictionary = get_player_journal(bot_id)
	var seen_evidence: Dictionary = {}
	var ideological_subjects: Array[Dictionary] = []
	var evidence_sources: Array[Dictionary] = []
	for item_variant in voter_journal.get("observed", []) + voter_journal.get("traces", []):
		if item_variant is Dictionary:
			evidence_sources.append({"item": item_variant, "public": false})
	for item_variant in tabled_evidence:
		evidence_sources.append({"item": item_variant, "public": true})

	for source in evidence_sources:
		var item: Dictionary = source["item"]
		var evidence_id: String = String(item.get("id", ""))
		if evidence_id != "" and seen_evidence.has(evidence_id):
			continue
		if evidence_id != "":
			seen_evidence[evidence_id] = true
		var evidence_tier: String = String(item.get("tier", ""))
		if evidence_tier not in [C.EVIDENCE_FACT, C.EVIDENCE_TRACE] or evidence_id.begins_with("claim:"):
			continue

		var text: String = String(item.get("text", ""))
		var lower_text: String = text.to_lower()
		var subject: String = String(item.get("subject", ""))
		var is_public: bool = bool(source["public"])
		var ideology_reason: String = ""
		var ideology_score: float = _get_ideology_evidence_score(evidence_tier)
		if "biosphere frequency" in lower_text:
			eco_score += ideology_score
			ideology_reason = _get_ideology_vote_reason(subject, "Biosphere", "Ecology", evidence_tier, is_public)
			eco_reasons.append({"weight": ideology_score, "reason": ideology_reason})
			if subject != "":
				ideological_subjects.append({"name": subject, "faction": "Ecology", "public": is_public, "tier": evidence_tier, "score": ideology_score})
		elif "old-world frequency" in lower_text:
			tech_score += ideology_score
			ideology_reason = _get_ideology_vote_reason(subject, "Old-World", "Technology", evidence_tier, is_public)
			tech_reasons.append({"weight": ideology_score, "reason": ideology_reason})
			if subject != "":
				ideological_subjects.append({"name": subject, "faction": "Technology", "public": is_public, "tier": evidence_tier, "score": ideology_score})

		var disruption_score: float = _get_sector_disruption_score(item)
		if disruption_score > 0.0:
			var source_phrase: String = "At First Council, residents tabled evidence of "
			if not is_public:
				source_phrase = "I personally witnessed " if evidence_tier == C.EVIDENCE_FACT else "I found a verified trace of "
			elif evidence_tier == C.EVIDENCE_TRACE:
				source_phrase = "At First Council, residents tabled a verified trace of "
			var disruption_reason: String = "%s%s near %s; that threat should shape the town's priorities." % [source_phrase, _get_evidence_action_label(lower_text), item.get("region", "a town sector")]
			var region_faction: String = _get_sector_protective_faction(String(item.get("region", "")))
			if region_faction == "Ecology":
				eco_score += disruption_score
				eco_reasons.append({"weight": disruption_score, "reason": disruption_reason})
			elif region_faction == "Technology":
				tech_score += disruption_score
				tech_reasons.append({"weight": disruption_score, "reason": disruption_reason})

	# Alibi conflicts are public corroboration, not faction evidence by themselves.
	var corroborated_subjects: Dictionary = {}
	for clue in ideological_subjects:
		for conflict in alibi_conflicts:
			if String(conflict.get("resident", "")) != String(clue.get("name", "")):
				continue
			var corroboration_key: String = "%s:%s" % [String(clue["name"]).to_lower(), String(clue["faction"])]
			if corroborated_subjects.has(corroboration_key):
				break
			corroborated_subjects[corroboration_key] = true
			var conflict_weight: float = minf(10.0, float(clue["score"]) * 0.67)
			var reason: String = "The public alibi record for %s conflicts with evidence of a %s action." % [clue["name"], String(clue["faction"])]
			if bool(clue.get("public", false)):
				reason = "At First Council, the alibi record for %s conflicted with tabled evidence of a %s action." % [clue["name"], String(clue["faction"])]
			if String(clue["faction"]) == "Ecology":
				eco_score += conflict_weight
				eco_reasons.append({"weight": float(clue["score"]) + conflict_weight, "reason": reason})
			else:
				tech_score += conflict_weight
				tech_reasons.append({"weight": float(clue["score"]) + conflict_weight, "reason": reason})
			break

	# 3. Private Archive Discovery (Finder only)
	if bot != null and int(bot.resident_id) == archive_finder_id:
		if archive_choice == C.ARCHIVE_CHOICE_ENTRUST_ECO:
			eco_score += 60.0
			eco_reasons.append({"weight": 60.0, "reason": "I unsealed the old failsafe myself and entrusted it to Ecology operatives. I stand by that choice."})
		elif archive_choice == C.ARCHIVE_CHOICE_ENTRUST_TECH:
			tech_score += 60.0
			tech_reasons.append({"weight": 60.0, "reason": "I unsealed the old failsafe archive and entrusted it to Technology operatives. I stand by that choice."})

	# 4. Civic Job baseline bias (mapped strictly to actual civic jobs)
	var job_name: String = bot.civic_job if bot != null else ""
	match job_name:
		"Crop Tender":
			eco_score += 5.0
			eco_reasons.append({"weight": 5.0, "reason": "My work tending crops makes protecting the soil and water especially important to me."})
		"Salvage Quartermaster":
			tech_score += 5.0
			tech_reasons.append({"weight": 5.0, "reason": "My salvage work makes reliable infrastructure and restored tools especially important to me."})
		# "Pump Technician", "Field Medic", "Town Watch": neutral (0.0)

	# Earlier public ballots create modest social pressure, not evidence.
	var court_influence: Dictionary = _get_public_court_influence(bot)
	var eco_influence: float = float(court_influence.get("ecology", 0.0))
	var tech_influence: float = float(court_influence.get("technology", 0.0))
	if eco_influence > 0.0:
		eco_score += eco_influence
		eco_reasons.append({
			"weight": eco_influence,
			"reason": String(court_influence.get("ecology_reason", "Earlier public Court votes are influencing my view of Ecology."))
		})
	if tech_influence > 0.0:
		tech_score += tech_influence
		tech_reasons.append({
			"weight": tech_influence,
			"reason": String(court_influence.get("technology_reason", "Earlier public Court votes are influencing my view of Technology."))
		})

	# 5. Small random tiebreaker noise (+/- 4)
	var noise: float = decision_rng.randf_range(-4.0, 4.0) if decision_rng != null else randf_range(-4.0, 4.0)
	eco_score += noise

	var pick: String = "Ecology" if eco_score >= tech_score else "Technology"
	var winning_reasons: Array[Dictionary] = eco_reasons if pick == "Ecology" else tech_reasons
	var reason: String = _get_strongest_vote_reason(winning_reasons)
	if reason == "":
		reason = "Preserving the soil and water balance must come before aggressive machine restarts." if pick == "Ecology" else "Restoring power and technology is the only viable path to long-term recovery."
	return {"vote": pick, "reason": reason}

func _get_public_court_influence(bot: Node) -> Dictionary:
	var influence := {
		"ecology": 0.0,
		"technology": 0.0,
		"ecology_reason": "",
		"technology_reason": ""
	}
	if bot == null or court_ballot_records.is_empty():
		return influence

	var bot_id: int = int(bot.get("resident_id"))
	var bot_name: String = String(bot.get("resident_name"))
	var bot_controller: Node = bot.get("bot_controller")
	var temperament: String = String(bot_controller.get("temperament")) if bot_controller != null else ""
	var temperament_weight: float = 0.65
	match temperament:
		"DUTIFUL":
			temperament_weight = 1.0
		"INVESTIGATOR":
			temperament_weight = 0.4
		"OPPORTUNIST":
			temperament_weight = 0.8
		"BOLD":
			temperament_weight = 0.25

	var trust_scores: Dictionary = {}
	if bot_controller != null:
		var memory: Dictionary = bot_controller.get("personal_memory")
		trust_scores = memory.get("trust_scores", {})
	var names_by_faction: Dictionary = {"Ecology": [], "Technology": []}
	for ballot_variant in court_ballot_records:
		if not ballot_variant is Dictionary:
			continue
		var ballot: Dictionary = ballot_variant
		var ballot_name: String = String(ballot.get("name", ""))
		var ballot_id: int = int(ballot.get("resident_id", -1))
		if (ballot_id >= 0 and ballot_id == bot_id) or (ballot_name != "" and ballot_name == bot_name):
			continue
		var vote: String = String(ballot.get("vote", ""))
		if not names_by_faction.has(vote):
			continue
		var side_key: String = vote.to_lower()
		var trust: float = clampf(float(trust_scores.get(ballot_name, 0.0)), -1.0, 1.0)
		var credibility: float = clampf(0.5 + trust * 0.5, 0.1, 1.0)
		var side_score: float = float(influence[side_key]) + 2.0 * temperament_weight * credibility
		influence[side_key] = minf(6.0, side_score)
		var supporting_names: Array = names_by_faction[vote]
		if ballot_name != "" and supporting_names.size() < 2:
			supporting_names.append(ballot_name)

	for faction in names_by_faction.keys():
		var side_key: String = String(faction).to_lower()
		var score: float = float(influence[side_key])
		if score <= 0.0:
			continue
		var names: Array = names_by_faction[faction]
		var supporters: String = ", ".join(PackedStringArray(names))
		var reason: String = "Earlier public Court votes for %s are influencing my view." % faction
		if supporters != "":
			reason = "Earlier public Court votes for %s from %s are influencing my view." % [faction, supporters]
		influence[side_key + "_reason"] = reason
	return influence

func _get_sector_disruption_score(item: Dictionary) -> float:
	var text: String = String(item.get("text", "")).to_lower()
	if not ("tamper" in text or "sabotage" in text or "jammed" in text or "caught" in text):
		return 0.0
	var tier: String = String(item.get("tier", ""))
	match tier:
		C.EVIDENCE_FACT:
			return 12.0
		C.EVIDENCE_TRACE:
			return 6.0
	return 0.0

func _get_ideology_vote_reason(subject: String, frequency: String, faction: String, tier: String, is_public: bool) -> String:
	var source_phrase: String = "Council-tabled evidence showed "
	if not is_public:
		source_phrase = "I witnessed " if tier == C.EVIDENCE_FACT else "I found a verified trace of "
	elif tier == C.EVIDENCE_TRACE:
		source_phrase = "Council-tabled records contained a verified trace of "
	var action_phrase: String = "%s's %s-frequency action" % [subject, frequency]
	if subject == "":
		var article: String = "an" if frequency == "Old-World" else "a"
		action_phrase = "%s %s-frequency action" % [article, frequency]
	return "%s%s, supporting %s." % [source_phrase, action_phrase, faction]

func _get_ideology_evidence_score(tier: String) -> float:
	return 15.0 if tier == C.EVIDENCE_FACT else 8.0

func _get_sector_protective_faction(region_name: String) -> String:
	var region: String = region_name.to_lower()
	if "pump" in region or "greenhouse" in region or "field" in region:
		return "Ecology"
	if "salvage" in region or "common works" in region:
		return "Technology"
	return ""

func _get_evidence_action_label(lower_text: String) -> String:
	if "sabotage" in lower_text or "tamper" in lower_text:
		return "sabotage or tampering"
	if "jammed" in lower_text:
		return "a station disruption"
	return "a suspicious action"

func _get_strongest_vote_reason(reasons: Array[Dictionary]) -> String:
	var strongest_weight: float = -1.0
	var strongest_reason: String = ""
	for candidate in reasons:
		var weight: float = float(candidate.get("weight", 0.0))
		if weight > strongest_weight:
			strongest_weight = weight
			strongest_reason = String(candidate.get("reason", ""))
	return strongest_reason

func get_civilian_bot_deliberation_delay(bot: Node) -> float:
	var delay: float = court_bot_deliberation_delay
	if bot != null:
		var bot_controller: Node = bot.get("bot_controller")
		if bot_controller != null:
			match String(bot_controller.get("temperament")):
				"BOLD":
					delay = 1.2
				"OPPORTUNIST":
					delay = 1.8
				"DUTIFUL":
					delay = 2.7
				"INVESTIGATOR":
					delay = 3.5
	return clampf(delay, 0.5, maxf(0.5, court_turn_duration - 0.5))

func _get_vote_reason_source(reason: String) -> String:
	var lower_reason: String = reason.to_lower()
	if "earlier public court votes" in lower_reason:
		return "COURT CONSENSUS"
	if "i witnessed" in lower_reason or "i personally witnessed" in lower_reason or "i found a verified trace" in lower_reason:
		return "PRIVATE WITNESS"
	if "council" in lower_reason or "first council" in lower_reason or "tabled evidence" in lower_reason:
		return "COUNCIL EVIDENCE"
	if "alibi" in lower_reason or "conflicted" in lower_reason:
		return "PUBLIC CONTRADICTION"
	if "aquifer" in lower_reason or "grid" in lower_reason or "water reserves" in lower_reason or "town infrastructure" in lower_reason or "stability" in lower_reason:
		return "RESOURCE BASELINE"
	return "JUDGMENT"

func _summarize_podium_reason(reason: String) -> String:
	var source_tag: String = _get_vote_reason_source(reason)
	var trimmed: String = String(reason).strip_edges()
	if trimmed.ends_with("."):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	if trimmed == "":
		return source_tag
	if "I witnessed" in trimmed or "I personally witnessed" in trimmed:
		trimmed = trimmed.replace("I witnessed ", "").replace("I personally witnessed ", "")
	elif "I found a verified trace of " in trimmed:
		trimmed = trimmed.replace("I found a verified trace of ", "")
	return "%s — %s." % [source_tag, trimmed]

func cast_sequential_court_ballot(civ: Node, vote: String, reason: String, defaulted: bool = false) -> void:
	if not court_ceremony_active:
		return
	if civ == null:
		return

	var ballot := {
		"name": civ.resident_name,
		"job": civ.civic_job,
		"vote": vote,
		"reason": reason,
		"reason_source": _get_vote_reason_source(reason),
		"reason_display": _summarize_podium_reason(reason),
		"defaulted": defaulted,
		"resident_id": int(civ.resident_id)
	}
	court_ballot_records.append(ballot)
	court_preview_votes.append({
		"name": civ.resident_name,
		"job": civ.civic_job,
		"vote": vote
	})

	var default_tag := " [DEFAULTED ON TIMEOUT]" if defaulted else ""
	log_event("[COURT] %s (%s) voted %s: \"%s\"%s" % [civ.resident_name, civ.civic_job, vote.to_upper(), reason, default_tag], Color(0.95, 0.82, 1.0))

	# Update running count in court_split_summary
	var eco_so_far := 0
	var tech_so_far := 0
	for b in court_ballot_records:
		if b["vote"] == "Ecology":
			eco_so_far += 1
		elif b["vote"] == "Technology":
			tech_so_far += 1
	court_split_summary = "%d-%d" % [eco_so_far, tech_so_far]

	court_active_speaker_reason = _summarize_podium_reason(reason)
	court_voter_index += 1

	if court_voter_index < court_civilians.size():
		# Advance to next civilian
		court_turn_timer = court_turn_duration
		court_active_speaker_name = court_civilians[court_voter_index].resident_name
		state_updated.emit()
	else:
		# All ballots cast! Evaluate dramatic verdict
		_finalize_court_ceremony()

func cast_player_court_ballot(vote: String) -> void:
	if not court_ceremony_active:
		return
	var active_civ: Node = get_active_court_voter()
	if active_civ != null and active_civ.is_player:
		var r_reason: String = "Player cast personal Court ballot for %s." % vote
		cast_sequential_court_ballot(active_civ, vote, r_reason, false)

func _finalize_court_ceremony() -> void:
	court_ceremony_active = false
	var eco_votes := 0
	var tech_votes := 0
	for b in court_ballot_records:
		if b["vote"] == "Ecology":
			eco_votes += 1
		elif b["vote"] == "Technology":
			tech_votes += 1

	# Check archive entrusted civ match
	archive_entrusted_civ_voted_match = false
	if archive_entrust_faction != "":
		for b in court_ballot_records:
			if b.get("name") == archive_finder_name:
				if String(b.get("vote", "")).to_lower() == archive_entrust_faction.to_lower():
					archive_entrusted_civ_voted_match = true
				break

	if eco_votes == 4:
		court_is_unanimous = true
		court_unanimous_winner = "ecology"
		court_split_summary = "4-0"
		court_alignment_summary = "UNANIMOUS 4-0 MANDATE -> Immediate Ecology Victory (Skips Finale!)"
		log_event("Civilian Court reached a UNANIMOUS 4-0 MANDATE for ECOLOGY! Town mandate granted.", Color(0.45, 0.92, 0.58))
		set_phase(Phase.MATCH_OVER)
	elif tech_votes == 4:
		court_is_unanimous = true
		court_unanimous_winner = "technology"
		court_split_summary = "4-0"
		court_alignment_summary = "UNANIMOUS 4-0 MANDATE -> Immediate Technology Victory (Skips Finale!)"
		log_event("Civilian Court reached a UNANIMOUS 4-0 MANDATE for TECHNOLOGY! Town mandate granted.", Color(0.42, 0.80, 0.98))
		set_phase(Phase.MATCH_OVER)
	else:
		court_is_unanimous = false
		court_split_summary = "%d-%d" % [eco_votes, tech_votes]
		court_alignment_summary = "COURT SPLIT %d-%d -> Alignment: %d Ecology vs %d Technology" % [
			eco_votes, tech_votes, 3 + eco_votes, 3 + tech_votes
		]
		log_event("Civilian Court adjourned with a %s split. Entering Strategic Deliberation." % court_split_summary, Color(0.95, 0.85, 0.45))
		start_strategic_decision()

func _evaluate_match_outcome() -> void:
	whistleblower_personal_win = false
	whistleblower_summary = ""
	loyal_personal_win = false
	civilian_commendation = ""

	if court_is_unanimous:
		if court_unanimous_winner == "ecology":
			match_ending_title = "4-0 COURT MANDATE: ECOLOGY VICTORY"
			match_ending_subtitle = "All 4 Unaffiliated Civilians backed Ecology at Court, granting an immediate town mandate."
			match_ending_color = Color(0.45, 0.92, 0.58)
		else:
			match_ending_title = "4-0 COURT MANDATE: TECHNOLOGY VICTORY"
			match_ending_subtitle = "All 4 Unaffiliated Civilians backed Technology at Court, granting an immediate town mandate."
			match_ending_color = Color(0.42, 0.80, 0.98)
	elif finale_route == C.FINALE_ROUTE_PEACE and charter_ratified and holdout_completed and not holdout_failed and common_works >= 99.9 and water > 0.0 and stability > 0.0:
		match_ending_title = "GRAY SYNTHESIS — CHARTER RATIFIED & RECONCILIATION ACHIEVED"
		match_ending_subtitle = "Both factions cooperated under the Common Works Charter. Water, Crops, and Infrastructure survived the crisis!"
		match_ending_color = Color(0.85, 0.72, 1.0)
	else:
		# Route A: Confrontation (or failed peace overtime)
		var eco_won: bool = false
		if generator_tug_meter <= 0.0:
			eco_won = true
			match_ending_title = "ECOLOGY VICTORY — BIOSPHERE CONTAINMENT"
			match_ending_subtitle = "Ecology neutralized the generator core, protecting the soil and aquifer from catastrophic overload."
			match_ending_color = Color(0.45, 0.92, 0.58)
		elif generator_tug_meter >= 100.0:
			eco_won = false
			match_ending_title = "TECHNOLOGY VICTORY — GENERATOR OVERDRIVE"
			match_ending_subtitle = "Technology pushed the generator past safety dampers, restoring high-output energy grid control."
			match_ending_color = Color(0.42, 0.80, 0.98)
		elif generator_tug_meter < 50.0:
			eco_won = true
			match_ending_title = "ECOLOGY VICTORY — GENERATOR CONTROL EDGE"
			match_ending_subtitle = "Timer expired with Ecology holding majority containment (Meter: %d%% Eco favored)." % int(100.0 - generator_tug_meter)
			match_ending_color = Color(0.45, 0.92, 0.58)
		elif generator_tug_meter > 50.0:
			eco_won = false
			match_ending_title = "TECHNOLOGY VICTORY — GENERATOR CONTROL EDGE"
			match_ending_subtitle = "Timer expired with Technology holding majority overdrive (Meter: %d%% Tech favored)." % int(generator_tug_meter)
			match_ending_color = Color(0.42, 0.80, 0.98)
		else:
			# Exact 50.0% dead heat tiebreaker
			if beacon_tech_freq > beacon_eco_freq:
				eco_won = false
				match_ending_title = "TECHNOLOGY VICTORY — BEACON FREQUENCY TIEBREAKER"
				match_ending_subtitle = "Dead heat on Generator (50%%). Decided by Emergency Beacon frequency advantage (%d%% Tech vs %d%% Eco)." % [int(beacon_tech_freq), int(beacon_eco_freq)]
				match_ending_color = Color(0.42, 0.80, 0.98)
			elif beacon_eco_freq > beacon_tech_freq:
				eco_won = true
				match_ending_title = "ECOLOGY VICTORY — BEACON FREQUENCY TIEBREAKER"
				match_ending_subtitle = "Dead heat on Generator (50%%). Decided by Emergency Beacon frequency advantage (%d%% Eco vs %d%% Tech)." % [int(beacon_eco_freq), int(beacon_tech_freq)]
				match_ending_color = Color(0.45, 0.92, 0.58)
			elif water > stability:
				eco_won = false
				match_ending_title = "TECHNOLOGY VICTORY — RESOURCE BALANCE TIEBREAKER"
				match_ending_subtitle = "Dead heat on Generator and Beacon. Decided by Water (%d) > Stability (%d)." % [int(water), int(stability)]
				match_ending_color = Color(0.42, 0.80, 0.98)
			else:
				eco_won = true
				match_ending_title = "ECOLOGY VICTORY — RESOURCE BALANCE TIEBREAKER"
				match_ending_subtitle = "Dead heat on Generator and Beacon. Decided by Stability (%d) >= Water (%d)." % [int(stability), int(water)]
				match_ending_color = Color(0.45, 0.92, 0.58)

	# Whistleblower Resolution
	if archive_whistleblower_active:
		if match_ending_title.begins_with("GRAY SYNTHESIS"):
			whistleblower_personal_win = true
			whistleblower_summary = "PERSONAL WIN: SUCCESS — Catastrophic design flaws exposed; town reconciled under the Charter."
		else:
			whistleblower_personal_win = false
			whistleblower_summary = "PERSONAL WIN: FAILED — Extreme faction dominance prevailed; reconciliation thwarted."

	# Loyal operative resolution
	var p_res: Node = get_player_resident()
	if p_res != null:
		if p_res.secret_role != "civilian":
			var p_faction_won: bool = (p_res.secret_role == "ecology" and match_ending_title.begins_with("ECOLOGY")) or (p_res.secret_role == "technology" and match_ending_title.begins_with("TECHNOLOGY"))
			loyal_personal_win = p_faction_won and not archive_whistleblower_active
		else:
			var civ_aligned: String = get_resident_alignment(p_res)
			if match_ending_title.begins_with("GRAY SYNTHESIS"):
				civilian_commendation = "CIVIC PEACE MEDAL: You helped navigate the town toward peaceful reconciliation."
			elif (civ_aligned == "ecology" and match_ending_title.begins_with("ECOLOGY")) or (civ_aligned == "technology" and match_ending_title.begins_with("TECHNOLOGY")):
				civilian_commendation = "FACTION COMMENDATION: The faction you backed at Court won decisive control."
			else:
				civilian_commendation = "CIVIC VETERAN: You survived the crisis despite opposing faction dominance."

	log_event("Match Complete -> " + match_ending_title, match_ending_color)

func _process(delta: float) -> void:
	if current_phase == Phase.LOBBY or current_phase == Phase.MATCH_OVER:
		return

	if current_phase == Phase.COURT:
		if court_ceremony_active:
			court_turn_timer = maxf(0.0, court_turn_timer - delta)
			var active_civ: Node = get_active_court_voter()
			if active_civ != null:
				if active_civ.is_player:
					if court_turn_timer <= 0.0:
						var def_vote: String = get_player_timeout_default_vote()
						var def_reason: String = "Defaulted on turn timeout (%s Priority)." % ("Aquifer" if def_vote == "Ecology" else "Grid")
						cast_sequential_court_ballot(active_civ, def_vote, def_reason, true)
						return
				else:
					# Bot temperament changes podium pacing; fast-forward remains immediate.
					if court_turn_timer <= (court_turn_duration - get_civilian_bot_deliberation_delay(active_civ)) or court_fast_forward:
						court_fast_forward = false
						var bot_controller: Node = active_civ.get("bot_controller")
						var decision_rng: RandomNumberGenerator = bot_controller.bot_rng if bot_controller != null else null
						if bot_controller != null and bot_controller.has_method("refresh_personal_memory"):
							bot_controller.refresh_personal_memory()
						var bot_eval: Dictionary = evaluate_civilian_bot_vote(active_civ, decision_rng)
						cast_sequential_court_ballot(active_civ, bot_eval["vote"], bot_eval["reason"], false)
						return
			state_updated.emit()
			return
		elif strategic_decision_active:
			strategic_timer = maxf(0.0, strategic_timer - delta)
			if strategic_timer <= 0.0:
				resolve_strategic_decision()
				return

	if current_phase == Phase.FINALE:
		if finale_route == C.FINALE_ROUTE_CONFRONTATION:
			if not pending_generator_deltas.is_empty():
				var net_delta: float = 0.0
				for d in pending_generator_deltas:
					net_delta += d
				pending_generator_deltas.clear()
				generator_tug_meter = clampf(generator_tug_meter + net_delta, 0.0, 100.0)
				if generator_tug_meter >= 100.0 or generator_tug_meter <= 0.0:
					set_phase(Phase.MATCH_OVER)
					return
		elif finale_route == C.FINALE_ROUTE_PEACE:
			if holdout_active:
				holdout_timer = maxf(0.0, holdout_timer - delta)
				hazard_spawn_timer -= delta
				if hazard_spawn_timer <= 0.0:
					spawn_holdout_hazard()
					hazard_spawn_timer = randf_range(12.0, 16.0)

				if water <= 0.01 or stability <= 0.01:
					trigger_failed_peace_fallback()
					return

				if holdout_timer <= 0.0:
					if common_works >= 99.9 and water > 0.0 and stability > 0.0:
						holdout_active = false
						holdout_completed = true
						set_phase(Phase.MATCH_OVER)
						return
					else:
						trigger_failed_peace_fallback()
						return

	time_remaining = maxf(0.0, time_remaining - delta)
	match_elapsed += delta

	if is_active_play_phase() and drain_enabled:
		var mult: float = get_drain_multiplier() * crisis_drain_scale
		if current_phase == Phase.ESCALATION or current_phase == Phase.FINALE:
			mult *= 1.25

		var water_haz_mult: float = 1.0
		var stab_haz_mult: float = 1.0
		for hz in active_hazards:
			if hz.get("kind") == "steam":
				water_haz_mult *= 3.0
			elif hz.get("kind") == "blight":
				stab_haz_mult *= 3.0

		water = maxf(0.0, water - BASE_WATER_DRAIN * mult * water_haz_mult * delta)
		var stab_rate: float = LOW_WATER_STABILITY_DRAIN if water <= 0.01 else BASE_STABILITY_DRAIN
		if current_phase == Phase.ESCALATION and crop_remediation_active:
			stab_rate *= 0.75
		stability = maxf(0.0, stability - stab_rate * mult * stab_haz_mult * delta)

		if water <= 0.01 or stability <= 0.01:
			critical_seconds += delta

	if time_remaining <= 0.0:
		if current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_PEACE and (not charter_ratified or holdout_active or not holdout_completed):
			trigger_failed_peace_fallback()
			return
		advance_to_next_phase()
		return

	state_updated.emit()

func get_drain_multiplier() -> float:
	var mult: float = 1.0
	if common_works >= 99.9:
		mult = 0.50
	elif common_works >= 66.0:
		mult = 0.70
	elif common_works >= 33.0:
		mult = 0.85
	if generator_eco_stabilized >= 50.0:
		mult *= 0.85
	if current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_PEACE and holdout_active:
		if charter_power == C.CHARTER_POWER_LOW:
			mult *= 0.70
		elif charter_power == C.CHARTER_POWER_HIGH:
			mult *= 1.25
	return mult

func get_common_works_status_text() -> String:
	if common_works >= 99.9:
		return "FULL SYNTHESIS (-50% Crisis Drain)"
	elif common_works >= 66.0:
		return "STAGE 2 ACTIVE (-30% Crisis Drain)"
	elif common_works >= 33.0:
		return "STAGE 1 ACTIVE (-15% Crisis Drain)"
	return "FOUNDATION (Needs 33% for Stage 1)"

func toggle_drain() -> void:
	drain_enabled = not drain_enabled
	var state_str := "ENABLED" if drain_enabled else "PAUSED (Free Flow Mode)"
	log_event("Resource Drain " + state_str + ".", Color(0.95, 0.85, 0.45))
	state_updated.emit()

func can_perform_task(task_type: String) -> bool:
	if not is_active_play_phase():
		return false
	match task_type:
		"cw_eco":
			return common_works_eco < 99.9 and water >= 1.0
		"cw_tech":
			return common_works_tech < 99.9 and scrap >= 1
		"cw_struct":
			return common_works_struct < 99.9
		"common_works":
			return scrap >= 1 and common_works < 99.9
		"generator_objective", "beacon_objective":
			return current_phase == Phase.ESCALATION or current_phase == Phase.FINALE
		"generator_tug":
			return current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_CONFRONTATION
		"ratify_eco":
			return current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_PEACE and not charter_eco_ratified
		"ratify_tech":
			return current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_PEACE and not charter_tech_ratified
		"hazard_clear":
			return current_phase == Phase.FINALE and finale_route == C.FINALE_ROUTE_PEACE and holdout_active
	return true

func _recalc_common_works() -> void:
	var prev_cw := common_works
	common_works = (common_works_eco + common_works_tech + common_works_struct) / 3.0
	peak_common_works = maxf(peak_common_works, common_works)
	if prev_cw < 33.0 and common_works >= 33.0:
		log_event("Common Works 33% Completed: Stage 1 Active (-15% Crisis Drain).", Color(0.85, 0.95, 0.55))
	elif prev_cw < 66.0 and common_works >= 66.0:
		log_event("Common Works 66% Completed: Stage 2 Active (-30% Crisis Drain).", Color(0.65, 1.0, 0.65))
	elif prev_cw < 99.9 and common_works >= 99.9:
		log_event("Common Works 100% Completed: Full Synthesis (-50% Crisis Drain)!", Color(0.50, 1.0, 0.75))

func execute_task(task_type: String, resident_name: String, is_player: bool, is_overclocked: bool = false) -> String:
	var summary := ""
	var out_mult: float = 1.5 if is_overclocked else 1.0
	var boost_tag: String = " [OVERCLOCKED +50%]" if is_overclocked else ""

	match task_type:
		"pump":
			if scrap >= 1:
				scrap -= 1
				var w_gain: float = round(8.0 * out_mult)
				water = minf(MAX_WATER, water + w_gain)
				summary = "%s repaired Pump (+%d Water, -1 Scrap)%s" % [resident_name, int(w_gain), boost_tag]
			else:
				var w_gain_low: float = round(4.0 * out_mult)
				water = minf(MAX_WATER, water + w_gain_low)
				summary = "%s patched Pump (+%d Water, 0 Scrap)%s" % [resident_name, int(w_gain_low), boost_tag]
			log_event(summary, Color(0.45, 0.82, 1.0))
		"greenhouse":
			var s_gain: float = round(7.0 * out_mult)
			stability = minf(MAX_STABILITY, stability + s_gain)
			summary = "%s tended Crops (+%d Town Stability)%s" % [resident_name, int(s_gain), boost_tag]
			log_event(summary, Color(0.55, 0.92, 0.58))
		"salvage":
			var raw_scrap: int = 3 if is_overclocked else 2
			var gained := mini(raw_scrap, MAX_SCRAP - scrap)
			scrap = mini(MAX_SCRAP, scrap + raw_scrap)
			summary = "%s gathered Salvage (+%d Scrap)%s" % [resident_name, gained, boost_tag]
			log_event(summary, Color(0.95, 0.76, 0.42))
		"cw_eco":
			if water >= 1.0:
				water = maxf(0.0, water - 1.0)
				var gain: float = round(10.0 * out_mult)
				common_works_eco = minf(MAX_COMMON_WORKS, common_works_eco + gain)
				_recalc_common_works()
				summary = "%s contributed to Ecological Stabilization (+%d%% Eco, -1 Water)%s" % [resident_name, int(gain), boost_tag]
			else:
				return "%s could not contribute to Ecological Stabilization (insufficient Water)" % resident_name
			log_event(summary, Color(0.45, 0.88, 0.55))
		"cw_tech":
			if scrap >= 1:
				scrap -= 1
				var gain: float = round(10.0 * out_mult)
				common_works_tech = minf(MAX_COMMON_WORKS, common_works_tech + gain)
				_recalc_common_works()
				summary = "%s contributed to Engineering Components (+%d%% Tech, -1 Scrap)%s" % [resident_name, int(gain), boost_tag]
			else:
				return "%s could not contribute to Engineering Components (0 Scrap)" % resident_name
			log_event(summary, Color(0.95, 0.72, 0.42))
		"cw_struct":
			var gain: float = round(10.0 * out_mult)
			common_works_struct = minf(MAX_COMMON_WORKS, common_works_struct + gain)
			_recalc_common_works()
			summary = "%s contributed to Structural Assembly (+%d%% Struct, -25 Stamina)%s" % [resident_name, int(gain), boost_tag]
			log_event(summary, Color(0.78, 0.65, 0.98))
		"generator_objective":
			var actor_role: String = "civilian"
			for r in session_residents:
				if r != null and r.resident_name == resident_name:
					actor_role = r.secret_role
					break
			match actor_role:
				"technology":
					generator_tech_primed = minf(100.0, generator_tech_primed + 25.0)
					summary = "%s primed Buried Generator Governor (Tech Primed: %d%%)%s" % [resident_name, int(generator_tech_primed), boost_tag]
					log_event(summary, Color(0.42, 0.82, 0.98))
				"ecology":
					generator_eco_stabilized = minf(100.0, generator_eco_stabilized + 25.0)
					summary = "%s installed Biosphere Damper on Generator (Eco Stabilized: %d%%)%s" % [resident_name, int(generator_eco_stabilized), boost_tag]
					log_event(summary, Color(0.45, 0.92, 0.58))
				_:
					scrap = mini(MAX_SCRAP, scrap + 1)
					generator_civilian_calibrated = true
					summary = "%s calibrated Generator feeds (+1 Scrap, Status Logged)%s" % [resident_name, boost_tag]
					log_event(summary, Color(0.85, 0.85, 0.92))
		"beacon_objective":
			var actor_role: String = "civilian"
			for r in session_residents:
				if r != null and r.resident_name == resident_name:
					actor_role = r.secret_role
					break
			match actor_role:
				"ecology":
					beacon_eco_freq = minf(100.0, beacon_eco_freq + 25.0)
					summary = "%s tuned Emergency Beacon to Biosphere Frequency (%d%%)%s" % [resident_name, int(beacon_eco_freq), boost_tag]
					log_event(summary, Color(0.45, 0.92, 0.58))
				"technology":
					beacon_tech_freq = minf(100.0, beacon_tech_freq + 25.0)
					summary = "%s tuned Emergency Beacon to Old-World Frequency (%d%%)%s" % [resident_name, int(beacon_tech_freq), boost_tag]
					log_event(summary, Color(0.42, 0.82, 0.98))
				_:
					beacon_eco_freq = minf(100.0, beacon_eco_freq + 12.0)
					beacon_tech_freq = minf(100.0, beacon_tech_freq + 12.0)
					summary = "%s stabilized Emergency Beacon broad spectrum%s" % [resident_name, boost_tag]
					log_event(summary, Color(0.85, 0.85, 0.92))
		"common_works":
			if scrap >= 1:
				scrap -= 1
				var part: float = round(3.5 * out_mult)
				common_works_eco = minf(MAX_COMMON_WORKS, common_works_eco + part)
				common_works_tech = minf(MAX_COMMON_WORKS, common_works_tech + part)
				common_works_struct = minf(MAX_COMMON_WORKS, common_works_struct + part)
				_recalc_common_works()
				summary = "%s built Common Works (+%d%% Progress, -1 Scrap)%s" % [resident_name, int(part), boost_tag]
			else:
				return "%s could not finish Common Works (0 Scrap remaining)" % resident_name
			log_event(summary, Color(0.85, 0.75, 1.0))
		"generator_tug":
			record_generator_tug(get_resident_by_name(resident_name))
			summary = "%s channeled Buried Generator." % resident_name
		"ratify_eco":
			record_charter_ratification(get_resident_by_name(resident_name), "ratify_eco")
			summary = "%s ratified Charter for Ecology." % resident_name
		"ratify_tech":
			record_charter_ratification(get_resident_by_name(resident_name), "ratify_tech")
			summary = "%s ratified Charter for Technology." % resident_name
		"hazard_clear":
			summary = "%s cleared a crisis hazard." % resident_name

	total_tasks_completed += 1
	if is_player:
		player_tasks_completed += 1
	else:
		bot_tasks_completed += 1

	state_updated.emit()
	return summary

func open_archive(resident: Node, target: Dictionary) -> Dictionary:
	if archive_opened or resident == null:
		return {}
	archive_opened = true
	archive_open_time = _match_clock_text()
	archive_finder_id = int(resident.resident_id)
	archive_finder_name = resident.resident_name
	archive_finder_role = resident.secret_role

	var stamp: String = archive_open_time
	var trace_text: String = "Old-World Archive accessed and failsafe key extracted at %s." % stamp
	var region_name: String = String(target.get("region", "Town Corridors"))

	var trace_entry: Dictionary = add_private_trace(archive_finder_id, trace_text, region_name, stamp)

	if resident.is_player:
		archive_dilemma_open = true
		if resident.has_method("show_popup"):
			resident.show_popup("Old-World Archive Unsealed! Dilemma presented.", Color(1.0, 0.90, 0.45))
	else:
		_resolve_bot_archive_choice(resident)

	state_updated.emit()
	return trace_entry

func _resolve_bot_archive_choice(bot_resident: Node) -> void:
	if bot_resident == null:
		return
	if bot_resident.secret_role == "civilian":
		if randf() < 0.50:
			resolve_player_archive_choice(C.ARCHIVE_CHOICE_RESERVE_CW)
		else:
			var picked: String = C.ARCHIVE_CHOICE_ENTRUST_ECO if randf() < 0.50 else C.ARCHIVE_CHOICE_ENTRUST_TECH
			resolve_player_archive_choice(picked)
	else:
		if randf() < 0.75:
			resolve_player_archive_choice(C.ARCHIVE_CHOICE_LOYAL)
		else:
			resolve_player_archive_choice(C.ARCHIVE_CHOICE_WHISTLEBLOWER)

func resolve_default_archive_choice() -> void:
	if not archive_dilemma_open:
		return
	var default_choice: String = C.ARCHIVE_CHOICE_LOYAL if archive_finder_role != "civilian" else C.ARCHIVE_CHOICE_RESERVE_CW
	resolve_player_archive_choice(default_choice)

func resolve_player_archive_choice(choice: String) -> void:
	archive_choice = choice
	archive_dilemma_open = false
	match choice:
		C.ARCHIVE_CHOICE_LOYAL:
			archive_loyal_faction = archive_finder_role
			archive_choice_details = "Stayed loyal: +12%% objective speed for %s in Finale." % archive_finder_role.capitalize()
			# Choice is kept strictly private to the finder (no public town log broadcast)
		C.ARCHIVE_CHOICE_WHISTLEBLOWER:
			archive_whistleblower_active = true
			archive_choice_details = "Whistleblower: Catastrophic flaw exposed. Personal objective changed to Gray Synthesis."
			# Choice is kept strictly private to the finder (no public town log broadcast)
		C.ARCHIVE_CHOICE_ENTRUST_ECO:
			archive_entrust_faction = "ecology"
			archive_choice_details = "Failsafe key entrusted to Ecology operatives (+12%% advantage if voted at Court)."
			# Choice is kept strictly private to the finder (no public town log broadcast)
		C.ARCHIVE_CHOICE_ENTRUST_TECH:
			archive_entrust_faction = "technology"
			archive_choice_details = "Failsafe key entrusted to Technology operatives (+12%% advantage if voted at Court)."
			# Choice is kept strictly private to the finder (no public town log broadcast)
		C.ARCHIVE_CHOICE_RESERVE_CW:
			archive_reserved_for_cw = true
			common_works_eco = minf(MAX_COMMON_WORKS, common_works_eco + 15.0)
			common_works_tech = minf(MAX_COMMON_WORKS, common_works_tech + 15.0)
			common_works_struct = minf(MAX_COMMON_WORKS, common_works_struct + 15.0)
			_recalc_common_works()
			archive_choice_details = "Reserved for Common Works: +15%% to all 3 tracks."
			# Anonymous town-wide power surge - does not identify finder or reveal archive
			log_event("Central power grid surge: +15%% to all 3 Common Works tracks.", Color(0.85, 0.75, 1.0))

	# Show private popup confirmation to the finder if they are the player
	for r in session_residents:
		if r != null and r.is_player and int(r.resident_id) == archive_finder_id:
			if choice == C.ARCHIVE_CHOICE_RESERVE_CW:
				r.show_popup("Archive Choice: +15% to all 3 Common Works tracks!", Color(0.85, 0.75, 1.0))
			elif choice == C.ARCHIVE_CHOICE_WHISTLEBLOWER:
				r.show_popup("Archive Choice: You are now a Whistleblower!", Color(0.88, 0.72, 1.0))
			elif choice == C.ARCHIVE_CHOICE_LOYAL:
				r.show_popup("Archive Choice: Failsafe secured (+12% Finale Speed)!", Color(0.72, 0.88, 1.0))
			elif choice == C.ARCHIVE_CHOICE_ENTRUST_ECO:
				r.show_popup("Archive Choice: Entrusted to Ecology (+12% Court Weight)!", Color(0.55, 0.95, 0.65))
			elif choice == C.ARCHIVE_CHOICE_ENTRUST_TECH:
				r.show_popup("Archive Choice: Entrusted to Technology (+12% Court Weight)!", Color(0.55, 0.85, 1.0))
			break

	state_updated.emit()

func get_player_resident() -> Node:
	for r in session_residents:
		if r != null and r.is_player:
			return r
	return null

func get_resident_by_name(r_name: String) -> Node:
	for r in session_residents:
		if r != null and r.resident_name == r_name:
			return r
	return null

func get_resident_alignment(resident: Node) -> String:
	if resident == null:
		return "civilian"
	if resident.secret_role == "ecology" or resident.secret_role == "technology":
		return resident.secret_role
	for entry in court_preview_votes:
		if entry.get("name") == resident.resident_name:
			return String(entry.get("vote", "civilian")).to_lower()
	return "civilian"

func get_archive_objective_speed_mult(faction: String) -> float:
	var mult: float = 1.0
	if archive_loyal_faction != "" and archive_loyal_faction == faction:
		mult *= 1.12
	if archive_entrusted_civ_voted_match and archive_entrust_faction == faction:
		mult *= 1.12
	return mult

func get_beacon_speed_buff(faction: String) -> float:
	if beacon_tech_freq > beacon_eco_freq and faction == "technology":
		return 1.15
	elif beacon_eco_freq > beacon_tech_freq and faction == "ecology":
		return 1.15
	return 1.0

func get_beacon_sightline_buff(faction: String) -> float:
	if beacon_tech_freq > beacon_eco_freq and faction == "technology":
		return 1.35
	elif beacon_eco_freq > beacon_tech_freq and faction == "ecology":
		return 1.35
	return 1.0

func get_court_vote_weight(voter_role: String, voted_faction: String) -> float:
	if archive_entrust_faction != "" and voter_role == "civilian" and voted_faction == archive_entrust_faction:
		return 1.12
	return 1.0

func start_strategic_decision() -> void:
	strategic_decision_active = true
	strategic_timer = 15.0
	strategic_decision_resolved = false
	player_strategic_choice = C.STRATEGIC_CHOICE_NONE
	eco_faction_decision = C.STRATEGIC_CHOICE_NONE
	tech_faction_decision = C.STRATEGIC_CHOICE_NONE
	strategic_votes_eco.clear()
	strategic_votes_tech.clear()

	# Simulate bot strategic votes based on role archetype and match status
	for res in session_residents:
		if res == null or res.is_player:
			continue
		var allegiance: String = get_resident_alignment(res)
		var choice: String = C.STRATEGIC_CHOICE_CONFRONTATION
		if res.secret_role == "civilian":
			# Civilians prefer Peace (70%) if Common Works >= 50%
			choice = C.STRATEGIC_CHOICE_PEACE if (common_works >= 50.0 and randf() < 0.70) else (C.STRATEGIC_CHOICE_PEACE if randf() < 0.40 else C.STRATEGIC_CHOICE_CONFRONTATION)
		else:
			# Operatives vote Peace (60%) if CW is high (>60%) and town is stable, otherwise Confrontation (70%)
			var live_eco_ballots := 0
			var live_tech_ballots := 0
			for entry in court_preview_votes:
				if String(entry.get("vote", "")) == "Ecology":
					live_eco_ballots += 1
				elif String(entry.get("vote", "")) == "Technology":
					live_tech_ballots += 1
			var team_adv: bool = (allegiance == "ecology" and live_eco_ballots > live_tech_ballots) or (allegiance == "technology" and live_tech_ballots > live_eco_ballots)
			if common_works >= 60.0 and water >= 40.0 and stability >= 40.0 and not team_adv:
				choice = C.STRATEGIC_CHOICE_PEACE if randf() < 0.60 else C.STRATEGIC_CHOICE_CONFRONTATION
			else:
				choice = C.STRATEGIC_CHOICE_CONFRONTATION if randf() < 0.70 else C.STRATEGIC_CHOICE_PEACE

		if allegiance == "ecology":
			strategic_votes_eco[res.resident_name] = choice
		elif allegiance == "technology":
			strategic_votes_tech[res.resident_name] = choice

	log_event("Strategic Council: Both factions vote [CONFRONTATION] vs. [PEACE]. (15s)", Color(0.95, 0.82, 0.45))
	state_updated.emit()

func cast_player_strategic_choice(choice: String) -> void:
	if not strategic_decision_active or strategic_decision_resolved:
		return
	player_strategic_choice = choice
	var p_res: Node = get_player_resident()
	if p_res != null:
		var allegiance: String = get_resident_alignment(p_res)
		if allegiance == "ecology":
			strategic_votes_eco[p_res.resident_name] = choice
		elif allegiance == "technology":
			strategic_votes_tech[p_res.resident_name] = choice
	state_updated.emit()

func resolve_strategic_decision() -> void:
	if strategic_decision_resolved:
		return
	strategic_decision_resolved = true
	strategic_decision_active = false

	# If player hasn't chosen, default to confrontation
	if player_strategic_choice == C.STRATEGIC_CHOICE_NONE:
		var p_res: Node = get_player_resident()
		if p_res != null:
			var allegiance: String = get_resident_alignment(p_res)
			if allegiance == "ecology":
				strategic_votes_eco[p_res.resident_name] = C.STRATEGIC_CHOICE_CONFRONTATION
			elif allegiance == "technology":
				strategic_votes_tech[p_res.resident_name] = C.STRATEGIC_CHOICE_CONFRONTATION

	# Count Eco faction votes
	var eco_peace_count := 0
	var eco_total := strategic_votes_eco.size()
	for v in strategic_votes_eco.values():
		if v == C.STRATEGIC_CHOICE_PEACE:
			eco_peace_count += 1
	eco_faction_decision = C.STRATEGIC_CHOICE_PEACE if (eco_total > 0 and float(eco_peace_count) / float(eco_total) > 0.50) else C.STRATEGIC_CHOICE_CONFRONTATION

	# Count Tech faction votes
	var tech_peace_count := 0
	var tech_total := strategic_votes_tech.size()
	for v in strategic_votes_tech.values():
		if v == C.STRATEGIC_CHOICE_PEACE:
			tech_peace_count += 1
	tech_faction_decision = C.STRATEGIC_CHOICE_PEACE if (tech_total > 0 and float(tech_peace_count) / float(tech_total) > 0.50) else C.STRATEGIC_CHOICE_CONFRONTATION

	log_event("Strategic Decision: Ecology voted %s (%d/%d Peace) • Technology voted %s (%d/%d Peace)" % [
		eco_faction_decision.to_upper(), eco_peace_count, eco_total,
		tech_faction_decision.to_upper(), tech_peace_count, tech_total
	], Color(0.92, 0.88, 0.65))

	if eco_faction_decision == C.STRATEGIC_CHOICE_PEACE and tech_faction_decision == C.STRATEGIC_CHOICE_PEACE:
		finale_route = C.FINALE_ROUTE_PEACE
		log_event("Both factions ratified PEACE! Proceeding to the Common Works Charter.", Color(0.55, 0.95, 0.70))
	else:
		finale_route = C.FINALE_ROUTE_CONFRONTATION
		log_event("Confrontation declared! Final battle over the Buried Generator begins.", Color(1.0, 0.60, 0.45))

	set_phase(Phase.FINALE)

func record_generator_tug(resident: Node) -> void:
	if current_phase != Phase.FINALE or finale_route != C.FINALE_ROUTE_CONFRONTATION or resident == null:
		return
	var allegiance: String = get_resident_alignment(resident)
	var delta_val: float = 0.0
	if allegiance == "technology":
		delta_val = C.TUG_OF_WAR_CHANNEL_DELTA
	elif allegiance == "ecology":
		delta_val = -C.TUG_OF_WAR_CHANNEL_DELTA
	else:
		return

	pending_generator_deltas.append(delta_val)
	log_event("%s channeled Generator (%s: %+.0f%%)" % [
		resident.resident_name, allegiance.capitalize(), delta_val
	], Color(0.42, 0.82, 0.98) if delta_val > 0.0 else Color(0.45, 0.92, 0.58))
	state_updated.emit()

func record_charter_ratification(resident: Node, console_type: String) -> void:
	if current_phase != Phase.FINALE or finale_route != C.FINALE_ROUTE_PEACE or resident == null:
		return
	var allegiance: String = get_resident_alignment(resident)
	if console_type == "ratify_eco" and (allegiance == "ecology" or resident.secret_role == "ecology"):
		if not charter_eco_ratified:
			charter_eco_ratified = true
			log_event("%s ratified Gray Synthesis Charter for Ecology." % resident.resident_name, Color(0.48, 0.95, 0.62))
	elif console_type == "ratify_tech" and (allegiance == "technology" or resident.secret_role == "technology"):
		if not charter_tech_ratified:
			charter_tech_ratified = true
			log_event("%s ratified Gray Synthesis Charter for Technology." % resident.resident_name, Color(0.45, 0.82, 1.0))

	if charter_eco_ratified and charter_tech_ratified and not charter_ratified:
		charter_ratified = true
		holdout_active = true
		holdout_duration = C.HOLDOUT_DURATION_LOW_POWER if charter_power == C.CHARTER_POWER_LOW else C.HOLDOUT_DURATION_HIGH_POWER
		holdout_timer = holdout_duration
		hazard_spawn_timer = 8.0

		if charter_med == C.CHARTER_MED_AUTOMATED:
			water = minf(MAX_WATER, water + 15.0)
			stability = minf(MAX_STABILITY, stability + 15.0)
			log_event("Automated Clinic protocol activated (+15 Water, +15 Stability buffer)!", Color(0.75, 0.95, 0.85))

		log_event("Charter Ratified! Cooperative crisis holdout begun (%ds)." % int(holdout_duration), Color(0.85, 0.72, 1.0))

	state_updated.emit()

func cycle_charter_term(term_name: String) -> void:
	if current_phase != Phase.FINALE or finale_route != C.FINALE_ROUTE_PEACE or charter_ratified:
		return
	match term_name:
		"power":
			charter_power = C.CHARTER_POWER_HIGH if charter_power == C.CHARTER_POWER_LOW else C.CHARTER_POWER_LOW
			var p_lbl := "High-Power (60s holdout, 1.25x drain)" if charter_power == C.CHARTER_POWER_HIGH else "Low-Power (90s holdout, 0.70x drain)"
			log_event("Charter Term updated: Power Grid -> %s" % p_lbl, Color(0.85, 0.90, 0.98))
		"land":
			charter_land = C.CHARTER_LAND_RESTRICTED if charter_land == C.CHARTER_LAND_OPEN else C.CHARTER_LAND_OPEN
			var l_lbl := "Restricted Reserves (Eco 1.3s hazard clear)" if charter_land == C.CHARTER_LAND_RESTRICTED else "Shared Commons (Standard)"
			log_event("Charter Term updated: Land Allocation -> %s" % l_lbl, Color(0.85, 0.90, 0.98))
		"med":
			charter_med = C.CHARTER_MED_SCHEDULED if charter_med == C.CHARTER_MED_AUTOMATED else C.CHARTER_MED_AUTOMATED
			var m_lbl := "Automated Clinics (+15 Water/Stability buffer on start)" if charter_med == C.CHARTER_MED_AUTOMATED else "Scheduled Clinics (Standard)"
			log_event("Charter Term updated: Medical Protocol -> %s" % m_lbl, Color(0.85, 0.90, 0.98))
	state_updated.emit()

func spawn_holdout_hazard() -> void:
	if not holdout_active or active_hazards.size() >= 2:
		return
	var candidates: Array[Dictionary] = []
	for h in C.HOLDOUT_HAZARD_SPAWNS:
		var already_active := false
		for ah in active_hazards:
			if ah["id"] == h["id"]:
				already_active = true
				break
		if not already_active:
			candidates.append(h)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var picked: Dictionary = candidates[0].duplicate()
	active_hazards.append(picked)
	var col := Color(1.0, 0.55, 0.40) if picked["kind"] == "blight" else Color(0.95, 0.75, 0.45)
	log_event("[CRISIS SURGE] %s reported in %s!" % [picked["label"], picked["region"]], col)
	state_updated.emit()

func clear_holdout_hazard(hazard_id: String, resident_name: String) -> void:
	var found_idx := -1
	for i in range(active_hazards.size()):
		if active_hazards[i]["id"] == hazard_id:
			found_idx = i
			break
	if found_idx != -1:
		var h: Dictionary = active_hazards[found_idx]
		active_hazards.remove_at(found_idx)
		log_event("%s cleared crisis hazard: %s." % [resident_name, h["label"]], Color(0.55, 0.95, 0.70))
		state_updated.emit()

func trigger_failed_peace_fallback() -> void:
	holdout_active = false
	holdout_failed = true
	active_hazards.clear()
	finale_route = C.FINALE_ROUTE_CONFRONTATION
	confrontation_overtime = true
	time_remaining = 60.0

	# Resource Penalty Applied: -15 Water, -15 Stability (clamped to 5.0 minimum)
	water = maxf(5.0, water - 15.0)
	stability = maxf(5.0, stability - 15.0)

	# -20% Common Works structural penalty
	common_works_eco = maxf(0.0, common_works_eco - 20.0)
	common_works_tech = maxf(0.0, common_works_tech - 20.0)
	common_works_struct = maxf(0.0, common_works_struct - 20.0)
	_recalc_common_works()

	log_event("The Charter collapsed! Crisis overwhelms town defenses—reverting to Confrontation!", Color(1.0, 0.45, 0.35))
	state_updated.emit()

func record_shove(actor_name: String, target_name: String) -> void:
	shoves_used += 1
	if target_name != "":
		log_event("%s used Civic Shove on %s (-35 Stamina)." % [actor_name, target_name], Color(1.0, 0.68, 0.52))

func record_civic_ability(actor_name: String, ability_name: String, detail: String) -> void:
	civic_abilities_used += 1
	log_event("%s used %s (%s)." % [actor_name, ability_name, detail], Color(0.68, 0.90, 0.98))

func record_faction_ability(caster: Node2D, town_map: Node2D, all_residents: Array) -> bool:
	faction_abilities_used += 1
	if current_phase != Phase.OPEN_TOWN:
		return false
	record_observed_sighting(caster, caster.global_position, town_map, all_residents, "used a special ability near")

	# Check wall-validated sightline against all other non-incapacitated residents
	var witnessed := false
	for other in all_residents:
		if other == null or other == caster or other.is_incapacitated:
			continue
		var other_allegiance: String = get_resident_alignment(other)
		var max_dist: float = C.WITNESS_RADIUS * get_beacon_sightline_buff(other_allegiance)
		var d: float = caster.global_position.distance_to(other.global_position)
		if d <= max_dist and town_map.has_clear_sightline(caster.global_position, other.global_position):
			witnessed = true
			break

	if witnessed:
		witnessed_disturbances += 1
		var region_name: String = town_map.get_region_name_at(caster.global_position)
		var region_anchor: Vector2 = town_map.get_region_alert_anchor_at(caster.global_position)
		# Strictly anonymous & kit-neutral public disturbance log + broad regional marker (never centered on the caster's exact position)
		var alert_text: String = "Unusual activity reported near %s." % region_name
		add_public_observed_fact(alert_text, region_name, _match_clock_text())
		town_map.spawn_field_zone("disturbance_ring", region_anchor, 210.0, 5.5, 0, region_name)
	return witnessed

func record_faction_ability_3d(caster: Node3D, town_map_3d: Node, all_residents: Array) -> bool:
	faction_abilities_used += 1
	if current_phase != Phase.OPEN_TOWN:
		return false
	var caster_pos: Vector3 = caster.global_position if caster.is_inside_tree() else caster.position
	record_observed_sighting_3d(caster, caster_pos, town_map_3d, all_residents, "used a special ability near")

	var witnessed := false
	for other in all_residents:
		if other == null or other == caster or other.is_incapacitated:
			continue
		var other_allegiance: String = get_resident_alignment(other)
		var max_dist: float = C.WITNESS_RADIUS * get_beacon_sightline_buff(other_allegiance)
		var other_pos: Vector3 = (other.global_position if other.is_inside_tree() else other.position) if (other is Node3D) else Vector3.ZERO
		var d: float = caster_pos.distance_to(other_pos)
		if d <= max_dist:
			if town_map_3d.has_method("has_clear_sightline_3d"):
				if town_map_3d.has_clear_sightline_3d(caster_pos, other_pos):
					witnessed = true
					break
			else:
				witnessed = true
				break

	if witnessed:
		witnessed_disturbances += 1
		var region_name: String = town_map_3d.get_region_name_at_3d(caster_pos) if town_map_3d.has_method("get_region_name_at_3d") else "Town Corridors"
		# Strictly anonymous & kit-neutral public disturbance log + broad regional marker (never centered on the caster's exact position)
		var alert_text: String = "Unusual activity reported near %s." % region_name
		add_public_observed_fact(alert_text, region_name, _match_clock_text())
		# Guardrail: never fall back to caster_pos; only spawn disturbance ring when a broad regional anchor is provided
		if town_map_3d.has_method("spawn_field_zone_3d") and town_map_3d.has_method("get_region_alert_anchor_at_3d"):
			var region_anchor: Vector3 = town_map_3d.get_region_alert_anchor_at_3d(caster_pos)
			town_map_3d.spawn_field_zone_3d("disturbance_ring", region_anchor, 6.0, 5.5, 0, region_name)
	return witnessed

func record_knockdown(victim_name: String) -> void:
	knockdowns_triggered += 1
	log_event("%s was exhausted and returned to Town Square Clinic (8s recovery)." % victim_name, Color(1.0, 0.52, 0.48))

func log_event(message: String, color: Color = Color(0.85, 0.88, 0.92)) -> void:
	var mins := int(time_remaining) / 60
	var secs := int(time_remaining) % 60
	var timestamp := "%02d:%02d" % [mins, secs]
	var entry := {
		"time": timestamp,
		"text": "[%s] %s" % [timestamp, message],
		"color": color
	}
	recent_events.push_front(entry)
	if recent_events.size() > 7:
		recent_events.pop_back()
	event_logged.emit(entry["text"], color)
