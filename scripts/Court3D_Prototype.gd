extends Node3D

# ==============================================================================
# The Gray Synthesis - Standalone 3D Court Scene Prototype
# ==============================================================================
# Demonstrates 3D spatial presence, atmospheric dusk lighting, faction-neutral
# character silhouettes, sequential podium walk-ups, speech bubbles, and live tally.
# 100% standalone courtroom prototype with no dependency on the main match flow.
# ==============================================================================

enum CamMode { DIRECTOR, TOP_DOWN, FREE_ORBIT }
var current_cam_mode: CamMode = CamMode.DIRECTOR

# Node references
var camera: Camera3D
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var podium_spotlight: SpotLight3D
var town_beacon_light: OmniLight3D
var ui_layer: CanvasLayer

# Environment elements
var podium_node: Node3D
var council_ring_node: Node3D
var buildings_node: Node3D
var residents_node: Node3D
var tally_board_3d: Node3D
var terminal_mesh: MeshInstance3D
var terminal_mat: StandardMaterial3D

# Residents data (10 residents)
var resident_nodes: Array[Node3D] = []
var resident_data: Array[Dictionary] = [
	# 4 Unaffiliated Civilians (The Voters)
	{ "id": 1, "name": "Voter 1 (Kael)", "job": "Pump Technician", "tool": "pipe_wrench", "role": "civilian", "seat_idx": 0 },
	{ "id": 2, "name": "Voter 2 (Mara)", "job": "Crop Tender", "tool": "sickle", "role": "civilian", "seat_idx": 1 },
	{ "id": 3, "name": "Voter 3 (Theron)", "job": "Salvage Quartermaster", "tool": "scrap_pack", "role": "civilian", "seat_idx": 2 },
	{ "id": 4, "name": "Voter 4 (Lyra)", "job": "Field Medic", "tool": "med_satchel", "role": "civilian", "seat_idx": 3 },
	# 3 Ecology Operatives (Secretly hidden in assembly)
	{ "id": 5, "name": "Resident 5 (Bram)", "job": "Crop Tender", "tool": "sickle", "role": "ecology", "seat_idx": 4 },
	{ "id": 6, "name": "Resident 6 (Soren)", "job": "Pump Technician", "tool": "pipe_wrench", "role": "ecology", "seat_idx": 5 },
	{ "id": 7, "name": "Resident 7 (Ansel)", "job": "Town Watch", "tool": "baton", "role": "ecology", "seat_idx": 6 },
	# 3 Technology Operatives (Secretly hidden in assembly)
	{ "id": 8, "name": "Resident 8 (Vance)", "job": "Salvage Quartermaster", "tool": "scrap_pack", "role": "technology", "seat_idx": 7 },
	{ "id": 9, "name": "Resident 9 (Cora)", "job": "Pump Technician", "tool": "pipe_wrench", "role": "technology", "seat_idx": 8 },
	{ "id": 10, "name": "Resident 10 (Dorian)", "job": "Field Medic", "tool": "med_satchel", "role": "technology", "seat_idx": 9 }
]

# Scripted Scenarios
var scenarios: Dictionary = {
	1: {
		"title": "PRESET 1: 3-1 SPLIT (6-4 ALIGNMENT -> WAR-OR-PEACE)",
		"votes": [
			{ "vote": "Ecology", "quote": "The aquifer is near depletion (20% Water). We cannot risk overloading the soil and crops." },
			{ "vote": "Ecology", "quote": "Preserving the soil and water balance must come before aggressive machine restarts." },
			{ "vote": "Technology", "quote": "Our grid is fracturing (20% Stability). Without machine power, our filters and heat will fail." },
			{ "vote": "Ecology", "quote": "Without clean water, the clinic cannot stop the fever. Ecology has my vote." }
		],
		"verdict": "COURT SPLIT 3-1 -> Alignment: 6 Ecology vs 4 Technology\nProceeding to Strategic War-or-Peace Deliberation!"
	},
	2: {
		"title": "PRESET 2: 4-0 UNANIMOUS MANDATE (ECOLOGY VICTORY)",
		"votes": [
			{ "vote": "Ecology", "quote": "The aquifer is near depletion (20% Water). Conservation is our immediate need." },
			{ "vote": "Ecology", "quote": "Preserving soil balance must come before machine restarts." },
			{ "vote": "Ecology", "quote": "Even with machine needs, without water the town dies. I yield to the aquifer." },
			{ "vote": "Ecology", "quote": "Unanimous consensus. We commit the settlement to biosphere preservation." }
		],
		"verdict": "UNANIMOUS 4-0 MANDATE: ECOLOGY VICTORY!\nTown Mandate Granted — Skips Finale!"
	},
	3: {
		"title": "PRESET 3: 4-0 UNANIMOUS MANDATE (TECHNOLOGY VICTORY)",
		"votes": [
			{ "vote": "Technology", "quote": "The pumps cannot run without generator power. We must restore the grid." },
			{ "vote": "Technology", "quote": "Hydroponic heaters are failing. We need electrical voltage immediately." },
			{ "vote": "Technology", "quote": "The old machinery is our only hope for long-term recovery and survival." },
			{ "vote": "Technology", "quote": "Automated medical synthesis requires high-power current. I back Technology." }
		],
		"verdict": "UNANIMOUS 4-0 MANDATE: TECHNOLOGY VICTORY!\nTown Mandate Granted — Skips Finale!"
	},
	4: {
		"title": "PRESET 4: 2-2 EVEN SPLIT (5-5 BALANCED ALIGNMENT)",
		"votes": [
			{ "vote": "Ecology", "quote": "Water reserves are falling behind. Aquifer conservation is priority one." },
			{ "vote": "Technology", "quote": "Town infrastructure is strained. Restoring power is our best hope." },
			{ "vote": "Ecology", "quote": "We cannot sacrifice our food crops for unproven machinery." },
			{ "vote": "Technology", "quote": "Without the generator, next winter will finish this settlement. Technology." }
		],
		"verdict": "COURT DEADLOCK 2-2 -> Balanced 5-5 Standoff\nMaximum tension entering Strategic Deliberation!"
	}
}

var current_scenario_id: int = 1
var is_ceremony_running: bool = false
var current_step_index: int = 0
var step_timer: float = 0.0
var step_state: String = "idle" # "walking_to_podium", "speaking", "walking_back", "finished"

var active_voter_node: Node3D = null
var active_voter_seat_pos: Vector3 = Vector3.ZERO
var active_voter_seat_rot: float = 0.0
var podium_speaker_pos: Vector3 = Vector3(0.0, 0.45, 1.3)

var recorded_votes: Array[Dictionary] = []
var show_inspector_overlay: bool = false

# Orbit camera state
var orbit_yaw: float = 0.0
var orbit_pitch: float = -0.45
var orbit_dist: float = 18.0
var is_orbiting: bool = false
var _is_initialized: bool = false

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_setup_lighting_and_environment()
	_build_town_square_architecture()
	_build_council_ring_and_podium()
	_spawn_10_residents()
	_setup_camera()
	_setup_ui_overlay()
	start_scenario(1)

func _process(delta: float) -> void:
	_update_ceremony_step(delta)
	_update_camera(delta)
	_update_beacon_pulse(delta)

# ------------------------------------------------------------------------------
# Lighting & Atmospheric Environment
# ------------------------------------------------------------------------------
func _setup_lighting_and_environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.15, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.36, 0.40)
	env.ambient_light_energy = 0.85

	# Volumetric fog / atmospheric dust
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.85, 0.72, 0.60)
	env.volumetric_fog_emission = Color(0.15, 0.12, 0.10)

	# Bloom / Glow
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Tonemap
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05

	world_env.environment = env
	add_child(world_env)

	# Low-angle warm amber dusk sun casting long dramatic shadows
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-24.0, 48.0, 0.0)
	sun_light.light_color = Color(1.0, 0.78, 0.52)
	sun_light.light_energy = 1.8
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.03
	add_child(sun_light)

	# Central podium dramatic spotlight (fades in on speaker)
	podium_spotlight = SpotLight3D.new()
	podium_spotlight.position = Vector3(0.0, 7.5, 1.3)
	podium_spotlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	podium_spotlight.spot_angle = 28.0
	podium_spotlight.spot_attenuation = 1.2
	podium_spotlight.light_color = Color(1.0, 0.95, 0.80)
	podium_spotlight.light_energy = 0.0 # Starts off, fades up during speeches
	podium_spotlight.shadow_enabled = true
	add_child(podium_spotlight)

	# Emergency Beacon pulsing omni-light
	town_beacon_light = OmniLight3D.new()
	town_beacon_light.position = Vector3(0.0, 8.5, -3.5)
	town_beacon_light.omni_range = 14.0
	town_beacon_light.light_color = Color(0.40, 0.85, 1.0)
	town_beacon_light.light_energy = 1.2
	add_child(town_beacon_light)

# ------------------------------------------------------------------------------
# Town Square Architecture & Blockouts
# ------------------------------------------------------------------------------
func _build_town_square_architecture() -> void:
	buildings_node = Node3D.new()
	buildings_node.name = "Buildings"
	add_child(buildings_node)

	# Ground Plane: Cobblestone & Dust Wasteland
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(90.0, 90.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.20, 0.18, 0.16)
	ground_mat.roughness = 0.92
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = ground_mat
	buildings_node.add_child(ground)

	# Inner Plaza Ring Pavement (Darker cobblestones)
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 16.0
	plaza_mesh.bottom_radius = 16.0
	plaza_mesh.height = 0.1
	var plaza_mat := StandardMaterial3D.new()
	plaza_mat.albedo_color = Color(0.14, 0.15, 0.18)
	plaza_mat.roughness = 0.88
	var plaza := MeshInstance3D.new()
	plaza.mesh = plaza_mesh
	plaza.material_override = plaza_mat
	plaza.position = Vector3(0.0, 0.05, 0.0)
	buildings_node.add_child(plaza)

	# North: Common Works Facade (Brutalist concrete base, rusted iron truss)
	_build_blockout_building(
		Vector3(0.0, 6.0, -16.5), Vector3(26.0, 12.0, 8.0),
		Color(0.25, 0.23, 0.28), "COMMON WORKS", Color(0.85, 0.75, 1.0)
	)
	# Common works industrial pipe conduits
	for px in [-8.0, -4.0, 4.0, 8.0]:
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.55
		pipe.bottom_radius = 0.55
		pipe.height = 13.0
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.35, 0.28, 0.22)
		p_mat.metallic = 0.7
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = pipe
		p_inst.material_override = p_mat
		p_inst.position = Vector3(px, 6.0, -12.4)
		buildings_node.add_child(p_inst)

	# West: Greenhouse & Fields (Weathered wood frame, glowing green glass)
	_build_blockout_building(
		Vector3(-22.0, 4.5, 0.0), Vector3(8.0, 9.0, 22.0),
		Color(0.18, 0.22, 0.19), "GREENHOUSE & HYDROPONICS", Color(0.55, 0.95, 0.65)
	)
	# Glowing interior hydroponic pane
	var gh_light := OmniLight3D.new()
	gh_light.position = Vector3(-17.5, 3.5, 0.0)
	gh_light.light_color = Color(0.35, 0.95, 0.55)
	gh_light.light_energy = 2.2
	gh_light.omni_range = 9.0
	buildings_node.add_child(gh_light)

	# East: Salvage Yard & Gantry Bay (Corrugated rust, steel scaffold)
	_build_blockout_building(
		Vector3(22.0, 5.0, 0.0), Vector3(8.0, 10.0, 22.0),
		Color(0.28, 0.20, 0.16), "SALVAGE DEPOT & GANTRY", Color(0.95, 0.70, 0.45)
	)
	var scrap_light := OmniLight3D.new()
	scrap_light.position = Vector3(17.5, 3.5, 0.0)
	scrap_light.light_color = Color(0.98, 0.65, 0.35)
	scrap_light.light_energy = 1.8
	scrap_light.omni_range = 8.0
	buildings_node.add_child(scrap_light)

	# South: Pump Station & Intake Basin
	_build_blockout_building(
		Vector3(0.0, 4.0, 18.0), Vector3(24.0, 8.0, 7.0),
		Color(0.16, 0.22, 0.28), "PUMP & TURBINE STATION", Color(0.45, 0.85, 1.0)
	)

	# Central Beacon Mast
	var mast := CylinderMesh.new()
	mast.top_radius = 0.25
	mast.bottom_radius = 0.35
	mast.height = 9.0
	var m_mat := StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.32, 0.35, 0.40)
	m_mat.metallic = 0.8
	var mast_inst := MeshInstance3D.new()
	mast_inst.mesh = mast
	mast_inst.material_override = m_mat
	mast_inst.position = Vector3(0.0, 4.5, -3.5)
	buildings_node.add_child(mast_inst)

	# Central Beacon Globe (emissive)
	var globe := SphereMesh.new()
	globe.radius = 0.65
	globe.height = 1.3
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.45, 0.85, 1.0)
	g_mat.emission_enabled = true
	g_mat.emission = Color(0.40, 0.85, 1.0)
	g_mat.emission_energy_multiplier = 3.5
	var globe_inst := MeshInstance3D.new()
	globe_inst.mesh = globe
	globe_inst.material_override = g_mat
	globe_inst.position = Vector3(0.0, 8.8, -3.5)
	buildings_node.add_child(globe_inst)

	# Braziers (flickering flame barrels)
	_spawn_brazier(Vector3(-7.5, 0.0, -5.0))
	_spawn_brazier(Vector3(7.5, 0.0, -5.0))
	_spawn_brazier(Vector3(-7.5, 0.0, 6.0))
	_spawn_brazier(Vector3(7.5, 0.0, 6.0))

func _build_blockout_building(pos: Vector3, size: Vector3, col: Color, label_text: String, label_col: Color) -> void:
	var b_mesh := BoxMesh.new()
	b_mesh.size = size
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.85

	var inst := MeshInstance3D.new()
	inst.mesh = b_mesh
	inst.material_override = b_mat
	inst.position = pos
	buildings_node.add_child(inst)

	# Architectural Label on facade
	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 32
	lbl.modulate = label_col
	lbl.outline_render_priority = 1
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.outline_size = 4
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.position = pos + Vector3(0.0, size.y * 0.5 + 1.2, 0.0)
	buildings_node.add_child(lbl)

func _spawn_brazier(pos: Vector3) -> void:
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.55
	barrel.bottom_radius = 0.50
	barrel.height = 1.0
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.24, 0.20, 0.18)
	b_mat.metallic = 0.5
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = barrel
	b_inst.material_override = b_mat
	b_inst.position = pos + Vector3(0.0, 0.5, 0.0)
	buildings_node.add_child(b_inst)

	var flame := OmniLight3D.new()
	flame.position = pos + Vector3(0.0, 1.2, 0.0)
	flame.light_color = Color(1.0, 0.65, 0.28)
	flame.light_energy = 1.4
	flame.omni_range = 5.5
	buildings_node.add_child(flame)

# ------------------------------------------------------------------------------
# Council Ring Dais & Central Speaker Podium
# ------------------------------------------------------------------------------
func _build_council_ring_and_podium() -> void:
	council_ring_node = Node3D.new()
	council_ring_node.name = "CouncilRing"
	add_child(council_ring_node)

	# Raised Stone Council Dais (Circular Platform)
	var dais_mesh := CylinderMesh.new()
	dais_mesh.top_radius = 7.5
	dais_mesh.bottom_radius = 7.8
	dais_mesh.height = 0.35
	var dais_mat := StandardMaterial3D.new()
	dais_mat.albedo_color = Color(0.22, 0.24, 0.28)
	dais_mat.roughness = 0.85
	var dais := MeshInstance3D.new()
	dais.mesh = dais_mesh
	dais.material_override = dais_mat
	dais.position = Vector3(0.0, 0.175, 0.0)
	council_ring_node.add_child(dais)

	# Outer Ring Stone Benches (Semi-circle where the 10 residents assemble)
	var bench_radius := 5.8
	for i in range(10):
		var angle := PI * 0.15 + (float(i) / 9.0) * (PI * 1.7) # Arc wrapping around
		var bx := cos(angle) * bench_radius
		var bz := sin(angle) * bench_radius

		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(1.1, 0.45, 0.55)
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.32, 0.30, 0.28)
		var b_inst := MeshInstance3D.new()
		b_inst.mesh = b_mesh
		b_inst.material_override = b_mat
		b_inst.position = Vector3(bx, 0.42, bz)
		b_inst.rotation.y = -angle + PI * 0.5
		council_ring_node.add_child(b_inst)

	# Central Speaker Podium (Where civilians step up to vote)
	podium_node = Node3D.new()
	podium_node.name = "Podium"
	podium_node.position = Vector3(0.0, 0.35, 1.3)
	council_ring_node.add_child(podium_node)

	# Podium Base & Rostrum Steps
	var p_base := CylinderMesh.new()
	p_base.top_radius = 1.35
	p_base.bottom_radius = 1.55
	p_base.height = 0.3
	var pb_mat := StandardMaterial3D.new()
	pb_mat.albedo_color = Color(0.18, 0.20, 0.25)
	var pb_inst := MeshInstance3D.new()
	pb_inst.mesh = p_base
	pb_inst.material_override = pb_mat
	pb_inst.position = Vector3(0.0, 0.15, 0.0)
	podium_node.add_child(pb_inst)

	# Speaker Lectern / Voting Console
	var lectern := BoxMesh.new()
	lectern.size = Vector3(0.85, 1.15, 0.55)
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.28, 0.32, 0.38)
	l_mat.metallic = 0.6
	var l_inst := MeshInstance3D.new()
	l_inst.mesh = lectern
	l_inst.material_override = l_mat
	l_inst.position = Vector3(0.0, 0.75, -0.45)
	podium_node.add_child(l_inst)

	# Voting Terminal Screen (Glows Green for Eco, Cyan for Tech)
	var term := BoxMesh.new()
	term.size = Vector3(0.65, 0.15, 0.35)
	terminal_mat = StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.70, 0.75, 0.85)
	terminal_mat.emission_enabled = true
	terminal_mat.emission = Color(0.70, 0.80, 0.95)
	terminal_mat.emission_energy_multiplier = 1.2
	terminal_mesh = MeshInstance3D.new()
	terminal_mesh.mesh = term
	terminal_mesh.material_override = terminal_mat
	terminal_mesh.position = Vector3(0.0, 1.35, -0.42)
	terminal_mesh.rotation_degrees.x = -25.0
	podium_node.add_child(terminal_mesh)

	# 3D Live Tally Monolith (Positioned near the podium base)
	_build_3d_tally_monolith()

func _build_3d_tally_monolith() -> void:
	tally_board_3d = Node3D.new()
	tally_board_3d.position = Vector3(0.0, 2.4, -1.8)
	council_ring_node.add_child(tally_board_3d)

	var board := BoxMesh.new()
	board.size = Vector3(3.2, 1.1, 0.25)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.12, 0.14, 0.18)
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = board
	b_inst.material_override = b_mat
	tally_board_3d.add_child(b_inst)

	var tally_lbl := Label3D.new()
	tally_lbl.name = "TallyText"
	tally_lbl.text = "CIVILIAN COURT RUNNING TALLY\n0 ECOLOGY   |   0 TECHNOLOGY"
	tally_lbl.font_size = 28
	tally_lbl.modulate = Color(1.0, 0.90, 0.65)
	tally_lbl.position = Vector3(0.0, 0.05, 0.15)
	tally_board_3d.add_child(tally_lbl)

# ------------------------------------------------------------------------------
# 10 Recognizable 3D Residents (Faction-Neutral Survivor Workwear)
# ------------------------------------------------------------------------------
func _spawn_10_residents() -> void:
	residents_node = Node3D.new()
	residents_node.name = "Residents"
	add_child(residents_node)

	var bench_radius := 5.8
	for i in range(resident_data.size()):
		var data: Dictionary = resident_data[i]
		var seat_idx: int = data["seat_idx"]
		var angle := PI * 0.15 + (float(seat_idx) / 9.0) * (PI * 1.7)
		var sx := cos(angle) * bench_radius
		var sz := sin(angle) * bench_radius

		var res_root := Node3D.new()
		res_root.name = "Resident_%d" % data["id"]
		res_root.position = Vector3(sx, 0.35, sz)
		# Face towards the center podium
		res_root.rotation.y = atan2(-sx, -sz)
		residents_node.add_child(res_root)

		# Save seat position & rotation for walking back
		data["seat_pos"] = res_root.position
		data["seat_rot_y"] = res_root.rotation.y

		_build_stylized_character_mesh(res_root, data)
		resident_nodes.append(res_root)

func _build_stylized_character_mesh(parent: Node3D, data: Dictionary) -> void:
	# Faction-neutral clothing palettes: Weathered canvas, dusty tan, faded slate, oil-stained brown
	var coat_colors: Array[Color] = [
		Color(0.38, 0.34, 0.30), # Weathered khaki tan
		Color(0.28, 0.32, 0.36), # Faded slate gray
		Color(0.35, 0.28, 0.22), # Workwear brown
		Color(0.24, 0.26, 0.28), # Charcoal canvas
		Color(0.42, 0.38, 0.32)  # Dust tan
	]
	var coat_col: Color = coat_colors[data["id"] % coat_colors.size()]

	# Torso / Greatcoat
	var torso := CapsuleMesh.new()
	torso.radius = 0.35
	torso.height = 1.15
	var torso_mat := StandardMaterial3D.new()
	torso_mat.albedo_color = coat_col
	torso_mat.roughness = 0.85
	var t_inst := MeshInstance3D.new()
	t_inst.name = "Torso"
	t_inst.mesh = torso
	t_inst.material_override = torso_mat
	t_inst.position = Vector3(0.0, 0.95, 0.0)
	parent.add_child(t_inst)

	# Head / Cowl
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.52
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.72, 0.62, 0.54) # Weathered skin / cowl
	var h_inst := MeshInstance3D.new()
	h_inst.name = "Head"
	h_inst.mesh = head
	h_inst.material_override = head_mat
	h_inst.position = Vector3(0.0, 1.68, 0.0)
	parent.add_child(h_inst)

	# Workwear Belt / Utility Rig
	var belt := BoxMesh.new()
	belt.size = Vector3(0.74, 0.16, 0.48)
	var belt_mat := StandardMaterial3D.new()
	belt_mat.albedo_color = Color(0.18, 0.14, 0.11)
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = belt
	b_inst.material_override = belt_mat
	b_inst.position = Vector3(0.0, 0.72, 0.0)
	parent.add_child(b_inst)

	# Public Civic Tool Silhouette (Distinguishes public job without revealing faction!)
	_attach_civic_tool_prop(parent, data["tool"])

	# Identity Label (Public name and civic job)
	var name_lbl := Label3D.new()
	name_lbl.name = "NameLabel"
	var is_civ: bool = (data["role"] == "civilian")
	var role_tag := "CIVILIAN VOTER" if is_civ else "TOWN RESIDENT"
	name_lbl.text = "%s\n[%s • %s]" % [data["name"], data["job"], role_tag]
	name_lbl.font_size = 20
	name_lbl.modulate = Color(1.0, 0.95, 0.75) if is_civ else Color(0.85, 0.88, 0.92)
	name_lbl.outline_size = 3
	name_lbl.outline_modulate = Color(0, 0, 0, 0.9)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	name_lbl.position = Vector3(0.0, 2.25, 0.0)
	parent.add_child(name_lbl)

	# 3D Speech Bubble (Appears when active voter speaks at podium)
	var speech_bubble := Label3D.new()
	speech_bubble.name = "SpeechBubble"
	speech_bubble.text = ""
	speech_bubble.font_size = 24
	speech_bubble.modulate = Color(1.0, 1.0, 1.0)
	speech_bubble.outline_size = 4
	speech_bubble.outline_modulate = Color(0.1, 0.1, 0.15, 0.95)
	speech_bubble.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	speech_bubble.position = Vector3(0.0, 2.75, 0.0)
	speech_bubble.visible = false
	parent.add_child(speech_bubble)

	# Secret Faction Aura Ring (Hidden by default, toggled via [Tab] for dev inspection)
	var aura := CylinderMesh.new()
	aura.top_radius = 0.65
	aura.bottom_radius = 0.65
	aura.height = 0.08
	var aura_mat := StandardMaterial3D.new()
	var role_col: Color = Color(0.45, 0.92, 0.58) if data["role"] == "ecology" else (Color(0.42, 0.82, 0.98) if data["role"] == "technology" else Color(0.95, 0.95, 0.95))
	aura_mat.albedo_color = role_col
	aura_mat.emission_enabled = true
	aura_mat.emission = role_col
	aura_mat.emission_energy_multiplier = 2.0
	var a_inst := MeshInstance3D.new()
	a_inst.name = "InspectorAura"
	a_inst.mesh = aura
	a_inst.material_override = aura_mat
	a_inst.position = Vector3(0.0, 0.05, 0.0)
	a_inst.visible = false # Hidden to preserve secrecy!
	parent.add_child(a_inst)

func _attach_civic_tool_prop(parent: Node3D, tool_type: String) -> void:
	match tool_type:
		"pipe_wrench": # Pump Technician
			var wrench := BoxMesh.new()
			wrench.size = Vector3(0.12, 0.85, 0.18)
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.55, 0.60, 0.68)
			w_mat.metallic = 0.85
			var w_inst := MeshInstance3D.new()
			w_inst.mesh = wrench
			w_inst.material_override = w_mat
			w_inst.position = Vector3(0.28, 1.1, -0.32)
			w_inst.rotation_degrees = Vector3(25.0, 15.0, -20.0)
			parent.add_child(w_inst)
		"sickle": # Crop Tender
			var handle := CylinderMesh.new()
			handle.top_radius = 0.04
			handle.bottom_radius = 0.04
			handle.height = 0.45
			var h_mat := StandardMaterial3D.new()
			h_mat.albedo_color = Color(0.42, 0.32, 0.22)
			var h_inst := MeshInstance3D.new()
			h_inst.mesh = handle
			h_inst.material_override = h_mat
			h_inst.position = Vector3(0.38, 0.75, 0.12)
			h_inst.rotation_degrees.z = 45.0
			parent.add_child(h_inst)
		"scrap_pack": # Salvage Quartermaster
			var pack := BoxMesh.new()
			pack.size = Vector3(0.55, 0.65, 0.38)
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.35, 0.28, 0.24)
			p_mat.metallic = 0.4
			var p_inst := MeshInstance3D.new()
			p_inst.mesh = pack
			p_inst.material_override = p_mat
			p_inst.position = Vector3(0.0, 1.05, -0.38)
			parent.add_child(p_inst)
		"med_satchel": # Field Medic
			var satchel := BoxMesh.new()
			satchel.size = Vector3(0.36, 0.38, 0.22)
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color(0.85, 0.85, 0.82)
			var s_inst := MeshInstance3D.new()
			s_inst.mesh = satchel
			s_inst.material_override = s_mat
			s_inst.position = Vector3(-0.42, 0.65, 0.08)
			parent.add_child(s_inst)
		"baton": # Town Watch
			var baton := CylinderMesh.new()
			baton.top_radius = 0.05
			baton.bottom_radius = 0.05
			baton.height = 0.75
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.22, 0.25, 0.30)
			var b_inst := MeshInstance3D.new()
			b_inst.mesh = baton
			b_inst.material_override = b_mat
			b_inst.position = Vector3(0.40, 0.85, 0.0)
			b_inst.rotation_degrees.x = 15.0
			parent.add_child(b_inst)

# ------------------------------------------------------------------------------
# Camera Setup & Modes
# ------------------------------------------------------------------------------
func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	_apply_director_camera_view("wide")

func _apply_director_camera_view(view_type: String) -> void:
	var target_pos: Vector3 = Vector3.ZERO
	var target_look: Vector3 = Vector3.ZERO

	match view_type:
		"wide": # Master shot of full assembly
			target_pos = Vector3(0.0, 9.5, 15.0)
			target_look = Vector3(0.0, 1.5, 0.5)
		"podium": # Medium-close dramatic framing of the speaker at the rostrum
			target_pos = Vector3(0.0, 2.6, 5.2)
			target_look = Vector3(0.0, 1.5, 1.3)
		"tight_pivotal": # Tense close-up for the pivotal 4th vote
			target_pos = Vector3(0.0, 2.2, 4.0)
			target_look = Vector3(0.0, 1.6, 1.3)
		"verdict": # Pull-back celebratory/tense wide angle
			target_pos = Vector3(0.0, 8.0, 13.5)
			target_look = Vector3(0.0, 1.8, 0.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(camera, "position", target_pos, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Smoothly orient camera to look at target
	var cur_rot := camera.rotation
	camera.look_at_from_position(target_pos, target_look, Vector3.UP)
	var final_rot := camera.rotation
	camera.rotation = cur_rot
	tw.tween_property(camera, "rotation", final_rot, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_camera(delta: float) -> void:
	if current_cam_mode == CamMode.TOP_DOWN:
		camera.position = camera.position.lerp(Vector3(0.0, 16.5, 12.0), delta * 4.0)
		camera.look_at_from_position(camera.position, Vector3(0.0, 0.5, 1.0), Vector3.UP)
	elif current_cam_mode == CamMode.FREE_ORBIT:
		var cx := cos(orbit_yaw) * cos(orbit_pitch) * orbit_dist
		var cy := -sin(orbit_pitch) * orbit_dist
		var cz := sin(orbit_yaw) * cos(orbit_pitch) * orbit_dist
		camera.position = Vector3(cx, cy, cz)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.2, 0.0), Vector3.UP)

func _update_beacon_pulse(delta: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0035)
	if town_beacon_light != null:
		town_beacon_light.light_energy = 0.8 + 0.9 * pulse

# ------------------------------------------------------------------------------
# UI Overlay & HUD
# ------------------------------------------------------------------------------
func _setup_ui_overlay() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var control := Control.new()
	control.name = "HUDControl"
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(control)

	# Top Header Banner
	var top_panel := Panel.new()
	top_panel.name = "TopBanner"
	top_panel.position = Vector2(24, 20)
	top_panel.size = Vector2(1392, 70)
	control.add_child(top_panel)

	var title_lbl := Label.new()
	title_lbl.name = "HeaderLabel"
	title_lbl.text = "THE GRAY SYNTHESIS — 3D VISUAL COURT PROTOTYPE (MILESTONE 7/8 EXPLORATION)"
	title_lbl.position = Vector2(20, 12)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	top_panel.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.name = "SubLabel"
	sub_lbl.text = scenarios[current_scenario_id]["title"]
	sub_lbl.position = Vector2(20, 38)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	top_panel.add_child(sub_lbl)

	# Live Tally HUD Card (Top Right)
	var tally_card := Panel.new()
	tally_card.name = "TallyCard"
	tally_card.position = Vector2(980, 20)
	tally_card.size = Vector2(436, 70)
	control.add_child(tally_card)

	var tally_hud_lbl := Label.new()
	tally_hud_lbl.name = "TallyHUDLabel"
	tally_hud_lbl.text = "LIVE TALLY: 0 ECOLOGY  vs  0 TECHNOLOGY\nTurn 0 of 4  •  Awaiting First Civilian"
	tally_hud_lbl.position = Vector2(16, 14)
	tally_hud_lbl.add_theme_font_size_override("font_size", 14)
	tally_hud_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	tally_card.add_child(tally_hud_lbl)

	# Bottom Controls Hint Bar
	var bot_panel := Panel.new()
	bot_panel.name = "BottomBar"
	bot_panel.position = Vector2(24, 820)
	bot_panel.size = Vector2(1392, 60)
	control.add_child(bot_panel)

	var hint_lbl := Label.new()
	hint_lbl.name = "ControlsHint"
	hint_lbl.text = "[SPACE / ENTER] Step / Advance  •  [1-4] Switch Scripted Scenario  •  [C] Camera Mode: DIRECTOR  •  [TAB] Toggle Inspector Reveal  •  [R] Replay"
	hint_lbl.position = Vector2(20, 20)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	bot_panel.add_child(hint_lbl)

	# Verdict Center Modal (Hidden initially)
	var verdict_panel := Panel.new()
	verdict_panel.name = "VerdictModal"
	verdict_panel.position = Vector2(370, 320)
	verdict_panel.size = Vector2(700, 180)
	verdict_panel.visible = false
	control.add_child(verdict_panel)

	var v_text := Label.new()
	v_text.name = "VerdictText"
	v_text.text = ""
	v_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v_text.position = Vector2(20, 20)
	v_text.size = Vector2(660, 140)
	v_text.add_theme_font_size_override("font_size", 16)
	verdict_panel.add_child(v_text)

# ------------------------------------------------------------------------------
# Scripted Ceremony Progression
# ------------------------------------------------------------------------------
func start_scenario(scenario_id: int) -> void:
	current_scenario_id = scenario_id
	current_step_index = 0
	recorded_votes.clear()
	is_ceremony_running = true
	step_state = "idle"
	step_timer = 0.8

	# Reset all residents to seats
	for i in range(resident_nodes.size()):
		var r_node: Node3D = resident_nodes[i]
		var d: Dictionary = resident_data[i]
		r_node.position = d["seat_pos"]
		r_node.rotation.y = d["seat_rot_y"]
		var bubble: Label3D = r_node.get_node_or_null("SpeechBubble")
		if bubble != null:
			bubble.visible = false

	# Reset terminal light & spotlight
	if terminal_mat != null:
		terminal_mat.emission = Color(0.6, 0.7, 0.8)
	if podium_spotlight != null:
		podium_spotlight.light_energy = 0.0

	_apply_director_camera_view("wide")
	_update_tally_ui()

	var hud: Control = ui_layer.get_node("HUDControl")
	hud.get_node("VerdictModal").visible = false
	var sub_lbl: Label = hud.get_node("TopBanner/SubLabel")
	sub_lbl.text = scenarios[current_scenario_id]["title"]

func _update_ceremony_step(delta: float) -> void:
	if not is_ceremony_running:
		return

	step_timer -= delta
	if step_timer > 0.0:
		return

	match step_state:
		"idle":
			if current_step_index < 4:
				_begin_voter_turn(current_step_index)
			else:
				_resolve_final_verdict()
		"speaking":
			_finish_voter_speech()
		"walking_back":
			_finish_return_to_seat()

func _begin_voter_turn(voter_idx: int) -> void:
	step_state = "walking_to_podium"
	active_voter_node = resident_nodes[voter_idx]
	active_voter_seat_pos = resident_data[voter_idx]["seat_pos"]
	active_voter_seat_rot = resident_data[voter_idx]["seat_rot_y"]

	# Camera choreography
	if current_cam_mode == CamMode.DIRECTOR:
		if voter_idx == 3:
			_apply_director_camera_view("tight_pivotal")
		else:
			_apply_director_camera_view("podium")

	# Fade in podium spotlight
	var tw_spot := create_tween()
	tw_spot.tween_property(podium_spotlight, "light_energy", 2.2, 0.9)

	# Walk civilian smoothly to podium with vertical bobbing
	var tw_walk := create_tween()
	tw_walk.set_parallel(false)

	# Turn towards podium
	if active_voter_node.position.distance_squared_to(podium_speaker_pos) > 0.01:
		active_voter_node.look_at_from_position(active_voter_node.position, podium_speaker_pos, Vector3.UP)

	# Walk interpolation
	var walk_dur := 1.6
	tw_walk.tween_property(active_voter_node, "position", podium_speaker_pos, walk_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_walk.tween_callback(Callable(self, "_on_reached_podium").bind(voter_idx))

func _on_reached_podium(voter_idx: int) -> void:
	# Face the assembled crowd
	active_voter_node.rotation.y = 0.0 # Facing forward towards assembly
	step_state = "speaking"
	step_timer = 3.6 # Time to display speech & conviction

	var scen: Dictionary = scenarios[current_scenario_id]
	var v_info: Dictionary = scen["votes"][voter_idx]
	var vote_choice: String = v_info["vote"]
	var quote_text: String = v_info["quote"]

	# Show 3D Speech Bubble
	var bubble: Label3D = active_voter_node.get_node_or_null("SpeechBubble")
	if bubble != null:
		var v_col := Color(0.45, 0.92, 0.58) if vote_choice == "Ecology" else Color(0.42, 0.82, 0.98)
		bubble.text = "\"%s\"\n[VOTES %s]" % [quote_text, vote_choice.to_upper()]
		bubble.modulate = v_col
		bubble.visible = true

	# Console terminal glow
	if terminal_mat != null:
		var term_col := Color(0.45, 0.92, 0.58) if vote_choice == "Ecology" else Color(0.42, 0.82, 0.98)
		terminal_mat.emission = term_col
		terminal_mat.emission_energy_multiplier = 3.0

	# Record ballot
	recorded_votes.append({
		"name": resident_data[voter_idx]["name"],
		"job": resident_data[voter_idx]["job"],
		"vote": vote_choice
	})
	_update_tally_ui()

func _finish_voter_speech() -> void:
	step_state = "walking_back"

	# Hide speech bubble
	if active_voter_node != null:
		var bubble: Label3D = active_voter_node.get_node_or_null("SpeechBubble")
		if bubble != null:
			bubble.visible = false

	# Dim terminal
	if terminal_mat != null:
		terminal_mat.emission_energy_multiplier = 1.0

	# Walk back to seat
	var tw_back := create_tween()
	if active_voter_node.position.distance_squared_to(active_voter_seat_pos) > 0.01:
		active_voter_node.look_at_from_position(active_voter_node.position, active_voter_seat_pos, Vector3.UP)
	tw_back.tween_property(active_voter_node, "position", active_voter_seat_pos, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_back.tween_callback(Callable(self, "_on_returned_to_seat"))

func _on_returned_to_seat() -> void:
	if active_voter_node != null:
		active_voter_node.rotation.y = active_voter_seat_rot

	current_step_index += 1
	step_state = "idle"
	step_timer = 0.6 # Brief pause before next voter

func _finish_return_to_seat() -> void:
	pass

func _resolve_final_verdict() -> void:
	is_ceremony_running = false
	step_state = "finished"

	# Fade spotlight down
	var tw_spot := create_tween()
	tw_spot.tween_property(podium_spotlight, "light_energy", 0.4, 1.0)

	_apply_director_camera_view("verdict")

	var scen: Dictionary = scenarios[current_scenario_id]
	var verdict_str: String = scen["verdict"]

	var hud: Control = ui_layer.get_node("HUDControl")
	var modal: Panel = hud.get_node("VerdictModal")
	var v_text: Label = modal.get_node("VerdictText")
	v_text.text = verdict_str
	var is_unanimous := (verdict_str.find("UNANIMOUS") != -1)
	v_text.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40) if is_unanimous else Color(0.90, 0.92, 1.0))
	modal.visible = true

	# Gold beacon flare if unanimous
	if is_unanimous and town_beacon_light != null:
		town_beacon_light.light_color = Color(1.0, 0.85, 0.35)
		town_beacon_light.light_energy = 3.5

func _update_tally_ui() -> void:
	var eco_count := 0
	var tech_count := 0
	for v in recorded_votes:
		if v["vote"] == "Ecology":
			eco_count += 1
		elif v["vote"] == "Technology":
			tech_count += 1

	# Update 3D Tally Monolith
	var t3d_lbl: Label3D = tally_board_3d.get_node_or_null("TallyText")
	if t3d_lbl != null:
		t3d_lbl.text = "CIVILIAN COURT RUNNING TALLY\n%d ECOLOGY   |   %d TECHNOLOGY" % [eco_count, tech_count]

	# Update 2D HUD Card
	var hud: Control = ui_layer.get_node("HUDControl")
	var tally_lbl: Label = hud.get_node("TallyCard/TallyHUDLabel")
	var status_line := "Ceremony Concluded" if step_state == "finished" else ("Turn %d of 4  •  %s" % [mini(4, current_step_index + 1), "At Podium" if step_state == "speaking" else "Deliberating"])
	tally_lbl.text = "LIVE TALLY: %d ECOLOGY  vs  %d TECHNOLOGY\n%s" % [eco_count, tech_count, status_line]

# ------------------------------------------------------------------------------
# Input & Interactive Controls
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				# Fast-forward speech / advance
				if step_state == "speaking":
					step_timer = 0.05
				elif step_state == "finished":
					# Cycle to next scenario
					var next_scen := (current_scenario_id % 4) + 1
					start_scenario(next_scen)
			KEY_1:
				start_scenario(1) # 3-1 Split
			KEY_2:
				start_scenario(2) # 4-0 Eco
			KEY_3:
				start_scenario(3) # 4-0 Tech
			KEY_4:
				start_scenario(4) # 2-2 Split
			KEY_R:
				start_scenario(current_scenario_id) # Replay
			KEY_TAB, KEY_X:
				# Toggle secret faction inspector overlay
				show_inspector_overlay = not show_inspector_overlay
				for r in resident_nodes:
					var aura: MeshInstance3D = r.get_node_or_null("InspectorAura")
					if aura != null:
						aura.visible = show_inspector_overlay
			KEY_C:
				# Cycle camera mode
				match current_cam_mode:
					CamMode.DIRECTOR:
						current_cam_mode = CamMode.TOP_DOWN
						_update_cam_hint("TOP-DOWN MOBA")
					CamMode.TOP_DOWN:
						current_cam_mode = CamMode.FREE_ORBIT
						orbit_dist = 18.0
						orbit_yaw = 0.0
						orbit_pitch = -0.45
						_update_cam_hint("FREE ORBIT (Hold RMB/MMB to orbit)")
					CamMode.FREE_ORBIT:
						current_cam_mode = CamMode.DIRECTOR
						_update_cam_hint("DIRECTOR")
						_apply_director_camera_view("wide")

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and current_cam_mode == CamMode.FREE_ORBIT:
			orbit_dist = clampf(orbit_dist - 1.2, 5.0, 35.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and current_cam_mode == CamMode.FREE_ORBIT:
			orbit_dist = clampf(orbit_dist + 1.2, 5.0, 35.0)

	elif event is InputEventMouseMotion and is_orbiting and current_cam_mode == CamMode.FREE_ORBIT:
		orbit_yaw -= event.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.008, -1.2, -0.05)

func _update_cam_hint(mode_name: String) -> void:
	var hud: Control = ui_layer.get_node("HUDControl")
	var hint: Label = hud.get_node("BottomBar/ControlsHint")
	hint.text = "[SPACE / ENTER] Step / Advance  •  [1-4] Switch Scripted Scenario  •  [C] Camera Mode: %s  •  [TAB] Toggle Inspector Reveal  •  [R] Replay" % mode_name
