extends Node3D

# ==============================================================================
# The Gray Synthesis - Full 3D Town Map
# ==============================================================================
# Comprehensive 3D Town environment encompassing all four sectors:
# 1. Pump & Generator Station (North)
# 2. Greenhouse & Hydroponic Fields (South-West)
# 3. Salvage Yard & Workshop (South-East)
# 4. Town Square & Council Plaza (Center)
#
# Features:
# - Spatial region queries & broad regional alert anchors (zero-leak privacy)
# - 3D Task Pads (Civic pads + Escalation-locked Generator/Beacon)
# - 4 Identical Secluded Bedrock Alcoves (Archive Secrecy: 1 active, zero visual leak)
# - 3D Waypoint Navigation Graph with deterministic pathfinding around obstacle walls
# - 3D Line-of-sight checks via direct space state raycast and registered AABBs
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

var game_manager: Node
var audio_manager: Node
var all_residents: Array = []

# Sectors in 3D (XZ plane)
var regions_3d: Array[Dictionary] = [
	{ "id": "town_square", "name": "Town Square", "min": Vector2(-14.0, -10.0), "max": Vector2(14.0, 10.0) },
	{ "id": "pump_station", "name": "Pump & Generator Station", "min": Vector2(-28.0, 10.0), "max": Vector2(28.0, 38.0) },
	{ "id": "greenhouse", "name": "Greenhouse & Fields", "min": Vector2(-38.0, -38.0), "max": Vector2(-4.0, -10.0) },
	{ "id": "salvage_yard", "name": "Salvage Yard", "min": Vector2(4.0, -38.0), "max": Vector2(38.0, -10.0) }
]

# Task Pad Registry
var task_pads: Array[Dictionary] = []

# Secluded Bedrock Alcoves (Archive Secrecy)
var secret_alcoves: Array[Dictionary] = []
var active_alcove_id: String = ""

# Waypoint Navigation Graph: id -> { "pos": Vector3, "neighbors": Array[String] }
var waypoints: Dictionary = {}

# Obstacle AABBs for collision & deterministic headless LOS checks
var obstacle_aabbs: Array[AABB] = []

# Active 3D field zones & diagnostic telemetry
var active_zones: Array[Dictionary] = []
var last_spawned_zone: Dictionary = {}

# Lighting & Atmospheric State
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var dais_spotlight: SpotLight3D
var beacon_light_node: OmniLight3D
var turbine_light_node: OmniLight3D
var lighting_tween: Tween
var anim_timer: float = 0.0
var current_lighting_phase: int = -1

# Narrative Phase Lighting Progression (Competitive Readability Protected)
const PHASE_LIGHTING_CONFIG: Dictionary = {
	0: { # LOBBY / PRE-MATCH
		"name": "Lobby Gathering",
		"sun_color": Color(1.0, 0.90, 0.82),
		"sun_energy": 1.4,
		"sun_rot": Vector3(-30.0, 36.0, 0.0),
		"ambient_color": Color(0.38, 0.36, 0.42),
		"ambient_energy": 0.95,
		"bg_color": Color(0.14, 0.13, 0.16),
		"dais_spot_energy": 1.4
	},
	1: { # BRIEFING: Dawn Gathering
		"name": "Dawn Briefing",
		"sun_color": Color(1.0, 0.90, 0.82),
		"sun_energy": 1.4,
		"sun_rot": Vector3(-30.0, 36.0, 0.0),
		"ambient_color": Color(0.38, 0.36, 0.42),
		"ambient_energy": 0.95,
		"bg_color": Color(0.14, 0.13, 0.16),
		"dais_spot_energy": 1.4
	},
	2: { # OPEN_TOWN: Crisp Midday Chores
		"name": "Midday Sun",
		"sun_color": Color(1.0, 0.94, 0.84),
		"sun_energy": 1.6,
		"sun_rot": Vector3(-34.0, 42.0, 0.0),
		"ambient_color": Color(0.40, 0.38, 0.44),
		"ambient_energy": 1.0,
		"bg_color": Color(0.15, 0.14, 0.17),
		"dais_spot_energy": 0.5
	},
	3: { # FIRST_COUNCIL: Golden Hour Debate
		"name": "Golden Hour Council",
		"sun_color": Color(1.0, 0.80, 0.52),
		"sun_energy": 1.45,
		"sun_rot": Vector3(-24.0, 60.0, 0.0),
		"ambient_color": Color(0.42, 0.36, 0.35),
		"ambient_energy": 0.95,
		"bg_color": Color(0.16, 0.12, 0.13),
		"dais_spot_energy": 1.8
	},
	4: { # ESCALATION: Moody Twilight (Objectives unlock, tensions peak)
		"name": "Moody Twilight",
		"sun_color": Color(0.85, 0.60, 0.52),
		"sun_energy": 1.15,
		"sun_rot": Vector3(-16.0, 72.0, 0.0),
		"ambient_color": Color(0.34, 0.34, 0.44),
		"ambient_energy": 0.88,
		"bg_color": Color(0.10, 0.09, 0.14),
		"dais_spot_energy": 0.8
	},
	5: { # COURT: Nightfall Tribunal (Moonlight key & Dais Spotlight)
		"name": "Nightfall Tribunal",
		"sun_color": Color(0.65, 0.76, 0.95),
		"sun_energy": 0.90,
		"sun_rot": Vector3(-45.0, -35.0, 0.0),
		"ambient_color": Color(0.30, 0.32, 0.42),
		"ambient_energy": 0.82,
		"bg_color": Color(0.07, 0.07, 0.11),
		"dais_spot_energy": 2.2
	},
	6: { # FINALE: Dusk Resolution
		"name": "Dusk Finale",
		"sun_color": Color(0.70, 0.74, 0.92),
		"sun_energy": 0.95,
		"sun_rot": Vector3(-40.0, -25.0, 0.0),
		"ambient_color": Color(0.30, 0.32, 0.40),
		"ambient_energy": 0.82,
		"bg_color": Color(0.07, 0.07, 0.10),
		"dais_spot_energy": 1.2
	},
	7: { # MATCH_OVER: Epilogue
		"name": "Resolution Dawn",
		"sun_color": Color(0.95, 0.88, 0.78),
		"sun_energy": 1.3,
		"sun_rot": Vector3(-28.0, 30.0, 0.0),
		"ambient_color": Color(0.36, 0.35, 0.40),
		"ambient_energy": 0.92,
		"bg_color": Color(0.12, 0.11, 0.15),
		"dais_spot_energy": 1.5
	}
}

var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_setup_environment_visuals()
	_setup_static_architecture()
	_setup_sector_decorations()
	_setup_task_pads()
	_setup_secluded_alcoves()
	_setup_waypoint_graph()

# ------------------------------------------------------------------------------
# 1. Environment & Lighting
# ------------------------------------------------------------------------------
func _setup_environment_visuals() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.13, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.36, 0.42)
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.rotation_degrees = Vector3(-34.0, 42.0, 0.0)
	sun_light.light_color = Color(1.0, 0.94, 0.84)
	sun_light.light_energy = 1.6
	sun_light.shadow_enabled = true
	add_child(sun_light)

	# Dedicated Central Council Dais Spotlight (theatrical accent for debate and court)
	dais_spotlight = SpotLight3D.new()
	dais_spotlight.name = "CouncilDaisSpotlight"
	dais_spotlight.position = Vector3(0.0, 8.5, 0.0)
	dais_spotlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	dais_spotlight.light_color = Color(1.0, 0.95, 0.88)
	dais_spotlight.light_energy = 0.6
	dais_spotlight.spot_range = 14.0
	dais_spotlight.spot_angle = 45.0
	dais_spotlight.spot_attenuation = 1.0
	add_child(dais_spotlight)

func apply_phase_lighting(phase: int, instant: bool = false, duration: float = 2.5) -> void:
	var cfg: Dictionary = PHASE_LIGHTING_CONFIG.get(phase, PHASE_LIGHTING_CONFIG[1])
	current_lighting_phase = phase

	if sun_light == null or world_environment == null or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment

	if instant or not is_inside_tree():
		if lighting_tween != null and lighting_tween.is_valid():
			lighting_tween.kill()
		sun_light.light_color = cfg["sun_color"]
		sun_light.light_energy = cfg["sun_energy"]
		sun_light.rotation_degrees = cfg["sun_rot"]
		env.ambient_light_color = cfg["ambient_color"]
		env.ambient_light_energy = cfg["ambient_energy"]
		env.background_color = cfg["bg_color"]
		if dais_spotlight != null:
			dais_spotlight.light_energy = cfg["dais_spot_energy"]
	else:
		if lighting_tween != null and lighting_tween.is_valid():
			lighting_tween.kill()
		lighting_tween = create_tween().set_parallel(true)
		lighting_tween.tween_property(sun_light, "light_color", cfg["sun_color"], duration)
		lighting_tween.tween_property(sun_light, "light_energy", cfg["sun_energy"], duration)
		lighting_tween.tween_property(sun_light, "rotation_degrees", cfg["sun_rot"], duration)
		lighting_tween.tween_property(env, "ambient_light_color", cfg["ambient_color"], duration)
		lighting_tween.tween_property(env, "ambient_light_energy", cfg["ambient_energy"], duration)
		lighting_tween.tween_property(env, "background_color", cfg["bg_color"], duration)
		if dais_spotlight != null:
			lighting_tween.tween_property(dais_spotlight, "light_energy", cfg["dais_spot_energy"], duration)

# ------------------------------------------------------------------------------
# 2. Static Town Architecture (Ground & Walls)
# ------------------------------------------------------------------------------
func _setup_static_architecture() -> void:
	# Main Ground Plane (80m x 80m)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_shape := CollisionShape3D.new()
	ground_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(90.0, 1.0, 90.0)
	ground_shape.shape = box
	ground_shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(ground_shape)

	var ground_mesh := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(90.0, 90.0)
	ground_mesh.mesh = plane_mesh
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.20, 0.18, 0.17)
	g_mat.roughness = 0.92
	ground_mesh.material_override = g_mat
	ground.add_child(ground_mesh)
	add_child(ground)

	# Flat Central Council Dais Medallion in Town Square (flush with plaza floor for smooth navigation)
	var podium := Node3D.new()
	podium.name = "CouncilPodium"

	var pod_mesh := MeshInstance3D.new()
	var pod_cyl := CylinderMesh.new()
	pod_cyl.top_radius = 3.6
	pod_cyl.bottom_radius = 3.6
	pod_cyl.height = 0.04
	pod_mesh.mesh = pod_cyl
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.45, 0.42, 0.40)
	p_mat.roughness = 0.75
	pod_mesh.material_override = p_mat
	pod_mesh.position = Vector3(0.0, 0.02, 0.0)
	podium.add_child(pod_mesh)
	add_child(podium)

	# Static Dividing Walls and Buildings separating sectors
	# 1. North Wall (separates Town Square from Pump Station, opening at X = -4..4)
	_build_wall(Vector3(-18.0, 1.5, 10.0), Vector3(16.0, 3.0, 2.0), "NorthWall_West")
	_build_wall(Vector3(18.0, 1.5, 10.0), Vector3(16.0, 3.0, 2.0), "NorthWall_East")

	# 2. South-West Wall (separates Town Square from Greenhouse, opening at X = -8, Z = -10)
	_build_wall(Vector3(-22.0, 1.5, -8.0), Vector3(14.0, 3.0, 2.0), "SW_DividingWall")

	# 3. South-East Wall (separates Town Square from Salvage Yard, opening at X = 8, Z = -10)
	_build_wall(Vector3(22.0, 1.5, -8.0), Vector3(14.0, 3.0, 2.0), "SE_DividingWall")

	# 4. Central Sector Divider between Greenhouse & Salvage Yard (along Z = -16..-36 at X = 0)
	_build_wall(Vector3(0.0, 1.5, -26.0), Vector3(2.0, 3.0, 20.0), "South_CenterDivider")

func _build_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = pos

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.28, 0.31)
	mat.roughness = 0.85
	mesh_inst.mesh = cube
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	# Architectural Stone Parapet Coping Cap
	var cap_inst := MeshInstance3D.new()
	cap_inst.name = "WallCopingCap"
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(size.x + 0.35, 0.20, size.z + 0.35)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.24, 0.22, 0.25)
	cap_mat.roughness = 0.80
	cap_inst.mesh = cap_mesh
	cap_inst.material_override = cap_mat
	cap_inst.position = Vector3(0.0, size.y * 0.5 + 0.10, 0.0)
	body.add_child(cap_inst)

	# Architectural Base Foundation Footer
	var base_inst := MeshInstance3D.new()
	base_inst.name = "WallBaseFooter"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(size.x + 0.25, 0.25, size.z + 0.25)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.18, 0.17, 0.20)
	base_mat.roughness = 0.90
	base_inst.mesh = base_mesh
	base_inst.material_override = base_mat
	base_inst.position = Vector3(0.0, -size.y * 0.5 + 0.125, 0.0)
	body.add_child(base_inst)

	add_child(body)

	# Register AABB for fast deterministic sightline checks
	var aabb := AABB(pos - size * 0.5, size)
	obstacle_aabbs.append(aabb)

# ------------------------------------------------------------------------------
# 2.5 Sector-Specific Visual Architecture & Props (Option 1 Polish)
# ------------------------------------------------------------------------------
func _setup_sector_decorations() -> void:
	var decor_root := Node3D.new()
	decor_root.name = "SectorDecorations"
	add_child(decor_root)

	_setup_sector_floors(decor_root)
	_setup_town_square_decor(decor_root)
	_setup_pump_station_decor(decor_root)
	_setup_greenhouse_decor(decor_root)
	_setup_salvage_yard_decor(decor_root)

func _setup_sector_floors(root: Node3D) -> void:
	var floor_group := Node3D.new()
	floor_group.name = "SectorFloors"
	root.add_child(floor_group)

	# 1. Town Square Slate Paved Plaza (Disc around Council Ring)
	var ts_disc := MeshInstance3D.new()
	ts_disc.name = "TownSquarePlaza"
	var ts_mesh := CylinderMesh.new()
	ts_mesh.top_radius = 8.8
	ts_mesh.bottom_radius = 8.8
	ts_mesh.height = 0.02
	var ts_mat := StandardMaterial3D.new()
	ts_mat.albedo_color = Color(0.26, 0.25, 0.28)
	ts_mat.roughness = 0.82
	ts_disc.mesh = ts_mesh
	ts_disc.material_override = ts_mat
	ts_disc.position = Vector3(0.0, 0.01, 0.0)
	floor_group.add_child(ts_disc)

	# Cobblestone outer perimeter trim
	var ts_trim := MeshInstance3D.new()
	ts_trim.name = "TownSquareTrim"
	var trim_mesh := TorusMesh.new()
	trim_mesh.inner_radius = 8.6
	trim_mesh.outer_radius = 9.1
	trim_mesh.rings = 36
	trim_mesh.ring_segments = 16
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.34, 0.32, 0.30)
	trim_mat.roughness = 0.90
	ts_trim.mesh = trim_mesh
	ts_trim.material_override = trim_mat
	ts_trim.position = Vector3(0.0, 0.015, 0.0)
	floor_group.add_child(ts_trim)

	# Common Works Foundation Excavation Slab
	var cw_slab := MeshInstance3D.new()
	cw_slab.name = "CommonWorksSlab"
	var cw_mesh := BoxMesh.new()
	cw_mesh.size = Vector3(7.2, 0.02, 7.2)
	var cw_mat := StandardMaterial3D.new()
	cw_mat.albedo_color = Color(0.25, 0.26, 0.28)
	cw_mat.roughness = 0.88
	cw_slab.mesh = cw_mesh
	cw_slab.material_override = cw_mat
	cw_slab.position = Vector3(-12.0, 0.012, 0.0)
	floor_group.add_child(cw_slab)

	# 2. Pump & Generator Station Industrial Reinforced Floor
	var pump_floor := MeshInstance3D.new()
	pump_floor.name = "PumpStationFloor"
	var pf_mesh := BoxMesh.new()
	pf_mesh.size = Vector3(44.0, 0.02, 26.0)
	var pf_mat := StandardMaterial3D.new()
	pf_mat.albedo_color = Color(0.18, 0.20, 0.23)
	pf_mat.roughness = 0.72
	pump_floor.mesh = pf_mesh
	pump_floor.material_override = pf_mat
	pump_floor.position = Vector3(0.0, 0.01, 24.0)
	floor_group.add_child(pump_floor)

	# 3. Greenhouse & Hydroponic Moist Loam Soil Patch
	var gh_floor := MeshInstance3D.new()
	gh_floor.name = "GreenhouseLoamFloor"
	var gh_mesh := BoxMesh.new()
	gh_mesh.size = Vector3(32.0, 0.02, 26.0)
	var gh_mat := StandardMaterial3D.new()
	gh_mat.albedo_color = Color(0.15, 0.12, 0.09)
	gh_mat.roughness = 0.95
	gh_floor.mesh = gh_mesh
	gh_floor.material_override = gh_mat
	gh_floor.position = Vector3(-19.0, 0.01, -24.0)
	floor_group.add_child(gh_floor)

	# 4. Salvage Yard Crushed Slag & Rust Gravel Pad
	var sy_floor := MeshInstance3D.new()
	sy_floor.name = "SalvageYardGravelFloor"
	var sy_mesh := BoxMesh.new()
	sy_mesh.size = Vector3(32.0, 0.02, 26.0)
	var sy_mat := StandardMaterial3D.new()
	sy_mat.albedo_color = Color(0.22, 0.16, 0.13)
	sy_mat.roughness = 0.88
	sy_floor.mesh = sy_mesh
	sy_floor.material_override = sy_mat
	sy_floor.position = Vector3(19.0, 0.01, -24.0)
	floor_group.add_child(sy_floor)

func _setup_town_square_decor(root: Node3D) -> void:
	var ts_decor := Node3D.new()
	ts_decor.name = "TownSquareDecor"
	root.add_child(ts_decor)

	# Lower concentric dais step under Council Podium
	var dais_step := MeshInstance3D.new()
	dais_step.name = "CouncilDaisStep"
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 4.4
	d_cyl.bottom_radius = 4.4
	d_cyl.height = 0.02
	var d_mat := StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.38, 0.36, 0.34)
	d_mat.roughness = 0.80
	dais_step.mesh = d_cyl
	dais_step.material_override = d_mat
	dais_step.position = Vector3(0.0, 0.015, 0.0)
	ts_decor.add_child(dais_step)

	# Stone & Brass Speaker Lectern on Podium
	var lectern := Node3D.new()
	lectern.name = "SpeakerLectern"
	lectern.position = Vector3(0.0, 0.02, 0.85)

	var plinth := MeshInstance3D.new()
	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = Vector3(0.55, 0.75, 0.40)
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color(0.34, 0.32, 0.30)
	plinth.mesh = plinth_mesh
	plinth.material_override = plinth_mat
	plinth.position = Vector3(0.0, 0.375, 0.0)
	lectern.add_child(plinth)

	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(0.65, 0.05, 0.45)
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.75, 0.62, 0.32)
	desk_mat.metallic = 0.5
	desk_mat.roughness = 0.4
	desk.mesh = desk_mesh
	desk.material_override = desk_mat
	desk.position = Vector3(0.0, 0.77, 0.0)
	desk.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	lectern.add_child(desk)
	ts_decor.add_child(lectern)

	# 10 Stone Council Benches behind resident positions
	var benches_root := Node3D.new()
	benches_root.name = "CouncilBenches"
	ts_decor.add_child(benches_root)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.32, 0.30, 0.30)
	b_mat.roughness = 0.85

	for i in range(10):
		var angle := (TAU / 10.0) * float(i) - PI * 0.5
		var bench := MeshInstance3D.new()
		bench.name = "CouncilBench_%d" % (i + 1)
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(1.25, 0.35, 0.45)
		bench.mesh = b_mesh
		bench.material_override = b_mat
		bench.position = Vector3(cos(angle) * 6.5, 0.18, sin(angle) * 6.5)
		bench.rotation.y = -angle + PI * 0.5
		benches_root.add_child(bench)

	# 4 Wrought-Iron Street Lanterns with Warm Amber Lighting
	var lanterns_root := Node3D.new()
	lanterns_root.name = "StreetLanterns"
	ts_decor.add_child(lanterns_root)

	var lantern_coords := [
		Vector3(-9.0, 0.0, -6.0),
		Vector3(9.0, 0.0, -6.0),
		Vector3(-9.0, 0.0, 6.0),
		Vector3(9.0, 0.0, 6.0)
	]
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.18, 0.20)
	iron_mat.metallic = 0.7
	iron_mat.roughness = 0.5

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.90, 0.65)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.88, 0.60)
	glow_mat.emission_energy_multiplier = 2.2

	for idx in range(lantern_coords.size()):
		var l_pos: Vector3 = lantern_coords[idx]
		var lamp_post := Node3D.new()
		lamp_post.name = "StreetLantern_%d" % (idx + 1)
		lamp_post.position = l_pos

		var pole := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.07
		p_mesh.bottom_radius = 0.09
		p_mesh.height = 3.2
		pole.mesh = p_mesh
		pole.material_override = iron_mat
		pole.position = Vector3(0.0, 1.6, 0.0)
		lamp_post.add_child(pole)

		var fixture := MeshInstance3D.new()
		var f_mesh := BoxMesh.new()
		f_mesh.size = Vector3(0.32, 0.42, 0.32)
		fixture.mesh = f_mesh
		fixture.material_override = glow_mat
		fixture.position = Vector3(0.0, 3.2, 0.0)
		lamp_post.add_child(fixture)

		var light := OmniLight3D.new()
		light.name = "LanternLight"
		light.light_color = Color(1.0, 0.86, 0.58)
		light.light_energy = 1.35
		light.omni_range = 11.5
		light.omni_attenuation = 1.2
		light.position = Vector3(0.0, 3.2, 0.0)
		lamp_post.add_child(light)

		lanterns_root.add_child(lamp_post)

	# Clinic Medical Pavilion Canopy Structure (Enlarged to comfortably shelter medical station)
	var clinic_pav := Node3D.new()
	clinic_pav.name = "ClinicPavilion"
	clinic_pav.position = Vector3(0.0, 0.0, -10.0)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.34, 0.28)
	wood_mat.roughness = 0.85

	# 4 Heavy Support Corner Pillars
	var pillar_offsets := [
		Vector3(-2.9, 1.6, -2.5),
		Vector3(2.9, 1.6, -2.5),
		Vector3(-2.9, 1.6, 2.5),
		Vector3(2.9, 1.6, 2.5)
	]
	for p_off in pillar_offsets:
		var pil := MeshInstance3D.new()
		var col_mesh := CylinderMesh.new()
		col_mesh.top_radius = 0.10
		col_mesh.bottom_radius = 0.12
		col_mesh.height = 3.2
		pil.mesh = col_mesh
		pil.material_override = wood_mat
		pil.position = p_off
		clinic_pav.add_child(pil)

	# Pitched Cream Canvas Roof Canopy
	var canopy := MeshInstance3D.new()
	canopy.name = "CanopyRoof"
	var c_mesh := PrismMesh.new()
	c_mesh.size = Vector3(6.2, 1.3, 5.4)
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.88, 0.86, 0.80)
	c_mat.roughness = 0.90
	canopy.mesh = c_mesh
	canopy.material_override = c_mat
	canopy.position = Vector3(0.0, 3.65, 0.0)
	clinic_pav.add_child(canopy)

	# Red Cross Medical Crest on Front Gable
	var cross_root := Node3D.new()
	cross_root.position = Vector3(0.0, 3.55, 2.72)
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.92, 0.22, 0.22)
	red_mat.emission_enabled = true
	red_mat.emission = Color(0.85, 0.18, 0.18)
	red_mat.emission_energy_multiplier = 0.8

	var h_bar := MeshInstance3D.new()
	var hb_mesh := BoxMesh.new()
	hb_mesh.size = Vector3(0.65, 0.18, 0.04)
	h_bar.mesh = hb_mesh
	h_bar.material_override = red_mat
	cross_root.add_child(h_bar)

	var v_bar := MeshInstance3D.new()
	var vb_mesh := BoxMesh.new()
	vb_mesh.size = Vector3(0.18, 0.65, 0.04)
	v_bar.mesh = vb_mesh
	v_bar.material_override = red_mat
	cross_root.add_child(v_bar)
	clinic_pav.add_child(cross_root)

	# Restorative Cyan Medical Examination Lamp
	var med_light := OmniLight3D.new()
	med_light.name = "ClinicMedicalLight"
	med_light.light_color = Color(0.55, 0.95, 1.0)
	med_light.light_energy = 1.35
	med_light.omni_range = 8.5
	med_light.omni_attenuation = 1.1
	med_light.position = Vector3(0.0, 3.1, 0.0)
	clinic_pav.add_child(med_light)

	# Medical Recovery Cots
	var cot_mat := StandardMaterial3D.new()
	cot_mat.albedo_color = Color(0.82, 0.82, 0.80)
	cot_mat.roughness = 0.85
	for cot_x in [-2.1, 2.1]:
		var cot := MeshInstance3D.new()
		cot.name = "RecoveryCot_%s" % ("L" if cot_x < 0 else "R")
		var cot_m := BoxMesh.new()
		cot_m.size = Vector3(0.9, 0.40, 2.0)
		cot.mesh = cot_m
		cot.material_override = cot_mat
		cot.position = Vector3(cot_x, 0.20, 0.0)
		clinic_pav.add_child(cot)

	ts_decor.add_child(clinic_pav)

	# Common Works Construction Foundation Site
	var cw_decor := Node3D.new()
	cw_decor.name = "CommonWorksDecor"
	cw_decor.position = Vector3(-12.0, 0.0, 0.0)

	# Timber framing border around foundation perimeter
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.48, 0.38, 0.28)
	frame_mat.roughness = 0.85

	var border_offsets := [
		{"pos": Vector3(0.0, 0.12, -3.4), "size": Vector3(7.2, 0.24, 0.2)},
		{"pos": Vector3(0.0, 0.12, 3.4), "size": Vector3(7.2, 0.24, 0.2)},
		{"pos": Vector3(-3.4, 0.12, 0.0), "size": Vector3(0.2, 0.24, 6.8)},
		{"pos": Vector3(3.4, 0.12, 0.0), "size": Vector3(0.2, 0.24, 6.8)}
	]
	for b_def in border_offsets:
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b_def["size"]
		board.mesh = bm
		board.material_override = frame_mat
		board.position = b_def["pos"]
		cw_decor.add_child(board)

	# 4 Corner Rebar Cages
	var rebar_mat := StandardMaterial3D.new()
	rebar_mat.albedo_color = Color(0.45, 0.30, 0.22)
	rebar_mat.metallic = 0.65
	rebar_mat.roughness = 0.70
	var rebar_positions := [
		Vector3(-3.1, 0.8, -3.1),
		Vector3(3.1, 0.8, -3.1),
		Vector3(-3.1, 0.8, 3.1),
		Vector3(3.1, 0.8, 3.1)
	]
	for r_pos in rebar_positions:
		var rebar := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.06
		rm.bottom_radius = 0.06
		rm.height = 1.6
		rebar.mesh = rm
		rebar.material_override = rebar_mat
		rebar.position = r_pos
		cw_decor.add_child(rebar)

	# Surveyor Blueprint Table
	var table := MeshInstance3D.new()
	table.name = "SurveyorTable"
	var tm := BoxMesh.new()
	tm.size = Vector3(1.0, 0.75, 0.7)
	table.mesh = tm
	table.material_override = frame_mat
	table.position = Vector3(2.5, 0.38, -2.2)
	cw_decor.add_child(table)

	# Construction Safety Beacon Lamp
	var cw_lamp := OmniLight3D.new()
	cw_lamp.name = "CommonWorksSafetyLamp"
	cw_lamp.light_color = Color(1.0, 0.75, 0.35)
	cw_lamp.light_energy = 1.1
	cw_lamp.omni_range = 6.5
	cw_lamp.position = Vector3(2.5, 1.2, -2.2)
	cw_decor.add_child(cw_lamp)

	ts_decor.add_child(cw_decor)

func _setup_pump_station_decor(root: Node3D) -> void:
	var ps_decor := Node3D.new()
	ps_decor.name = "PumpStationDecor"
	root.add_child(ps_decor)

	# 1. Concrete Water Reservoir Basin
	var reservoir := Node3D.new()
	reservoir.name = "WaterReservoir"
	reservoir.position = Vector3(-14.0, 0.0, 26.0)

	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.30, 0.32, 0.34)
	concrete_mat.roughness = 0.85

	# 4 Basin Curbing Walls
	var rims := [
		{ "pos": Vector3(0.0, 0.25, -2.6), "size": Vector3(7.4, 0.5, 0.3) },
		{ "pos": Vector3(0.0, 0.25, 2.6), "size": Vector3(7.4, 0.5, 0.3) },
		{ "pos": Vector3(-3.6, 0.25, 0.0), "size": Vector3(0.3, 0.5, 5.2) },
		{ "pos": Vector3(3.6, 0.25, 0.0), "size": Vector3(0.3, 0.5, 5.2) }
	]
	for r_def in rims:
		var rim := MeshInstance3D.new()
		var r_mesh := BoxMesh.new()
		r_mesh.size = r_def["size"]
		rim.mesh = r_mesh
		rim.material_override = concrete_mat
		rim.position = r_def["pos"]
		reservoir.add_child(rim)

	# Translucent Reflective Water Surface
	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	var w_mesh := PlaneMesh.new()
	w_mesh.size = Vector2(7.0, 5.0)
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.12, 0.38, 0.55, 0.80)
	w_mat.roughness = 0.05
	w_mat.metallic = 0.15
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.mesh = w_mesh
	water.material_override = w_mat
	water.position = Vector3(0.0, 0.28, 0.0)
	reservoir.add_child(water)

	# Submerged Intake Pipe
	var intake_pipe := MeshInstance3D.new()
	var ip_mesh := CylinderMesh.new()
	ip_mesh.top_radius = 0.18
	ip_mesh.bottom_radius = 0.18
	ip_mesh.height = 2.4
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.24, 0.26, 0.28)
	pipe_mat.metallic = 0.8
	pipe_mat.roughness = 0.4
	intake_pipe.mesh = ip_mesh
	intake_pipe.material_override = pipe_mat
	intake_pipe.position = Vector3(2.5, 0.5, 0.0)
	intake_pipe.rotation_degrees = Vector3(0.0, 0.0, 40.0)
	reservoir.add_child(intake_pipe)
	ps_decor.add_child(reservoir)

	# Subtle Condensation Steam Vent near Water Reservoir Overflow
	var steam_vent := CPUParticles3D.new()
	steam_vent.name = "PumpStationSteam"
	steam_vent.amount = 16
	steam_vent.lifetime = 2.4
	steam_vent.preprocess = 0.5
	steam_vent.speed_scale = 0.85
	steam_vent.randomness = 0.35
	steam_vent.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam_vent.emission_box_extents = Vector3(1.2, 0.1, 1.2)
	steam_vent.direction = Vector3(0.0, 1.0, 0.0)
	steam_vent.spread = 22.0
	steam_vent.gravity = Vector3(0.0, 0.18, 0.0)
	steam_vent.initial_velocity_min = 0.35
	steam_vent.initial_velocity_max = 0.85
	steam_vent.scale_amount_min = 0.25
	steam_vent.scale_amount_max = 0.65

	var steam_mesh := SphereMesh.new()
	steam_mesh.radius = 0.18
	steam_mesh.height = 0.36
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.85, 0.92, 0.98, 0.20)
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mesh.material = s_mat
	steam_vent.mesh = steam_mesh
	steam_vent.position = Vector3(-14.0, 0.6, 26.0)
	ps_decor.add_child(steam_vent)

	# 2. Industrial Pipeline Conduits along North Dividing Wall
	var pipes_root := Node3D.new()
	pipes_root.name = "IndustrialPipelines"
	ps_decor.add_child(pipes_root)

	var pipe_sections := [
		{ "pos": Vector3(-18.0, 1.2, 11.1), "len": 13.0 },
		{ "pos": Vector3(18.0, 1.2, 11.1), "len": 13.0 }
	]
	var valve_mat := StandardMaterial3D.new()
	valve_mat.albedo_color = Color(0.85, 0.22, 0.20)
	valve_mat.roughness = 0.6

	for sec in pipe_sections:
		var p_inst := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.18
		pm.bottom_radius = 0.18
		pm.height = sec["len"]
		p_inst.mesh = pm
		p_inst.material_override = pipe_mat
		p_inst.position = sec["pos"]
		p_inst.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		pipes_root.add_child(p_inst)

		# Red Valve Wheel
		var valve := MeshInstance3D.new()
		var vm := TorusMesh.new()
		vm.inner_radius = 0.15
		vm.outer_radius = 0.25
		valve.mesh = vm
		valve.material_override = valve_mat
		valve.position = sec["pos"] + Vector3(2.0, 0.0, 0.22)
		valve.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		pipes_root.add_child(valve)

	# 3. Overdrive Generator Turbine Details
	var turbine := Node3D.new()
	turbine.name = "GeneratorTurbine"
	turbine.position = Vector3(9.4, 0.0, 24.0)

	var t_casing := MeshInstance3D.new()
	var tc_mesh := CylinderMesh.new()
	tc_mesh.top_radius = 1.15
	tc_mesh.bottom_radius = 1.15
	tc_mesh.height = 2.4
	var tc_mat := StandardMaterial3D.new()
	tc_mat.albedo_color = Color(0.24, 0.25, 0.28)
	tc_mat.metallic = 0.85
	tc_mat.roughness = 0.4
	t_casing.mesh = tc_mesh
	t_casing.material_override = tc_mat
	t_casing.position = Vector3(0.0, 1.2, 0.0)
	t_casing.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	turbine.add_child(t_casing)

	# Copper Induction Coils
	var coil := MeshInstance3D.new()
	var coil_mesh := TorusMesh.new()
	coil_mesh.inner_radius = 1.05
	coil_mesh.outer_radius = 1.25
	var coil_mat := StandardMaterial3D.new()
	coil_mat.albedo_color = Color(0.85, 0.52, 0.25)
	coil_mat.metallic = 0.9
	coil_mat.roughness = 0.3
	coil_mat.emission_enabled = true
	coil_mat.emission = Color(0.85, 0.50, 0.20)
	coil_mat.emission_energy_multiplier = 0.6
	coil.mesh = coil_mesh
	coil.material_override = coil_mat
	coil.position = Vector3(0.0, 1.2, 0.0)
	coil.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	turbine.add_child(coil)

	# Electric Micro-Arcs / Induction Sparks around Coils
	var sparks := CPUParticles3D.new()
	sparks.name = "TurbineSparks"
	sparks.amount = 8
	sparks.lifetime = 0.6
	sparks.preprocess = 0.2
	sparks.explosiveness = 0.75
	sparks.randomness = 0.8
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_radius = 1.15
	sparks.emission_ring_inner_radius = 0.95
	sparks.emission_ring_height = 0.3
	sparks.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 180.0
	sparks.gravity = Vector3(0.0, -1.2, 0.0)
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.8
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.08

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.04, 0.04, 0.04)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.60, 0.90, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.50, 0.90, 1.0)
	spark_mat.emission_energy_multiplier = 3.0
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	sparks.position = Vector3(0.0, 1.2, 0.0)
	turbine.add_child(sparks)

	ps_decor.add_child(turbine)

	# 4. Signal Beacon Communications Mast
	var beacon_mast := Node3D.new()
	beacon_mast.name = "SignalBeaconMast"
	beacon_mast.position = Vector3(0.0, 0.0, 28.0)

	var mast_spire := MeshInstance3D.new()
	var ms_mesh := CylinderMesh.new()
	ms_mesh.top_radius = 0.06
	ms_mesh.bottom_radius = 0.32
	ms_mesh.height = 6.8
	var ms_mat := StandardMaterial3D.new()
	ms_mat.albedo_color = Color(0.26, 0.28, 0.30)
	ms_mat.metallic = 0.8
	ms_mat.roughness = 0.5
	mast_spire.mesh = ms_mesh
	mast_spire.material_override = ms_mat
	mast_spire.position = Vector3(0.0, 3.4, 0.0)
	beacon_mast.add_child(mast_spire)

	# Parabolic Transmitter Dish
	var dish := MeshInstance3D.new()
	var d_mesh := CylinderMesh.new()
	d_mesh.top_radius = 0.65
	d_mesh.bottom_radius = 0.20
	d_mesh.height = 0.25
	dish.mesh = d_mesh
	dish.material_override = ms_mat
	dish.position = Vector3(0.0, 5.2, 0.35)
	dish.rotation_degrees = Vector3(45.0, 0.0, 0.0)
	beacon_mast.add_child(dish)

	# Pulsing Aviation Spire Warning Light
	var beacon_light := OmniLight3D.new()
	beacon_light.name = "BeaconMastLight"
	beacon_light.light_color = Color(1.0, 0.38, 0.15)
	beacon_light.light_energy = 1.9
	beacon_light.omni_range = 9.5
	beacon_light.position = Vector3(0.0, 6.9, 0.0)
	beacon_mast.add_child(beacon_light)
	beacon_light_node = beacon_light
	ps_decor.add_child(beacon_mast)

	# 5. Cool Industrial Hydro-Cyan Ambient Floodlight (Pump Station Sector Identity)
	var pump_light := OmniLight3D.new()
	pump_light.name = "PumpStationIndustrialLight"
	pump_light.light_color = Color(0.35, 0.78, 0.95)
	pump_light.light_energy = 1.45
	pump_light.omni_range = 15.0
	pump_light.omni_attenuation = 1.15
	pump_light.position = Vector3(-12.0, 4.2, 24.0)
	ps_decor.add_child(pump_light)

	# 6. Electric Coil Hum Light (Turbine Generator Sector Identity)
	var turbine_light := OmniLight3D.new()
	turbine_light.name = "TurbineGeneratorLight"
	turbine_light.light_color = Color(0.45, 0.85, 1.0)
	turbine_light.light_energy = 1.25
	turbine_light.omni_range = 11.5
	turbine_light.omni_attenuation = 1.1
	turbine_light.position = Vector3(9.4, 3.6, 24.0)
	ps_decor.add_child(turbine_light)
	turbine_light_node = turbine_light

func _setup_greenhouse_decor(root: Node3D) -> void:
	var gh_decor := Node3D.new()
	gh_decor.name = "GreenhouseDecor"
	root.add_child(gh_decor)

	# 1. Overhead Arched Translucent Glasshouse Ribs
	var ribs_root := Node3D.new()
	ribs_root.name = "GlasshouseRibs"
	gh_decor.add_child(ribs_root)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.28, 0.35, 0.30)
	frame_mat.roughness = 0.70

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.35, 0.55, 0.45, 0.35)
	glass_mat.roughness = 0.20
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var rib_z_positions := [-16.0, -24.0, -32.0]
	for rz in rib_z_positions:
		var arch := Node3D.new()
		arch.position = Vector3(-19.0, 0.0, rz)

		var rib_beam := MeshInstance3D.new()
		var rb_mesh := BoxMesh.new()
		rb_mesh.size = Vector3(26.0, 0.25, 0.25)
		rib_beam.mesh = rb_mesh
		rib_beam.material_override = frame_mat
		rib_beam.position = Vector3(0.0, 4.8, 0.0)
		arch.add_child(rib_beam)

		var glass_pane := MeshInstance3D.new()
		var gp_mesh := PlaneMesh.new()
		gp_mesh.size = Vector2(25.0, 3.5)
		glass_pane.mesh = gp_mesh
		glass_pane.material_override = glass_mat
		glass_pane.position = Vector3(0.0, 4.75, 0.0)
		arch.add_child(glass_pane)
		ribs_root.add_child(arch)

	# 2. 3 Raised Timber Planter Boxes with Lush Foliage
	var beds_root := Node3D.new()
	beds_root.name = "RaisedPlanterBeds"
	gh_decor.add_child(beds_root)

	var timber_mat := StandardMaterial3D.new()
	timber_mat.albedo_color = Color(0.38, 0.28, 0.20)
	timber_mat.roughness = 0.90

	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.14, 0.10, 0.08)
	soil_mat.roughness = 0.98

	var crop_mat1 := StandardMaterial3D.new()
	crop_mat1.albedo_color = Color(0.26, 0.65, 0.26)
	crop_mat1.roughness = 0.80

	var crop_mat2 := StandardMaterial3D.new()
	crop_mat2.albedo_color = Color(0.42, 0.82, 0.32)
	crop_mat2.roughness = 0.80

	var bed_configs := [
		{ "pos": Vector3(-26.0, 0.0, -26.0), "size": Vector3(4.0, 0.55, 2.2) },
		{ "pos": Vector3(-14.0, 0.0, -26.0), "size": Vector3(4.0, 0.55, 2.2) },
		{ "pos": Vector3(-20.0, 0.0, -32.0), "size": Vector3(5.4, 0.55, 2.2) }
	]

	for b_idx in range(bed_configs.size()):
		var b_cfg: Dictionary = bed_configs[b_idx]
		var bed := Node3D.new()
		bed.name = "PlanterBed_%d" % (b_idx + 1)
		bed.position = b_cfg["pos"]

		# Wooden Frame
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = b_cfg["size"]
		frame.mesh = fm
		frame.material_override = timber_mat
		frame.position = Vector3(0.0, 0.275, 0.0)
		bed.add_child(frame)

		# Soil Fill
		var soil := MeshInstance3D.new()
		var sm := BoxMesh.new()
		var s_size: Vector3 = b_cfg["size"] - Vector3(0.3, 0.05, 0.3)
		sm.size = s_size
		soil.mesh = sm
		soil.material_override = soil_mat
		soil.position = Vector3(0.0, 0.32, 0.0)
		bed.add_child(soil)

		# Foliage Mounds / Crop Clusters
		for c_idx in range(3):
			var foliage := MeshInstance3D.new()
			var fol_mesh := SphereMesh.new()
			fol_mesh.radius = 0.35
			fol_mesh.height = 0.55
			foliage.mesh = fol_mesh
			foliage.material_override = crop_mat1 if (c_idx % 2 == 0) else crop_mat2
			var x_offset := (float(c_idx) - 1.0) * (s_size.x * 0.28)
			foliage.position = Vector3(x_offset, 0.65, 0.0)
			bed.add_child(foliage)

		beds_root.add_child(bed)

	# 3. Botanical Grow Light Bars
	var grow_lights := Node3D.new()
	grow_lights.name = "BotanicalGrowLights"
	gh_decor.add_child(grow_lights)

	var light_positions := [Vector3(-20.0, 3.8, -26.0), Vector3(-20.0, 3.8, -32.0)]
	for lp in light_positions:
		var gl := OmniLight3D.new()
		gl.light_color = Color(0.60, 1.0, 0.55)
		gl.light_energy = 1.40
		gl.omni_range = 9.0
		gl.position = lp
		grow_lights.add_child(gl)

	# 4. Photosynthetic Horticultural Violet/Magenta Tint Light (Greenhouse Identity)
	var v_gl := OmniLight3D.new()
	v_gl.name = "GrowLightViolet"
	v_gl.light_color = Color(0.85, 0.45, 0.95)
	v_gl.light_energy = 1.15
	v_gl.omni_range = 11.0
	v_gl.position = Vector3(-18.0, 3.8, -20.0)
	grow_lights.add_child(v_gl)

	# 5. Bioluminescent Agricultural Spores (Gentle Canopy Drifting Motes)
	var spores := CPUParticles3D.new()
	spores.name = "GreenhouseSpores"
	spores.amount = 24
	spores.lifetime = 4.0
	spores.preprocess = 1.0
	spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spores.emission_box_extents = Vector3(10.0, 1.8, 8.0)
	spores.direction = Vector3(0.2, 0.1, 0.1)
	spores.spread = 45.0
	spores.gravity = Vector3(0.0, -0.02, 0.0)
	spores.initial_velocity_min = 0.08
	spores.initial_velocity_max = 0.22
	spores.scale_amount_min = 0.06
	spores.scale_amount_max = 0.14

	var spore_mesh := SphereMesh.new()
	spore_mesh.radius = 0.04
	spore_mesh.height = 0.08
	var sp_mat := StandardMaterial3D.new()
	sp_mat.albedo_color = Color(0.65, 1.0, 0.60, 0.60)
	sp_mat.emission_enabled = true
	sp_mat.emission = Color(0.55, 0.95, 0.50)
	sp_mat.emission_energy_multiplier = 1.5
	sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spore_mesh.material = sp_mat
	spores.mesh = spore_mesh
	spores.position = Vector3(-19.0, 2.2, -24.0)
	gh_decor.add_child(spores)

func _setup_salvage_yard_decor(root: Node3D) -> void:
	var sy_decor := Node3D.new()
	sy_decor.name = "SalvageYardDecor"
	root.add_child(sy_decor)

	# 1. Overhead Yellow Steel Gantry Crane
	var gantry := Node3D.new()
	gantry.name = "SalvageGantryCrane"
	gantry.position = Vector3(23.0, 0.0, -24.0)

	var crane_mat := StandardMaterial3D.new()
	crane_mat.albedo_color = Color(0.92, 0.75, 0.15) # Safety yellow
	crane_mat.roughness = 0.65

	# Left & Right A-frame Uprights
	var upright_left := MeshInstance3D.new()
	var ul_mesh := CylinderMesh.new()
	ul_mesh.top_radius = 0.20
	ul_mesh.bottom_radius = 0.30
	ul_mesh.height = 5.2
	upright_left.mesh = ul_mesh
	upright_left.material_override = crane_mat
	upright_left.position = Vector3(-8.5, 2.6, 0.0)
	gantry.add_child(upright_left)

	var upright_right := MeshInstance3D.new()
	var ur_mesh := CylinderMesh.new()
	ur_mesh.top_radius = 0.20
	ur_mesh.bottom_radius = 0.30
	ur_mesh.height = 5.2
	upright_right.mesh = ur_mesh
	upright_right.material_override = crane_mat
	upright_right.position = Vector3(8.5, 2.6, 0.0)
	gantry.add_child(upright_right)

	# Overhead Cross-beam Girder
	var girder := MeshInstance3D.new()
	var g_mesh := BoxMesh.new()
	g_mesh.size = Vector3(18.5, 0.55, 0.55)
	girder.mesh = g_mesh
	girder.material_override = crane_mat
	girder.position = Vector3(0.0, 5.2, 0.0)
	gantry.add_child(girder)

	# Motorized Hoist Trolley & Steel Hook Cable
	var hoist := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(1.2, 0.4, 0.8)
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.25, 0.26, 0.28)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.4
	hoist.mesh = h_mesh
	hoist.material_override = steel_mat
	hoist.position = Vector3(0.0, 4.8, 0.0)
	gantry.add_child(hoist)

	var cable := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.03
	c_mesh.bottom_radius = 0.03
	c_mesh.height = 2.0
	cable.mesh = c_mesh
	cable.material_override = steel_mat
	cable.position = Vector3(0.0, 3.6, 0.0)
	gantry.add_child(cable)
	sy_decor.add_child(gantry)

	# 2. Stacked Weathered Shipping Containers
	var containers_root := Node3D.new()
	containers_root.name = "StackedShippingContainers"
	sy_decor.add_child(containers_root)

	var container_defs := [
		{ "pos": Vector3(30.0, 1.25, -16.0), "rot": 0.0, "col": Color(0.58, 0.22, 0.18) },
		{ "pos": Vector3(32.0, 1.25, -31.0), "rot": 15.0, "col": Color(0.22, 0.38, 0.52) },
		{ "pos": Vector3(32.0, 3.75, -31.0), "rot": 15.0, "col": Color(0.32, 0.36, 0.24) }
	]

	for c_idx in range(container_defs.size()):
		var c_def: Dictionary = container_defs[c_idx]
		var c_inst := MeshInstance3D.new()
		c_inst.name = "ShippingContainer_%d" % (c_idx + 1)
		var cm := BoxMesh.new()
		cm.size = Vector3(2.6, 2.5, 5.8)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = c_def["col"]
		cmat.roughness = 0.75
		cmat.metallic = 0.40
		c_inst.mesh = cm
		c_inst.material_override = cmat
		c_inst.position = c_def["pos"]
		c_inst.rotation_degrees = Vector3(0.0, c_def["rot"], 0.0)
		containers_root.add_child(c_inst)

	# 3. Scrap Metal Junk Mounds
	var scrap_root := Node3D.new()
	scrap_root.name = "ScrapMetalPiles"
	sy_decor.add_child(scrap_root)

	var scrap_positions := [Vector3(14.0, 0.35, -28.0), Vector3(26.0, 0.35, -28.0)]
	var scrap_mat := StandardMaterial3D.new()
	scrap_mat.albedo_color = Color(0.40, 0.35, 0.30)
	scrap_mat.metallic = 0.7
	scrap_mat.roughness = 0.6

	for sp in scrap_positions:
		var pile := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.6
		p_mesh.bottom_radius = 1.4
		p_mesh.height = 0.7
		pile.mesh = p_mesh
		pile.material_override = scrap_mat
		pile.position = sp
		scrap_root.add_child(pile)

	# 4. Salvage Quartermaster Workbench with Industrial Vise
	var bench := Node3D.new()
	bench.name = "SalvageWorkbench"
	bench.position = Vector3(25.0, 0.0, -16.0)

	var table := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(2.4, 0.8, 1.1)
	var timber_bench_mat := StandardMaterial3D.new()
	timber_bench_mat.albedo_color = Color(0.38, 0.28, 0.20)
	timber_bench_mat.roughness = 0.90
	table.mesh = t_mesh
	table.material_override = timber_bench_mat
	table.position = Vector3(0.0, 0.4, 0.0)
	bench.add_child(table)

	var vise := MeshInstance3D.new()
	var v_mesh := BoxMesh.new()
	v_mesh.size = Vector3(0.3, 0.3, 0.3)
	vise.mesh = v_mesh
	vise.material_override = steel_mat
	vise.position = Vector3(0.8, 0.95, 0.2)
	bench.add_child(vise)
	sy_decor.add_child(bench)

	# 5. Industrial Halogen Work Floodlight
	var floodlight := Node3D.new()
	floodlight.name = "SalvageFloodlight"
	floodlight.position = Vector3(26.0, 0.0, -10.0)

	var fl_pole := MeshInstance3D.new()
	var flp_mesh := CylinderMesh.new()
	flp_mesh.top_radius = 0.08
	flp_mesh.bottom_radius = 0.12
	flp_mesh.height = 4.8
	fl_pole.mesh = flp_mesh
	fl_pole.material_override = steel_mat
	fl_pole.position = Vector3(0.0, 2.4, 0.0)
	floodlight.add_child(fl_pole)

	var fl_light := OmniLight3D.new()
	fl_light.name = "HalogenLamp"
	fl_light.light_color = Color(1.0, 0.90, 0.65)
	fl_light.light_energy = 1.70
	fl_light.omni_range = 13.0
	fl_light.omni_attenuation = 1.1
	fl_light.position = Vector3(0.0, 4.8, 0.0)
	floodlight.add_child(fl_light)
	sy_decor.add_child(floodlight)

	# 6. Industrial Welding Workbench Lamp (Salvage Yard Identity)
	var wb_lamp := OmniLight3D.new()
	wb_lamp.name = "SalvageWorkbenchLamp"
	wb_lamp.light_color = Color(1.0, 0.72, 0.38) # Warm welding amber
	wb_lamp.light_energy = 1.35
	wb_lamp.omni_range = 10.0
	wb_lamp.omni_attenuation = 1.15
	wb_lamp.position = Vector3(16.0, 3.2, -24.0)
	sy_decor.add_child(wb_lamp)

# ------------------------------------------------------------------------------
# 3. 3D Task Pads (Civic & Escalation-Locked)
# ------------------------------------------------------------------------------
func _setup_task_pads() -> void:
	# Civic Pads Active in Open Town
	_create_pad("pump", "Pump Station Repair", "pump", Vector3(-6.0, 0.05, 24.0), 2.8, Color(0.35, 0.75, 1.0), false)
	_create_pad("greenhouse", "Crop Bed Tending", "greenhouse", Vector3(-20.0, 0.05, -20.0), 2.8, Color(0.40, 0.90, 0.55), false)
	_create_pad("salvage", "Scrap Heap Sorting", "salvage", Vector3(20.0, 0.05, -20.0), 2.8, Color(0.95, 0.70, 0.35), false)
	_create_pad("clinic", "Town Clinic Recovery", "clinic", Vector3(0.0, 0.05, -10.0), 2.8, Color(0.92, 0.45, 0.50), false)
	_create_pad("common_works", "Common Works Foundation", "common_works", Vector3(-12.0, 0.05, 0.0), 3.2, Color(0.85, 0.65, 0.95), false)

	# Escalation-Locked Landmarks (visibly locked during Phase 1 & Open Town)
	_create_pad("generator", "Overdrive Generator\n[Locked until Escalation]", "generator", Vector3(6.0, 0.05, 24.0), 2.8, Color(0.70, 0.55, 0.30), true)
	_create_pad("beacon", "Signal Beacon\n[Locked until Escalation]", "beacon", Vector3(0.0, 0.05, 28.0), 2.4, Color(0.65, 0.52, 0.28), true)

func _create_pad(id: String, title: String, task_type: String, pos: Vector3, radius: float, col: Color, is_locked: bool) -> void:
	var root_node := Node3D.new()
	root_node.name = "Pad_" + id
	root_node.position = pos
	add_child(root_node)

	# 1. Physical Station Base Plinth (Raised stone & composite foundation)
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = radius
	plinth_mesh.bottom_radius = radius * 1.02
	plinth_mesh.height = 0.12
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color(0.22, 0.23, 0.26)
	plinth_mat.roughness = 0.88
	plinth_mat.metallic = 0.20
	var plinth_inst := MeshInstance3D.new()
	plinth_inst.name = "StationPlinth"
	plinth_inst.mesh = plinth_mesh
	plinth_inst.material_override = plinth_mat
	plinth_inst.position = Vector3(0.0, 0.06, 0.0)
	root_node.add_child(plinth_inst)

	# 2. Beveled Dark Steel Perimeter Curb / Rim
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius * 1.01
	rim_mesh.bottom_radius = radius * 1.01
	rim_mesh.height = 0.04
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.16, 0.17, 0.19)
	rim_mat.roughness = 0.50
	rim_mat.metallic = 0.75
	var rim_inst := MeshInstance3D.new()
	rim_inst.name = "StationRim"
	rim_inst.mesh = rim_mesh
	rim_inst.material_override = rim_mat
	rim_inst.position = Vector3(0.0, 0.11, 0.0)
	root_node.add_child(rim_inst)

	# 3. Inner Industrial Diamond-Grate Floor
	var grate_mesh := CylinderMesh.new()
	grate_mesh.top_radius = radius * 0.90
	grate_mesh.bottom_radius = radius * 0.90
	grate_mesh.height = 0.02
	var grate_mat := StandardMaterial3D.new()
	grate_mat.albedo_color = Color(0.12, 0.13, 0.15)
	grate_mat.roughness = 0.70
	grate_mat.metallic = 0.60
	var grate_inst := MeshInstance3D.new()
	grate_inst.name = "StationGrate"
	grate_inst.mesh = grate_mesh
	grate_inst.material_override = grate_mat
	grate_inst.position = Vector3(0.0, 0.12, 0.0)
	root_node.add_child(grate_inst)

	# 4. Embedded Neon Indicator Guide Ring (Preserved mesh_inst and mat for compatibility)
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.84
	ring.outer_radius = radius * 0.90
	ring.rings = 36
	ring.ring_segments = 16
	var mat := StandardMaterial3D.new()
	var alpha: float = 0.35 if is_locked else 0.85
	mat.albedo_color = col * alpha
	mat.emission_enabled = not is_locked
	mat.emission = col
	mat.emission_energy_multiplier = 0.85 if not is_locked else 0.0
	mat.roughness = 0.30
	var ring_inst := MeshInstance3D.new()
	ring_inst.name = "StationBeaconRing"
	ring_inst.mesh = ring
	ring_inst.material_override = mat
	ring_inst.position = Vector3(0.0, 0.13, 0.0)
	root_node.add_child(ring_inst)

	# 5. Station Physical Control Pedestal & Terminal Console
	var term_offset_z: float = -radius * 0.70
	var pedestal_base := MeshInstance3D.new()
	pedestal_base.name = "TerminalPedestal"
	var ped_mesh := BoxMesh.new()
	ped_mesh.size = Vector3(0.55, 0.80, 0.28)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.18, 0.19, 0.22)
	ped_mat.roughness = 0.65
	ped_mat.metallic = 0.70
	pedestal_base.mesh = ped_mesh
	pedestal_base.material_override = ped_mat
	pedestal_base.position = Vector3(0.0, 0.45, term_offset_z)
	root_node.add_child(pedestal_base)

	# Console Angled Terminal Head
	var head_inst := MeshInstance3D.new()
	head_inst.name = "TerminalHead"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.60, 0.32, 0.26)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.22, 0.23, 0.26)
	head_mat.roughness = 0.60
	head_mat.metallic = 0.65
	head_inst.mesh = head_mesh
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 0.92, term_offset_z + 0.05)
	head_inst.rotation_degrees.x = -25.0
	root_node.add_child(head_inst)

	# Illuminated Terminal Screen
	var screen_inst := MeshInstance3D.new()
	screen_inst.name = "TerminalScreen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.48, 0.22, 0.02)
	var screen_mat := StandardMaterial3D.new()
	if is_locked:
		screen_mat.albedo_color = Color(0.20, 0.18, 0.16)
		screen_mat.emission_enabled = false
	else:
		screen_mat.albedo_color = col * 0.7
		screen_mat.emission_enabled = true
		screen_mat.emission = col
		screen_mat.emission_energy_multiplier = 1.1
	screen_inst.mesh = screen_mesh
	screen_inst.material_override = screen_mat
	screen_inst.position = Vector3(0.0, 0.94, term_offset_z + 0.17)
	screen_inst.rotation_degrees.x = -25.0
	root_node.add_child(screen_inst)

	# Station Status Beacon Dome
	var dome_inst := MeshInstance3D.new()
	dome_inst.name = "TerminalBeaconDome"
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.08
	dome_mesh.height = 0.12
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = col if not is_locked else Color(0.4, 0.35, 0.25)
	dome_mat.emission_enabled = not is_locked
	dome_mat.emission = col
	dome_mat.emission_energy_multiplier = 1.4 if not is_locked else 0.0
	dome_inst.mesh = dome_mesh
	dome_inst.material_override = dome_mat
	dome_inst.position = Vector3(0.0, 1.14, term_offset_z)
	root_node.add_child(dome_inst)

	# 6. Station-Specific Accent Props
	_add_station_props(root_node, id, radius, term_offset_z, col)

	# 7. High-Contrast Readable World Label
	var lbl := Label3D.new()
	lbl.text = title if is_locked else "%s\n[Hold E to Channel]" % title
	lbl.font_size = 28
	lbl.modulate = Color(0.75, 0.70, 0.65) if is_locked else col
	lbl.outline_size = 5
	lbl.outline_modulate = Color(0, 0, 0, 0.98)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.35, term_offset_z)
	root_node.add_child(lbl)

	task_pads.append({
		"id": id,
		"name": title,
		"base_title": title.split("\n")[0],
		"task_type": task_type,
		"position": pos,
		"radius": radius,
		"node": root_node,
		"mesh_inst": ring_inst,
		"mat": mat,
		"screen_mat": screen_mat,
		"dome_mat": dome_mat,
		"label_node": lbl,
		"color": col,
		"is_locked": is_locked,
		"cooldown": 0.0,
		"jammed_timer": 0.0,
		"overclocked": false,
		"active_user": null,
		"reserved_by": null,
		"last_user_name": "",
		"last_used_action": ""
	})

func _add_station_props(root: Node3D, pad_id: String, radius: float, term_z: float, col: Color) -> void:
	match pad_id:
		"pump":
			# Industrial intake pipe coupling running into pedestal rear
			var pipe_inst := MeshInstance3D.new()
			pipe_inst.name = "PumpIntakePipe"
			var pipe_mesh := CylinderMesh.new()
			pipe_mesh.top_radius = 0.07
			pipe_mesh.bottom_radius = 0.07
			pipe_mesh.height = 0.60
			var pipe_mat := StandardMaterial3D.new()
			pipe_mat.albedo_color = Color(0.20, 0.28, 0.35)
			pipe_mat.metallic = 0.80
			pipe_mat.roughness = 0.40
			pipe_inst.mesh = pipe_mesh
			pipe_inst.material_override = pipe_mat
			pipe_inst.position = Vector3(0.22, 0.30, term_z - 0.12)
			root.add_child(pipe_inst)

			var pipe2 := pipe_inst.duplicate() as MeshInstance3D
			pipe2.name = "PumpIntakePipe2"
			pipe2.position.x = -0.22
			root.add_child(pipe2)

		"greenhouse":
			# Botanical nutrient sampling rack
			var planter := MeshInstance3D.new()
			planter.name = "BotanicalSamplingRack"
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(0.35, 0.25, 0.50)
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.32, 0.24, 0.16)
			planter.mesh = p_mesh
			planter.material_override = p_mat
			planter.position = Vector3(0.48, 0.15, term_z)
			root.add_child(planter)

		"salvage":
			# Scrap sorting parts bin
			var bin := MeshInstance3D.new()
			bin.name = "ScrapPartsBin"
			var b_mesh := BoxMesh.new()
			b_mesh.size = Vector3(0.45, 0.30, 0.45)
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.45, 0.32, 0.18)
			b_mat.metallic = 0.60
			bin.mesh = b_mesh
			bin.material_override = b_mat
			bin.position = Vector3(-0.50, 0.16, term_z)
			root.add_child(bin)

		"clinic":
			# Red cross caduceus emblem on terminal face
			var cross_v := MeshInstance3D.new()
			cross_v.name = "MedicalCrossV"
			var cv_mesh := BoxMesh.new()
			cv_mesh.size = Vector3(0.06, 0.18, 0.03)
			var cv_mat := StandardMaterial3D.new()
			cv_mat.albedo_color = Color(0.95, 0.20, 0.20)
			cv_mat.emission_enabled = true
			cv_mat.emission = Color(0.95, 0.20, 0.20)
			cv_mat.emission_energy_multiplier = 0.8
			cross_v.mesh = cv_mesh
			cross_v.material_override = cv_mat
			cross_v.position = Vector3(0.0, 0.94, term_z + 0.19)
			cross_v.rotation_degrees.x = -25.0
			root.add_child(cross_v)

			var cross_h := MeshInstance3D.new()
			cross_h.name = "MedicalCrossH"
			var ch_mesh := BoxMesh.new()
			ch_mesh.size = Vector3(0.18, 0.06, 0.03)
			cross_h.mesh = ch_mesh
			cross_h.material_override = cv_mat
			cross_h.position = Vector3(0.0, 0.94, term_z + 0.19)
			cross_h.rotation_degrees.x = -25.0
			root.add_child(cross_h)

		"generator":
			# Coiled high-voltage conduit linking into pedestal
			var conduit := MeshInstance3D.new()
			conduit.name = "GeneratorConduit"
			var c_mesh := CylinderMesh.new()
			c_mesh.top_radius = 0.08
			c_mesh.bottom_radius = 0.08
			c_mesh.height = 0.70
			var c_mat := StandardMaterial3D.new()
			c_mat.albedo_color = Color(0.15, 0.15, 0.16)
			conduit.mesh = c_mesh
			conduit.material_override = c_mat
			conduit.position = Vector3(0.0, 0.35, term_z - 0.14)
			root.add_child(conduit)

		"beacon":
			# Communications antenna mast spike atop terminal
			var antenna := MeshInstance3D.new()
			antenna.name = "BeaconAntennaSpike"
			var a_mesh := CylinderMesh.new()
			a_mesh.top_radius = 0.015
			a_mesh.bottom_radius = 0.03
			a_mesh.height = 0.65
			var a_mat := StandardMaterial3D.new()
			a_mat.albedo_color = Color(0.70, 0.72, 0.75)
			a_mat.metallic = 0.90
			antenna.mesh = a_mesh
			antenna.material_override = a_mat
			antenna.position = Vector3(0.0, 1.45, term_z)
			root.add_child(antenna)

# ------------------------------------------------------------------------------
# 4. Secluded Bedrock Alcoves (Archive Secrecy)
# ------------------------------------------------------------------------------
# 4 identical-looking recessed stone alcoves across the town sectors.
# Exactly one is activated per match via game_manager.archive_active_spawn_id.
# All 4 look identical until inspected—no permanent 'Archive' pad or visual leak.
func _setup_secluded_alcoves() -> void:
	var alcove_defs: Array[Dictionary] = [
		{ "id": "north_pass", "name": "North Pass Crevice", "pos": Vector3(0.0, 0.05, 34.0), "region": "Pump & Generator Station" },
		{ "id": "salvage_alcove", "name": "Salvage Gantry Alcove", "pos": Vector3(28.0, 0.05, -24.0), "region": "Salvage Yard" },
		{ "id": "pump_basin", "name": "Pump Basin Crevice", "pos": Vector3(-24.0, 0.05, 26.0), "region": "Pump & Generator Station" },
		{ "id": "council_niche", "name": "Council Ring Old Niche", "pos": Vector3(-14.0, 0.05, 8.0), "region": "Town Square" }
	]

	for alc in alcove_defs:
		var root_node := Node3D.new()
		root_node.name = "Alcove_" + String(alc["id"])
		root_node.position = alc["pos"]
		add_child(root_node)

		# Stone alcove floor recess marker
		var recess := CylinderMesh.new()
		recess.top_radius = 1.4
		recess.bottom_radius = 1.4
		recess.height = 0.05
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24, 0.25, 0.28, 0.85)
		mat.roughness = 0.95
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = recess
		r_inst.material_override = mat
		root_node.add_child(r_inst)

		# Weathered stone marker pillar
		var pillar := BoxMesh.new()
		pillar.size = Vector3(0.4, 0.8, 0.4)
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.32, 0.33, 0.36)
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = pillar
		p_inst.material_override = p_mat
		p_inst.position = Vector3(0.0, 0.4, 0.0)
		root_node.add_child(p_inst)

		# Neutral overhead label (all 4 alcoves read identically)
		var lbl := Label3D.new()
		lbl.text = "Secluded Bedrock Alcove\n[Inspect: V]"
		lbl.font_size = 26
		lbl.modulate = Color(0.70, 0.75, 0.82, 0.90)
		lbl.outline_size = 5
		lbl.outline_modulate = Color(0, 0, 0, 0.98)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0.0, 1.6, 0.0)
		root_node.add_child(lbl)

		secret_alcoves.append({
			"id": String(alc["id"]),
			"name": String(alc["name"]),
			"pos": alc["pos"],
			"region": String(alc["region"]),
			"node": root_node,
			"is_active": false
		})

	# Randomly activate one alcove per match or sync with GameManager
	_sync_active_alcove()

func _sync_active_alcove() -> void:
	if game_manager != null and game_manager.get("archive_active_spawn_id") != "":
		active_alcove_id = String(game_manager.archive_active_spawn_id)
	else:
		if secret_alcoves.size() > 0:
			var rand_idx: int = randi() % secret_alcoves.size()
			active_alcove_id = secret_alcoves[rand_idx]["id"]
			if game_manager != null:
				game_manager.set("archive_active_spawn_id", active_alcove_id)

	for alc in secret_alcoves:
		alc["is_active"] = (alc["id"] == active_alcove_id)

# ------------------------------------------------------------------------------
# 5. 3D Waypoint Navigation Graph & Pathfinding
# ------------------------------------------------------------------------------
func _setup_waypoint_graph() -> void:
	# Register 3D Waypoints across all four sectors and corridors
	_add_wp("ts_center", Vector3(0.0, 0.0, 0.0), ["ts_north", "ts_south_west", "ts_south_east", "pad_cw", "pad_clinic"])
	_add_wp("ts_north", Vector3(0.0, 0.0, 8.0), ["ts_center", "corridor_north", "alcove_council", "ts_east"])
	_add_wp("corridor_north", Vector3(0.0, 0.0, 14.0), ["ts_north", "pump_south", "gen_south"])
	_add_wp("pump_south", Vector3(-6.0, 0.0, 18.0), ["corridor_north", "pad_pump", "pump_west"])
	_add_wp("pad_pump", Vector3(-6.0, 0.0, 24.0), ["pump_south", "pump_west"])
	_add_wp("pump_west", Vector3(-18.0, 0.0, 24.0), ["pump_south", "pad_pump", "alcove_pump"])
	_add_wp("alcove_pump", Vector3(-24.0, 0.0, 26.0), ["pump_west"])

	_add_wp("gen_south", Vector3(6.0, 0.0, 18.0), ["corridor_north", "pad_gen", "beacon_wp"])
	_add_wp("pad_gen", Vector3(6.0, 0.0, 24.0), ["gen_south", "beacon_wp"])
	_add_wp("beacon_wp", Vector3(0.0, 0.0, 28.0), ["pad_gen", "alcove_north_pass"])
	_add_wp("alcove_north_pass", Vector3(0.0, 0.0, 34.0), ["beacon_wp"])

	_add_wp("pad_cw", Vector3(-12.0, 0.0, 0.0), ["ts_center", "alcove_council", "ts_south_west"])
	_add_wp("alcove_council", Vector3(-14.0, 0.0, 8.0), ["pad_cw", "ts_north"])
	_add_wp("pad_clinic", Vector3(0.0, 0.0, -10.0), ["ts_center", "ts_south_west", "ts_south_east"])

	_add_wp("ts_south_west", Vector3(-8.0, 0.0, -8.0), ["ts_center", "pad_clinic", "corridor_gh", "pad_cw"])
	_add_wp("corridor_gh", Vector3(-14.0, 0.0, -14.0), ["ts_south_west", "pad_greenhouse"])
	_add_wp("pad_greenhouse", Vector3(-20.0, 0.0, -20.0), ["corridor_gh"])

	_add_wp("ts_east", Vector3(12.0, 0.0, 0.0), ["ts_north", "ts_south_east"])
	_add_wp("ts_south_east", Vector3(8.0, 0.0, -8.0), ["ts_center", "pad_clinic", "corridor_sy", "ts_east"])
	_add_wp("corridor_sy", Vector3(14.0, 0.0, -14.0), ["ts_south_east", "pad_salvage"])
	_add_wp("pad_salvage", Vector3(20.0, 0.0, -20.0), ["corridor_sy", "alcove_salvage"])
	_add_wp("alcove_salvage", Vector3(28.0, 0.0, -24.0), ["pad_salvage"])

func _add_wp(wp_id: String, pos: Vector3, nbrs: Array[String]) -> void:
	waypoints[wp_id] = {
		"id": wp_id,
		"pos": pos,
		"neighbors": nbrs
	}

func get_nearest_waypoint_id(pos: Vector3) -> String:
	var best_id := "ts_center"
	var best_dist := 999999.0
	for wp_id in waypoints.keys():
		var d: float = pos.distance_to(waypoints[wp_id]["pos"])
		if d < best_dist:
			best_dist = d
			best_id = wp_id
	return best_id

func find_path_between_waypoints(start_wp_id: String, target_wp_id: String) -> Array[Vector3]:
	if not waypoints.has(start_wp_id) or not waypoints.has(target_wp_id):
		return []
	if start_wp_id == target_wp_id:
		return [waypoints[target_wp_id]["pos"]]

	# Standard BFS shortest path over waypoint graph
	var queue: Array[String] = [start_wp_id]
	var visited := { start_wp_id: true }
	var came_from: Dictionary = {}

	while not queue.is_empty():
		var curr: String = queue.pop_front()
		if curr == target_wp_id:
			break
		var nbrs: Array = waypoints[curr].get("neighbors", [])
		for nbr_var in nbrs:
			var nbr: String = String(nbr_var)
			if not visited.has(nbr):
				visited[nbr] = true
				came_from[nbr] = curr
				queue.push_back(nbr)

	if not came_from.has(target_wp_id):
		return []

	# Reconstruct path
	var path_ids: Array[String] = []
	var step: String = target_wp_id
	while step != start_wp_id:
		path_ids.push_front(step)
		step = came_from[step]

	var result: Array[Vector3] = []
	for pid in path_ids:
		result.append(waypoints[pid]["pos"])
	return result

func find_path(from_pos: Vector3, to_pos: Vector3) -> Array[Vector3]:
	var start_wp := get_nearest_waypoint_id(from_pos)
	var end_wp := get_nearest_waypoint_id(to_pos)
	var path := find_path_between_waypoints(start_wp, end_wp)
	path.append(to_pos)
	return path

# ------------------------------------------------------------------------------
# 6. Spatial Queries, Anonymity & Line of Sight
# ------------------------------------------------------------------------------
func get_region_id_at_3d(pos: Vector3) -> String:
	var p2 := Vector2(pos.x, pos.z)
	for reg in regions_3d:
		var min_p: Vector2 = reg["min"]
		var max_p: Vector2 = reg["max"]
		if p2.x >= min_p.x and p2.x <= max_p.x and p2.y >= min_p.y and p2.y <= max_p.y:
			return reg["id"]
	return "town_square"

func get_region_name_at_3d(pos: Vector3) -> String:
	var p2 := Vector2(pos.x, pos.z)
	for reg in regions_3d:
		var min_p: Vector2 = reg["min"]
		var max_p: Vector2 = reg["max"]
		if p2.x >= min_p.x and p2.x <= max_p.x and p2.y >= min_p.y and p2.y <= max_p.y:
			return reg["name"]
	return "Town Corridors"

func get_region_name_at(pos: Variant) -> String:
	if pos is Vector3:
		return get_region_name_at_3d(pos)
	elif pos is Vector2:
		return get_region_name_at_3d(Vector3(pos.x, 0.0, pos.y))
	return "Town Square"

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

func has_clear_sightline_3d(from_pos: Vector3, to_pos: Vector3) -> bool:
	var p_eye := from_pos + Vector3(0.0, 1.2, 0.0)
	var t_eye := to_pos + Vector3(0.0, 1.2, 0.0)

	# 1. Deterministic geometric check against registered obstacle AABBs
	for box in obstacle_aabbs:
		if box.intersects_segment(p_eye, t_eye):
			return false

	# 2. Physics server raycast fallback if space state is synced
	if is_inside_tree():
		var world := get_world_3d()
		if world != null:
			var space := world.direct_space_state
			if space != null:
				var query := PhysicsRayQueryParameters3D.create(p_eye, t_eye)
				var hit := space.intersect_ray(query)
				if not hit.is_empty():
					return false

	return true

func spawn_field_zone_3d(zone_type: String, pos: Vector3, radius: float, duration: float, team: int, region: String = "", extra_pos: Vector3 = Vector3.ZERO) -> Node3D:
	last_spawned_zone = {
		"zone_type": zone_type,
		"pos": pos,
		"radius": radius,
		"duration": duration,
		"team": team,
		"region": region,
		"extra_pos": extra_pos
	}

	var ring := CylinderMesh.new()
	ring.top_radius = radius
	ring.bottom_radius = radius
	ring.height = 0.08
	var mat := StandardMaterial3D.new()

	var z_col := Color(1.0, 0.75, 0.35, 0.6)
	var e_col := Color(1.0, 0.65, 0.25)
	match zone_type:
		"mulch_mist":
			z_col = Color(0.40, 0.95, 0.55, 0.45)
			e_col = Color(0.35, 0.90, 0.50)
		"root_snare":
			z_col = Color(0.70, 0.85, 0.25, 0.50)
			e_col = Color(0.65, 0.80, 0.20)
		"thorn_guard":
			z_col = Color(0.35, 0.95, 0.75, 0.50)
			e_col = Color(0.30, 0.90, 0.70)
		"spark_trail":
			z_col = Color(0.45, 0.88, 1.0, 0.60)
			e_col = Color(0.40, 0.85, 1.0)
		"disturbance_ring":
			z_col = Color(1.0, 0.72, 0.30, 0.55)
			e_col = Color(1.0, 0.65, 0.25)
		"scent_scan":
			z_col = Color(0.50, 1.0, 0.70, 0.35)
			e_col = Color(0.40, 0.95, 0.65)

	mat.albedo_color = z_col
	mat.emission_enabled = true
	mat.emission = e_col
	mat.emission_energy_multiplier = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var inst := MeshInstance3D.new()
	inst.mesh = ring
	inst.material_override = mat
	inst.position = pos + Vector3(0.0, 0.06, 0.0)
	add_child(inst)

	# Enhanced visual geometry based on zone type (Option 1 Polish)
	match zone_type:
		"mulch_mist":
			# Bilayered organic spore mist cloud
			for m_idx in range(4):
				var mist_puff := MeshInstance3D.new()
				var puff_mesh := SphereMesh.new()
				puff_mesh.radius = radius * 0.45
				puff_mesh.height = radius * 0.60
				mist_puff.mesh = puff_mesh
				var puff_mat := StandardMaterial3D.new()
				puff_mat.albedo_color = Color(0.35, 0.92, 0.48, 0.28)
				puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				puff_mat.roughness = 0.9
				mist_puff.mesh = puff_mesh
				mist_puff.material_override = puff_mat
				var angle := (TAU / 4.0) * float(m_idx)
				mist_puff.position = Vector3(cos(angle) * (radius * 0.4), 0.35 + float(m_idx) * 0.1, sin(angle) * (radius * 0.4))
				inst.add_child(mist_puff)

		"root_snare":
			# Briar root thorns encircling perimeter
			var thorn_mat := StandardMaterial3D.new()
			thorn_mat.albedo_color = Color(0.42, 0.36, 0.20)
			thorn_mat.roughness = 0.85
			for t_idx in range(8):
				var thorn := MeshInstance3D.new()
				var t_cone := CylinderMesh.new()
				t_cone.top_radius = 0.02
				t_cone.bottom_radius = 0.12
				t_cone.height = 0.65
				thorn.mesh = t_cone
				thorn.material_override = thorn_mat
				var angle := (TAU / 8.0) * float(t_idx)
				thorn.position = Vector3(cos(angle) * (radius * 0.9), 0.32, sin(angle) * (radius * 0.9))
				thorn.rotation_degrees = Vector3(15.0, -rad_to_deg(angle), 0.0)
				inst.add_child(thorn)

		"thorn_guard":
			# Translucent crystalline protective hemisphere shield
			var dome := MeshInstance3D.new()
			var dome_mesh := SphereMesh.new()
			dome_mesh.radius = radius
			dome_mesh.height = radius
			dome_mesh.is_hemisphere = true
			var d_mat := StandardMaterial3D.new()
			d_mat.albedo_color = Color(0.30, 0.95, 0.80, 0.25)
			d_mat.emission_enabled = true
			d_mat.emission = Color(0.25, 0.90, 0.75)
			d_mat.emission_energy_multiplier = 0.5
			d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			d_mat.roughness = 0.1
			dome.mesh = dome_mesh
			dome.material_override = d_mat
			dome.position = Vector3(0.0, 0.0, 0.0)
			inst.add_child(dome)

		"spark_trail":
			# Electric arc core with emission
			var spark_core := MeshInstance3D.new()
			var sc_mesh := BoxMesh.new()
			sc_mesh.size = Vector3(radius * 0.4, 0.15, radius * 0.4)
			var sc_mat := StandardMaterial3D.new()
			sc_mat.albedo_color = Color(0.60, 0.95, 1.0)
			sc_mat.emission_enabled = true
			sc_mat.emission = Color(0.50, 0.92, 1.0)
			sc_mat.emission_energy_multiplier = 2.0
			spark_core.mesh = sc_mesh
			spark_core.material_override = sc_mat
			spark_core.position = Vector3(0.0, 0.1, 0.0)
			inst.add_child(spark_core)

	active_zones.append({
		"type": zone_type,
		"pos": pos,
		"radius": radius,
		"duration": duration,
		"time_left": duration,
		"owner_id": team,
		"node": inst
	})

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(Callable(inst, "queue_free"))
	return inst

# ------------------------------------------------------------------------------
# 7. Zone Queries & Faction Mechanics
# ------------------------------------------------------------------------------
func is_slowed_by_root_snare(pos: Vector3, exclude_id: int = -1) -> bool:
	for z in active_zones:
		if z["type"] == "root_snare" and z["time_left"] > 0.0:
			if z["owner_id"] != exclude_id:
				if pos.distance_to(z["pos"]) <= z["radius"]:
					return true
	return false

func is_protected_by_thorn_guard(pos: Vector3) -> bool:
	for z in active_zones:
		if z["type"] == "thorn_guard" and z["time_left"] > 0.0:
			if pos.distance_to(z["pos"]) <= z["radius"]:
				return true
	return false

func is_inside_mulch_mist(pos: Vector3) -> bool:
	for z in active_zones:
		if z["type"] == "mulch_mist" and z["time_left"] > 0.0:
			if pos.distance_to(z["pos"]) <= z["radius"]:
				return true
	return false

func cleanse_hazards_near_3d(pos: Vector3, radius: float = 5.0) -> int:
	var cleansed_count := 0
	for pad in task_pads:
		if pos.distance_to(pad["position"]) <= radius:
			if float(pad.get("jammed_timer", 0.0)) > 0.0:
				pad["jammed_timer"] = 0.0
				cleansed_count += 1
	for z in active_zones:
		if float(z.get("time_left", 0.0)) > 0.0:
			var z_type: String = String(z.get("type", ""))
			if (z_type == "root_snare" or z_type == "spark_trail") and pos.distance_to(z["pos"]) <= (radius + float(z.get("radius", 0.0))):
				z["time_left"] = 0.0
				var z_node: Node = z.get("node")
				if z_node != null and is_instance_valid(z_node):
					z_node.visible = false
				cleansed_count += 1
	spawn_field_zone_3d("mulch_mist", pos, 3.2, 2.5, 0)
	return cleansed_count

func trigger_tracker_scent_snapshot_3d(caster: Node, residents: Array, scan_radius: float = 14.0, duration: float = 5.0) -> int:
	var c_pos: Vector3 = caster.global_position if caster.is_inside_tree() else caster.position
	spawn_field_zone_3d("scent_scan", c_pos, scan_radius, 2.0, caster.resident_id)

	var detected_count := 0
	for r in residents:
		if r == null or r == caster or r.is_incapacitated:
			continue
		var r_pos: Vector3 = r.global_position if r.is_inside_tree() else r.position
		if c_pos.distance_to(r_pos) <= scan_radius:
			detected_count += 1

	for pad in task_pads:
		if c_pos.distance_to(pad["position"]) <= scan_radius and pad.get("last_user_name", "") != "":
			detected_count += 1

	return maxi(1, detected_count)

# ------------------------------------------------------------------------------
# 8. Interactive Task Pad API & Escalation Unlocks
# ------------------------------------------------------------------------------
func get_nearest_pad(pos: Vector3, max_dist: float = 3.8) -> Dictionary:
	var best_pad: Dictionary = {}
	var best_dist: float = max_dist
	for pad in task_pads:
		var pad_pos: Vector3 = pad["position"]
		var d: float = pos.distance_to(pad_pos)
		var check_r: float = pad.get("radius", 2.8) + 0.8
		if d <= check_r and d < best_dist:
			best_dist = d
			best_pad = pad
	return best_pad

func get_pad_by_id(pad_id: String) -> Dictionary:
	for pad in task_pads:
		if pad.get("id") == pad_id:
			return pad
	return {}

func start_using_pad(pad: Dictionary, resident: Node) -> bool:
	if pad.is_empty():
		return false
	if pad.get("is_locked", false):
		return false
	if float(pad.get("cooldown", 0.0)) > 0.0 or float(pad.get("jammed_timer", 0.0)) > 0.0:
		return false
	if pad.get("active_user") != null and pad.get("active_user") != resident:
		return false
	if game_manager != null and not game_manager.can_perform_task(pad.get("task_type", "")):
		return false

	pad["active_user"] = resident
	pad["reserved_by"] = resident
	record_pad_interaction(pad, resident.resident_name, "accessed")

	if game_manager != null and game_manager.get("sensor_beacons_active") == true:
		if game_manager.has_method("record_beacon_access"):
			game_manager.record_beacon_access(resident, get_region_name_at_3d(pad["position"]), pad["name"])

	return true

func finish_using_pad(pad: Dictionary, resident: Node, is_player: bool) -> String:
	if pad.is_empty():
		return ""
	var was_overclocked: bool = bool(pad.get("overclocked", false))
	pad["overclocked"] = false
	pad["active_user"] = null
	pad["reserved_by"] = null
	pad["cooldown"] = C.PAD_COOLDOWN

	record_pad_interaction(pad, resident.resident_name, "worked")

	var task_t: String = String(pad.get("task_type", ""))
	if task_t == "clinic":
		if resident.has_method("recover_full_stamina"):
			resident.recover_full_stamina()
		else:
			resident.stamina = resident.max_stamina
		if game_manager != null:
			game_manager.log_event("%s recovered stamina at Town Clinic." % resident.resident_name, Color(0.55, 0.98, 0.72))
		return "%s received care at Town Clinic (+100%% Stamina)" % resident.resident_name

	if game_manager != null:
		if task_t == "generator" or task_t == "generator_objective":
			if game_manager.current_phase == game_manager.Phase.FINALE and game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION:
				pad["cooldown"] = 1.0
				game_manager.record_generator_tug(resident)
				return "%s channeled Buried Generator (Tug-of-War)!" % resident.resident_name
			return game_manager.execute_task("generator_objective", resident.resident_name, is_player, was_overclocked)
		elif task_t == "beacon" or task_t == "beacon_objective":
			return game_manager.execute_task("beacon_objective", resident.resident_name, is_player, was_overclocked)
		else:
			var res_msg: String = game_manager.execute_task(task_t, resident.resident_name, is_player, was_overclocked)
			if resident != null:
				var passive_id: String = String(resident.get("hero_passive_id")) if resident.get("hero_passive_id") != null else ""
				if task_t == "greenhouse" and passive_id == "seedbank_curator":
					game_manager.stability = minf(100.0, game_manager.stability + 2.0)
					game_manager.state_updated.emit()
					res_msg += " [+2% Seedbank Curator]"
				elif task_t == "salvage" and passive_id == "scavengers_eye":
					game_manager.scrap = mini(10, game_manager.scrap + 1)
					game_manager.state_updated.emit()
					res_msg += " [+1 Scavenger's Eye]"
			return res_msg
	return ""

func release_reservations_for(resident: Node) -> void:
	for pad in task_pads:
		if pad.get("active_user") == resident:
			pad["active_user"] = null
		if pad.get("reserved_by") == resident:
			pad["reserved_by"] = null

func reset_pads() -> void:
	for pad in task_pads:
		pad["cooldown"] = 0.0
		pad["jammed_timer"] = 0.0
		pad["overclocked"] = false
		pad["active_user"] = null
		pad["reserved_by"] = null
	active_zones.clear()

func record_pad_interaction(pad: Dictionary, user_name: String, action_type: String) -> void:
	pad["last_user_name"] = user_name
	pad["last_used_action"] = action_type
	if game_manager != null and game_manager.has_method("_match_clock_text"):
		pad["last_used_time_str"] = game_manager._match_clock_text()

func update_escalation_unlocks() -> void:
	if game_manager == null:
		return
	var in_escalation: bool = (game_manager.current_phase == game_manager.Phase.ESCALATION or game_manager.current_phase == game_manager.Phase.FINALE)
	if not in_escalation:
		return

	for pad in task_pads:
		if pad["id"] == "generator" and pad.get("is_locked", false):
			pad["is_locked"] = false
			pad["name"] = "Overdrive Generator"
			if pad.get("label_node") != null:
				pad["label_node"].text = "Overdrive Generator\n[Hold E to Prime/Damper]"
				pad["label_node"].modulate = Color(1.0, 0.85, 0.40)
			if pad.get("mat") != null:
				pad["mat"].albedo_color = Color(0.95, 0.75, 0.30, 0.75)
				pad["mat"].emission_enabled = true
				pad["mat"].emission = Color(1.0, 0.80, 0.35)
				pad["mat"].emission_energy_multiplier = 1.3
			if pad.get("screen_mat") != null:
				pad["screen_mat"].albedo_color = Color(1.0, 0.85, 0.40)
				pad["screen_mat"].emission_enabled = true
				pad["screen_mat"].emission = Color(1.0, 0.85, 0.40)
				pad["screen_mat"].emission_energy_multiplier = 1.2
			if pad.get("dome_mat") != null:
				pad["dome_mat"].albedo_color = Color(1.0, 0.85, 0.40)
				pad["dome_mat"].emission_enabled = true
				pad["dome_mat"].emission = Color(1.0, 0.85, 0.40)
				pad["dome_mat"].emission_energy_multiplier = 1.5
			game_manager.log_event("Overdrive Generator unlocked for Escalation!", Color(1.0, 0.85, 0.35))

		elif pad["id"] == "beacon" and pad.get("is_locked", false):
			pad["is_locked"] = false
			pad["name"] = "Signal Beacon"
			if pad.get("label_node") != null:
				pad["label_node"].text = "Signal Beacon\n[Hold E to Tune Frequency]"
				pad["label_node"].modulate = Color(0.45, 0.85, 1.0)
			if pad.get("mat") != null:
				pad["mat"].albedo_color = Color(0.35, 0.75, 1.0, 0.75)
				pad["mat"].emission_enabled = true
				pad["mat"].emission = Color(0.40, 0.85, 1.0)
				pad["mat"].emission_energy_multiplier = 1.3
			if pad.get("screen_mat") != null:
				pad["screen_mat"].albedo_color = Color(0.45, 0.85, 1.0)
				pad["screen_mat"].emission_enabled = true
				pad["screen_mat"].emission = Color(0.45, 0.85, 1.0)
				pad["screen_mat"].emission_energy_multiplier = 1.2
			if pad.get("dome_mat") != null:
				pad["dome_mat"].albedo_color = Color(0.45, 0.85, 1.0)
				pad["dome_mat"].emission_enabled = true
				pad["dome_mat"].emission = Color(0.45, 0.85, 1.0)
				pad["dome_mat"].emission_energy_multiplier = 1.5
			game_manager.log_event("Signal Beacon unlocked for Escalation!", Color(0.45, 0.85, 1.0))

# ------------------------------------------------------------------------------
# 9. Secluded Bedrock Alcove Inspection API
# ------------------------------------------------------------------------------
func get_nearest_alcove(pos: Vector3, max_dist: float = 3.8) -> Dictionary:
	var best_alc: Dictionary = {}
	var best_dist: float = max_dist
	for alc in secret_alcoves:
		var a_pos: Vector3 = alc["pos"]
		var d: float = pos.distance_to(a_pos)
		if d <= 3.2 and d < best_dist:
			best_dist = d
			best_alc = alc
	return best_alc

func complete_site_inspection(resident: Node, alcove: Dictionary) -> Dictionary:
	if resident == null or alcove.is_empty() or game_manager == null:
		return {}

	var region_name: String = String(alcove.get("region", "Town Corridors"))
	var is_active: bool = bool(alcove.get("is_active", false)) or (game_manager.archive_active_spawn_id == String(alcove["id"]))

	if is_active:
		if not game_manager.archive_opened:
			var res_entry: Dictionary = game_manager.open_archive(resident, alcove)
			spawn_field_zone_3d("disturbance_ring", alcove["pos"], 2.8, 10.0, 0, region_name)
			return res_entry
		else:
			var stamp: String = game_manager.archive_open_time
			var trace_txt: String = "Old-World Archive accessed and failsafe key extracted at %s." % stamp
			return game_manager.add_private_trace(int(resident.resident_id), trace_txt, region_name, stamp)
	else:
		var stamp: String = game_manager._match_clock_text() if game_manager.has_method("_match_clock_text") else "04:00"
		var trace_txt: String = "Weathered bedrock alcove inspected at %s. No pre-collapse cache present." % stamp
		var cache_entry: Dictionary = game_manager.add_private_trace(int(resident.resident_id), trace_txt, region_name, stamp)
		spawn_field_zone_3d("scent_scan", alcove["pos"], 2.2, 5.0, resident.resident_id)
		return cache_entry

# ------------------------------------------------------------------------------
# 10. Frame Process
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Tick down pad timers & refresh labels
	for pad in task_pads:
		if pad.get("cooldown", 0.0) > 0.0:
			pad["cooldown"] = maxf(0.0, float(pad["cooldown"]) - delta)
		if pad.get("jammed_timer", 0.0) > 0.0:
			pad["jammed_timer"] = maxf(0.0, float(pad["jammed_timer"]) - delta)

		var lbl: Label3D = pad.get("label_node")
		if lbl != null:
			var base: String = String(pad.get("base_title", pad.get("name", "")))
			if pad.get("is_locked", false):
				lbl.text = "%s\n[Locked until Escalation]" % base
			elif float(pad.get("jammed_timer", 0.0)) > 0.0:
				lbl.text = "%s\n[JAMMED: %.1fs]" % [base, float(pad["jammed_timer"])]
				lbl.modulate = Color(1.0, 0.45, 0.35)
			elif float(pad.get("cooldown", 0.0)) > 0.0:
				lbl.text = "%s\n[Cooling: %.1fs]" % [base, float(pad["cooldown"])]
				lbl.modulate = Color(0.85, 0.75, 0.50)
			elif bool(pad.get("overclocked", false)):
				lbl.text = "%s\n[OVERCLOCKED +50%% - Hold E]" % base
				lbl.modulate = Color(0.40, 0.95, 1.0)
			else:
				lbl.text = "%s\n[Hold E to Channel]" % base
				lbl.modulate = pad.get("color", Color.WHITE)

	# Tick down active zones
	for z in active_zones:
		z["time_left"] = maxf(0.0, float(z.get("time_left", 0.0)) - delta)
	active_zones = active_zones.filter(func(z): return float(z.get("time_left", 0.0)) > 0.0)

	# Dynamic Beacon & Coil Lighting Animation
	anim_timer += delta
	if beacon_light_node != null:
		var pulse: float = (sin(anim_timer * 3.5) + 1.0) * 0.5
		beacon_light_node.light_energy = 0.8 + pulse * 1.4
	if turbine_light_node != null:
		var coil_hum: float = (sin(anim_timer * 8.0) + 1.0) * 0.5
		turbine_light_node.light_energy = 1.05 + coil_hum * 0.35

	update_escalation_unlocks()

