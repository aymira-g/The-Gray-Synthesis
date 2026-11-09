extends CharacterBody3D

# ==============================================================================
# The Gray Synthesis - 3D Bot Controller
# ==============================================================================
# Navigates 3D waypoints around obstacle walls, detects arrival at task pads,
# channels tasks via execute_task(), and acts as an observer for witness checks.
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

var game_manager: Node
var slice_map: Node

var resident_id: int = 2
var resident_name: String = "Bot_Mara"
var secret_role: String = "civilian"
var civic_job: String = "Crop Tender"
var is_player: bool = false
var is_incapacitated: bool = false

var move_speed: float = 4.8

# Waypoints routing around the ObstacleWall to reach the Greenhouse Crop Pad
var waypoints: Array[Vector3] = [
	Vector3(8.0, 0.0, 2.0),
	Vector3(8.0, 0.0, 6.0),
	Vector3(8.0, 0.0, 10.0) # TaskPad_Greenhouse position
]
var current_wp_idx: int = 0
var patrol_forward: bool = true

# Channeling state
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_duration: float = 2.0
var tasks_completed_count: int = 0

var name_label: Label3D
var action_label: Label3D
var mesh_root: Node3D
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
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)

func _setup_visuals() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)

	# Torso (Weathered Slate Gray)
	var torso := CapsuleMesh.new()
	torso.radius = 0.36
	torso.height = 1.15
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.28, 0.32, 0.36)
	var t_inst := MeshInstance3D.new()
	t_inst.mesh = torso
	t_inst.material_override = t_mat
	t_inst.position = Vector3(0.0, 0.95, 0.0)
	mesh_root.add_child(t_inst)

	# Head
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.52
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.72, 0.62, 0.54)
	var h_inst := MeshInstance3D.new()
	h_inst.mesh = head
	h_inst.material_override = h_mat
	h_inst.position = Vector3(0.0, 1.68, 0.0)
	mesh_root.add_child(h_inst)

	# Sickle tool prop
	var handle := CylinderMesh.new()
	handle.top_radius = 0.04
	handle.bottom_radius = 0.04
	handle.height = 0.45
	var h_prop_mat := StandardMaterial3D.new()
	h_prop_mat.albedo_color = Color(0.42, 0.32, 0.22)
	var h_prop_inst := MeshInstance3D.new()
	h_prop_inst.mesh = handle
	h_prop_inst.material_override = h_prop_mat
	h_prop_inst.position = Vector3(0.38, 0.75, 0.12)
	h_prop_inst.rotation_degrees.z = 45.0
	mesh_root.add_child(h_prop_inst)

	# Name Label
	name_label = Label3D.new()
	name_label.text = "BOT (MARA)\n[Crop Tender • Civilian]"
	name_label.font_size = 20
	name_label.modulate = Color(0.85, 0.92, 1.0)
	name_label.outline_size = 3
	name_label.outline_modulate = Color(0, 0, 0, 0.9)
	name_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	name_label.position = Vector3(0.0, 2.30, 0.0)
	add_child(name_label)

	# Action Label
	action_label = Label3D.new()
	action_label.text = "Patrolling"
	action_label.font_size = 20
	action_label.modulate = Color(0.55, 0.95, 0.65)
	action_label.outline_size = 3
	action_label.outline_modulate = Color(0, 0, 0, 0.9)
	action_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	action_label.position = Vector3(0.0, 2.70, 0.0)
	add_child(action_label)

func _physics_process(delta: float) -> void:
	if is_incapacitated:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_channeling:
		_process_channeling(delta)
	else:
		_process_navigation(delta)

func _process_navigation(delta: float) -> void:
	if waypoints.is_empty():
		return

	var target_wp := waypoints[current_wp_idx]
	var diff := target_wp - global_position
	diff.y = 0.0 # Maintain ground plane

	if diff.length() < 0.6:
		# Check if reached target task pad (Waypoint 2 is Greenhouse pad!)
		if current_wp_idx == 2 and patrol_forward:
			_start_task_channel()
			return

		# Advance waypoint
		if patrol_forward:
			current_wp_idx += 1
			if current_wp_idx >= waypoints.size():
				current_wp_idx = waypoints.size() - 2
				patrol_forward = false
		else:
			current_wp_idx -= 1
			if current_wp_idx < 0:
				current_wp_idx = 1
				patrol_forward = true

	var dir := diff.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if dir != Vector3.ZERO and mesh_root != null:
		var target_yaw: float = atan2(-dir.x, -dir.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_yaw, delta * 8.0)

	if action_label != null:
		action_label.text = "Navigating to Waypoint %d" % current_wp_idx

func _start_task_channel() -> void:
	is_channeling = true
	channel_timer = 0.0
	velocity = Vector3.ZERO
	if action_label != null:
		action_label.text = "Channeling Crop Bed..."
		action_label.modulate = Color(0.45, 0.95, 0.60)

func _process_channeling(delta: float) -> void:
	channel_timer += delta
	var pct := int((channel_timer / channel_duration) * 100.0)

	if action_label != null:
		action_label.text = "Tending Crops: %d%%" % pct

	if channel_timer >= channel_duration:
		is_channeling = false
		channel_timer = 0.0
		tasks_completed_count += 1

		# Real execute_task call!
		if slice_map != null:
			slice_map.execute_pad_channel("greenhouse", resident_name, false)

		if action_label != null:
			action_label.text = "Crops Tended! (+7 Stability)"

		# Turn around and patrol back
		patrol_forward = false
		current_wp_idx = 1
