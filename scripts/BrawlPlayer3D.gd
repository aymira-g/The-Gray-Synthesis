extends "res://scripts/BrawlHero3D.gd"

var move_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	is_bot = false
	super._ready()

func _physics_process(_delta: float) -> void:
	move_input = Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	move_from_input(move_input)

func move_from_input(input_direction: Vector2) -> void:
	if _defeated:
		velocity = Vector3.ZERO
		return
	var direction := Vector3(input_direction.x, 0.0, input_direction.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	if stunned_remaining > 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	velocity.x = direction.x * move_speed * (0.55 if slowed_remaining > 0.0 else 1.0)
	velocity.z = direction.z * move_speed * (0.55 if slowed_remaining > 0.0 else 1.0)
	velocity.y = 0.0
	move_and_slide()
	if direction.length_squared() > 0.0 and mesh_root != null:
		mesh_root.rotation.y = atan2(-direction.x, -direction.z)

func _unhandled_input(event: InputEvent) -> void:
	if _defeated:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		attack_nearest_enemy()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		use_ability("Q")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		use_ability("E")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		use_ability("R")
	elif allow_hero_selection and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				select_hero("garrick_cole")
			KEY_2:
				select_hero("nyx_calder")
			KEY_3:
				select_hero("mira_solis")
			KEY_4:
				select_hero("aris_thorne")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack_nearest_enemy()

func attack_nearest_enemy() -> bool:
	var target: Node3D
	var closest_distance := attack_range
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) == team_id:
			continue
		var offset: Vector3 = global_position - candidate.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < closest_distance:
			target = candidate
			closest_distance = distance
	if target == null:
		return false
	return try_basic_attack(target)
