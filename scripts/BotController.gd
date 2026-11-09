class_name BotController
extends Node

const C = preload("res://scripts/GameConstants.gd")
const MOVE_SPEED: float = C.MOVE_SPEED

var resident: CharacterBody2D
var town_map: Node2D
var game_manager: Node

var state: String = "PAUSE" # "PAUSE", "MOVING_TO_PAD", "PATROLLING", "CHANNELING"
var pause_timer: float = 1.0
var target_pad: Dictionary = {}
var path_points: Array[Vector2] = []

var ability_check_timer: float = 1.5
var bot_inspection_cooldown: float = 0.0

# Stuck watchdog
var watchdog_timer: float = 0.0
var last_watchdog_pos: Vector2 = Vector2.ZERO

func setup(res: CharacterBody2D, map: Node2D, gm: Node, initial_delay: float) -> void:
	resident = res
	town_map = map
	game_manager = gm
	state = "PAUSE"
	pause_timer = initial_delay
	ability_check_timer = randf_range(1.5, 4.0)
	bot_inspection_cooldown = 0.0
	last_watchdog_pos = resident.global_position

func reset_bot(initial_delay: float) -> void:
	state = "PAUSE"
	pause_timer = initial_delay
	ability_check_timer = randf_range(1.5, 4.0)
	bot_inspection_cooldown = 0.0
	target_pad = {}
	path_points.clear()
	if resident != null:
		resident.desired_velocity = Vector2.ZERO
		last_watchdog_pos = resident.global_position

func _process(delta: float) -> void:
	if resident == null or town_map == null or game_manager == null:
		return
	if not game_manager.is_active_play_phase() or resident.is_incapacitated:
		if not target_pad.is_empty():
			town_map.release_reservations_for(resident)
			target_pad = {}
		path_points.clear()
		state = "PAUSE"
		pause_timer = randf_range(0.5, 1.4)
		resident.desired_velocity = Vector2.ZERO
		return
	if bot_inspection_cooldown > 0.0:
		bot_inspection_cooldown = maxf(0.0, bot_inspection_cooldown - delta)

	ability_check_timer -= delta
	if ability_check_timer <= 0.0:
		ability_check_timer = randf_range(2.2, 4.2)
		_evaluate_bot_abilities()

	if resident.is_inspecting:
		state = "INSPECTING"
		resident.desired_velocity = Vector2.ZERO
		return
	elif state == "INSPECTING":
		state = "PAUSE"
		pause_timer = randf_range(0.8, 1.6)
		return

	if resident.is_channeling:
		state = "CHANNELING"
		resident.desired_velocity = Vector2.ZERO
		return
	elif state == "CHANNELING":
		state = "PAUSE"
		pause_timer = randf_range(1.2, 2.6)
		target_pad = {}
		path_points.clear()
		return

	match state:
		"PAUSE":
			resident.desired_velocity = Vector2.ZERO
			pause_timer -= delta
			if pause_timer <= 0.0:
				_pick_next_goal()

		"MOVING_TO_PAD":
			if target_pad.is_empty() or not town_map.is_pad_available_for_bot(target_pad, resident):
				town_map.release_reservations_for(resident)
				target_pad = {}
				_pick_next_goal()
				return

			_follow_path(delta)

			if resident.global_position.distance_to(target_pad["pos"]) <= 34.0:
				resident.desired_velocity = Vector2.ZERO
				if resident.try_start_channel():
					state = "CHANNELING"
				else:
					town_map.release_reservations_for(resident)
					target_pad = {}
					state = "PAUSE"
					pause_timer = randf_range(0.8, 1.6)

		"PATROLLING":
			_follow_path(delta)
			if path_points.is_empty():
				state = "PAUSE"
				pause_timer = randf_range(0.8, 1.8)

func _evaluate_bot_abilities() -> void:
	if resident.is_channeling or resident.is_inspecting:
		return

	if bot_inspection_cooldown <= 0.0:
		var inspect_target: Dictionary = town_map.get_inspection_target(resident.global_position, 100.0)
		if not inspect_target.is_empty():
			var target_kind: String = String(inspect_target.get("kind", ""))
			if target_kind == "archive_cache" and not bool(inspect_target.get("is_opened", false)) and not game_manager.archive_opened:
				if randf() < 0.35 and resident.try_inspect_site():
					town_map.release_reservations_for(resident)
					target_pad = {}
					path_points.clear()
					state = "INSPECTING"
					bot_inspection_cooldown = 20.0
					return
			elif target_kind == "pad" and game_manager.current_phase == game_manager.Phase.OPEN_TOWN:
				var inspect_pad: Dictionary = inspect_target.get("pad", {})
				var was_recently_used: bool = float(inspect_pad.get("last_use_time", -1.0)) >= 0.0
				var is_suspicious: bool = float(inspect_pad.get("jammed_timer", 0.0)) > 0.0 or String(inspect_pad.get("last_action", "")) in ["jammed", "overclocked", "snared"]
				if (was_recently_used or is_suspicious) and randf() < 0.25 and resident.try_inspect_site():
					town_map.release_reservations_for(resident)
					target_pad = {}
					path_points.clear()
					state = "INSPECTING"
					bot_inspection_cooldown = 25.0
					return

	# 1. Public Civic Job Ability [F]
	if resident.civic_cooldown_left <= 0.01:
		match resident.civic_job:
			"Salvage Quartermaster":
				if (state == "MOVING_TO_PAD" or state == "PATROLLING") and randf() < 0.45:
					resident.try_civic_ability()
			"Pump Technician":
				var np: Dictionary = town_map.get_nearest_pad(resident.global_position, 135.0)
				if not np.is_empty() and (float(np["cooldown"]) > 3.0 or float(np["jammed_timer"]) > 1.0):
					resident.try_civic_ability()
			"Crop Tender":
				if resident.stamina < 85.0 and randf() < 0.65:
					resident.try_civic_ability()
			"Field Medic":
				if resident.stamina < 80.0:
					resident.try_civic_ability()
				else:
					for other in resident.all_residents:
						if other != null and other != resident and not other.is_incapacitated and other.stamina < 85.0:
							if resident.global_position.distance_to(other.global_position) <= 105.0:
								resident.try_civic_ability()
								break
			"Town Watch":
				if game_manager.is_faction_kit_unlocked_openly() and randf() < 0.35:
					resident.try_civic_ability()

	# 2. Operative Faction Kit [C] & Clash Shove [Q] during Escalation and Finale
	if game_manager.is_faction_kit_unlocked_openly() and resident.secret_role != "civilian":
		if resident.faction_cooldown_left <= 0.01:
			var pad_near: Dictionary = town_map.get_nearest_pad(resident.global_position, 125.0)
			match resident.operative_kit:
				"saboteur":
					if not pad_near.is_empty() and float(pad_near["jammed_timer"]) <= 0.0 and randf() < 0.55:
						resident.try_faction_ability()
						return
				"mechanic":
					if not pad_near.is_empty() and (float(pad_near["cooldown"]) > 3.0 or not bool(pad_near["overclocked"])) and randf() < 0.55:
						resident.try_faction_ability()
						return
				"warden":
					if not pad_near.is_empty() and randf() < 0.45:
						resident.try_faction_ability()
						return
				"grower":
					if randf() < 0.35:
						resident.try_faction_ability()
						return
				"runner":
					if (state == "MOVING_TO_PAD" or state == "PATROLLING") and randf() < 0.45:
						resident.try_faction_ability()
						return
				"tracker":
					if randf() < 0.35:
						resident.try_faction_ability()
						return

		# Contesting shove against non-partner channeling a pad during Escalation / Finale
		if resident.shove_cooldown_left <= 0.01 and randf() < 0.35:
			for other in resident.all_residents:
				if other == null or other == resident or other.is_incapacitated:
					continue
				if other.secret_role != resident.secret_role and other.is_channeling:
					if resident.global_position.distance_to(other.global_position) <= 82.0:
						resident.try_civic_shove()
						return

func _follow_path(delta: float) -> void:
	if path_points.is_empty():
		resident.desired_velocity = Vector2.ZERO
		return

	watchdog_timer += delta
	if watchdog_timer >= 1.2:
		var moved_dist := resident.global_position.distance_to(last_watchdog_pos)
		watchdog_timer = 0.0
		last_watchdog_pos = resident.global_position
		if moved_dist < 15.0:
			town_map.release_reservations_for(resident)
			target_pad = {}
			_pick_patrol_route()
			return

	var next_pt: Vector2 = path_points[0]
	var diff: Vector2 = next_pt - resident.global_position
	if diff.length() <= 24.0:
		path_points.pop_front()
		if path_points.is_empty():
			resident.desired_velocity = Vector2.ZERO
			return
		next_pt = path_points[0]
		diff = next_pt - resident.global_position

	resident.desired_velocity = diff.normalized() * (MOVE_SPEED * 0.90)

func _pick_next_goal() -> void:
	var candidates: Array[Dictionary] = []
	for pad in town_map.task_pads:
		if town_map.is_pad_available_for_bot(pad, resident):
			candidates.append(pad)
	for hid in town_map.hazard_pads.keys():
		var hpad: Dictionary = town_map.hazard_pads[hid]
		if town_map.is_pad_available_for_bot(hpad, resident):
			candidates.append(hpad)

	if not candidates.is_empty():
		var best_pad: Dictionary = candidates[0]
		var best_score: float = -9999.0
		var my_allegiance: String = resident.get_allegiance() if resident.has_method("get_allegiance") else resident.secret_role
		var in_finale: bool = (game_manager.current_phase == game_manager.Phase.FINALE)
		var is_confrontation: bool = (in_finale and game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION)
		var is_peace: bool = (in_finale and game_manager.finale_route == C.FINALE_ROUTE_PEACE)

		for pad in candidates:
			var score: float = randf_range(0.0, 25.0)
			var dist: float = resident.global_position.distance_to(pad["pos"])
			score -= dist * 0.012

			match pad["task_type"]:
				"pump":
					if game_manager.water < 65.0:
						score += 32.0
				"greenhouse":
					if game_manager.stability < 70.0:
						score += 28.0
				"salvage":
					if game_manager.scrap < 5:
						score += 30.0
				"cw_eco":
					if game_manager.water >= 1.0 and game_manager.common_works_eco < 100.0:
						score += 35.0 if is_peace else 26.0
				"cw_tech":
					if game_manager.scrap >= 1 and game_manager.common_works_tech < 100.0:
						score += 35.0 if is_peace else 26.0
				"cw_struct":
					if resident.stamina >= 35.0 and game_manager.common_works_struct < 100.0:
						score += 35.0 if is_peace else 24.0
				"common_works":
					if game_manager.scrap >= 3 and game_manager.common_works < 100.0:
						score += 26.0
				"generator_objective":
					if is_confrontation:
						score += 55.0 if (my_allegiance == "technology" or my_allegiance == "ecology") else 20.0
					else:
						if my_allegiance == "technology":
							score += 38.0
						elif my_allegiance == "ecology":
							score += 34.0
						else:
							score += 18.0
				"beacon_objective":
					if is_confrontation:
						score += 40.0
					else:
						if my_allegiance == "ecology":
							score += 38.0
						elif my_allegiance == "technology":
							score += 34.0
						else:
							score += 18.0
				"ratify_eco":
					if is_peace and my_allegiance == "ecology":
						score += 65.0
				"ratify_tech":
					if is_peace and my_allegiance == "technology":
						score += 65.0
				"hazard_clear":
					if is_peace and game_manager.holdout_active:
						score += 60.0

			if score > best_score:
				best_score = score
				best_pad = pad

		if town_map.reserve_pad(best_pad, resident):
			target_pad = best_pad
			var wp: String = String(best_pad.get("waypoint", town_map.get_nearest_waypoint_id(best_pad["pos"])))
			path_points = town_map.find_waypoint_path(resident.global_position, wp)
			var jitter := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			path_points.append(best_pad["pos"] + jitter)
			state = "MOVING_TO_PAD"
			watchdog_timer = 0.0
			last_watchdog_pos = resident.global_position
			return

	_pick_patrol_route()

func _pick_patrol_route() -> void:
	# 10% chance to investigate a secluded cache site if the archive has not yet been discovered
	if not game_manager.archive_opened and randf() < 0.10:
		var cache_wps := ["cache_north_pass", "cache_salvage", "cache_pump", "cache_council"]
		var picked_cache: String = cache_wps[randi() % cache_wps.size()]
		path_points = town_map.find_waypoint_path(resident.global_position, picked_cache)
		state = "PATROLLING"
		watchdog_timer = 0.0
		last_watchdog_pos = resident.global_position
		return

	var wp_keys: Array = town_map.waypoints.keys()
	var current_wp: String = town_map.get_nearest_waypoint_id(resident.global_position)
	var random_wp: String = wp_keys[randi() % wp_keys.size()]
	if random_wp == current_wp and wp_keys.size() > 1:
		random_wp = wp_keys[(wp_keys.find(current_wp) + 1 + (randi() % (wp_keys.size() - 1))) % wp_keys.size()]
	path_points = town_map.find_waypoint_path(resident.global_position, random_wp)
	if path_points.size() > 1 and resident.global_position.distance_to(path_points[0]) < 85.0:
		path_points.pop_front()
	var jitter := Vector2(randf_range(-32.0, 32.0), randf_range(-32.0, 32.0))
	if not path_points.is_empty():
		path_points[path_points.size() - 1] += jitter
	state = "PATROLLING"
	watchdog_timer = 0.0
	last_watchdog_pos = resident.global_position
