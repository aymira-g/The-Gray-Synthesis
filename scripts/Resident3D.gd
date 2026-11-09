extends CharacterBody3D

# ==============================================================================
# The Gray Synthesis - Unified 3D Resident
# ==============================================================================
# Standard CharacterBody3D entity representing all 10 town residents.
# Features:
# - Faction-neutral civilian workwear styling (canvas khaki/slate/sand)
# - Civic job identification tool props (wrench, sickle, torch, scanner, baton)
# - Stamina-based sprint and isometric velocity movement
# - Overhead 3D name & job billboarding label
# - Headlamp with directional glow
# - Physics capsule collision
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

signal trauma_impact_requested(amount: float, source_pos: Vector3)
signal task_completed

var resident_id: int = 1
var resident_name: String = "Resident 1"
var civic_job: String = "Pump Technician"
var secret_role: String = "civilian"
var operative_kit: String = "none"
var is_player: bool = false
var is_incapacitated: bool = false
var exhaustion_timer: float = 0.0
var bot_controller: Node = null

# Hero Roster Identity (10-Hero System: 1 Unique Active [F] + 1 Unique Passive Trait)
var hero_id: String = "kaelen_vance"
var hero_title: String = "Chief Hydro-Rig Specialist"
var hero_variant: String = "Vanguard"
var hero_active_id: String = "field_calibrator"
var hero_active_name: String = "Field Calibrator"
var hero_active_cd: float = 14.0
var hero_active_desc: String = "Reduces nearest pad cooldown by 6s (or jam by 4s), or grants +40% work speed for 4s."
var hero_passive_id: String = "hydro_mastery"
var hero_passive_name: String = "Hydro-Mastery"
var hero_passive_desc: String = "+20% task channel speed on Water Pump and Generator stations."
var hero_torso_color: Color = Color(0.28, 0.44, 0.56)
var hero_accent_color: Color = Color(0.35, 0.85, 1.0)
var hero_lore: String = "Designed the town's dual-stage intake manifold before the gray silt encroached."
var _hero_default_job: String = "Pump Technician"

func is_operative() -> bool:
	return secret_role == "ecology" or secret_role == "technology"

# Milestone 8 Playtest & Tuning overrides
static var task_channel_scale: float = 1.0
static var shove_cooldown_override: float = 4.0

# Task channeling state
var is_channeling: bool = false
var channel_progress: float = 0.0
var active_pad: Dictionary = {}
var is_inspecting: bool = false
var inspection_timer: float = 0.0
var inspection_target: Dictionary = {}

# Ability cooldowns & status buffs
var shove_cooldown_left: float = 0.0
var civic_cooldown_left: float = 0.0
var faction_cooldown_left: float = 0.0
var speed_buff_timer: float = 0.0
var speed_buff_mult: float = 1.0
var watch_shield_timer: float = 0.0
var work_speed_timer: float = 0.0
var adrenaline_timer: float = 0.0
var recon_pulse_timer: float = 0.0
var popup_timer: float = 0.0
var popup_text: String = ""
var popup_color: Color = Color.WHITE

# Movement & Stamina
var walk_speed: float = 6.0
var sprint_speed: float = 9.2
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_drain: float = 28.0
var stamina_recovery: float = 20.0
var is_sprinting: bool = false
var spawn_position: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO
var knockback_velocity: Vector3 = Vector3.ZERO

# Environmental references
var town_map: Node
var game_manager: Node
var audio_manager: Node
var all_residents: Array = []
var last_step_sign: float = 0.0

# Visual nodes
var mesh_root: Node3D
var name_label: Label3D
var action_label: Label3D
var speech_label: Label3D
var speech_timer: float = 0.0
var tool_mesh: MeshInstance3D
var player_ring: MeshInstance3D
var player_marker: Label3D
var player_marker_timer: float = 0.0
var player_light: OmniLight3D
var torso_node: MeshInstance3D
var hero_trim_node: MeshInstance3D
var head_node: MeshInstance3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var job_accessory_root: Node3D
var walk_cycle: float = 0.0
var idle_phase: float = 0.0
var sim_time: float = 0.0
var covert_hunch_timer: float = 0.0
var channel_progress_ring: MeshInstance3D
var channel_ring_mat: StandardMaterial3D
var _is_setup: bool = false

func _init() -> void:
	_init_components()

func _enter_tree() -> void:
	_init_components()

func _ready() -> void:
	_init_components()

func _init_components() -> void:
	if _is_setup:
		return
	_is_setup = true
	_setup_collision()
	_setup_visuals()

func _setup_collision() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 # Collide with static environment walls, allowing residents to bypass each other
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.40
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)

func _setup_visuals() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# 1. Torso (Dusty Canvas Workwear with Hero Trim Collar)
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.55, 0.70, 0.35)
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = hero_torso_color
	t_mat.roughness = 0.88
	torso_node = MeshInstance3D.new()
	torso_node.name = "Torso"
	torso_node.mesh = torso_mesh
	torso_node.material_override = t_mat
	torso_node.position = Vector3(0.0, 1.05, 0.0)
	mesh_root.add_child(torso_node)

	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.57, 0.10, 0.37)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = hero_accent_color
	trim_mat.roughness = 0.55
	hero_trim_node = MeshInstance3D.new()
	hero_trim_node.name = "HeroCollarTrim"
	hero_trim_node.mesh = trim_mesh
	hero_trim_node.material_override = trim_mat
	hero_trim_node.position = Vector3(0.0, 0.31, 0.0)
	torso_node.add_child(hero_trim_node)

	# 2. Articulated Legs (Utility Trousers with procedural stride)
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.24, 0.25, 0.28)
	l_mat.roughness = 0.90

	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.14, 0.72, 0.0)
	var l_mesh := BoxMesh.new()
	l_mesh.size = Vector3(0.20, 0.70, 0.26)
	var left_leg := MeshInstance3D.new()
	left_leg.name = "LeftLeg"
	left_leg.mesh = l_mesh
	left_leg.material_override = l_mat
	left_leg.position = Vector3(0.0, -0.35, 0.0)
	left_leg_pivot.add_child(left_leg)
	mesh_root.add_child(left_leg_pivot)

	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.14, 0.72, 0.0)
	var r_mesh := BoxMesh.new()
	r_mesh.size = Vector3(0.20, 0.70, 0.26)
	var right_leg := MeshInstance3D.new()
	right_leg.name = "RightLeg"
	right_leg.mesh = r_mesh
	right_leg.material_override = l_mat
	right_leg.position = Vector3(0.0, -0.35, 0.0)
	right_leg_pivot.add_child(right_leg)
	mesh_root.add_child(right_leg_pivot)

	# 2.5 Articulated Arms (Counter-swing & task reach)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.48, 0.44, 0.38)
	arm_mat.roughness = 0.88

	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(-0.35, 1.35, 0.0)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.16, 0.58, 0.16)
	var left_arm := MeshInstance3D.new()
	left_arm.name = "LeftArm"
	left_arm.mesh = arm_mesh
	left_arm.material_override = arm_mat
	left_arm.position = Vector3(0.0, -0.26, 0.0)
	left_arm_pivot.add_child(left_arm)
	mesh_root.add_child(left_arm_pivot)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(0.35, 1.35, 0.0)
	var right_arm := MeshInstance3D.new()
	right_arm.name = "RightArm"
	right_arm.mesh = arm_mesh
	right_arm.material_override = arm_mat
	right_arm.position = Vector3(0.0, -0.26, 0.0)
	right_arm_pivot.add_child(right_arm)
	mesh_root.add_child(right_arm_pivot)

	# 2.6 Civic Job Silhouette Accessories Container
	job_accessory_root = Node3D.new()
	job_accessory_root.name = "JobAccessories"
	mesh_root.add_child(job_accessory_root)

	# 3. Head & Headlamp
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.78, 0.68, 0.58)
	head_node = MeshInstance3D.new()
	head_node.name = "Head"
	head_node.mesh = head_mesh
	head_node.material_override = h_mat
	head_node.position = Vector3(0.0, 1.58, 0.0)
	mesh_root.add_child(head_node)

	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.12, 0.08, 0.12)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.95, 0.8)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.95, 0.75)
	lamp_mat.emission_energy_multiplier = 1.2
	var lamp := MeshInstance3D.new()
	lamp.mesh = lamp_mesh
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0.0, 1.68, 0.18)
	mesh_root.add_child(lamp)

	# 4. Civic Tool Prop
	_setup_civic_tool()

	# 4.5 Civic Job Silhouette Accessories
	_setup_civic_accessories()

	# 4.6 Ground Progress Ring during Active Channeling / Inspection
	channel_progress_ring = MeshInstance3D.new()
	channel_progress_ring.name = "ChannelProgressRing"
	var t_ring := TorusMesh.new()
	t_ring.inner_radius = 1.05
	t_ring.outer_radius = 1.25
	t_ring.rings = 32
	t_ring.ring_segments = 16
	channel_ring_mat = StandardMaterial3D.new()
	channel_ring_mat.albedo_color = Color(0.35, 0.88, 1.0, 0.75)
	channel_ring_mat.emission_enabled = true
	channel_ring_mat.emission = Color(0.35, 0.88, 1.0)
	channel_ring_mat.emission_energy_multiplier = 1.2
	channel_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	channel_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	channel_progress_ring.mesh = t_ring
	channel_progress_ring.material_override = channel_ring_mat
	channel_progress_ring.position = Vector3(0.0, 0.04, 0.0)
	channel_progress_ring.visible = false
	add_child(channel_progress_ring)

	# 5. Overhead Billboarding Labels
	name_label = Label3D.new()
	name_label.text = "%s\n[%s]" % [resident_name, civic_job]
	name_label.font_size = 22
	name_label.outline_size = 5
	name_label.outline_modulate = Color(0, 0, 0, 0.95)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0.0, 2.2, 0.0)
	add_child(name_label)

	action_label = Label3D.new()
	action_label.text = ""
	action_label.font_size = 22
	action_label.modulate = Color(1.0, 0.85, 0.3)
	action_label.outline_size = 5
	action_label.outline_modulate = Color(0, 0, 0, 0.95)
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.position = Vector3(0.0, 2.6, 0.0)
	add_child(action_label)

	speech_label = Label3D.new()
	speech_label.text = ""
	speech_label.font_size = 26
	speech_label.modulate = Color(1.0, 0.98, 0.8)
	speech_label.outline_size = 5
	speech_label.outline_modulate = Color(0, 0, 0, 0.95)
	speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_label.position = Vector3(0.0, 3.0, 0.0)
	add_child(speech_label)

func _setup_civic_tool() -> void:
	if tool_mesh != null and tool_mesh.get_parent() != null:
		tool_mesh.queue_free()

	tool_mesh = MeshInstance3D.new()
	tool_mesh.name = "CivicToolMesh"
	var tool_mat := StandardMaterial3D.new()

	var local_pos := Vector3(0.05, -0.45, 0.12) if right_arm_pivot != null else Vector3(0.35, 0.9, 0.15)

	match civic_job:
		"Crop Tender":
			var sickle := CylinderMesh.new()
			sickle.top_radius = 0.03
			sickle.bottom_radius = 0.03
			sickle.height = 0.55
			tool_mat.albedo_color = Color(0.40, 0.85, 0.45)
			tool_mesh.mesh = sickle
			tool_mesh.position = local_pos
			tool_mesh.rotation_degrees = Vector3(30, 0, 25)
		"Salvage Quartermaster":
			var torch := BoxMesh.new()
			torch.size = Vector3(0.08, 0.45, 0.08)
			tool_mat.albedo_color = Color(0.95, 0.65, 0.25)
			tool_mesh.mesh = torch
			tool_mesh.position = local_pos
			tool_mesh.rotation_degrees = Vector3(-20, 0, 15)
		"Field Medic":
			var scanner := BoxMesh.new()
			scanner.size = Vector3(0.18, 0.25, 0.08)
			tool_mat.albedo_color = Color(0.90, 0.35, 0.40)
			tool_mesh.mesh = scanner
			tool_mesh.position = local_pos
		"Town Watch":
			var baton := CylinderMesh.new()
			baton.top_radius = 0.04
			baton.bottom_radius = 0.04
			baton.height = 0.65
			tool_mat.albedo_color = Color(0.30, 0.50, 0.85)
			tool_mesh.mesh = baton
			tool_mesh.position = local_pos
			tool_mesh.rotation_degrees = Vector3(15, 0, 20)
		_: # "Pump Technician" or default
			var wrench := BoxMesh.new()
			wrench.size = Vector3(0.08, 0.50, 0.08)
			tool_mat.albedo_color = Color(0.35, 0.70, 0.95)
			tool_mesh.mesh = wrench
			tool_mesh.position = local_pos
			tool_mesh.rotation_degrees = Vector3(25, 0, 20)

	tool_mesh.material_override = tool_mat
	if right_arm_pivot != null:
		right_arm_pivot.add_child(tool_mesh)
	elif mesh_root != null:
		mesh_root.add_child(tool_mesh)

func _setup_civic_accessories() -> void:
	if job_accessory_root == null:
		return

	# Clear previous accessories if any
	for child in job_accessory_root.get_children():
		job_accessory_root.remove_child(child)
		child.queue_free()

	# Create distinct thematic accessories for each civic job (purely civic, zero role leakage)
	match civic_job:
		"Pump Technician":
			# 1. Dual Hydro-Pressure Canisters on back
			var tank_mat := StandardMaterial3D.new()
			tank_mat.albedo_color = Color(0.25, 0.48, 0.62)
			tank_mat.metallic = 0.65
			tank_mat.roughness = 0.35

			var tank_mesh := CylinderMesh.new()
			tank_mesh.top_radius = 0.085
			tank_mesh.bottom_radius = 0.085
			tank_mesh.height = 0.50

			var tank_left := MeshInstance3D.new()
			tank_left.name = "HydroTankLeft"
			tank_left.mesh = tank_mesh
			tank_left.material_override = tank_mat
			tank_left.position = Vector3(-0.16, 1.15, -0.24)
			job_accessory_root.add_child(tank_left)

			var tank_right := MeshInstance3D.new()
			tank_right.name = "HydroTankRight"
			tank_right.mesh = tank_mesh
			tank_right.material_override = tank_mat
			tank_right.position = Vector3(0.16, 1.15, -0.24)
			job_accessory_root.add_child(tank_right)

			# 2. Brass Cross-Manifold linking the dual tanks
			var pipe_mat := StandardMaterial3D.new()
			pipe_mat.albedo_color = Color(0.85, 0.72, 0.35)
			pipe_mat.metallic = 0.8
			pipe_mat.roughness = 0.3

			var pipe_mesh := CylinderMesh.new()
			pipe_mesh.top_radius = 0.035
			pipe_mesh.bottom_radius = 0.035
			pipe_mesh.height = 0.34

			var cross_pipe := MeshInstance3D.new()
			cross_pipe.name = "ManifoldCrossPipe"
			cross_pipe.mesh = pipe_mesh
			cross_pipe.material_override = pipe_mat
			cross_pipe.rotation_degrees = Vector3(0, 0, 90)
			cross_pipe.position = Vector3(0.0, 1.25, -0.24)
			job_accessory_root.add_child(cross_pipe)

			# 3. Pressure Dial Gauge on chest
			var gauge_mesh := CylinderMesh.new()
			gauge_mesh.top_radius = 0.06
			gauge_mesh.bottom_radius = 0.06
			gauge_mesh.height = 0.03
			var gauge_mat := StandardMaterial3D.new()
			gauge_mat.albedo_color = Color(0.95, 0.95, 0.90)
			gauge_mat.metallic = 0.3
			var gauge := MeshInstance3D.new()
			gauge.name = "PressureGauge"
			gauge.mesh = gauge_mesh
			gauge.material_override = gauge_mat
			gauge.rotation_degrees = Vector3(90, 0, 0)
			gauge.position = Vector3(0.16, 1.25, 0.19)
			job_accessory_root.add_child(gauge)

			# 4. Bump Cap Brim on head
			var brim_mesh := BoxMesh.new()
			brim_mesh.size = Vector3(0.34, 0.04, 0.16)
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.20, 0.35, 0.48)
			var bump_cap := MeshInstance3D.new()
			bump_cap.name = "BumpCapBrim"
			bump_cap.mesh = brim_mesh
			bump_cap.material_override = cap_mat
			bump_cap.position = Vector3(0.0, 1.66, 0.20)
			job_accessory_root.add_child(bump_cap)

		"Crop Tender":
			# 1. Broad-Brimmed Harvest Straw Hat
			var brim_mesh := CylinderMesh.new()
			brim_mesh.top_radius = 0.38
			brim_mesh.bottom_radius = 0.38
			brim_mesh.height = 0.04
			var straw_mat := StandardMaterial3D.new()
			straw_mat.albedo_color = Color(0.82, 0.72, 0.42)
			straw_mat.roughness = 0.95
			var harvest_hat := MeshInstance3D.new()
			harvest_hat.name = "HarvestHatBrim"
			harvest_hat.mesh = brim_mesh
			harvest_hat.material_override = straw_mat
			harvest_hat.position = Vector3(0.0, 1.74, 0.0)
			job_accessory_root.add_child(harvest_hat)

			# 2. Botanical Green Hatband
			var band_mesh := CylinderMesh.new()
			band_mesh.top_radius = 0.24
			band_mesh.bottom_radius = 0.24
			band_mesh.height = 0.06
			var ribbon_mat := StandardMaterial3D.new()
			ribbon_mat.albedo_color = Color(0.22, 0.65, 0.32)
			var hat_band := MeshInstance3D.new()
			hat_band.name = "BotanicalHatBand"
			hat_band.mesh = band_mesh
			hat_band.material_override = ribbon_mat
			hat_band.position = Vector3(0.0, 1.78, 0.0)
			job_accessory_root.add_child(hat_band)

			# 3. Seed Satchel Pouch on hip
			var satchel_mesh := BoxMesh.new()
			satchel_mesh.size = Vector3(0.18, 0.24, 0.16)
			var satchel_mat := StandardMaterial3D.new()
			satchel_mat.albedo_color = Color(0.46, 0.32, 0.18)
			var seed_satchel := MeshInstance3D.new()
			seed_satchel.name = "SeedSatchel"
			seed_satchel.mesh = satchel_mesh
			seed_satchel.material_override = satchel_mat
			seed_satchel.position = Vector3(-0.30, 0.82, 0.05)
			job_accessory_root.add_child(seed_satchel)

			# 4. Diagonal Satchel Strap
			var strap_mesh := BoxMesh.new()
			strap_mesh.size = Vector3(0.05, 0.70, 0.02)
			var strap := MeshInstance3D.new()
			strap.name = "SatchelStrap"
			strap.mesh = strap_mesh
			strap.material_override = satchel_mat
			strap.position = Vector3(-0.10, 1.15, 0.18)
			strap.rotation_degrees = Vector3(0, 0, -32)
			job_accessory_root.add_child(strap)

		"Salvage Quartermaster":
			# 1. Welder Visor Mask with horizontal slit
			var mask_mesh := BoxMesh.new()
			mask_mesh.size = Vector3(0.30, 0.24, 0.16)
			var mask_mat := StandardMaterial3D.new()
			mask_mat.albedo_color = Color(0.22, 0.24, 0.28)
			mask_mat.metallic = 0.5
			var welder_mask := MeshInstance3D.new()
			welder_mask.name = "WelderMask"
			welder_mask.mesh = mask_mesh
			welder_mask.material_override = mask_mat
			welder_mask.position = Vector3(0.0, 1.58, 0.16)
			job_accessory_root.add_child(welder_mask)

			# Glowing Amber Viewing Slit
			var slit_mesh := BoxMesh.new()
			slit_mesh.size = Vector3(0.20, 0.035, 0.04)
			var slit_mat := StandardMaterial3D.new()
			slit_mat.albedo_color = Color(1.0, 0.70, 0.20)
			slit_mat.emission_enabled = true
			slit_mat.emission = Color(1.0, 0.65, 0.15)
			slit_mat.emission_energy_multiplier = 2.0
			var welder_slit := MeshInstance3D.new()
			welder_slit.name = "WelderSlit"
			welder_slit.mesh = slit_mesh
			welder_slit.material_override = slit_mat
			welder_slit.position = Vector3(0.0, 1.58, 0.25)
			job_accessory_root.add_child(welder_slit)

			# 2. Asymmetrical Heavy Scrap Pauldron on left shoulder
			var pauldron_mesh := BoxMesh.new()
			pauldron_mesh.size = Vector3(0.24, 0.16, 0.28)
			var pauldron_mat := StandardMaterial3D.new()
			pauldron_mat.albedo_color = Color(0.55, 0.42, 0.32)
			pauldron_mat.metallic = 0.7
			pauldron_mat.roughness = 0.6
			var salvage_pauldron := MeshInstance3D.new()
			salvage_pauldron.name = "SalvagePauldron"
			salvage_pauldron.mesh = pauldron_mesh
			salvage_pauldron.material_override = pauldron_mat
			salvage_pauldron.position = Vector3(-0.35, 1.42, 0.0)
			job_accessory_root.add_child(salvage_pauldron)

			# 3. Cutting Gas Cylinder on back
			var gas_mesh := CylinderMesh.new()
			gas_mesh.top_radius = 0.12
			gas_mesh.bottom_radius = 0.12
			gas_mesh.height = 0.62
			var gas_mat := StandardMaterial3D.new()
			gas_mat.albedo_color = Color(0.90, 0.45, 0.15)
			gas_mat.roughness = 0.4
			var gas_tank := MeshInstance3D.new()
			gas_tank.name = "CuttingGasTank"
			gas_tank.mesh = gas_mesh
			gas_tank.material_override = gas_mat
			gas_tank.position = Vector3(0.0, 1.15, -0.26)
			job_accessory_root.add_child(gas_tank)

		"Field Medic":
			# 1. Clinical Reflector Mirror on forehead
			var mirror_mesh := CylinderMesh.new()
			mirror_mesh.top_radius = 0.09
			mirror_mesh.bottom_radius = 0.09
			mirror_mesh.height = 0.02
			var mirror_mat := StandardMaterial3D.new()
			mirror_mat.albedo_color = Color(0.92, 0.95, 0.98)
			mirror_mat.metallic = 0.9
			mirror_mat.roughness = 0.1
			var reflector := MeshInstance3D.new()
			reflector.name = "ClinicalReflector"
			reflector.mesh = mirror_mesh
			reflector.material_override = mirror_mat
			reflector.rotation_degrees = Vector3(90, 0, 0)
			reflector.position = Vector3(0.0, 1.70, 0.23)
			job_accessory_root.add_child(reflector)

			# 2. Medical Trauma Kit Backpack
			var pack_mesh := BoxMesh.new()
			pack_mesh.size = Vector3(0.38, 0.46, 0.20)
			var pack_mat := StandardMaterial3D.new()
			pack_mat.albedo_color = Color(0.94, 0.94, 0.92)
			pack_mat.roughness = 0.8
			var trauma_pack := MeshInstance3D.new()
			trauma_pack.name = "TraumaPack"
			trauma_pack.mesh = pack_mesh
			trauma_pack.material_override = pack_mat
			trauma_pack.position = Vector3(0.0, 1.12, -0.24)
			job_accessory_root.add_child(trauma_pack)

			# Red Cross Vertical & Horizontal Bars
			var cross_mat := StandardMaterial3D.new()
			cross_mat.albedo_color = Color(0.92, 0.15, 0.18)
			cross_mat.emission_enabled = true
			cross_mat.emission = Color(0.92, 0.15, 0.18)
			cross_mat.emission_energy_multiplier = 0.8

			var v_mesh := BoxMesh.new()
			v_mesh.size = Vector3(0.06, 0.24, 0.02)
			var cross_v := MeshInstance3D.new()
			cross_v.name = "RedCrossV"
			cross_v.mesh = v_mesh
			cross_v.material_override = cross_mat
			cross_v.position = Vector3(0.0, 1.12, -0.35)
			job_accessory_root.add_child(cross_v)

			var h_mesh := BoxMesh.new()
			h_mesh.size = Vector3(0.24, 0.06, 0.02)
			var cross_h := MeshInstance3D.new()
			cross_h.name = "RedCrossH"
			cross_h.mesh = h_mesh
			cross_h.material_override = cross_mat
			cross_h.position = Vector3(0.0, 1.12, -0.35)
			job_accessory_root.add_child(cross_h)

			# 3. Antiseptic Flask on right hip
			var flask_mesh := CylinderMesh.new()
			flask_mesh.top_radius = 0.055
			flask_mesh.bottom_radius = 0.055
			flask_mesh.height = 0.22
			var flask_mat := StandardMaterial3D.new()
			flask_mat.albedo_color = Color(0.30, 0.85, 0.85)
			flask_mat.roughness = 0.3
			var flask := MeshInstance3D.new()
			flask.name = "AntisepticFlask"
			flask.mesh = flask_mesh
			flask.material_override = flask_mat
			flask.position = Vector3(0.30, 0.85, 0.0)
			job_accessory_root.add_child(flask)

		"Town Watch":
			# 1. Peaked Security Patrol Cap
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.24
			cap_mesh.bottom_radius = 0.24
			cap_mesh.height = 0.12
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.14, 0.18, 0.28)
			var patrol_cap := MeshInstance3D.new()
			patrol_cap.name = "SecurityPatrolCap"
			patrol_cap.mesh = cap_mesh
			patrol_cap.material_override = cap_mat
			patrol_cap.position = Vector3(0.0, 1.74, 0.0)
			job_accessory_root.add_child(patrol_cap)

			var brim_mesh := BoxMesh.new()
			brim_mesh.size = Vector3(0.28, 0.03, 0.14)
			var brim_mat := StandardMaterial3D.new()
			brim_mat.albedo_color = Color(0.08, 0.10, 0.15)
			var cap_brim := MeshInstance3D.new()
			cap_brim.name = "SecurityCapBrim"
			cap_brim.mesh = brim_mesh
			cap_brim.material_override = brim_mat
			cap_brim.position = Vector3(0.0, 1.68, 0.18)
			job_accessory_root.add_child(cap_brim)

			# Gold Security Crest Pip
			var pip_mesh := BoxMesh.new()
			pip_mesh.size = Vector3(0.06, 0.06, 0.03)
			var pip_mat := StandardMaterial3D.new()
			pip_mat.albedo_color = Color(1.0, 0.85, 0.25)
			pip_mat.metallic = 0.8
			var pip := MeshInstance3D.new()
			pip.name = "SecurityPip"
			pip.mesh = pip_mesh
			pip.material_override = pip_mat
			pip.position = Vector3(0.0, 1.76, 0.23)
			job_accessory_root.add_child(pip)

			# 2. Twin Armored Pauldrons (Left & Right)
			var pauldron_mesh := BoxMesh.new()
			pauldron_mesh.size = Vector3(0.18, 0.12, 0.22)
			var pauldron_mat := StandardMaterial3D.new()
			pauldron_mat.albedo_color = Color(0.18, 0.24, 0.35)
			pauldron_mat.metallic = 0.6
			var left_p := MeshInstance3D.new()
			left_p.name = "WatchLeftPauldron"
			left_p.mesh = pauldron_mesh
			left_p.material_override = pauldron_mat
			left_p.position = Vector3(-0.35, 1.40, 0.0)
			job_accessory_root.add_child(left_p)

			var right_p := MeshInstance3D.new()
			right_p.name = "WatchRightPauldron"
			right_p.mesh = pauldron_mesh
			right_p.material_override = pauldron_mat
			right_p.position = Vector3(0.35, 1.40, 0.0)
			job_accessory_root.add_child(right_p)

			# 3. Tactical Radio Transceiver & Antenna Whip
			var radio_mesh := BoxMesh.new()
			radio_mesh.size = Vector3(0.14, 0.24, 0.10)
			var radio_mat := StandardMaterial3D.new()
			radio_mat.albedo_color = Color(0.15, 0.15, 0.18)
			var radio := MeshInstance3D.new()
			radio.name = "RadioTransceiver"
			radio.mesh = radio_mesh
			radio.material_override = radio_mat
			radio.position = Vector3(-0.18, 1.15, -0.22)
			job_accessory_root.add_child(radio)

			var whip_mesh := CylinderMesh.new()
			whip_mesh.top_radius = 0.012
			whip_mesh.bottom_radius = 0.012
			whip_mesh.height = 0.52
			var whip_mat := StandardMaterial3D.new()
			whip_mat.albedo_color = Color(0.70, 0.70, 0.75)
			whip_mat.metallic = 0.9
			var antenna := MeshInstance3D.new()
			antenna.name = "RadioAntenna"
			antenna.mesh = whip_mesh
			antenna.material_override = whip_mat
			antenna.position = Vector3(-0.18, 1.48, -0.22)
			job_accessory_root.add_child(antenna)

func apply_hero_profile(profile: Dictionary) -> void:
	if profile.is_empty():
		return
	hero_id = str(profile.get("hero_id", profile.get("id", hero_id)))
	resident_name = str(profile.get("name", resident_name))
	hero_title = str(profile.get("title", hero_title))
	civic_job = str(profile.get("civic_job", civic_job))
	_hero_default_job = civic_job
	hero_variant = str(profile.get("variant", hero_variant))
	hero_active_id = str(profile.get("active_id", hero_active_id))
	hero_active_name = str(profile.get("active_name", hero_active_name))
	hero_active_cd = float(profile.get("active_cd", hero_active_cd))
	hero_active_desc = str(profile.get("active_desc", hero_active_desc))
	hero_passive_id = str(profile.get("passive_id", hero_passive_id))
	hero_passive_name = str(profile.get("passive_name", hero_passive_name))
	hero_passive_desc = str(profile.get("passive_desc", hero_passive_desc))
	hero_torso_color = profile.get("torso_color", hero_torso_color)
	hero_accent_color = profile.get("accent_color", hero_accent_color)
	hero_lore = str(profile.get("lore", hero_lore))

	if hero_passive_id == "heavy_frame":
		max_stamina = 125.0
	else:
		max_stamina = 100.0
	stamina = max_stamina

	refresh_identity_labels()

func set_hero_by_id(h_id: String) -> void:
	apply_hero_profile(C.get_hero_by_id(h_id))

func set_hero_by_index(idx: int) -> void:
	apply_hero_profile(C.get_hero_by_index(idx))

func refresh_identity_labels() -> void:
	if torso_node != null:
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = hero_torso_color
		t_mat.roughness = 0.88
		torso_node.material_override = t_mat
	if hero_trim_node != null:
		var trim_mat := StandardMaterial3D.new()
		trim_mat.albedo_color = hero_accent_color
		trim_mat.roughness = 0.55
		hero_trim_node.material_override = trim_mat

	if is_player:
		_setup_player_indicators()
		if name_label != null:
			name_label.text = "★ YOU ★\n%s\n[%s]" % [resident_name, civic_job]
			name_label.modulate = Color(0.35, 1.0, 0.92) # Bright glowing cyan-turquoise
			name_label.font_size = 28
			name_label.outline_size = 6
			name_label.outline_modulate = Color(0.0, 0.06, 0.16, 1.0)
	else:
		if name_label != null:
			name_label.text = "%s\n[%s]" % [resident_name, civic_job]
			name_label.modulate = Color(0.92, 0.92, 0.96) # Crisp civilian neutral
			name_label.font_size = 22
			name_label.outline_size = 5
			name_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	_setup_civic_tool()
	_setup_civic_accessories()

func _setup_player_indicators() -> void:
	# 1. Ground Ring (Glowing Cyan Torus under player's feet)
	if player_ring == null:
		player_ring = MeshInstance3D.new()
		player_ring.name = "PlayerSelectionRing"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.70
		torus.outer_radius = 0.95
		torus.rings = 32
		torus.ring_segments = 16
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.20, 0.90, 1.0, 0.95)
		r_mat.emission_enabled = true
		r_mat.emission = Color(0.25, 0.95, 1.0)
		r_mat.emission_energy_multiplier = 3.0
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		player_ring.mesh = torus
		player_ring.material_override = r_mat
		player_ring.position = Vector3(0.0, 0.06, 0.0)
		add_child(player_ring)

	# 2. Floating Marker ("▼ YOU ▼" Billboard Banner)
	if player_marker == null:
		player_marker = Label3D.new()
		player_marker.name = "PlayerMarker"
		player_marker.text = "▼ YOU ▼"
		player_marker.font_size = 28
		player_marker.modulate = Color(0.30, 1.0, 0.90)
		player_marker.outline_size = 6
		player_marker.outline_modulate = Color(0.0, 0.05, 0.18, 1.0)
		player_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		player_marker.position = Vector3(0.0, 3.1, 0.0)
		add_child(player_marker)

	# 3. Dedicated Player Spotlight / Soft Beacon
	if player_light == null:
		player_light = OmniLight3D.new()
		player_light.name = "PlayerLight"
		player_light.light_color = Color(0.70, 0.92, 1.0)
		player_light.light_energy = 1.8
		player_light.omni_range = 5.0
		player_light.omni_attenuation = 1.2
		player_light.position = Vector3(0.0, 2.2, 0.0)
		add_child(player_light)

	# 4. Player Canvas Vest Highlight (distinct teal-cyan utility vest)
	if mesh_root != null:
		var torso_node = mesh_root.get_node_or_null("Torso")
		if torso_node != null and torso_node is MeshInstance3D:
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.24, 0.45, 0.55) # Distinct teal-cyan utility vest
			p_mat.roughness = 0.75
			torso_node.material_override = p_mat

func get_speed_multiplier() -> float:
	var mult: float = speed_buff_mult if speed_buff_timer > 0.0 else 1.0
	if hero_passive_id == "crisis_responder" and game_manager != null and float(game_manager.water) < 50.0:
		mult *= 1.15
	if town_map != null and town_map.has_method("is_slowed_by_root_snare"):
		var my_pos: Vector3 = global_position if is_inside_tree() else position
		if town_map.is_slowed_by_root_snare(my_pos, resident_id):
			mult *= 0.55
	return mult

func get_effective_stamina_drain() -> float:
	if adrenaline_timer > 0.0:
		return 0.0
	return stamina_drain

func get_allegiance() -> String:
	if game_manager != null and game_manager.has_method("get_resident_alignment"):
		return game_manager.get_resident_alignment(self)
	return secret_role

func show_popup(text: String, col: Color = Color.WHITE) -> void:
	popup_text = text
	popup_color = col
	popup_timer = 2.0
	if action_label != null:
		action_label.text = text
		action_label.modulate = col

func _physics_process(delta: float) -> void:
	# Tick down cooldowns & status timers
	if shove_cooldown_left > 0.0:
		shove_cooldown_left = maxf(0.0, shove_cooldown_left - delta)
	if civic_cooldown_left > 0.0:
		civic_cooldown_left = maxf(0.0, civic_cooldown_left - delta)
	if faction_cooldown_left > 0.0:
		faction_cooldown_left = maxf(0.0, faction_cooldown_left - delta)
	if speed_buff_timer > 0.0:
		speed_buff_timer = maxf(0.0, speed_buff_timer - delta)
	if watch_shield_timer > 0.0:
		watch_shield_timer = maxf(0.0, watch_shield_timer - delta)
	if work_speed_timer > 0.0:
		work_speed_timer = maxf(0.0, work_speed_timer - delta)
	if adrenaline_timer > 0.0:
		adrenaline_timer = maxf(0.0, adrenaline_timer - delta)
	if recon_pulse_timer > 0.0:
		recon_pulse_timer = maxf(0.0, recon_pulse_timer - delta)
	if covert_hunch_timer > 0.0:
		covert_hunch_timer = maxf(0.0, covert_hunch_timer - delta)
	if popup_timer > 0.0:
		popup_timer = maxf(0.0, popup_timer - delta)
		if popup_timer <= 0.0 and action_label != null and not is_channeling and not is_inspecting and not is_incapacitated:
			action_label.text = ""
	if speech_timer > 0.0:
		speech_timer = maxf(0.0, speech_timer - delta)
		if speech_timer <= 0.0 and speech_label != null:
			speech_label.text = ""

	# Freeze during briefing
	if game_manager != null and not game_manager.is_active_play_phase():
		if is_channeling:
			cancel_channeling()
		if is_inspecting:
			cancel_inspection()
		velocity = Vector3.ZERO
		return

	# Handle 8s Clinic Medical Recovery
	if is_incapacitated:
		exhaustion_timer = maxf(0.0, exhaustion_timer - delta)
		velocity = Vector3.ZERO
		if action_label != null:
			action_label.text = "Exhausted! Clinic Recovery: %.1fs" % exhaustion_timer
			action_label.modulate = Color(1.0, 0.45, 0.42)
		if exhaustion_timer <= 0.0:
			is_incapacitated = false
			stamina = max_stamina
			show_popup("Recovered!", Color(0.55, 0.98, 0.68))
		return

	# Secluded Alcove Inspection
	if is_inspecting:
		inspection_timer = maxf(0.0, inspection_timer - delta)
		velocity = Vector3.ZERO
		if channel_progress_ring != null:
			channel_progress_ring.visible = true
			channel_progress_ring.rotation.y += delta * 2.2
			var insp_pct: float = clampf(1.0 - (inspection_timer / 2.5), 0.0, 1.0)
			channel_progress_ring.scale = Vector3(0.90 + insp_pct * 0.25, 1.0, 0.90 + insp_pct * 0.25)
			if channel_ring_mat != null:
				channel_ring_mat.albedo_color = Color(0.55, 0.88, 1.0, 0.70)
				channel_ring_mat.emission = Color(0.55, 0.88, 1.0)
				channel_ring_mat.emission_energy_multiplier = 1.0 + insp_pct * 1.5
		if action_label != null:
			action_label.text = "Inspecting Alcove... (%.1fs)" % inspection_timer
			action_label.modulate = Color(0.55, 0.88, 1.0)
		if inspection_timer <= 0.0:
			if channel_progress_ring != null:
				channel_progress_ring.visible = false
			var target_alc := inspection_target
			is_inspecting = false
			inspection_target = {}
			var my_pos: Vector3 = global_position if is_inside_tree() else position
			if town_map != null:
				var res_entry: Dictionary = town_map.complete_site_inspection(self, target_alc)
				var is_active: bool = bool(target_alc.get("is_active", false)) or (game_manager != null and game_manager.archive_active_spawn_id == String(target_alc.get("id", "")))
				if is_active:
					if audio_manager != null:
						audio_manager.play_sfx_3d("archive_unseal", target_alc.get("pos", my_pos))
					show_popup("Old-World Archive Unsealed!", Color(1.0, 0.90, 0.45))
				else:
					if audio_manager != null:
						audio_manager.play_sfx_3d("alcove_inspect", target_alc.get("pos", my_pos))
					show_popup("Weathered Bedrock Inspected (No cache).", Color(0.75, 0.82, 0.92))
		return

	# Task Channeling
	if is_channeling:
		var my_pos: Vector3 = global_position if is_inside_tree() else position
		if active_pad.is_empty() or my_pos.distance_to(active_pad["position"]) > 4.5:
			cancel_channeling()
		elif float(active_pad.get("jammed_timer", 0.0)) > 0.0:
			cancel_channeling()
			if audio_manager != null:
				audio_manager.play_sfx_3d("task_jammed", my_pos)
			show_popup("Station Jammed!", Color(1.0, 0.48, 0.42))
		else:
			var ch_mult: float = 1.40 if work_speed_timer > 0.0 else 1.0
			if hero_passive_id == "hydro_mastery":
				var p_type: String = String(active_pad.get("task_type", ""))
				if p_type == "pump" or p_type == "generator" or p_type == "generator_objective":
					ch_mult *= 1.20
			if game_manager != null and game_manager.current_phase == game_manager.Phase.FINALE:
				var allegiance: String = get_allegiance()
				ch_mult *= game_manager.get_archive_objective_speed_mult(allegiance)
				if active_pad.get("task_type", "") == "generator_objective":
					ch_mult *= game_manager.get_beacon_speed_buff(allegiance)
			channel_progress += delta * ch_mult
			var base_dur: float = 3.0 if active_pad.get("task_type", "") == "common_works" else 2.0
			var req_duration: float = base_dur * task_channel_scale
			var pct: int = mini(100, int((channel_progress / req_duration) * 100.0))
			if channel_progress_ring != null:
				channel_progress_ring.visible = true
				channel_progress_ring.rotation.y += delta * 2.8
				var ch_pct: float = clampf(channel_progress / req_duration, 0.0, 1.0)
				channel_progress_ring.scale = Vector3(0.85 + ch_pct * 0.35, 1.0, 0.85 + ch_pct * 0.35)
				if channel_ring_mat != null:
					var pad_col: Color = active_pad.get("color", Color(0.40, 0.90, 1.0))
					channel_ring_mat.albedo_color = Color(pad_col.r, pad_col.g, pad_col.b, 0.75)
					channel_ring_mat.emission = pad_col
					channel_ring_mat.emission_energy_multiplier = 1.2 + ch_pct * 2.2
			if action_label != null:
				action_label.text = "%s [%d%%]" % [String(active_pad.get("base_title", active_pad.get("name", "Task"))).split("\n")[0], pct]
				action_label.modulate = Color(0.45, 0.88, 1.0)
			if channel_progress >= req_duration:
				if channel_progress_ring != null:
					channel_progress_ring.visible = false
				var completed_pad := active_pad
				is_channeling = false
				channel_progress = 0.0
				active_pad = {}
				var summary: String = ""
				if town_map != null:
					summary = town_map.finish_using_pad(completed_pad, self, is_player)
				if is_player:
					task_completed.emit()
				if audio_manager != null:
					audio_manager.play_sfx_3d("task_complete", my_pos)
				show_popup("Task Complete! " + summary, Color(0.55, 0.98, 0.65))
		velocity = Vector3.ZERO
		if is_inside_tree():
			move_and_slide()
		return

	# Passive Stamina Regen (enhanced in Mulch Mist and Hero Passives)
	var regen: float = stamina_recovery
	var my_pos_regen: Vector3 = global_position if is_inside_tree() else position
	if town_map != null:
		if town_map.has_method("is_inside_mulch_mist") and town_map.is_inside_mulch_mist(my_pos_regen):
			regen += 8.0
		if hero_passive_id == "deep_roots" and town_map.has_method("get_region_id_at_3d"):
			if town_map.get_region_id_at_3d(my_pos_regen) == "greenhouse":
				regen += 2.5
	if hero_passive_id == "apothecarys_aura":
		regen += 2.0
	else:
		for other in all_residents:
			if other != null and other != self and not other.is_incapacitated and String(other.get("hero_passive_id")) == "apothecarys_aura":
				var o_pos: Vector3 = other.global_position if other.is_inside_tree() else other.position
				if my_pos_regen.distance_to(o_pos) <= 4.0:
					regen += 2.0
					break
	if hero_passive_id == "triage_veteran" and stamina < 50.0:
		regen *= 1.30
	if not is_sprinting and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + regen * delta)

	# Update player marker bobbing animation
	if is_player and player_marker != null:
		player_marker_timer += delta * 4.5
		player_marker.position.y = 2.75 + sin(player_marker_timer) * 0.12

	# Knockback velocity decay
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 24.0)

	if is_player:
		_process_player_movement(delta)

	velocity += knockback_velocity
	if is_inside_tree():
		move_and_slide()

	_update_procedural_animations(delta)

func _update_procedural_animations(delta: float) -> void:
	if mesh_root == null:
		return

	if is_incapacitated:
		# Collapse / lie down while recovering in Clinic
		mesh_root.rotation.x = lerp_angle(mesh_root.rotation.x, deg_to_rad(80.0), delta * 8.0)
		mesh_root.position.y = lerpf(mesh_root.position.y, -0.4, delta * 8.0)
		if left_arm_pivot != null:
			left_arm_pivot.rotation = Vector3.ZERO
		if right_arm_pivot != null:
			right_arm_pivot.rotation = Vector3.ZERO
		if channel_progress_ring != null:
			channel_progress_ring.visible = false
		return

	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_moving: bool = h_speed > 0.25

	# Base mesh alignment
	mesh_root.rotation.x = lerp_angle(mesh_root.rotation.x, 0.0, delta * 8.0)
	if not is_channeling and not is_inspecting and channel_progress_ring != null and channel_progress_ring.visible:
		channel_progress_ring.visible = false

	# State 1: Active Task Channeling or Bedrock Inspection (Working Pose)
	if is_channeling or is_inspecting:
		mesh_root.position.y = lerpf(mesh_root.position.y, 0.0, delta * 8.0)
		# Both arms reach forward towards work target
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, deg_to_rad(-65.0), delta * 10.0)
			left_arm_pivot.rotation.y = lerpf(left_arm_pivot.rotation.y, deg_to_rad(15.0), delta * 10.0)
			left_arm_pivot.rotation.z = lerpf(left_arm_pivot.rotation.z, 0.0, delta * 10.0)
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, deg_to_rad(-70.0), delta * 10.0)
			right_arm_pivot.rotation.y = lerpf(right_arm_pivot.rotation.y, deg_to_rad(-15.0), delta * 10.0)
			right_arm_pivot.rotation.z = lerpf(right_arm_pivot.rotation.z, 0.0, delta * 10.0)

		# Torso leans forward attentively
		if torso_node != null:
			torso_node.position.y = 1.05
			torso_node.rotation.x = lerpf(torso_node.rotation.x, deg_to_rad(-14.0), delta * 8.0)
		# Head tilts downward towards hands
		if head_node != null:
			head_node.position.y = 1.58
			head_node.rotation.x = lerpf(head_node.rotation.x, deg_to_rad(12.0), delta * 8.0)
			head_node.rotation.y = lerp_angle(head_node.rotation.y, 0.0, delta * 8.0)

		# Return legs to stable stance
		if left_leg_pivot != null:
			left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, 0.0, delta * 10.0)
		if right_leg_pivot != null:
			right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, 0.0, delta * 10.0)

		# Active rhythmic tool oscillation while working
		if tool_mesh != null:
			var tool_work_cycle := sin(float(Time.get_ticks_msec()) * 0.012) * 18.0
			tool_mesh.rotation_degrees.z = 25.0 + tool_work_cycle

	# State 2: Covert Sabotage / Faction Hunch Pose
	elif covert_hunch_timer > 0.0:
		mesh_root.position.y = lerpf(mesh_root.position.y, -0.14, delta * 8.0) # Suspicious low crouch

		# Sharp forward torso hunch
		if torso_node != null:
			torso_node.position.y = 1.05
			torso_node.rotation.x = lerpf(torso_node.rotation.x, deg_to_rad(-24.0), delta * 10.0)

		# Arms pulled in close defensively to body
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, deg_to_rad(-35.0), delta * 10.0)
			left_arm_pivot.rotation.y = lerpf(left_arm_pivot.rotation.y, 0.0, delta * 10.0)
			left_arm_pivot.rotation.z = lerpf(left_arm_pivot.rotation.z, deg_to_rad(16.0), delta * 10.0)
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, deg_to_rad(-35.0), delta * 10.0)
			right_arm_pivot.rotation.y = lerpf(right_arm_pivot.rotation.y, 0.0, delta * 10.0)
			right_arm_pivot.rotation.z = lerpf(right_arm_pivot.rotation.z, deg_to_rad(-16.0), delta * 10.0)

		# Head glances furtively left and right to check for observers
		sim_time += delta
		if head_node != null:
			head_node.position.y = 1.58
			head_node.rotation.x = lerpf(head_node.rotation.x, deg_to_rad(-6.0), delta * 8.0)
			head_node.rotation.y = sin(sim_time * 6.0) * deg_to_rad(26.0)

		# Legs slightly bent
		if left_leg_pivot != null:
			left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, deg_to_rad(8.0), delta * 10.0)
		if right_leg_pivot != null:
			right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, deg_to_rad(-8.0), delta * 10.0)

	# State 3: Bipedal Locomotion (Walking & Sprinting with Articulated Arm Counter-Swing)
	elif is_moving:
		mesh_root.position.y = lerpf(mesh_root.position.y, 0.0, delta * 8.0)
		sim_time += delta
		var stride_freq: float = 14.0 if is_sprinting else 8.5
		walk_cycle += delta * stride_freq
		var stride_amp: float = 0.55 if is_sprinting else 0.40

		# Legs stride
		if left_leg_pivot != null:
			left_leg_pivot.rotation.x = sin(walk_cycle) * stride_amp
		if right_leg_pivot != null:
			right_leg_pivot.rotation.x = -sin(walk_cycle) * stride_amp

		# Arms counter-swing opposite to legs
		var arm_swing_amp: float = stride_amp * 0.85
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = -sin(walk_cycle) * arm_swing_amp
			left_arm_pivot.rotation.y = lerpf(left_arm_pivot.rotation.y, 0.0, delta * 10.0)
			left_arm_pivot.rotation.z = lerpf(left_arm_pivot.rotation.z, 0.0, delta * 10.0)
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = sin(walk_cycle) * arm_swing_amp
			right_arm_pivot.rotation.y = lerpf(right_arm_pivot.rotation.y, 0.0, delta * 10.0)
			right_arm_pivot.rotation.z = lerpf(right_arm_pivot.rotation.z, 0.0, delta * 10.0)

		# Procedural footstep acoustic triggering per stride impact
		var curr_step_sign: float = signf(sin(walk_cycle))
		if curr_step_sign != 0.0 and curr_step_sign != last_step_sign:
			last_step_sign = curr_step_sign
			_trigger_footstep()

		# Bipedal vertical bounce & forward lean
		var bounce: float = absf(sin(walk_cycle)) * 0.05
		if torso_node != null:
			torso_node.position.y = 1.05 + bounce
			var target_lean: float = -0.16 if is_sprinting else -0.06
			torso_node.rotation.x = lerpf(torso_node.rotation.x, target_lean, delta * 8.0)
		if head_node != null:
			head_node.position.y = 1.58 + bounce
			head_node.rotation.x = lerpf(head_node.rotation.x, 0.0, delta * 8.0)
			head_node.rotation.y = lerp_angle(head_node.rotation.y, 0.0, delta * 8.0)

	# State 4: Idle Rest Stance
	else:
		mesh_root.position.y = lerpf(mesh_root.position.y, 0.0, delta * 8.0)

		# Return legs to upright rest stance
		if left_leg_pivot != null:
			left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, 0.0, delta * 10.0)
		if right_leg_pivot != null:
			right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, 0.0, delta * 10.0)

		# Arms relax naturally at sides with subtle breathing sway
		idle_phase += delta * 2.5
		var breath: float = sin(idle_phase) * 0.015
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, 0.0, delta * 10.0)
			left_arm_pivot.rotation.y = lerp_angle(left_arm_pivot.rotation.y, 0.0, delta * 10.0)
			left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, breath * 1.5, delta * 5.0)
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, 0.0, delta * 10.0)
			right_arm_pivot.rotation.y = lerp_angle(right_arm_pivot.rotation.y, 0.0, delta * 10.0)
			right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, -breath * 1.5, delta * 5.0)

		# Idle breathing cycle on torso & head
		if torso_node != null:
			torso_node.position.y = 1.05 + breath
			torso_node.rotation.x = lerpf(torso_node.rotation.x, 0.0, delta * 8.0)
		if head_node != null:
			head_node.position.y = 1.58 + breath
			head_node.rotation.x = lerpf(head_node.rotation.x, 0.0, delta * 8.0)
			head_node.rotation.y = lerp_angle(head_node.rotation.y, 0.0, delta * 8.0)

func _trigger_footstep() -> void:
	if audio_manager == null:
		return
	var my_pos: Vector3 = global_position if is_inside_tree() else position
	var sec_id: String = "town_square"
	if town_map != null and town_map.has_method("get_region_id_at_3d"):
		sec_id = town_map.get_region_id_at_3d(my_pos)
	audio_manager.play_footstep(sec_id, my_pos, is_sprinting, resident_id, sim_time)

func _process_player_movement(delta: float) -> void:
	# Restrict movement during formal debate phases or while Evidence Journal / Dev Panel / Archive Dilemma / Settings Menu is open
	if game_manager != null and (game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL or game_manager.current_phase == game_manager.Phase.COURT or game_manager.current_phase == game_manager.Phase.MATCH_OVER or game_manager.evidence_journal_open or game_manager.get("dev_panel_open") == true or game_manager.archive_dilemma_open or game_manager.get("settings_menu_open") == true):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var input_x := 0.0
	var input_z := 0.0

	# W / Up Arrow: move towards top of screen (-Z)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		input_z -= 1.0
	# S / Down Arrow: move towards bottom of screen (+Z)
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		input_z += 1.0
	# A / Left Arrow: move towards left of screen (-X)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		input_x -= 1.0
	# D / Right Arrow: move towards right of screen (+X)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		input_x += 1.0

	var has_input := (input_x != 0.0 or input_z != 0.0)
	if has_input:
		if is_channeling:
			cancel_channeling()
		if is_inspecting:
			cancel_inspection()

	# Stamina Sprint
	var wants_sprint := Input.is_key_pressed(KEY_SHIFT) and has_input
	if wants_sprint and (stamina > 5.0 or adrenaline_timer > 0.0):
		is_sprinting = true
		stamina = maxf(0.0, stamina - get_effective_stamina_drain() * delta)
	else:
		is_sprinting = false

	var base_speed := sprint_speed if is_sprinting else walk_speed
	var speed := base_speed * get_speed_multiplier()
	var dir := Vector3(input_x, 0.0, input_z).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if dir.length_squared() > 0.01 and mesh_root != null:
		var target_yaw := atan2(-dir.x, -dir.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_yaw, delta * 14.0)

# ------------------------------------------------------------------------------
# Action Methods: Channeling & Site Inspection
# ------------------------------------------------------------------------------
func try_start_channel() -> bool:
	if is_channeling or is_inspecting or is_incapacitated or town_map == null or game_manager == null:
		return false
	if not game_manager.is_active_play_phase():
		return false

	var my_pos: Vector3 = global_position if is_inside_tree() else position
	var pad: Dictionary = town_map.get_nearest_pad(my_pos, 3.8)
	if pad.is_empty():
		if is_player:
			show_popup("Move closer to a task station", Color(0.95, 0.78, 0.45))
		return false

	if pad.get("is_locked", false):
		if is_player:
			show_popup("Objective locked until Escalation!", Color(1.0, 0.65, 0.45))
		return false

	if float(pad.get("jammed_timer", 0.0)) > 0.0:
		if is_player:
			show_popup("Station Jammed (%.1fs)" % float(pad["jammed_timer"]), Color(1.0, 0.50, 0.42))
		return false

	if float(pad.get("cooldown", 0.0)) > 0.0:
		if is_player:
			show_popup("Station cooling down (%.1fs)" % float(pad["cooldown"]), Color(0.95, 0.65, 0.45))
		return false

	if pad.get("active_user") != null and pad.get("active_user") != self:
		if is_player:
			show_popup("Station in use by another resident", Color(0.95, 0.65, 0.45))
		return false

	if not game_manager.can_perform_task(pad.get("task_type", "")):
		if is_player:
			show_popup("No Scrap / Already Complete", Color(0.95, 0.65, 0.45))
		return false

	if town_map.start_using_pad(pad, self):
		is_channeling = true
		channel_progress = 0.0
		active_pad = pad
		desired_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		if audio_manager != null:
			audio_manager.play_sfx_3d("channel_start", pad["position"])
		show_popup("Channeling %s..." % String(pad["name"]).split("\n")[0], Color(0.75, 0.88, 1.0))
		return true

	return false

func cancel_channeling() -> void:
	if not is_channeling and active_pad.is_empty():
		return
	is_channeling = false
	channel_progress = 0.0
	if channel_progress_ring != null:
		channel_progress_ring.visible = false
	if town_map != null:
		town_map.release_reservations_for(self)
	active_pad = {}
	if action_label != null and popup_timer <= 0.0:
		action_label.text = ""

func try_inspect_site() -> bool:
	if is_inspecting or is_channeling or is_incapacitated or town_map == null or game_manager == null:
		return false
	if not game_manager.is_active_play_phase():
		return false

	var my_pos: Vector3 = global_position if is_inside_tree() else position
	var alc: Dictionary = town_map.get_nearest_alcove(my_pos, 3.8)
	if alc.is_empty():
		if is_player:
			show_popup("Move closer to a secluded alcove", Color(0.95, 0.78, 0.45))
		return false

	is_inspecting = true
	inspection_timer = 1.75 if hero_passive_id == "forensic_eye" else 2.5
	inspection_target = alc
	desired_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	if audio_manager != null:
		audio_manager.play_sfx_3d("channel_start", alc.get("pos", my_pos), 0.8)
	show_popup("Inspecting Secluded Alcove (%.1fs)..." % inspection_timer, Color(0.55, 0.88, 1.0))
	return true

func cancel_inspection() -> void:
	if not is_inspecting:
		return
	is_inspecting = false
	inspection_timer = 0.0
	inspection_target = {}
	if channel_progress_ring != null:
		channel_progress_ring.visible = false
	if action_label != null and popup_timer <= 0.0:
		action_label.text = ""

# ------------------------------------------------------------------------------
# Action Methods: Civic Shove & Non-Lethal Knockdown
# ------------------------------------------------------------------------------
func try_civic_shove() -> bool:
	if is_incapacitated:
		return false
	if game_manager != null and not game_manager.is_active_play_phase():
		return false
	if shove_cooldown_left > 0.0:
		if is_player:
			show_popup("Shove on cooldown (%.1fs)" % shove_cooldown_left, Color(0.95, 0.65, 0.45))
		return false

	cancel_channeling()
	cancel_inspection()
	if hero_passive_id == "sentinels_reach":
		shove_cooldown_left = maxf(1.5, shove_cooldown_override - 1.5)
	else:
		shove_cooldown_left = shove_cooldown_override

	var closest_other: CharacterBody3D = null
	var closest_dist: float = 3.5
	var my_pos: Vector3 = global_position if is_inside_tree() else position
	for other in all_residents:
		if other == null or other == self or other.is_incapacitated:
			continue
		var o_pos: Vector3 = other.global_position if other.is_inside_tree() else other.position
		var d: float = my_pos.distance_to(o_pos)
		if d <= closest_dist:
			closest_dist = d
			closest_other = other

	if closest_other != null:
		var o_pos: Vector3 = closest_other.global_position if closest_other.is_inside_tree() else closest_other.position
		var diff: Vector3 = o_pos - my_pos
		diff.y = 0.0
		var dir: Vector3 = diff.normalized() if diff.length() > 0.01 else Vector3(0, 0, 1)
		var out_dmg: float = C.SHOVE_STAMINA_DAMAGE + (10.0 if hero_passive_id == "sentinels_reach" else 0.0)
		closest_other.receive_shove(dir * 12.0, out_dmg, self, false)
		if game_manager != null:
			game_manager.record_shove(resident_name, closest_other.resident_name)
		show_popup("Shoved %s!" % closest_other.resident_name, Color(1.0, 0.82, 0.45))
	else:
		if game_manager != null:
			game_manager.record_shove(resident_name, "")
		show_popup("Civic Shove (No target)", Color(0.85, 0.85, 0.90))

	if is_player:
		trauma_impact_requested.emit(0.18, my_pos)

	return true

func receive_shove(impulse: Vector3, stamina_dmg: float = 35.0, attacker: Node = null, is_shock: bool = false) -> void:
	if is_incapacitated:
		return

	var my_pos: Vector3 = global_position if is_inside_tree() else position

	# Town Watch shield block
	if watch_shield_timer > 0.0:
		watch_shield_timer = 0.0
		if audio_manager != null:
			audio_manager.play_sfx_3d("zone_shield", my_pos)
		show_popup("Watch Shield Blocked Hit!", Color(0.65, 0.92, 1.0))
		return

	# Warden Thorn Guard protect & reflect
	if not is_shock and town_map != null and town_map.has_method("is_protected_by_thorn_guard") and town_map.is_protected_by_thorn_guard(my_pos):
		if audio_manager != null:
			audio_manager.play_sfx_3d("zone_shield", my_pos)
		show_popup("Protected by Thorn Guard!", Color(0.52, 1.0, 0.75))
		if attacker != null and attacker != self and not attacker.is_incapacitated:
			attacker.stamina = maxf(0.0, attacker.stamina - 20.0)
			attacker.show_popup("Thorn Guard Reflected -20 Stam!", Color(1.0, 0.55, 0.45))
			if attacker.stamina <= 0.01:
				attacker.trigger_knockdown()
		return

	if audio_manager != null:
		audio_manager.play_sfx_3d("shove_impact", my_pos)

	trauma_impact_requested.emit(0.38, my_pos)

	var was_channeling := is_channeling
	cancel_channeling()
	cancel_inspection()

	stamina = maxf(0.0, stamina - stamina_dmg)
	if stamina <= 0.01:
		trigger_knockdown()
		return

	knockback_velocity = impulse * (0.80 if hero_passive_id == "heavy_frame" else 1.0)
	if is_shock:
		show_popup("Shocked! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.52, 0.42))
	elif was_channeling:
		show_popup("Interrupted! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.48, 0.42))
	else:
		show_popup("Shoved! (-%d Stamina)" % int(stamina_dmg), Color(1.0, 0.72, 0.45))

func trigger_knockdown() -> void:
	var my_pos: Vector3 = global_position if is_inside_tree() else position
	trauma_impact_requested.emit(0.55, my_pos)

	cancel_channeling()
	cancel_inspection()
	is_incapacitated = true
	if hero_passive_id == "triage_veteran":
		exhaustion_timer = maxf(1.0, C.RESPAWN_DURATION - 2.5)
	else:
		exhaustion_timer = C.RESPAWN_DURATION
	stamina = 0.0
	speed_buff_timer = 0.0
	watch_shield_timer = 0.0
	work_speed_timer = 0.0
	adrenaline_timer = 0.0
	velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO

	# Non-lethal relocation to Town Square Clinic
	position = Vector3(0.0, 0.05, -10.0)

	if game_manager != null:
		game_manager.record_knockdown(resident_name)
	show_popup("Exhausted! Recovering at Clinic (%.1fs)" % exhaustion_timer, Color(1.0, 0.45, 0.42))

func recover_full_stamina() -> void:
	stamina = max_stamina
	is_incapacitated = false
	exhaustion_timer = 0.0
	show_popup("Stamina Fully Restored!", Color(0.55, 0.98, 0.72))

func trigger_covert_hunch(duration: float = 2.0) -> void:
	covert_hunch_timer = duration
	if audio_manager != null:
		var my_pos: Vector3 = global_position if is_inside_tree() else position
		audio_manager.play_sfx_3d("covert_hunch", my_pos, 1.0, -4.0)

# ------------------------------------------------------------------------------
# Action Methods: 5 Civic Kits & 6 Operative Faction Abilities
# ------------------------------------------------------------------------------
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

	# Determine active ability ID (honors Hero active when civic_job matches hero's job, or falls back to job default if civic_job was manually reassigned)
	var effective_active_id: String = hero_active_id
	var ab_name: String = hero_active_name
	var cd: float = hero_active_cd
	if civic_job != _hero_default_job:
		var kit_meta: Dictionary = C.CIVIC_KIT_INFO.get(civic_job, {})
		cd = float(kit_meta.get("cooldown", 14.0))
		ab_name = String(kit_meta.get("ability_name", "Civic Ability"))
		match civic_job:
			"Crop Tender":
				effective_active_id = "mulch_mist"
			"Salvage Quartermaster":
				effective_active_id = "haul_rig_sprint"
			"Field Medic":
				effective_active_id = "first_aid_patch"
			"Town Watch":
				effective_active_id = "brace_and_lantern"
			_:
				effective_active_id = "field_calibrator"

	civic_cooldown_left = cd

	var my_pos: Vector3 = global_position if is_inside_tree() else position
	match effective_active_id:
		"field_calibrator":
			if audio_manager != null:
				audio_manager.play_sfx_3d("channel_start", my_pos, 1.25)
			var near_pad: Dictionary = town_map.get_nearest_pad(my_pos, 4.5)
			if not near_pad.is_empty() and (float(near_pad.get("cooldown", 0.0)) > 0.0 or float(near_pad.get("jammed_timer", 0.0)) > 0.0):
				near_pad["cooldown"] = maxf(0.0, float(near_pad.get("cooldown", 0.0)) - 6.0)
				near_pad["jammed_timer"] = maxf(0.0, float(near_pad.get("jammed_timer", 0.0)) - 4.0)
				town_map.record_pad_interaction(near_pad, resident_name, "calibrated")
				game_manager.record_civic_ability(resident_name, ab_name, "calibrated " + String(near_pad.get("name", "pad")))
				show_popup("Field Calibrator: -6s Pad CD!", Color(0.45, 0.88, 1.0))
			else:
				work_speed_timer = 4.0
				game_manager.record_civic_ability(resident_name, ab_name, "+40% work speed (4s)")
				show_popup("Field Calibrator: +40% Work Spd!", Color(0.45, 0.88, 1.0))

		"pressure_surge":
			if audio_manager != null:
				audio_manager.play_sfx_3d("speed_burst", my_pos, 1.15)
			stamina = minf(max_stamina, stamina + 20.0)
			speed_buff_timer = 3.5
			speed_buff_mult = 1.30
			town_map.spawn_field_zone_3d("scent_scan", my_pos, 3.2, 1.8, resident_id)
			var pushed_count := 0
			for other in all_residents:
				if other == null or other == self or other.is_incapacitated:
					continue
				var o_pos: Vector3 = other.global_position if other.is_inside_tree() else other.position
				if my_pos.distance_to(o_pos) <= 3.2:
					var diff: Vector3 = o_pos - my_pos
					diff.y = 0.0
					var dir: Vector3 = diff.normalized() if diff.length() > 0.01 else Vector3(0, 0, 1)
					other.knockback_velocity = dir * 9.0
					other.show_popup("Hydro Surge Pushback!", Color(0.45, 0.90, 1.0))
					pushed_count += 1
			game_manager.record_civic_ability(resident_name, ab_name, "+20 Stam, +30%% speed (%d pushed)" % pushed_count)
			show_popup("Pressure Surge (+20 Stam, +30% Spd)!", Color(0.40, 0.92, 1.0))

		"mulch_mist":
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_mist", my_pos)
			town_map.spawn_field_zone_3d("mulch_mist", my_pos, 4.0, 5.0, resident_id)
			game_manager.record_civic_ability(resident_name, ab_name, "4m stamina mist")
			show_popup("Mulch Mist (+8 Stam/s)!", Color(0.48, 0.96, 0.62))

		"blight_cleanse":
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_mist", my_pos, 1.15)
			var cleansed: int = 0
			if town_map.has_method("cleanse_hazards_near_3d"):
				cleansed = town_map.cleanse_hazards_near_3d(my_pos, 5.0)
			stamina = minf(max_stamina, stamina + 25.0)
			game_manager.record_civic_ability(resident_name, ab_name, "cleansed %d hazards & +25 Stamina" % cleansed)
			show_popup("Blight Cleanse (+25 Stam, %d Cleared)!" % cleansed, Color(0.48, 0.98, 0.72))

		"haul_rig_sprint":
			if audio_manager != null:
				audio_manager.play_sfx_3d("speed_burst", my_pos)
			speed_buff_timer = 3.5
			speed_buff_mult = 1.45
			game_manager.record_civic_ability(resident_name, ab_name, "+45% move speed")
			show_popup("Haul Rig Sprint (+45% Spd)!", Color(0.98, 0.78, 0.38))

		"scrap_overdrive":
			if audio_manager != null:
				audio_manager.play_sfx_3d("speed_burst", my_pos, 1.2)
			work_speed_timer = 5.0
			speed_buff_timer = 5.0
			speed_buff_mult = 1.20
			game_manager.record_civic_ability(resident_name, ab_name, "+40% work & +20% move speed (5s)")
			show_popup("Scrap Overdrive (+40% Work, +20% Spd)!", Color(1.0, 0.78, 0.32))

		"first_aid_patch":
			if audio_manager != null:
				audio_manager.play_sfx_3d("task_complete", my_pos, 0.9)
			stamina = minf(max_stamina, stamina + 35.0)
			var ally: CharacterBody3D = _find_nearest_other_resident(4.0)
			if ally != null:
				ally.stamina = minf(ally.max_stamina, ally.stamina + 35.0)
				ally.show_popup("+35 Stamina (First Aid)!", Color(0.55, 0.98, 0.72))
				game_manager.record_civic_ability(resident_name, ab_name, "healed self & " + ally.resident_name)
				show_popup("First Aid: +35 Stam (+%s)!" % ally.resident_name, Color(0.55, 0.98, 0.72))
			else:
				game_manager.record_civic_ability(resident_name, ab_name, "restored +35 Stamina")
				show_popup("First Aid Patch: +35 Stamina!", Color(0.55, 0.98, 0.72))

		"adrenaline_tonic":
			if audio_manager != null:
				audio_manager.play_sfx_3d("task_complete", my_pos, 1.15)
			stamina = minf(max_stamina, stamina + 25.0)
			adrenaline_timer = 3.5
			speed_buff_timer = 3.5
			speed_buff_mult = 1.25
			var tonic_ally: CharacterBody3D = _find_nearest_other_resident(4.0)
			if tonic_ally != null:
				tonic_ally.stamina = minf(tonic_ally.max_stamina, tonic_ally.stamina + 15.0)
				tonic_ally.set("adrenaline_timer", 3.5)
				tonic_ally.show_popup("+15 Stam & Adrenaline Tonic!", Color(0.45, 0.98, 0.85))
			game_manager.record_civic_ability(resident_name, ab_name, "+25 Stam & zero sprint drain (3.5s)")
			show_popup("Adrenaline Tonic (+25 Stam, Zero Drain)!", Color(0.45, 0.98, 0.85))

		"brace_and_lantern":
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_shield", my_pos)
			watch_shield_timer = 4.5
			game_manager.record_civic_ability(resident_name, ab_name, "4.5s Watch Shield")
			show_popup("Brace & Lantern (Shield 4.5s)!", Color(0.75, 0.88, 1.0))

		"recon_pulse":
			if audio_manager != null:
				audio_manager.play_sfx_3d("alcove_inspect", my_pos, 1.2)
			var contacts: int = town_map.trigger_tracker_scent_snapshot_3d(self, all_residents, 10.0, 4.0)
			recon_pulse_timer = 5.0
			speed_buff_timer = 3.5
			speed_buff_mult = 1.20
			game_manager.record_civic_ability(resident_name, ab_name, "10m recon pulse (%d contacts)" % contacts)
			show_popup("Recon Pulse (%d contacts, +20%% Spd)!" % contacts, Color(0.60, 0.92, 1.0))

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
	covert_hunch_timer = 2.2

	var my_pos: Vector3 = global_position if is_inside_tree() else position
	match operative_kit:
		"tracker":
			if audio_manager != null:
				audio_manager.play_sfx_3d("alcove_inspect", my_pos, 1.3)
			var traces: int = town_map.trigger_tracker_scent_snapshot_3d(self, all_residents, 14.0, 5.0)
			if is_player:
				show_popup("Scent Trail Snapshot (%d traces, 5s)" % traces, Color(0.52, 1.0, 0.72))

		"grower":
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_roots", my_pos)
			town_map.spawn_field_zone_3d("root_snare", my_pos, 4.5, 6.0, resident_id)
			var gh_pad: Dictionary = town_map.get_nearest_pad(my_pos, 4.5)
			if not gh_pad.is_empty() and String(gh_pad.get("task_type", "")) == "greenhouse":
				town_map.record_pad_interaction(gh_pad, resident_name, "snared")
			if is_player:
				show_popup("Root Snare Placed (6s)!", Color(0.62, 0.95, 0.45))

		"warden":
			var near_pad_w: Dictionary = town_map.get_nearest_pad(my_pos, 4.5)
			var canopy_pos: Vector3 = near_pad_w["position"] if not near_pad_w.is_empty() else my_pos
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_shield", canopy_pos)
			town_map.spawn_field_zone_3d("thorn_guard", canopy_pos, 4.0, 6.0, resident_id)
			if is_player:
				show_popup("Thorn Guard Canopy (6s)!", Color(0.48, 0.98, 0.72))

		"runner":
			cancel_channeling()
			var start_p := my_pos
			var dash_dir := desired_velocity.normalized() if desired_velocity.length() > 0.1 else Vector3(0, 0, 1)
			velocity = dash_dir * 18.0
			speed_buff_timer = 2.5
			speed_buff_mult = 1.35
			if audio_manager != null:
				audio_manager.play_sfx_3d("zone_sparks", my_pos)
			town_map.spawn_field_zone_3d("spark_trail", my_pos, 1.5, 4.0, resident_id, "", start_p)
			if is_player:
				show_popup("Exosuit Burst!", Color(0.45, 0.88, 1.0))

		"mechanic":
			var near_pad_m: Dictionary = town_map.get_nearest_pad(my_pos, 4.5)
			if audio_manager != null:
				audio_manager.play_sfx_3d("channel_start", my_pos, 1.35)
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
			if audio_manager != null:
				audio_manager.play_sfx_3d("task_jammed", my_pos)
			var near_pad_s: Dictionary = town_map.get_nearest_pad(my_pos, 4.5)
			var target_res: CharacterBody3D = null
			if not near_pad_s.is_empty():
				if near_pad_s.get("active_user") != null and near_pad_s["active_user"] != self:
					target_res = near_pad_s["active_user"]
				near_pad_s["jammed_timer"] = 8.0
				town_map.record_pad_interaction(near_pad_s, resident_name, "jammed")
			else:
				target_res = _find_nearest_other_resident(3.5)

			if target_res != null and target_res != self:
				var t_pos: Vector3 = target_res.global_position if target_res.is_inside_tree() else target_res.position
				var diff_s: Vector3 = t_pos - my_pos
				diff_s.y = 0.0
				var dir_s: Vector3 = diff_s.normalized() if diff_s.length() > 0.01 else Vector3(0, 0, 1)
				target_res.receive_shove(dir_s * 8.0, 25.0, self, true)

			if is_player:
				if not near_pad_s.is_empty():
					show_popup("Shock Tool: Pad Jammed (8s)!", Color(1.0, 0.58, 0.42))
				elif target_res != null:
					show_popup("Shock Tool: Hit %s (-25 Stam)!" % target_res.resident_name, Color(1.0, 0.58, 0.42))
				else:
					show_popup("Shock Tool (No Pad/Target in range)", Color(0.90, 0.75, 0.55))

	var was_witnessed: bool = game_manager.record_faction_ability_3d(self, town_map, all_residents)
	if was_witnessed and is_player:
		show_popup("Witnessed! Disturbance logged!", Color(1.0, 0.72, 0.32))

	return true

func _find_nearest_other_resident(max_r: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d: float = max_r
	var my_pos: Vector3 = global_position if is_inside_tree() else position
	for other in all_residents:
		if other == null or other == self or other.is_incapacitated:
			continue
		var o_pos: Vector3 = other.global_position if other.is_inside_tree() else other.position
		var d: float = my_pos.distance_to(o_pos)
		if d <= best_d:
			best_d = d
			best = other
	return best

func reset_to_spawn(pos: Vector3) -> void:
	position = pos
	spawn_position = pos
	velocity = Vector3.ZERO
	is_incapacitated = false
	exhaustion_timer = 0.0
	stamina = max_stamina
	is_channeling = false
	channel_progress = 0.0
	is_inspecting = false
	inspection_timer = 0.0
	if action_label != null:
		action_label.text = ""

func show_speech_bubble(text: String, duration: float = 4.5) -> void:
	if speech_label != null:
		speech_label.text = "\"%s\"" % text
		speech_label.modulate = Color(1.0, 0.98, 0.78)
	speech_timer = duration

func gather_at_council_ring(ring_pos: Vector3) -> void:
	cancel_channeling()
	cancel_inspection()
	is_incapacitated = false
	exhaustion_timer = 0.0
	stamina = max_stamina
	velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	position = ring_pos
	if mesh_root != null:
		var dir := (Vector3.ZERO - ring_pos).normalized()
		if dir.length_squared() > 0.01:
			mesh_root.rotation.y = atan2(-dir.x, -dir.z)

func walk_to_podium(podium_pos: Vector3 = Vector3(0.0, 0.0, 0.6)) -> void:
	cancel_channeling()
	cancel_inspection()
	velocity = Vector3.ZERO
	position = podium_pos
	if mesh_root != null:
		mesh_root.rotation.y = PI # Face south toward council assembly

func return_to_seat(seat_pos: Vector3) -> void:
	position = seat_pos
	velocity = Vector3.ZERO
	if mesh_root != null:
		var dir := (Vector3.ZERO - seat_pos).normalized()
		if dir.length_squared() > 0.01:
			mesh_root.rotation.y = atan2(-dir.x, -dir.z)
