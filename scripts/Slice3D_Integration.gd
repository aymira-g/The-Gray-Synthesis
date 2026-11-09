extends Node3D

# ==============================================================================
# The Gray Synthesis - Integrated 3D Gameplay Slice
# ==============================================================================
# Proves the 4 core technical interfaces:
# 1. Player 3D Movement & Collision (CharacterBody3D + isometric follow camera)
# 2. Task Interaction & Live State Mutation (Real execute_task() calls)
# 3. Bot 3D Navigation around obstacles
# 4. 3D Physics Sightline & Evidence-Parity Witness Detection
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")
const GMClass = preload("res://scripts/GameManager.gd")
const PlayerClass = preload("res://scripts/PlayerController3D.gd")
const BotClass = preload("res://scripts/BotController3D.gd")

var game_manager: Node
var player_node: CharacterBody3D
var bot_node: CharacterBody3D
var camera: Camera3D
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var ui_layer: CanvasLayer

# 3D Task Pads
var task_pads: Array[Dictionary] = []
var last_spawned_zone: Dictionary = {}

# Region boundaries in 3D (XZ plane)
var regions_3d: Array[Dictionary] = [
	{ "id": "pump_station", "name": "Pump & Generator Station", "min": Vector2(-25.0, 4.0), "max": Vector2(25.0, 25.0) },
	{ "id": "greenhouse", "name": "Greenhouse & Fields", "min": Vector2(-25.0, -25.0), "max": Vector2(0.0, 4.0) },
	{ "id": "salvage_yard", "name": "Salvage Yard", "min": Vector2(0.0, -25.0), "max": Vector2(25.0, 4.0) },
	{ "id": "town_square", "name": "Town Square", "min": Vector2(-10.0, -10.0), "max": Vector2(10.0, 10.0) }
]

var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_setup_game_manager()
	_setup_environment()
	_setup_static_architecture()
	_setup_task_pads()
	_setup_characters()
	_setup_camera()
	_setup_ui()

func _process(delta: float) -> void:
	if game_manager != null and game_manager.has_method("_process"):
		# Update clock if match is running
		pass
	_update_camera_follow(delta)
	_update_hud()

# ------------------------------------------------------------------------------
# 1. Match Manager Setup
# ------------------------------------------------------------------------------
func _setup_game_manager() -> void:
	game_manager = GMClass.new()
	game_manager.name = "GameManager"
	add_child(game_manager)

	# Enter Open Town phase for task work and witness tests
	game_manager.current_phase = game_manager.Phase.OPEN_TOWN
	# Set clock to 210.0s (03:30), perfectly inside the 04:00-03:00 witness interval!
	game_manager.time_remaining = 210.0

	# Initial resources
	game_manager.water = 50.0
	game_manager.stability = 50.0
	game_manager.scrap = 3

# ------------------------------------------------------------------------------
# 2. 3D Environment & Static Collision Architecture
# ------------------------------------------------------------------------------
func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.15, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.36, 0.40)
	env.ambient_light_energy = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-28.0, 45.0, 0.0)
	sun_light.light_color = Color(1.0, 0.80, 0.55)
	sun_light.light_energy = 1.6
	sun_light.shadow_enabled = true
	add_child(sun_light)

func _setup_static_architecture() -> void:
	# Ground Plane with Static Collision
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	var ground_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(60.0, 1.0, 60.0)
	ground_col.shape = box_shape
	ground_col.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(ground_col)

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60.0, 60.0)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.18, 0.17, 0.16)
	g_mat.roughness = 0.90
	var ground_inst := MeshInstance3D.new()
	ground_inst.mesh = ground_mesh
	ground_inst.material_override = g_mat
	ground_body.add_child(ground_inst)
	add_child(ground_body)

	# 3D Obstacle Wall (Separates Zone A and Zone B for sightline & pathfinding tests)
	# Positioned at X = 0, Z between -2.0 and 12.0
	var wall_body := StaticBody3D.new()
	wall_body.name = "ObstacleWall"
	wall_body.collision_layer = 1 # Layer 1 for sightline rays and movement
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(1.2, 4.0, 14.0)
	wall_col.shape = wall_shape
	wall_col.position = Vector3(0.0, 2.0, 5.0)
	wall_body.add_child(wall_col)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.2, 4.0, 14.0)
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.32, 0.28, 0.25)
	w_mat.roughness = 0.8
	var wall_inst := MeshInstance3D.new()
	wall_inst.mesh = wall_mesh
	wall_inst.material_override = w_mat
	wall_inst.position = Vector3(0.0, 2.0, 5.0)
	wall_body.add_child(wall_inst)
	add_child(wall_body)

# ------------------------------------------------------------------------------
# 3. 3D Task Pads (Authentic Task API Integration)
# ------------------------------------------------------------------------------
func _setup_task_pads() -> void:
	# Task Pad 1: Pump Station (Repairs Pump -> +8 Water, -1 Scrap)
	_create_task_pad(
		"pump", "Pump Repair Pad", "pump",
		Vector3(-8.0, 0.05, 10.0), 2.8, Color(0.35, 0.75, 1.0)
	)

	# Task Pad 2: Greenhouse (Tends Crops -> +7 Stability)
	_create_task_pad(
		"greenhouse", "Crop Bed Pad", "greenhouse",
		Vector3(8.0, 0.05, 10.0), 2.8, Color(0.40, 0.90, 0.55)
	)

	# Task Pad 3: Salvage Yard (Gathers Scrap -> +2 Scrap)
	_create_task_pad(
		"salvage", "Scrap Heap Pad", "salvage",
		Vector3(-8.0, 0.05, -5.0), 2.8, Color(0.95, 0.70, 0.35)
	)

func _create_task_pad(pad_id: String, pad_title: String, task_type: String, pos: Vector3, radius: float, col: Color) -> void:
	var pad_root := Node3D.new()
	pad_root.name = "Pad_" + pad_id
	pad_root.position = pos
	add_child(pad_root)

	# Ground ring visual marker
	var ring := CylinderMesh.new()
	ring.top_radius = radius
	ring.bottom_radius = radius
	ring.height = 0.06
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = col * 0.4
	r_mat.emission_enabled = true
	r_mat.emission = col
	r_mat.emission_energy_multiplier = 0.8
	var r_inst := MeshInstance3D.new()
	r_inst.mesh = ring
	r_inst.material_override = r_mat
	pad_root.add_child(r_inst)

	# Overhead label
	var lbl := Label3D.new()
	lbl.text = "%s\n[Hold E to Channel]" % pad_title
	lbl.font_size = 22
	lbl.modulate = col
	lbl.outline_size = 3
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.position = Vector3(0.0, 1.8, 0.0)
	pad_root.add_child(lbl)

	task_pads.append({
		"id": pad_id,
		"name": pad_title,
		"task_type": task_type,
		"position": pos,
		"radius": radius,
		"node": pad_root,
		"color": col
	})

func get_task_pad_at(world_pos: Vector3) -> Dictionary:
	for pad in task_pads:
		var d: float = world_pos.distance_to(pad["position"])
		if d <= pad["radius"]:
			return pad
	return {}

func execute_pad_channel(task_type: String, resident_name: String, is_player: bool) -> String:
	if game_manager == null:
		return ""
	# Real execute_task API call!
	var summary: String = game_manager.execute_task(task_type, resident_name, is_player)
	return summary

# ------------------------------------------------------------------------------
# 4. 3D Character Instantiation (Player & Bot)
# ------------------------------------------------------------------------------
func _setup_characters() -> void:
	# Player 3D CharacterBody3D (Pump Technician with wrench)
	player_node = PlayerClass.new()
	player_node.name = "Player3D"
	player_node.position = Vector3(-8.0, 0.0, 2.0)
	add_child(player_node)

	# Inject dependencies into PlayerController3D
	player_node.set("game_manager", game_manager)
	player_node.set("slice_map", self)
	player_node.set("resident_id", 1)
	player_node.set("resident_name", "Player")
	player_node.set("secret_role", "ecology") # Ecology operative with faction ability [C]
	player_node.set("civic_job", "Pump Technician")
	player_node.set("is_player", true)

	# Bot 3D CharacterBody3D (Crop Tender with sickle)
	bot_node = BotClass.new()
	bot_node.name = "Bot3D"
	bot_node.position = Vector3(8.0, 0.0, 2.0)
	add_child(bot_node)

	# Inject dependencies into BotController3D
	bot_node.set("game_manager", game_manager)
	bot_node.set("slice_map", self)
	bot_node.set("resident_id", 2)
	bot_node.set("resident_name", "Bot_Mara")
	bot_node.set("secret_role", "civilian") # Civilian observer
	bot_node.set("civic_job", "Crop Tender")
	bot_node.set("is_player", false)

	# Register session residents in game_manager
	game_manager.session_residents = [player_node, bot_node]

# ------------------------------------------------------------------------------
# 5. Camera Setup (Top-Down Isometric Follow Camera)
# ------------------------------------------------------------------------------
func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	add_child(camera)
	camera.position = Vector3(-8.0, 18.0, 16.0)
	camera.look_at_from_position(camera.position, Vector3(-8.0, 1.0, 2.0), Vector3.UP)

func _update_camera_follow(delta: float) -> void:
	if player_node == null:
		return
	var target_cam_pos: Vector3 = player_node.position + Vector3(0.0, 16.0, 13.5)
	camera.position = camera.position.lerp(target_cam_pos, delta * 4.5)
	camera.look_at_from_position(camera.position, player_node.position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

# ------------------------------------------------------------------------------
# 6. 3D Line-of-Sight & Witness System (Strict Physics Raycast Contract)
# ------------------------------------------------------------------------------
var obstacle_aabbs: Array[AABB] = [
	AABB(Vector3(-0.6, 0.0, -2.0), Vector3(1.2, 4.0, 14.0))
]

func has_clear_sightline_3d(from_pos: Vector3, to_pos: Vector3) -> bool:
	var ray_start := from_pos + Vector3(0.0, 1.4, 0.0)
	var ray_end := to_pos + Vector3(0.0, 1.4, 0.0)

	# 1. Direct geometric check against obstacle AABBs (fast & deterministic)
	for aabb in obstacle_aabbs:
		var hit_pt: Variant = aabb.intersects_segment(ray_start, ray_end)
		if hit_pt != null:
			return false

	# 2. Physics space raycast if inside active physics tree
	if is_inside_tree():
		var w3d := get_world_3d()
		if w3d != null:
			var space_state := w3d.direct_space_state
			if space_state != null:
				var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				query.collision_mask = 1 # Obstacle walls on layer 1
				var hit := space_state.intersect_ray(query)
				if not hit.is_empty():
					return false

	return true

func get_region_name_at_3d(pos: Vector3) -> String:
	var p2 := Vector2(pos.x, pos.z)
	for reg in regions_3d:
		var min_p: Vector2 = reg["min"]
		var max_p: Vector2 = reg["max"]
		if p2.x >= min_p.x and p2.x <= max_p.x and p2.y >= min_p.y and p2.y <= max_p.y:
			return reg["name"]
	return "Town Corridors"

func get_region_alert_anchor_at_3d(pos: Vector3) -> Vector3:
	var p2 := Vector2(pos.x, pos.z)
	for reg in regions_3d:
		var min_p: Vector2 = reg["min"]
		var max_p: Vector2 = reg["max"]
		if p2.x >= min_p.x and p2.x <= max_p.x and p2.y >= min_p.y and p2.y <= max_p.y:
			var cx: float = (min_p.x + max_p.x) * 0.5
			var cz: float = (min_p.y + max_p.y) * 0.5
			return Vector3(cx, 0.05, cz)
	return Vector3(0.0, 0.05, 0.0)

func spawn_field_zone_3d(zone_type: String, pos: Vector3, radius: float, duration: float, team: int, region: String) -> void:
	last_spawned_zone = {
		"zone_type": zone_type,
		"pos": pos,
		"radius": radius,
		"duration": duration,
		"team": team,
		"region": region
	}
	# Visual 3D marker for witnessed disturbance ring
	var ring := CylinderMesh.new()
	ring.top_radius = radius
	ring.bottom_radius = radius
	ring.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.35, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.25)
	var inst := MeshInstance3D.new()
	inst.mesh = ring
	inst.material_override = mat
	inst.position = pos + Vector3(0.0, 0.1, 0.0)
	add_child(inst)

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(Callable(inst, "queue_free"))

# ------------------------------------------------------------------------------
# 7. UI Overlay & Real-Time Diagnostics
# ------------------------------------------------------------------------------
func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var root_ctrl := Control.new()
	root_ctrl.name = "HUD"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root_ctrl)

	# Top Live Resource Panel
	var top_panel := Panel.new()
	top_panel.position = Vector2(24, 20)
	top_panel.size = Vector2(1392, 70)
	root_ctrl.add_child(top_panel)

	var res_lbl := Label.new()
	res_lbl.name = "ResourceLabel"
	res_lbl.text = "LIVE MATCH RESOURCES:  WATER: 50%  •  STABILITY: 50%  •  SCRAP: 3"
	res_lbl.position = Vector2(20, 14)
	res_lbl.add_theme_font_size_override("font_size", 16)
	res_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	top_panel.add_child(res_lbl)

	var sub_lbl := Label.new()
	sub_lbl.name = "SubLabel"
	sub_lbl.text = "3D Integrated Slice — Real GameManager Mutation & 3D Witness System"
	sub_lbl.position = Vector2(20, 40)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	top_panel.add_child(sub_lbl)

	# Diagnostics Card (Top Right)
	var diag_panel := Panel.new()
	diag_panel.position = Vector2(980, 20)
	diag_panel.size = Vector2(436, 110)
	root_ctrl.add_child(diag_panel)

	var diag_lbl := Label.new()
	diag_lbl.name = "DiagLabel"
	diag_lbl.text = "3D SIGHTLINE DIAGNOSTIC:\nBot Line-of-Sight: CLEAR\nPlayer Task: None"
	diag_lbl.position = Vector2(16, 12)
	diag_lbl.add_theme_font_size_override("font_size", 13)
	diag_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	diag_panel.add_child(diag_lbl)

	# Bottom Controls Hint Bar
	var bot_panel := Panel.new()
	bot_panel.position = Vector2(24, 820)
	bot_panel.size = Vector2(1392, 60)
	root_ctrl.add_child(bot_panel)

	var hint_lbl := Label.new()
	hint_lbl.name = "HintLabel"
	hint_lbl.text = "[W/A/S/D] Move 3D Player  •  [SHIFT] Sprint (Stamina)  •  [HOLD E] Channel 3D Task Pad  •  [C] Trigger Faction Ability (Witness Test)"
	hint_lbl.position = Vector2(20, 20)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	bot_panel.add_child(hint_lbl)

func _update_hud() -> void:
	if game_manager == null or ui_layer == null:
		return
	var hud: Control = ui_layer.get_node_or_null("HUD")
	if hud == null:
		return

	# Resource banner
	var res_lbl: Label = hud.get_node_or_null("TopPanel/ResourceLabel")
	if res_lbl == null:
		res_lbl = hud.find_child("ResourceLabel", true, false)
	if res_lbl != null:
		res_lbl.text = "LIVE MATCH RESOURCES:  WATER: %d%%  •  STABILITY: %d%%  •  SCRAP: %d  (Phase: %s)" % [
			int(game_manager.water), int(game_manager.stability), int(game_manager.scrap),
			game_manager.get_phase_name()
		]

	# Sightline diagnostic
	var diag_lbl: Label = hud.find_child("DiagLabel", true, false)
	if diag_lbl != null and player_node != null and bot_node != null:
		var has_los: bool = has_clear_sightline_3d(player_node.position, bot_node.position)
		var los_str := "[CLEAR - WITNESSED]" if has_los else "[BLOCKED BY WALL - HIDDEN]"
		var los_col := Color(0.45, 0.95, 0.60) if has_los else Color(1.0, 0.50, 0.40)
		var p_channeling: String = player_node.get("active_pad_name") if player_node.has_method("get") else "None"
		diag_lbl.text = "3D SIGHTLINE DIAGNOSTIC:\nBot Sightline to Player: %s\nActive Task Pad: %s" % [los_str, p_channeling]
