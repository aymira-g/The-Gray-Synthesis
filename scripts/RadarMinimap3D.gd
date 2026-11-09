extends Control

# ==============================================================================
# The Gray Synthesis - 3D Tactical Radar Minimap
# ==============================================================================
# Real-time overhead schematic HUD overlay tracking:
# - All 4 Town Sectors (Pump Station, Greenhouse, Salvage Yard, Town Square)
# - Static dividing walls and sector corridors
# - 3D Task Station status (active, cooldown, jammed, escalation-locked)
# - Broad regional disturbance rings and ability zones
# - Player blip with directional heading indicator
# - Resident blips honoring 3D Line-of-Sight and Sector Privacy
# ==============================================================================

var town_map: Node3D
var player_node: CharacterBody3D
var all_residents: Array = []
var game_manager: Node

var pulse_time: float = 0.0
var _is_setup: bool = false
var is_stealth_phase: bool = false

func _ready() -> void:
	if _is_setup:
		return
	_is_setup = true
	custom_minimum_size = Vector2(234, 188)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -250.0
	offset_top = 100.0
	offset_right = -16.0
	offset_bottom = 288.0

func _process(delta: float) -> void:
	pulse_time += delta
	update_stealth_phase()
	queue_redraw()

func update_stealth_phase() -> void:
	is_stealth_phase = false
	if game_manager != null:
		is_stealth_phase = (
			game_manager.current_phase == game_manager.Phase.OPEN_TOWN or
			game_manager.current_phase == game_manager.Phase.ESCALATION or
			game_manager.current_phase == game_manager.Phase.FINALE
		)

func _project_to_radar(pos: Vector3, center: Vector2, sx: float, sy: float) -> Vector2:
	return Vector2(
		center.x + pos.x * sx,
		center.y - pos.z * sy # +Z is North (top)
	)

func _draw() -> void:
	var vp_rect := Rect2(Vector2.ZERO, size)
	
	# 1. Outer Frame & Background Panel
	draw_rect(vp_rect, Color(0.06, 0.08, 0.12, 0.92), true)
	draw_rect(vp_rect, Color(0.32, 0.42, 0.55, 0.85), false, 1.5)
	
	# Radar drawing area (inner margin)
	var radar_rect := Rect2(12, 24, 210, 138)
	draw_rect(radar_rect, Color(0.04, 0.05, 0.08, 0.88), true)
	draw_rect(radar_rect, Color(0.20, 0.28, 0.38, 0.75), false, 1.0)
	
	var radar_center: Vector2 = radar_rect.position + radar_rect.size * 0.5
	var scale_x: float = radar_rect.size.x / 80.0 # 2.625 px/m
	var scale_y: float = radar_rect.size.y / 80.0 # 1.725 px/m
	
	# 2. Sector Footprints
	# Pump Station: X (-28..28), Z (10..38)
	var ps_min: Vector2 = _project_to_radar(Vector3(-28.0, 0.0, 38.0), radar_center, scale_x, scale_y)
	var ps_max: Vector2 = _project_to_radar(Vector3(28.0, 0.0, 10.0), radar_center, scale_x, scale_y)
	draw_rect(Rect2(ps_min, ps_max - ps_min), Color(0.12, 0.18, 0.26, 0.60), true)
	draw_rect(Rect2(ps_min, ps_max - ps_min), Color(0.25, 0.38, 0.52, 0.40), false, 1.0)
	
	# Greenhouse: X (-38..-4), Z (-38..-10)
	var gh_min: Vector2 = _project_to_radar(Vector3(-38.0, 0.0, -10.0), radar_center, scale_x, scale_y)
	var gh_max: Vector2 = _project_to_radar(Vector3(-4.0, 0.0, -38.0), radar_center, scale_x, scale_y)
	draw_rect(Rect2(gh_min, gh_max - gh_min), Color(0.12, 0.22, 0.15, 0.60), true)
	draw_rect(Rect2(gh_min, gh_max - gh_min), Color(0.25, 0.48, 0.30, 0.40), false, 1.0)
	
	# Salvage Yard: X (4..38), Z (-38..-10)
	var sy_min: Vector2 = _project_to_radar(Vector3(4.0, 0.0, -10.0), radar_center, scale_x, scale_y)
	var sy_max: Vector2 = _project_to_radar(Vector3(38.0, 0.0, -38.0), radar_center, scale_x, scale_y)
	draw_rect(Rect2(sy_min, sy_max - sy_min), Color(0.22, 0.16, 0.12, 0.60), true)
	draw_rect(Rect2(sy_min, sy_max - sy_min), Color(0.48, 0.35, 0.25, 0.40), false, 1.0)
	
	# Town Square Plaza: Radius ~8.8m
	draw_circle(radar_center, 8.8 * scale_y, Color(0.18, 0.20, 0.24, 0.70))
	draw_arc(radar_center, 8.8 * scale_y, 0, TAU, 32, Color(0.35, 0.40, 0.48, 0.50), 1.0)
	
	# 3. Dividing Wall Lines
	# North Walls (Z = 10, X=-28..-4 and X=4..28)
	draw_line(_project_to_radar(Vector3(-28.0, 0.0, 10.0), radar_center, scale_x, scale_y), _project_to_radar(Vector3(-4.0, 0.0, 10.0), radar_center, scale_x, scale_y), Color(0.42, 0.45, 0.50, 0.85), 1.5)
	draw_line(_project_to_radar(Vector3(4.0, 0.0, 10.0), radar_center, scale_x, scale_y), _project_to_radar(Vector3(28.0, 0.0, 10.0), radar_center, scale_x, scale_y), Color(0.42, 0.45, 0.50, 0.85), 1.5)
	
	# South Dividing Walls (Z = -8, X=-28..-15 and X=15..28)
	draw_line(_project_to_radar(Vector3(-28.0, 0.0, -8.0), radar_center, scale_x, scale_y), _project_to_radar(Vector3(-15.0, 0.0, -8.0), radar_center, scale_x, scale_y), Color(0.42, 0.45, 0.50, 0.85), 1.5)
	draw_line(_project_to_radar(Vector3(15.0, 0.0, -8.0), radar_center, scale_x, scale_y), _project_to_radar(Vector3(28.0, 0.0, -8.0), radar_center, scale_x, scale_y), Color(0.42, 0.45, 0.50, 0.85), 1.5)
	
	# South Central Divider (X = 0, Z=-16..-36)
	draw_line(_project_to_radar(Vector3(0.0, 0.0, -16.0), radar_center, scale_x, scale_y), _project_to_radar(Vector3(0.0, 0.0, -36.0), radar_center, scale_x, scale_y), Color(0.42, 0.45, 0.50, 0.85), 1.5)
	
	# 4. Task Stations
	if town_map != null and town_map.task_pads != null:
		for pad in town_map.task_pads:
			var pad_pos: Vector3 = pad.get("position", Vector3.ZERO)
			var mp: Vector2 = _project_to_radar(pad_pos, radar_center, scale_x, scale_y)
			var pad_col: Color = pad.get("color", Color.WHITE)
			var is_locked: bool = bool(pad.get("is_locked", false))
			var cooldown: float = float(pad.get("cooldown", 0.0))
			var jammed: float = float(pad.get("jammed_timer", 0.0))
			
			if jammed > 0.0:
				var flash: float = (sin(pulse_time * 8.0) + 1.0) * 0.5
				draw_circle(mp, 4.5, Color(1.0, 0.2, 0.2, 0.4 + flash * 0.5))
				draw_circle(mp, 2.5, Color(1.0, 0.3, 0.3))
			elif is_locked:
				draw_circle(mp, 2.8, Color(0.38, 0.36, 0.34, 0.6))
				draw_arc(mp, 3.8, 0, TAU, 12, Color(0.55, 0.50, 0.45, 0.5), 1.0)
			elif cooldown > 0.0:
				draw_circle(mp, 2.8, Color(0.45, 0.45, 0.50, 0.75))
			else:
				var active_pulse: float = (sin(pulse_time * 3.5) + 1.0) * 0.5
				draw_circle(mp, 3.2, pad_col)
				draw_arc(mp, 4.2 + active_pulse * 1.5, 0, TAU, 16, pad_col * Color(1, 1, 1, 0.5 - active_pulse * 0.3), 1.0)

	# 5. Disturbance Rings & Active Field Zones
	if town_map != null and town_map.last_spawned_zone != null and not town_map.last_spawned_zone.is_empty():
		var z_pos: Vector3 = town_map.last_spawned_zone.get("pos", Vector3.ZERO)
		var z_mp: Vector2 = _project_to_radar(z_pos, radar_center, scale_x, scale_y)
		var ripple: float = fmod(pulse_time * 12.0, 16.0)
		draw_arc(z_mp, ripple, 0, TAU, 24, Color(1.0, 0.75, 0.30, maxf(0.0, 1.0 - ripple / 16.0)), 1.5)

	# 6. Residents (Strict 3D Line-of-Sight & Privacy)
	var p_pos: Vector3 = player_node.global_position if (player_node != null and player_node.is_inside_tree()) else (player_node.position if player_node != null else Vector3.ZERO)
	var p_sec: String = town_map.get_region_id_at_3d(p_pos) if (town_map != null and town_map.has_method("get_region_id_at_3d")) else "town_square"
	update_stealth_phase()

	for res in all_residents:
		if res == null:
			continue
		var r_pos: Vector3 = res.global_position if res.is_inside_tree() else res.position
		var r_mp: Vector2 = _project_to_radar(r_pos, radar_center, scale_x, scale_y)
		
		if res.is_player:
			# Player blip: bright cyan core with heading pointer
			var core_col := Color(0.40, 0.92, 1.0)
			draw_circle(r_mp, 4.5, core_col)
			draw_circle(r_mp, 2.2, Color.WHITE)
			draw_arc(r_mp, 6.0, 0, TAU, 16, Color(0.40, 0.92, 1.0, 0.65), 1.2)
			
			# Direction heading tick
			var p_yaw: float = res.mesh_root.rotation.y if res.mesh_root != null else 0.0
			var forward_2d: Vector2 = Vector2(-sin(p_yaw), cos(p_yaw)) * 7.5
			draw_line(r_mp, r_mp + forward_2d, Color(1.0, 1.0, 1.0, 0.95), 1.5)
		else:
			# Privacy check for other residents
			var show_bot: bool = true
			if is_stealth_phase and town_map != null:
				var r_sec: String = town_map.get_region_id_at_3d(r_pos) if town_map.has_method("get_region_id_at_3d") else "town_square"
				var in_same_sec: bool = (p_sec == r_sec)
				var has_los: bool = town_map.has_clear_sightline_3d(p_pos, r_pos) if town_map.has_method("has_clear_sightline_3d") else false
				show_bot = (in_same_sec or has_los)
			
			if show_bot:
				var bot_col := Color(0.60, 0.80, 0.98, 0.85)
				if res.is_incapacitated:
					bot_col = Color(1.0, 0.45, 0.45, 0.90)
				draw_circle(r_mp, 2.8, bot_col)

	# 7. Compass & Header Labels
	var default_font: Font = ThemeDB.fallback_font
	draw_string(default_font, Vector2(14, 18), "TOWN RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.92, 1.0))
	draw_string(default_font, Vector2(radar_center.x - 4, radar_rect.position.y + 11), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.85, 1.0, 0.85))
	
	# Current sector readout & hint
	var loc_name: String = town_map.get_region_name_at_3d(p_pos) if (town_map != null and town_map.has_method("get_region_name_at_3d")) else "Town Square"
	draw_string(default_font, Vector2(14, 178), loc_name, HORIZONTAL_ALIGNMENT_LEFT, 130, 11, Color(0.65, 0.88, 0.98))
	draw_string(default_font, Vector2(size.x - 76, 178), "[J] Journal", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.80, 0.75, 0.55))
