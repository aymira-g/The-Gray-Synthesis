extends CharacterBody3D

@export var move_speed: float = 7.0

var move_input: Vector2 = Vector2.ZERO
var mesh_root: Node3D

func _ready() -> void:
	_build_character()

func _physics_process(_delta: float) -> void:
	move_input = Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	move_from_input(move_input)

func move_from_input(input_direction: Vector2) -> void:
	var direction := Vector3(input_direction.x, 0.0, input_direction.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = 0.0
	move_and_slide()
	if direction.length_squared() > 0.0 and mesh_root != null:
		mesh_root.rotation.y = atan2(-direction.x, -direction.z)

func _build_character() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.93
	add_child(collision)

	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	_add_box_visual("Body", Vector3(0.0, 1.0, 0.0), Vector3(0.62, 0.85, 0.38), Color(0.18, 0.62, 0.92))
	_add_sphere_visual("Head", Vector3(0.0, 1.72, 0.0), 0.25, Color(0.78, 0.70, 0.60))
	_add_box_visual("TeamStripe", Vector3(0.0, 1.30, 0.205), Vector3(0.52, 0.12, 0.04), Color(0.62, 0.90, 1.0), true)

func _add_box_visual(node_name: String, local_position: Vector3, size: Vector3, tint: Color, emissive: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	if emissive:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.6
	mesh_instance.material_override = material
	mesh_root.add_child(mesh_instance)

func _add_sphere_visual(node_name: String, local_position: Vector3, radius: float, tint: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.86
	mesh_instance.material_override = material
	mesh_root.add_child(mesh_instance)
