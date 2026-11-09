extends Node3D

const MODE_SELECT_PATH := "res://scenes/ModeSelect.tscn"
const BrawlPlayerScript = preload("res://scripts/BrawlPlayer3D.gd")

var player: CharacterBody3D
var camera: Camera3D
var pause_overlay: PanelContainer
var return_to_modes_button: Button
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	_build_arena()
	_spawn_player()
	_setup_camera()
	_build_hud()

func _process(_delta: float) -> void:
	if camera != null and player != null:
		camera.global_position = player.global_position + Vector3(0.0, 26.0, 25.0)
		camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.09, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.62, 0.72)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "ArenaSun"
	sunlight.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sunlight.light_color = Color(0.78, 0.86, 1.0)
	sunlight.light_energy = 1.35
	sunlight.shadow_enabled = true
	add_child(sunlight)

func _build_arena() -> void:
	var world_root := Node3D.new()
	world_root.name = "Arena"
	add_child(world_root)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)
	_add_box(ground, "LaneFloor", Vector3(0.0, -0.3, 0.0), Vector3(66.0, 0.6, 32.0), Color(0.19, 0.22, 0.26), true, Vector3(66.0, 0.6, 32.0))

	_add_box(world_root, "CenterLane", Vector3(0.0, 0.02, 0.0), Vector3(60.0, 0.06, 12.0), Color(0.27, 0.30, 0.34))
	_add_box(world_root, "Centerline", Vector3(0.0, 0.065, 0.0), Vector3(60.0, 0.025, 0.10), Color(0.78, 0.72, 0.48), true)
	_add_box(world_root, "BlueBasePad", Vector3(-26.0, 0.08, 0.0), Vector3(9.0, 0.12, 15.0), Color(0.12, 0.30, 0.47), true)
	_add_box(world_root, "RedBasePad", Vector3(26.0, 0.08, 0.0), Vector3(9.0, 0.12, 15.0), Color(0.47, 0.18, 0.20), true)
	_add_collision_box(world_root, "NorthBoundary", Vector3(0.0, 0.65, -16.0), Vector3(66.0, 1.3, 0.7), Color(0.16, 0.19, 0.23))
	_add_collision_box(world_root, "SouthBoundary", Vector3(0.0, 0.65, 16.0), Vector3(66.0, 1.3, 0.7), Color(0.16, 0.19, 0.23))

	_add_collision_box(world_root, "NorthCoverWest", Vector3(-6.0, 0.7, -9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "NorthCoverEast", Vector3(7.0, 0.7, -9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "SouthCoverWest", Vector3(-7.0, 0.7, 9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "SouthCoverEast", Vector3(6.0, 0.7, 9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))

	_add_landmark(world_root, "BlueTurret", Vector3(-16.0, 0.0, 0.0), Color(0.18, 0.66, 0.96), "TURRET")
	_add_landmark(world_root, "RedTurret", Vector3(16.0, 0.0, 0.0), Color(0.96, 0.36, 0.34), "TURRET")
	_add_landmark(world_root, "BlueCore", Vector3(-28.0, 0.0, 0.0), Color(0.28, 0.78, 1.0), "BLUE CORE")
	_add_landmark(world_root, "RedCore", Vector3(28.0, 0.0, 0.0), Color(1.0, 0.42, 0.34), "RED CORE")

	_add_ground_ring(world_root, "CenterControlMarker", Vector3.ZERO, 4.0, Color(0.80, 0.72, 0.40))
	_add_ground_ring(world_root, "BlueSpawnMarker", Vector3(-22.0, 0.03, 0.0), 3.0, Color(0.20, 0.68, 0.98))
	_add_ground_ring(world_root, "RedSpawnMarker", Vector3(22.0, 0.03, 0.0), 3.0, Color(0.98, 0.35, 0.32))

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "BrawlPlayer"
	player.set_script(BrawlPlayerScript)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(-22.0, 0.0, 2.0)
	add_child(player)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "BrawlCamera"
	camera.current = true
	camera.position = player.position + Vector3(0.0, 26.0, 25.0)
	camera.fov = 52.0
	add_child(camera)
	camera.look_at(player.position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "BrawlHUD"
	add_child(hud)

	var title := Label.new()
	title.name = "StageLabel"
	title.text = "ONE-LANE BRAWL  |  STAGE 1 GRAYBOX"
	title.position = Vector2(24.0, 20.0)
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.86, 0.93, 1.0)
	hud.add_child(title)

	var controls := Label.new()
	controls.name = "ControlsLabel"
	controls.text = "Move: WASD / Arrow Keys    |    Esc: Pause"
	controls.position = Vector2(24.0, 54.0)
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(0.72, 0.82, 0.94)
	hud.add_child(controls)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause [Esc]"
	pause_button.position = Vector2(1240.0, 18.0)
	pause_button.custom_minimum_size = Vector2(160.0, 42.0)
	pause_button.pressed.connect(_toggle_pause)
	hud.add_child(pause_button)

	pause_overlay = PanelContainer.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_overlay.offset_left = -200.0
	pause_overlay.offset_top = -110.0
	pause_overlay.offset_right = 200.0
	pause_overlay.offset_bottom = 110.0
	pause_overlay.visible = false
	hud.add_child(pause_overlay)

	var pause_content := VBoxContainer.new()
	pause_content.add_theme_constant_override("separation", 12)
	pause_overlay.add_child(pause_content)

	var pause_title := Label.new()
	pause_title.text = "BRAWL PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 20)
	pause_content.add_child(pause_title)

	var resume_button := Button.new()
	resume_button.name = "ResumeButton"
	resume_button.text = "Resume"
	resume_button.pressed.connect(_toggle_pause)
	pause_content.add_child(resume_button)

	return_to_modes_button = Button.new()
	return_to_modes_button.name = "ReturnToModeSelectButton"
	return_to_modes_button.text = "Return to Mode Select"
	return_to_modes_button.pressed.connect(_return_to_mode_select)
	pause_content.add_child(return_to_modes_button)

func _toggle_pause() -> void:
	_paused = not _paused
	pause_overlay.visible = _paused
	get_tree().paused = _paused

func _return_to_mode_select() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(MODE_SELECT_PATH)
	if error != OK:
		push_error("Could not return to mode selection: %s" % error_string(error))

func _add_landmark(parent: Node3D, node_name: String, world_position: Vector3, tint: Color, label_text: String) -> void:
	var landmark := Node3D.new()
	landmark.name = node_name
	landmark.position = world_position
	parent.add_child(landmark)
	_add_cylinder(landmark, "Base", Vector3(0.0, 0.35, 0.0), 1.25, 0.7, Color(0.20, 0.23, 0.27))
	_add_cylinder(landmark, "Structure", Vector3(0.0, 1.5, 0.0), 0.72, 2.3, tint)
	_add_sphere(landmark, "Core", Vector3(0.0, 2.9, 0.0), 0.72, tint.lightened(0.25), true)
	var label := Label3D.new()
	label.name = "LandmarkLabel"
	label.text = label_text
	label.position = Vector3(0.0, 4.0, 0.0)
	label.font_size = 24
	label.outline_size = 5
	label.outline_modulate = Color(0.02, 0.03, 0.05, 0.98)
	label.modulate = tint.lightened(0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	landmark.add_child(label)

func _add_ground_ring(parent: Node3D, node_name: String, world_position: Vector3, radius: float, tint: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.6
	ring.material_override = material
	ring.position = world_position
	ring.rotation_degrees.x = 90.0
	parent.add_child(ring)

func _add_box(parent: Node3D, node_name: String, world_position: Vector3, size: Vector3, tint: Color, emissive: bool = false, collision_size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = world_position
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	if emissive:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.45
	instance.material_override = material
	parent.add_child(instance)
	if parent is StaticBody3D and collision_size != Vector3.ZERO:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = collision_size
		shape.shape = box_shape
		shape.position = world_position
		parent.add_child(shape)
	return instance

func _add_collision_box(parent: Node3D, node_name: String, world_position: Vector3, size: Vector3, tint: Color) -> void:
	_add_box(parent, node_name, world_position, size, tint)
	var body := StaticBody3D.new()
	body.name = node_name + "Collision"
	body.position = world_position
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	parent.add_child(body)

func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	instance.mesh = cylinder
	instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.25
	material.roughness = 0.72
	instance.material_override = material
	parent.add_child(instance)

func _add_sphere(parent: Node3D, node_name: String, local_position: Vector3, radius: float, tint: Color, emissive: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	instance.mesh = sphere
	instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	if emissive:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.2
	instance.material_override = material
	parent.add_child(instance)
