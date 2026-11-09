extends "res://scripts/BrawlCombatant3D.gd"

@export var move_speed: float = 2.4
@export var aggro_range: float = 5.0
@export var minion_attack_range: float = 1.65
@export var minion_attack_cooldown: float = 1.25
@export var minion_attack_damage: float = 10.0

var lane_direction: float = 1.0
var mesh_root: Node3D

func _ready() -> void:
	unit_type = "minion"
	max_health = 90.0
	attack_damage = minion_attack_damage
	attack_range = minion_attack_range
	attack_cooldown = minion_attack_cooldown
	health_bar_height = 1.55
	mana_regen_per_second = 0.0
	super._ready()
	_build_minion()

func _physics_process(_delta: float) -> void:
	if _defeated:
		return
	if stunned_remaining > 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if (lane_direction > 0.0 and global_position.x >= 25.0) or (lane_direction < 0.0 and global_position.x <= -25.0):
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var target := _find_nearby_enemy()
	if target != null:
		var distance := _planar_distance_to(target)
		if distance <= attack_range:
			velocity = Vector3.ZERO
			try_basic_attack(target)
			move_and_slide()
			return
		if distance <= aggro_range:
			_move_toward(target.global_position)
			return
	_move_toward(global_position + Vector3(lane_direction, 0.0, 0.0))

func _find_nearby_enemy() -> Node3D:
	var closest: Node3D
	var closest_distance := aggro_range
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) == team_id:
			continue
		var distance := _planar_distance_to(candidate)
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance
	return closest

func _move_toward(destination: Vector3) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity = direction * move_speed * (0.55 if slowed_remaining > 0.0 else 1.0)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func _build_minion() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.25
	collision.shape = capsule
	collision.position.y = 0.63
	add_child(collision)

	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	var tint := Color(0.24, 0.70, 0.98) if team_id == "blue" else Color(0.98, 0.38, 0.34)
	_add_minion_box("Body", Vector3(0.0, 0.67, 0.0), Vector3(0.48, 0.62, 0.34), tint)
	_add_minion_sphere("Head", Vector3(0.0, 1.16, 0.0), 0.2, tint.lightened(0.22))
	_add_minion_box("TeamMark", Vector3(0.0, 0.82, 0.18), Vector3(0.3, 0.08, 0.035), Color(0.86, 0.94, 1.0), true)

func _add_minion_box(node_name: String, local_position: Vector3, size: Vector3, tint: Color, emissive: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	mesh_instance.material_override = _make_minion_material(tint, emissive)
	mesh_root.add_child(mesh_instance)

func _add_minion_sphere(node_name: String, local_position: Vector3, radius: float, tint: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.position = local_position
	mesh_instance.material_override = _make_minion_material(tint)
	mesh_root.add_child(mesh_instance)

func _make_minion_material(tint: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	if emissive:
		material.emission_enabled = true
		material.emission = tint
	return material
