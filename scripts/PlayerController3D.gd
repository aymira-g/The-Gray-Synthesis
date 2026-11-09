extends CharacterBody3D

# ==============================================================================
# The Gray Synthesis - 3D Player Controller
# ==============================================================================
# Top-down isometric 3D movement, sprint/stamina, collision, task channeling via [E],
# and faction ability trigger via [C].
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

var game_manager: Node
var slice_map: Node

var resident_id: int = 1
var resident_name: String = "Player"
var secret_role: String = "ecology"
var civic_job: String = "Pump Technician"
var is_player: bool = true
var is_incapacitated: bool = false

# Movement & Stamina
var walk_speed: float = 6.0
var sprint_speed: float = 9.2
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_drain: float = 28.0
var stamina_recovery: float = 20.0
var is_sprinting: bool = false

# Task Channeling
var active_pad: Dictionary = {}
var active_pad_name: String = "None"
var channel_progress: float = 0.0
var channel_duration: float = 2.0
var is_channeling: bool = false

var channel_label: Label3D
var name_label: Label3D
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

	# Torso (Dusty Canvas Khaki)
	var torso := CapsuleMesh.new()
	torso.radius = 0.38
	torso.height = 1.15
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.38, 0.35, 0.30)
	var t_inst := MeshInstance3D.new()
	t_inst.mesh = torso
	t_inst.material_override = t_mat
	t_inst.position = Vector3(0.0, 0.95, 0.0)
	mesh_root.add_child(t_inst)

	# Head
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.55
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.75, 0.65, 0.55)
	var h_inst := MeshInstance3D.new()
	h_inst.mesh = head
	h_inst.material_override = h_mat
	h_inst.position = Vector3(0.0, 1.70, 0.0)
	mesh_root.add_child(h_inst)

	# Pipe wrench on back
	var wrench := BoxMesh.new()
	wrench.size = Vector3(0.14, 0.95, 0.20)
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.55, 0.62, 0.70)
	w_mat.metallic = 0.85
	var w_inst := MeshInstance3D.new()
	w_inst.mesh = wrench
	w_inst.material_override = w_mat
	w_inst.position = Vector3(0.30, 1.15, -0.32)
	w_inst.rotation_degrees = Vector3(25.0, 15.0, -20.0)
	mesh_root.add_child(w_inst)

	# Overhead Identity Label
	name_label = Label3D.new()
	name_label.text = "PLAYER (YOU)\n[Pump Technician]"
	name_label.font_size = 20
	name_label.modulate = Color(1.0, 0.95, 0.65)
	name_label.outline_size = 3
	name_label.outline_modulate = Color(0, 0, 0, 0.9)
	name_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	name_label.position = Vector3(0.0, 2.30, 0.0)
	add_child(name_label)

	# Channeling Progress Label
	channel_label = Label3D.new()
	channel_label.text = ""
	channel_label.font_size = 22
	channel_label.modulate = Color(0.45, 0.95, 0.65)
	channel_label.outline_size = 3
	channel_label.outline_modulate = Color(0, 0, 0, 0.9)
	channel_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	channel_label.position = Vector3(0.0, 2.70, 0.0)
	channel_label.visible = false
	add_child(channel_label)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_channeling(delta)

func _handle_movement(delta: float) -> void:
	var move_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	# Sprint handling
	is_sprinting = (Input.is_key_pressed(KEY_SHIFT) and move_vec != Vector2.ZERO and stamina > 5.0)
	var cur_speed: float = sprint_speed if is_sprinting else walk_speed

	if is_sprinting:
		stamina = maxf(0.0, stamina - stamina_drain * delta)
	else:
		stamina = minf(max_stamina, stamina + stamina_recovery * delta)

	# Top-down isometric projection
	var move_3d := Vector3.ZERO
	if move_vec != Vector2.ZERO:
		move_vec = move_vec.normalized()
		# Map 2D input to 3D XZ ground plane
		move_3d.x = move_vec.x
		move_3d.z = move_vec.y

	velocity.x = move_3d.x * cur_speed
	velocity.z = move_3d.z * cur_speed

	# Gravity / Ground clamp
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Face movement direction
	if move_3d != Vector3.ZERO and mesh_root != null:
		var target_yaw: float = atan2(-move_3d.x, -move_3d.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_yaw, delta * 12.0)

func _handle_channeling(delta: float) -> void:
	if slice_map == null:
		return

	# Detect interactive task pad at player position
	active_pad = slice_map.get_task_pad_at(global_position)
	active_pad_name = active_pad.get("name", "None")

	var holding_e := Input.is_key_pressed(KEY_E)

	if not active_pad.is_empty() and holding_e:
		is_channeling = true
		channel_progress += delta
		var pct := int((channel_progress / channel_duration) * 100.0)

		if channel_label != null:
			channel_label.text = "Channeling %s: %d%%" % [active_pad["name"], pct]
			channel_label.visible = true

		if channel_progress >= channel_duration:
			# Complete task via real execute_task API!
			channel_progress = 0.0
			is_channeling = false
			if channel_label != null:
				channel_label.text = "TASK COMPLETED!"
			var task_type: String = String(active_pad.get("task_type", "pump"))
			slice_map.execute_pad_channel(task_type, resident_name, true)
	else:
		if is_channeling:
			channel_progress = 0.0
			is_channeling = false
			if channel_label != null:
				channel_label.visible = false
		elif channel_label != null:
			channel_label.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			# Trigger Faction Ability (Witness check!)
			trigger_faction_ability()

func trigger_faction_ability() -> bool:
	if game_manager == null or slice_map == null:
		return false
	var residents: Array = game_manager.get("session_residents") if game_manager.get("session_residents") != null else [self]
	# Real explicit 3D faction ability entry point!
	var witnessed: bool = game_manager.record_faction_ability_3d(self, slice_map, residents)
	return witnessed
