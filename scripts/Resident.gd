class_name Resident
extends CharacterBody2D

const C = preload("res://scripts/GameConstants.gd")

const MOVE_SPEED: float = C.MOVE_SPEED
const CHANNEL_DURATION: float = C.CHANNEL_DURATION
const PAD_INTERACT_RADIUS: float = C.PAD_INTERACT_RADIUS
const SHOVE_COOLDOWN: float = C.SHOVE_COOLDOWN
const SHOVE_RADIUS: float = C.SHOVE_RADIUS
const SHOVE_STAMINA_DAMAGE: float = C.SHOVE_STAMINA_DAMAGE
const MAX_STAMINA: float = C.MAX_STAMINA
const STAMINA_REGEN_RATE: float = C.STAMINA_REGEN_RATE
const RESPAWN_DURATION: float = C.RESPAWN_DURATION
const SEPARATION_RADIUS: float = C.SEPARATION_RADIUS

var resident_id: int = 1
var resident_name: String = "Resident 1"
var civic_job: String = "Pump Technician"
var secret_role: String = "civilian" # "ecology", "technology", or "civilian" (strictly hidden on sprite)
var operative_kit: String = "none" # "tracker", "grower", "warden", "runner", "mechanic", "saboteur", or "none"
var is_player: bool = false

var spawn_position: Vector2 = Vector2.ZERO
var town_map: Node2D
var game_manager: Node
var all_residents: Array = []

var desired_velocity: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO

# Stamina & Non-Lethal Knockdown / Respawn state
var stamina: float = MAX_STAMINA
var is_incapacitated: bool = false
var respawn_timer: float = 0.0

# Visual readability & animation state
var facing_angle: float = 0.0
var walk_cycle: float = 0.0
var work_anim_time: float = 0.0

# Task channeling state
var is_channeling: bool = false
var channel_progress: float = 0.0
var active_pad: Dictionary = {}
var is_inspecting: bool = false
var inspection_timer: float = 0.0
var inspection_target: Dictionary = {}

# Ability cooldowns & status buffs
var shove_cooldown_left: float = 0.0
var shove_visual_timer: float = 0.0
var shove_target_offset: Vector2 = Vector2.ZERO

var civic_cooldown_left: float = 0.0
var faction_cooldown_left: float = 0.0

var speed_buff_timer: float = 0.0
var speed_buff_mult: float = 1.0
var watch_shield_timer: float = 0.0
var work_speed_timer: float = 0.0

# Floating status popup
var popup_text: String = ""
var popup_color: Color = Color.WHITE
var popup_timer: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 # Collide solidly with walls (layer 1), use soft steering for other residents

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	col_shape.shape = circle
	add_child(col_shape)

func reset_to_spawn(spawn_pos: Vector2) -> void:
	spawn_position = spawn_pos
	cancel_channeling()
	cancel_inspection()
	global_position = spawn_pos
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	stamina = MAX_STAMINA
	is_incapacitated = false
	respawn_timer = 0.0
	shove_cooldown_left = 0.0
	shove_visual_timer = 0.0
	civic_cooldown_left = 0.0
	faction_cooldown_left = 0.0
	speed_buff_timer = 0.0
	speed_buff_mult = 1.0
	watch_shield_timer = 0.0
	work_speed_timer = 0.0
	popup_timer = 0.0
	walk_cycle = 0.0
	var to_center := Vector2(0, 120) - spawn_pos
	if to_center.length_squared() > 1.0:
		facing_angle = to_center.angle()
	queue_redraw()

func gather_at_council_ring(bench_pos: Vector2) -> void:
	cancel_channeling()
	cancel_inspection()
	global_position = bench_pos
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	is_incapacitated = false
	respawn_timer = 0.0
	speed_buff_timer = 0.0
	watch_shield_timer = 0.0
	work_speed_timer = 0.0
	stamina = MAX_STAMINA
	var to_center := Vector2(0, 120) - bench_pos
	if to_center.length_squared() > 1.0:
		facing_angle = to_center.angle()
	queue_redraw()

func get_speed_multiplier() -> float:
	var mult: float = speed_buff_mult if speed_buff_timer > 0.0 else 1.0
	if town_map != null and town_map.is_slowed_by_root_snare(global_position, resident_id):
		mult *= 0.55
	return mult

func _physics_process(delta: float) -> void:
	if shove_cooldown_left > 0.0:
		shove_cooldown_left = maxf(0.0, shove_cooldown_left - delta)
	if civic_cooldown_left > 0.0:
		civic_cooldown_left = maxf(0.0, civic_cooldown_left - delta)
	if faction_cooldown_left > 0.0:
		faction_cooldown_left = maxf(0.0, faction_cooldown_left - delta)
	if speed_buff_timer > 0.0:
		speed_buff_timer = maxf(0.0, speed_buff_timer - delta)
		queue_redraw()
	if watch_shield_timer > 0.0:
		watch_shield_timer = maxf(0.0, watch_shield_timer - delta)
		queue_redraw()
	if work_speed_timer > 0.0:
		work_speed_timer = maxf(0.0, work_speed_timer - delta)
	if shove_visual_timer > 0.0:
		shove_visual_timer = maxf(0.0, shove_visual_timer - delta)
		queue_redraw()
	if popup_timer > 0.0:
		popup_timer = maxf(0.0, popup_timer - delta)
		queue_redraw()

	if game_manager != null and not game_manager.is_active_play_phase():
		if is_channeling:
			cancel_channeling()
		cancel_inspection()
		desired_velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		return

	if is_inspecting:
		if desired_velocity.length() > 35.0:
			cancel_inspection()
		else:
			inspection_timer = maxf(0.0, inspection_timer - delta)
			desired_velocity = Vector2.ZERO
			velocity = Vector2.ZERO
			queue_redraw()
			if inspection_timer <= 0.0:
				var completed_target: Dictionary = inspection_target
				is_inspecting = false
				inspection_target = {}
				if town_map != null:
					town_map.complete_site_inspection(self, completed_target)
				if is_player:
					show_popup("Verified trace recorded in [J].", Color(0.48, 0.90, 1.0))
			return

	# Handle 8s non-lethal recovery at Town Square bench
	if is_incapacitated:
		respawn_timer = maxf(0.0, respawn_timer - delta)
		desired_velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		queue_redraw()
		if respawn_timer <= 0.0:
			is_incapacitated = false
			stamina = MAX_STAMINA
			show_popup("Recovered!", Color(0.55, 0.98, 0.68))
		return

	if game_manager != null and town_map != null:
		game_manager.record_region_sample(self, town_map.get_region_name_at(global_position))

	# Passive stamina recovery + Mulch Mist bonus regeneration
	var regen: float = STAMINA_REGEN_RATE
	if town_map != null and town_map.is_inside_mulch_mist(global_position):
		regen += 8.0
	if stamina < MAX_STAMINA:
		stamina = minf(MAX_STAMINA, stamina + regen * delta)
		queue_redraw()

	if is_channeling:
		work_anim_time += delta
		if not active_pad.is_empty():
			var console_world: Vector2 = active_pad["pos"] + active_pad.get("console_offset", Vector2.ZERO)
			var to_console := console_world - global_position
			if to_console.length_squared() > 1.0:
				facing_angle = lerp_angle(facing_angle, to_console.angle(), 12.0 * delta)

		if active_pad.is_empty() or global_position.distance_to(active_pad["pos"]) > PAD_INTERACT_RADIUS + 14.0:
			cancel_channeling()
		elif float(active_pad.get("jammed_timer", 0.0)) > 0.0:
			cancel_channeling()
			show_popup("Station Jammed!", Color(1.0, 0.48, 0.42))
		elif game_manager != null and not game_manager.can_perform_task(active_pad["task_type"]):
			cancel_channeling()
			if is_player:
				show_popup("No Scrap / Already Complete", Color(0.95, 0.65, 0.45))
		elif desired_velocity.length() > 35.0:
			cancel_channeling()
		else:
			var ch_mult: float = 1.40 if work_speed_timer > 0.0 else 1.0
			if game_manager != null and game_manager.current_phase == game_manager.Phase.FINALE:
				var allegiance: String = get_allegiance()
				ch_mult *= game_manager.get_archive_objective_speed_mult(allegiance)
				if active_pad.get("task_type", "") == "generator_objective":
					ch_mult *= game_manager.get_beacon_speed_buff(allegiance)
			channel_progress += delta * ch_mult
			queue_redraw()
			var req_duration: float = float(active_pad.get("channel_duration", CHANNEL_DURATION))
			if active_pad.get("task_type", "") == "hazard_clear" and game_manager != null:
				if game_manager.charter_land == C.CHARTER_LAND_RESTRICTED and get_allegiance() == "ecology":
					req_duration = C.HOLDOUT_HAZARD_CLEAR_RESTRICTED_ECO
			if channel_progress >= req_duration:
				var completed_pad := active_pad
				is_channeling = false
				channel_progress = 0.0
				active_pad = {}
				if completed_pad.get("task_type", "") == "cw_struct":
					stamina = maxf(0.0, stamina - 25.0)
				if town_map != null:
					town_map.finish_using_pad(completed_pad, self, is_player)
				show_popup("Task Complete!", Color(0.55, 0.98, 0.65))

	var sep_force := _compute_soft_separation()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 620.0 * delta)

	var move_vec := Vector2.ZERO if is_channeling else (desired_velocity * get_speed_multiplier())
	velocity = move_vec + sep_force + knockback_velocity
	move_and_slide()

	if move_vec.length_squared() > 25.0:
		facing_angle = lerp_angle(facing_angle, move_vec.angle(), 11.0 * delta)
		walk_cycle += delta * 11.5 * get_speed_multiplier()
		queue_redraw()
	elif velocity.length_squared() > 4.0 or is_channeling:
		queue_redraw()

func get_allegiance() -> String:
	if game_manager != null:
		return game_manager.get_resident_alignment(self)
	return secret_role

func _compute_soft_separation() -> Vector2:
	var push := Vector2.ZERO
	for other in all_residents:
		if other == null or other == self or other.is_incapacitated:
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()
		if dist > 0.001 and dist < SEPARATION_RADIUS:
			var strength: float = (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS
			push += (diff / dist) * strength * 115.0
	return push

func try_start_channel() -> bool:
	if is_channeling or is_inspecting or is_incapacitated or town_map == null:
		return false
	if game_manager != null and (not game_manager.is_active_play_phase() or game_manager.archive_dilemma_open):
		return false
	var pad: Dictionary = town_map.get_nearest_pad(global_position)
	if pad.is_empty():
		if is_player:
			show_popup("Move closer to a task station", Color(0.95, 0.78, 0.45))
		return false
	if float(pad.get("jammed_timer", 0.0)) > 0.0:
		if is_player:
			show_popup("Station Jammed (%.1fs)" % float(pad["jammed_timer"]), Color(1.0, 0.50, 0.42))
		return false
	if pad["cooldown"] > 0.0:
		if is_player:
			show_popup("Station cooling down (%.1fs)" % pad["cooldown"], Color(0.95, 0.65, 0.45))
		return false
	if pad["active_user"] != null and pad["active_user"] != self:
		if is_player:
			show_popup("Station in use by another resident", Color(0.95, 0.65, 0.45))
		return false

	var task_t: String = String(pad.get("task_type", ""))
	if (task_t == "generator_objective" or task_t == "beacon_objective"):
		if game_manager != null and not (game_manager.current_phase == game_manager.Phase.ESCALATION or game_manager.current_phase == game_manager.Phase.FINALE):
			if is_player:
				show_popup("Objective locked until Escalation!", Color(1.0, 0.65, 0.45))
			return false
	elif task_t == "cw_struct" and stamina < 25.0:
		if is_player:
			show_popup("Needs at least 25 Stamina!", Color(1.0, 0.55, 0.45))
		return false
	elif task_t == "ratify_eco":
		var my_align: String = get_allegiance()
		if my_align != "ecology" and secret_role != "ecology":
			if is_player:
				show_popup("Requires Ecological alignment to ratify!", Color(1.0, 0.55, 0.45))
			return false
	elif task_t == "ratify_tech":
		var my_align: String = get_allegiance()
		if my_align != "technology" and secret_role != "technology":
			if is_player:
				show_popup("Requires Technology alignment to ratify!", Color(1.0, 0.55, 0.45))
			return false
	elif game_manager != null and not game_manager.can_perform_task(task_t):
		if is_player:
			if task_t == "cw_eco":
				show_popup("Needs at least 1 Water or already 100%!", Color(0.98, 0.55, 0.45))
			elif task_t == "cw_tech":
				show_popup("Needs at least 1 Scrap or already 100%!", Color(0.98, 0.55, 0.45))
			elif task_t == "cw_struct":
				show_popup("Structural track already 100% complete!", Color(0.65, 0.95, 0.75))
			elif task_t == "common_works" and game_manager.common_works >= 99.9:
				show_popup("Common Works already 100% complete!", Color(0.65, 0.95, 0.75))
			else:
				show_popup("Needs at least 1 Scrap!", Color(0.98, 0.55, 0.45))
		return false

	if town_map.start_using_pad(pad, self):
		is_channeling = true
		channel_progress = 0.0
		work_anim_time = 0.0
		active_pad = pad
		desired_velocity = Vector2.ZERO
		queue_redraw()
		return true
	return false

func cancel_channeling() -> void:
	if not is_channeling and active_pad.is_empty():
		return
	is_channeling = false
	channel_progress = 0.0
	if town_map != null:
		town_map.release_reservations_for(self)
	active_pad = {}
	queue_redraw()

func try_inspect_site() -> bool:
	if is_inspecting or is_channeling or is_incapacitated or town_map == null or game_manager == null:
		return false
	if not game_manager.is_active_play_phase() or (is_player and game_manager.archive_dilemma_open):
		return false
	var target: Dictionary = town_map.get_inspection_target(global_position, 100.0)
	if target.is_empty():
		if is_player:
			show_popup("Move within 100px of a station or inspection site.", Color(0.95, 0.78, 0.45))
		return false
	is_inspecting = true
	inspection_timer = 2.5
	inspection_target = target
	desired_velocity = Vector2.ZERO
	if is_player:
		show_popup("Inspecting %s (2.5s)…" % String(target.get("label", "site")), Color(0.55, 0.88, 1.0))
	queue_redraw()
	return true

func cancel_inspection() -> void:
	if not is_inspecting:
		return
	is_inspecting = false
	inspection_timer = 0.0
	inspection_target = {}
	queue_redraw()

func try_civic_shove() -> bool:
	if is_incapacitated:
		return false
	if game_manager != null and not game_manager.is_active_play_phase():
		return false
	if shove_cooldown_left > 0.0:
		if is_player:
			show_popup("Shove on cooldown (%.1fs)" % shove_cooldown_left, Color(0.95, 0.65, 0.45))
		return false
	cancel_inspection()

	var closest_other: Node2D = null
	var closest_dist: float = SHOVE_RADIUS
	for other in all_residents:
		if other == null or other == self or other.is_incapacitated:
			continue
		var dist: float = global_position.distance_to(other.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest_other = other

	cancel_channeling()
	shove_cooldown_left = SHOVE_COOLDOWN
	shove_visual_timer = 0.32

	if closest_other != null:
		var diff: Vector2 = closest_other.global_position - global_position
		var dir: Vector2 = diff.normalized() if diff.length() > 0.01 else Vector2(cos(facing_angle), sin(facing_angle))
		facing_angle = dir.angle()
		shove_target_offset = diff
		closest_other.receive_shove(dir * 340.0, SHOVE_STAMINA_DAMAGE, self, false)
		if game_manager != null:
			game_manager.record_shove(resident_name, closest_other.resident_name)
		show_popup("Shoved %s!" % closest_other.resident_name, Color(1.0, 0.82, 0.45))
	else:
		shove_target_offset = Vector2(cos(facing_angle), sin(facing_angle)) * 48.0
		if game_manager != null:
			game_manager.record_shove(resident_name, "")
		show_popup("Civic Shove (No target)", Color(0.85, 0.85, 0.90))
	if town_map != null:
		town_map.record_resident_action(self, "used Civic Shove")

	queue_redraw()
	return true

func try_civic_ability() -> bool:
	if is_incapacitated or town_map == null or game_manager == null:
		return false
	if not game_manager.is_active_play_phase():
		return false
	if civic_cooldown_left > 0.0:
		if is_player:
			show_popup("Civic Kit on cooldown (%.1fs)" % civic_cooldown_left, Color(0.95, 0.65, 0.45))
		return false
	cancel_inspection()

	var kit_meta: Dictionary = C.CIVIC_KIT_INFO.get(civic_job, {})
	var cd: float = float(kit_meta.get("cooldown", 14.0))
	var ab_name: String = String(kit_meta.get("ability_name", "Civic Ability"))
	civic_cooldown_left = cd

	match civic_job:
		"Pump Technician":
			var near_pad: Dictionary = town_map.get_nearest_pad(global_position, 140.0)
			if not near_pad.is_empty() and (float(near_pad["cooldown"]) > 0.0 or float(near_pad["jammed_timer"]) > 0.0):
				near_pad["cooldown"] = maxf(0.0, float(near_pad["cooldown"]) - 6.0)
				near_pad["jammed_timer"] = maxf(0.0, float(near_pad["jammed_timer"]) - 4.0)
				town_map.record_pad_interaction(near_pad, resident_name, "calibrated")
				game_manager.record_civic_ability(resident_name, ab_name, "calibrated " + String(near_pad["label"]))
				show_popup("Field Calibrator: -6s Pad CD!", Color(0.45, 0.88, 1.0))
			else:
				work_speed_timer = 4.0
				game_manager.record_civic_ability(resident_name, ab_name, "+40% work speed (4s)")
				show_popup("Field Calibrator: +40% Work Spd!", Color(0.45, 0.88, 1.0))

		"Crop Tender":
			town_map.spawn_field_zone("mulch_mist", global_position, 95.0, 5.0, resident_id)
			game_manager.record_civic_ability(resident_name, ab_name, "95px stamina mist")
			show_popup("Mulch Mist (+8 Stam/s)!", Color(0.48, 0.96, 0.62))

		"Salvage Quartermaster":
			speed_buff_timer = 3.5
			speed_buff_mult = 1.45
			game_manager.record_civic_ability(resident_name, ab_name, "+45% move speed")
			show_popup("Haul Rig Sprint (+45% Spd)!", Color(0.98, 0.78, 0.38))

		"Field Medic":
			stamina = minf(MAX_STAMINA, stamina + 35.0)
			var ally: Node2D = _find_nearest_other_resident(110.0)
			if ally != null:
				ally.stamina = minf(MAX_STAMINA, ally.stamina + 35.0)
				ally.show_popup("+35 Stamina (First Aid)!", Color(0.55, 0.98, 0.72))
				game_manager.record_civic_ability(resident_name, ab_name, "healed self & " + ally.resident_name)
				show_popup("First Aid: +35 Stam (+%s)!" % ally.resident_name, Color(0.55, 0.98, 0.72))
			else:
				game_manager.record_civic_ability(resident_name, ab_name, "restored +35 Stamina")
				show_popup("First Aid Patch: +35 Stamina!", Color(0.55, 0.98, 0.72))

		"Town Watch":
			watch_shield_timer = 4.5
			game_manager.record_civic_ability(resident_name, ab_name, "4.5s Watch Shield")
			show_popup("Brace & Lantern (Shield 4.5s)!", Color(0.75, 0.88, 1.0))

	queue_redraw()
	town_map.record_resident_action(self, "used a public civic ability")
	return true

func try_faction_ability() -> bool:
	if is_incapacitated or town_map == null or game_manager == null:
		return false
	if not game_manager.is_active_play_phase():
		return false
	if operative_kit == "none" or secret_role == "civilian":
		if is_player:
			show_popup("Civilian: Use [F] Civic Kit & Court Vote", Color(0.92, 0.86, 0.58))
		return false
	if faction_cooldown_left > 0.0:
		if is_player:
			show_popup("Special Kit on cooldown (%.1fs)" % faction_cooldown_left, Color(0.95, 0.65, 0.45))
		return false
	cancel_inspection()

	var kit_meta: Dictionary = C.OPERATIVE_KIT_INFO.get(operative_kit, {})
	var cd: float = float(kit_meta.get("cooldown", 16.0))
	faction_cooldown_left = cd

	match operative_kit:
		"tracker":
			var traces: int = town_map.trigger_tracker_scent_snapshot(self, all_residents, 320.0, 5.0)
			if is_player:
				show_popup("Scent Trail Snapshot (%d traces, 5s)" % traces, Color(0.52, 1.0, 0.72))

		"grower":
			town_map.spawn_field_zone("root_snare", global_position, 105.0, 6.0, resident_id)
			var greenhouse_pad: Dictionary = town_map.get_nearest_pad(global_position, 105.0)
			if not greenhouse_pad.is_empty() and String(greenhouse_pad.get("task_type", "")) == "greenhouse":
				town_map.record_pad_interaction(greenhouse_pad, resident_name, "snared")
			if is_player:
				show_popup("Root Snare Placed (6s)!", Color(0.62, 0.95, 0.45))

		"warden":
			var near_pad: Dictionary = town_map.get_nearest_pad(global_position, 120.0)
			var canopy_pos: Vector2 = near_pad["pos"] if not near_pad.is_empty() else global_position
			town_map.spawn_field_zone("thorn_guard", canopy_pos, 90.0, 6.0, resident_id)
			if is_player:
				show_popup("Thorn Guard Canopy (6s)!", Color(0.48, 0.98, 0.72))

		"runner":
			cancel_channeling()
			var start_p := global_position
			var dash_dir := desired_velocity.normalized() if desired_velocity.length() > 10.0 else Vector2(cos(facing_angle), sin(facing_angle))
			facing_angle = dash_dir.angle()
			move_and_collide(dash_dir * 160.0)
			speed_buff_timer = 2.5
			speed_buff_mult = 1.35
			town_map.spawn_field_zone("spark_trail", global_position, 24.0, 4.0, resident_id, "", start_p)
			if is_player:
				show_popup("Exosuit Burst!", Color(0.45, 0.88, 1.0))

		"mechanic":
			var near_pad_m: Dictionary = town_map.get_nearest_pad(global_position, 140.0)
			if not near_pad_m.is_empty():
				near_pad_m["cooldown"] = 0.0
				near_pad_m["jammed_timer"] = 0.0
				near_pad_m["overclocked"] = true
				town_map.record_pad_interaction(near_pad_m, resident_name, "overclocked")
				if is_player:
					show_popup("Overclock Rig: Pad Ready +50%!", Color(0.45, 0.95, 1.0))
			else:
				work_speed_timer = 6.0
				if is_player:
					show_popup("Overclock Rig: +40% Work Spd (6s)!", Color(0.45, 0.95, 1.0))

		"saboteur":
			cancel_channeling()
			var near_pad_s: Dictionary = town_map.get_nearest_pad(global_position, 130.0)
			var target_res: Node2D = null
			if not near_pad_s.is_empty():
				# Case 1: Pad in range (130px) -> jam the pad for 8s, and ONLY shock the resident actively working that pad (if any)
				if near_pad_s["active_user"] != null and near_pad_s["active_user"] != self:
					target_res = near_pad_s["active_user"]
				near_pad_s["jammed_timer"] = 8.0
				town_map.record_pad_interaction(near_pad_s, resident_name, "jammed")
			else:
				# Case 2: No pad in range -> shock the single nearest other resident within 100px
				target_res = _find_nearest_other_resident(100.0)
			if target_res != null and target_res != self:
				var diff_s: Vector2 = target_res.global_position - global_position
				var dir_s: Vector2 = diff_s.normalized() if diff_s.length() > 0.01 else Vector2(cos(facing_angle), sin(facing_angle))
				target_res.receive_shove(dir_s * 220.0, 25.0, self, true)
			if is_player:
				if not near_pad_s.is_empty():
					show_popup("Shock Tool: Pad Jammed (8s)!", Color(1.0, 0.58, 0.42))
				elif target_res != null:
					show_popup("Shock Tool: Hit %s (-25 Stam)!" % target_res.resident_name, Color(1.0, 0.58, 0.42))
				else:
					show_popup("Shock Tool (No Pad/Target in range)", Color(0.90, 0.75, 0.55))

	var was_witnessed: bool = game_manager.record_faction_ability(self, town_map, all_residents)
	if was_witnessed and is_player:
		show_popup("Witnessed! Disturbance logged!", Color(1.0, 0.72, 0.32))

	queue_redraw()
	return true

func _find_nearest_other_resident(max_r: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_r
	for other in all_residents:
		if other == null or other == self or other.is_incapacitated:
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d <= best_d:
			best_d = d
			best = other
	return best

func receive_shove(impulse: Vector2, stamina_dmg: float = SHOVE_STAMINA_DAMAGE, attacker: Node2D = null, is_shock_tool: bool = false) -> void:
	if is_incapacitated:
		return

	# 1. Town Watch Shield blocks incoming Shove / Shock Tool
	if watch_shield_timer > 0.0:
		watch_shield_timer = 0.0
		show_popup("Watch Shield Blocked Hit!", Color(0.65, 0.92, 1.0))
		queue_redraw()
		return

	# 2. Warden's Thorn Guard Canopy protects occupants from Civic Shove and reflects 20 Stamina damage
	if not is_shock_tool and town_map != null and town_map.is_protected_by_thorn_guard(global_position):
		show_popup("Protected by Thorn Guard!", Color(0.52, 1.0, 0.75))
		if attacker != null and attacker != self and not attacker.is_incapacitated:
			attacker.stamina = maxf(0.0, attacker.stamina - 20.0)
			attacker.show_popup("Thorn Guard Reflected -20 Stam!", Color(1.0, 0.55, 0.45))
			if attacker.stamina <= 0.01:
				attacker.trigger_knockdown()
		queue_redraw()
		return

	var was_channeling := is_channeling
	cancel_channeling()
	cancel_inspection()
	stamina = maxf(0.0, stamina - stamina_dmg)
	if stamina <= 0.01:
		trigger_knockdown()
		return

	knockback_velocity = impulse
	if is_shock_tool:
		show_popup("Shocked! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.52, 0.42))
	elif was_channeling:
		show_popup("Interrupted! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.48, 0.42))
	else:
		show_popup("Shoved! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.72, 0.45))
	queue_redraw()

func trigger_knockdown() -> void:
	cancel_channeling()
	is_incapacitated = true
	respawn_timer = RESPAWN_DURATION
	speed_buff_timer = 0.0
	watch_shield_timer = 0.0
	work_speed_timer = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	if game_manager != null:
		game_manager.record_knockdown(resident_name)
	show_popup("Exhausted! Recovering (8s)", Color(1.0, 0.45, 0.42))
	queue_redraw()

func show_popup(text: String, col: Color = Color.WHITE) -> void:
	popup_text = text
	popup_color = col
	popup_timer = 1.4
	queue_redraw()

func _get_action_verb() -> String:
	if active_pad.is_empty():
		return "Working..."
	match active_pad.get("task_type", ""):
		"pump":
			return "Repairing Pump..."
		"greenhouse":
			return "Tending Crops..."
		"salvage":
			return "Sorting Scrap..."
		"common_works":
			return "Building Facility..."
	return "Working..."

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var is_moving := desired_velocity.length_squared() > 25.0 and not is_channeling and not is_incapacitated

	# 1. Single-target Civic Shove directional arc visual
	if shove_visual_timer > 0.0:
		var t: float = 1.0 - (shove_visual_timer / 0.32)
		var ang := shove_target_offset.angle()
		var rad := lerpf(22.0, 68.0, t)
		draw_arc(Vector2.ZERO, rad, ang - 0.55, ang + 0.55, 16, Color(1.0, 0.82, 0.45, 1.0 - t), 4.0)

	# 2. Active Status Rings (Watch Shield / Speed Buff)
	if is_inspecting:
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 36, Color(0.48, 0.88, 1.0, 0.9), 3.0)
		draw_rect(Rect2(Vector2(-24, -43), Vector2(48, 5)), Color(0.12, 0.16, 0.20, 0.9), true)
		var inspect_ratio: float = clampf(1.0 - inspection_timer / 2.5, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-24, -43), Vector2(48.0 * inspect_ratio, 5)), Color(0.48, 0.88, 1.0, 1.0), true)
	if watch_shield_timer > 0.0:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(0.55, 0.88, 1.0, 0.85), 3.0)
	if speed_buff_timer > 0.0:
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.42, 0.80), 2.2)

	# 3. Local-only selection ring under the player's feet
	if is_player:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 32, Color(0.95, 0.98, 1.0, 0.82), 2.2)

	# 4. Walking stride dust ring when moving
	var forward := Vector2(cos(facing_angle), sin(facing_angle))
	var right := Vector2(-forward.y, forward.x)
	if is_moving:
		var dust_offset := -forward * 16.0 + right * sin(walk_cycle) * 6.0
		draw_circle(dust_offset, 4.5, Color(0.75, 0.78, 0.82, 0.22))

	# 5. Working Tool Tether & Sparks (when channeling a station)
	if is_channeling and not active_pad.is_empty():
		var console_local: Vector2 = (active_pad["pos"] + active_pad.get("console_offset", Vector2.ZERO)) - global_position
		var beam_col: Color = active_pad.get("color", Color(1.0, 0.9, 0.4))
		draw_line(forward * 14.0, console_local, Color(beam_col.r, beam_col.g, beam_col.b, 0.65), 3.0)
		var spark_ang := work_anim_time * 10.0
		for s in range(3):
			var sp_dir := Vector2(cos(spark_ang + float(s) * 2.1), sin(spark_ang + float(s) * 2.1))
			draw_line(console_local, console_local + sp_dir * 10.0, Color(1.0, 0.94, 0.55, 0.9), 2.0)

	# 6. Top-Down Character Silhouette (100% identical neutral civic gear for all 10 residents)
	var alpha_mod := 0.50 if is_incapacitated else 1.0
	draw_circle(Vector2(0, 5), 18.0, Color(0, 0, 0, 0.38 * alpha_mod))

	var pack_pos := -forward * 12.0
	draw_circle(pack_pos, 9.0, Color(0.24, 0.28, 0.33, alpha_mod))

	var l_hand_forward := 4.0
	var r_hand_forward := 4.0
	if is_channeling:
		var tool_bob := sin(work_anim_time * 12.0) * 3.0
		l_hand_forward = 13.0 + tool_bob
		r_hand_forward = 13.0 - tool_bob
	elif is_moving:
		l_hand_forward = sin(walk_cycle) * 7.0
		r_hand_forward = -sin(walk_cycle) * 7.0

	var l_hand := -right * 14.0 + forward * l_hand_forward
	var r_hand := right * 14.0 + forward * r_hand_forward
	draw_circle(l_hand, 5.5, Color(0.68, 0.76, 0.84, alpha_mod))
	draw_circle(r_hand, 5.5, Color(0.68, 0.76, 0.84, alpha_mod))

	draw_circle(-right * 7.0, 11.5, Color(0.34, 0.48, 0.58, alpha_mod))
	draw_circle(right * 7.0, 11.5, Color(0.34, 0.48, 0.58, alpha_mod))
	draw_circle(Vector2.ZERO, 15.0, Color(0.38, 0.52, 0.63, alpha_mod))
	draw_arc(Vector2.ZERO, 15.5, 0.0, TAU, 28, Color(0.78, 0.86, 0.94, 0.95 * alpha_mod), 2.0)

	draw_circle(forward * 2.0, 9.5, Color(0.84, 0.88, 0.92, alpha_mod))
	draw_line(forward * 7.5 - right * 5.0, forward * 7.5 + right * 5.0, Color(0.18, 0.28, 0.38, 0.95 * alpha_mod), 3.2)

	# 7. Public Nameplate
	var label_text := resident_name + (" (You)" if is_player else "")
	draw_string(font, Vector2(-42, 36), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.95, 0.98))

	# 8. Recovery timer bar (if incapacitated) or Stamina bar (if damaged)
	if is_incapacitated:
		var rec_pct := clampf(1.0 - (respawn_timer / RESPAWN_DURATION), 0.0, 1.0)
		var r_rect := Rect2(-38, -36, 76, 8)
		draw_rect(r_rect, Color(0.12, 0.08, 0.08, 0.92), true)
		draw_rect(Rect2(r_rect.position, Vector2(76.0 * rec_pct, 8)), Color(1.0, 0.55, 0.42, 1.0), true)
		draw_rect(r_rect, Color(1.0, 0.75, 0.68, 0.85), false, 1.2)
		draw_string(font, Vector2(-44, -42), "Recovering %.1fs" % respawn_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.72, 0.65))
	elif stamina < MAX_STAMINA - 0.5 and not is_channeling:
		var s_pct := clampf(stamina / MAX_STAMINA, 0.0, 1.0)
		var s_rect := Rect2(-28, -32, 56, 5)
		draw_rect(s_rect, Color(0.08, 0.10, 0.13, 0.88), true)
		draw_rect(Rect2(s_rect.position, Vector2(56.0 * s_pct, 5)), Color(0.95, 0.78, 0.36, 0.95), true)

	# 9. High-Contrast Segmented Task Channel Bar
	if is_channeling:
		var pct: float = clampf(channel_progress / CHANNEL_DURATION, 0.0, 1.0)
		var bar_w := 86.0
		var bar_h := 10.0
		var bar_pos := Vector2(-bar_w * 0.5, -40.0)
		var bar_col: Color = active_pad.get("color", Color(0.45, 0.95, 0.62)).lightened(0.15)

		draw_rect(Rect2(bar_pos - Vector2(2, 2), Vector2(bar_w + 4, bar_h + 4)), Color(0.06, 0.08, 0.11, 0.92), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * pct, bar_h)), bar_col, true)
		for seg in range(1, 5):
			var sx := bar_pos.x + (bar_w / 5.0) * float(seg)
			draw_line(Vector2(sx, bar_pos.y), Vector2(sx, bar_pos.y + bar_h), Color(0.08, 0.10, 0.13, 0.85), 1.5)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.90, 0.95, 1.0, 0.9), false, 1.5)
		draw_string(font, Vector2(-46, -46), _get_action_verb(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, bar_col.lightened(0.25))

	# 10. Popup status text
	if popup_timer > 0.0:
		var y_off: float = lerpf(-64.0, -50.0, popup_timer / 1.4)
		draw_string(font, Vector2(-52, y_off), popup_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, popup_color)
