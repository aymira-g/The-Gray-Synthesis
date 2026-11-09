extends "res://scripts/BrawlCombatant3D.gd"

const HERO_KITS := {
	"garrick_cole": {"name": "Garrick Cole", "role": "Frontline", "color": Color(0.82, 0.48, 0.22), "max_health": 850.0, "damage": 48.0, "range": 3.4, "speed": 5.6},
	"nyx_calder": {"name": "Nyx Calder", "role": "Ranger", "color": Color(0.42, 0.58, 0.92), "max_health": 590.0, "damage": 54.0, "range": 8.0, "speed": 7.0},
	"mira_solis": {"name": "Mira Solis", "role": "Disruptor", "color": Color(0.22, 0.72, 0.76), "max_health": 670.0, "damage": 42.0, "range": 6.0, "speed": 6.2},
	"aris_thorne": {"name": "Dr. Aris Thorne", "role": "Support", "color": Color(0.68, 0.82, 0.78), "max_health": 700.0, "damage": 38.0, "range": 5.5, "speed": 6.0}
}

signal hero_changed(hero_name: String, hero_id: String)

@export var hero_id: String = "garrick_cole"
@export var is_bot: bool = false
@export var retreat_health_fraction: float = 0.30

var hero_name: String = ""
var combatant_name: String = ""
var role_name: String = ""
var move_speed: float = 6.0
var lane_direction: float = 1.0
var _fortify_remaining: float = 0.0
var _ability_cooldowns: Dictionary = {"Q": 0.0, "E": 0.0, "R": 0.0}
var _brain_think_remaining: float = 0.0
var _brain_target: Node3D
var mesh_root: Node3D
var _base_color: Color

func _ready() -> void:
	unit_type = "hero"
	_apply_hero_kit(hero_id)
	_build_hero()
	super._ready()

func _apply_hero_kit(selected_hero_id: String) -> void:
	var kit: Dictionary = HERO_KITS.get(selected_hero_id, HERO_KITS["garrick_cole"])
	hero_name = String(kit["name"])
	role_name = String(kit["role"])
	_base_color = kit["color"]
	max_health = float(kit["max_health"])
	max_mana = 100.0
	attack_damage = float(kit["damage"])
	attack_range = float(kit["range"])
	attack_cooldown = 0.78
	move_speed = float(kit["speed"])
	health_bar_height = 2.45
	mana_regen_per_second = 5.5

func select_hero(selected_hero_id: String) -> bool:
	if not HERO_KITS.has(selected_hero_id):
		return false
	var health_fraction := current_health / maxf(max_health, 1.0)
	var mana_fraction := current_mana / maxf(max_mana, 1.0)
	hero_id = selected_hero_id
	_apply_hero_kit(hero_id)
	current_health = max_health * health_fraction
	current_mana = max_mana * mana_fraction
	if mesh_root != null:
		var body := mesh_root.get_node_or_null("Body") as MeshInstance3D
		if body != null:
			body.material_override = _make_hero_material(_base_color)
		var nameplate := mesh_root.get_node_or_null("HeroNameplate") as Label3D
		if nameplate != null:
			nameplate.text = hero_name
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	hero_changed.emit(hero_name, hero_id)
	return true

func _process(delta: float) -> void:
	super._process(delta)
	for ability in _ability_cooldowns.keys():
		_ability_cooldowns[ability] = maxf(0.0, float(_ability_cooldowns[ability]) - delta)
	_fortify_remaining = maxf(0.0, _fortify_remaining - delta)
	damage_reduction = 0.45 if _fortify_remaining > 0.0 else 0.0
	if is_bot:
		_brain_think_remaining -= delta
		if _brain_think_remaining <= 0.0:
			_brain_think_remaining = 0.22
			_run_bot_brain()

func _physics_process(_delta: float) -> void:
	if _defeated:
		return
	if stunned_remaining > 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if is_bot:
		_bot_move()

func take_damage(amount: float, source: Node = null) -> void:
	super.take_damage(amount, source)

func use_ability(ability: String) -> bool:
	var key := ability.to_upper()
	if not HERO_KITS.has(hero_id) or not _ability_cooldowns.has(key) or float(_ability_cooldowns[key]) > 0.0:
		return false
	var mana_cost := 18.0 if key != "R" else 32.0
	if current_mana < mana_cost:
		return false
	current_mana -= mana_cost
	mana_changed.emit(current_mana, max_mana)
	_ability_cooldowns[key] = 5.0 if key != "R" else 15.0
	match hero_id:
		"garrick_cole":
			_use_garrick_ability(key)
		"nyx_calder":
			_use_nyx_ability(key)
		"mira_solis":
			_use_mira_ability(key)
		"aris_thorne":
			_use_aris_ability(key)
	return true

func get_ability_cooldown(ability: String) -> float:
	return float(_ability_cooldowns.get(ability.to_upper(), 0.0))

func get_nearest_enemy(max_distance: float = INF) -> Node3D:
	var nearest: Node3D
	var nearest_distance := max_distance
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) == team_id:
			continue
		var distance := _planar_distance_to(candidate)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _run_bot_brain() -> void:
	if _defeated:
		return
	var health_fraction := current_health / maxf(max_health, 1.0)
	if health_fraction <= retreat_health_fraction:
		_brain_target = null
		return
	_brain_target = get_nearest_enemy(attack_range + 4.5)
	if _brain_target != null:
		var distance := _planar_distance_to(_brain_target)
		if distance <= attack_range:
			try_basic_attack(_brain_target)
		_try_bot_abilities(distance)
	else:
		_try_support_ability()

func _bot_move() -> void:
	var health_fraction := current_health / maxf(max_health, 1.0)
	var destination := Vector3(-24.0 if team_id == "blue" else 24.0, 0.0, global_position.z * 0.5)
	if health_fraction > retreat_health_fraction and _brain_target != null and is_instance_valid(_brain_target):
		var target_distance := _planar_distance_to(_brain_target)
		if target_distance <= attack_range * 0.82:
			velocity = Vector3.ZERO
			move_and_slide()
			return
		destination = _brain_target.global_position
	elif health_fraction > retreat_health_fraction:
		destination = Vector3(24.0 if team_id == "blue" else -24.0, 0.0, global_position.z * 0.55)
	_move_toward(destination, move_speed * (0.62 if health_fraction <= retreat_health_fraction else 1.0))

func _try_bot_abilities(target_distance: float) -> void:
	if hero_id == "aris_thorne":
		_try_support_ability()
		if target_distance <= 3.5:
			use_ability("E")
		if target_distance <= 4.5 and get_ability_cooldown("R") <= 0.0:
			use_ability("R")
	elif target_distance <= attack_range:
		if get_ability_cooldown("Q") <= 0.0:
			use_ability("Q")
		elif get_ability_cooldown("E") <= 0.0 and target_distance <= 3.5:
			use_ability("E")
		elif get_ability_cooldown("R") <= 0.0 and target_distance <= 7.0:
			use_ability("R")

func _try_support_ability() -> void:
	if hero_id != "aris_thorne":
		return
	var ally := _get_neediest_ally(5.5)
	if ally != null and float(ally.get("current_health")) / maxf(float(ally.get("max_health")), 1.0) < 0.62:
		use_ability("Q")

func _get_neediest_ally(max_distance: float) -> Node3D:
	var neediest: Node3D
	var lowest_fraction := 0.62
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) != team_id or String(candidate.get("unit_type")) != "hero":
			continue
		var distance := _planar_distance_to(candidate)
		if distance > max_distance:
			continue
		var fraction := float(candidate.get("current_health")) / maxf(float(candidate.get("max_health")), 1.0)
		if fraction < lowest_fraction:
			lowest_fraction = fraction
			neediest = candidate
	return neediest

func _use_garrick_ability(ability: String) -> void:
	match ability:
		"Q":
			_damage_enemies_in_radius(4.5, attack_damage * 1.65)
		"E":
			_fortify_remaining = 3.5
			damage_reduction = 0.45
		"R":
			_damage_enemies_in_radius(6.0, attack_damage * 2.3, 0.7)

func _use_nyx_ability(ability: String) -> void:
	match ability:
		"Q":
			var target := get_nearest_enemy(14.0)
			if target != null:
				_deal_damage(target, attack_damage * 1.8)
		"E":
			global_position += Vector3(-lane_direction * 3.0, 0.0, 0.0)
			velocity = Vector3.ZERO
		"R":
			for target in _get_enemies_in_radius(14.0):
				_deal_damage(target, attack_damage * 1.35)

func _use_mira_ability(ability: String) -> void:
	match ability:
		"Q":
			_damage_enemies_in_radius(5.5, attack_damage * 1.25, 2.0)
		"E":
			_damage_enemies_in_radius(7.0, attack_damage * 0.75, 3.5)
		"R":
			_damage_enemies_in_radius(9.0, attack_damage * 1.8, 2.5)

func _use_aris_ability(ability: String) -> void:
	match ability:
		"Q":
			_heal_allies_in_radius(6.0, 150.0)
		"E":
			var target := get_nearest_enemy(5.0)
			if target != null:
				target.set("stunned_remaining", 1.5)
				_deal_damage(target, attack_damage * 0.8)
		"R":
			_heal_allies_in_radius(10.0, 230.0)

func _get_enemies_in_radius(radius: float) -> Array[Node3D]:
	var enemies: Array[Node3D] = []
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) == team_id:
			continue
		if _planar_distance_to(candidate) <= radius:
			enemies.append(candidate)
	return enemies

func _damage_enemies_in_radius(radius: float, amount: float, slow_duration: float = 0.0) -> void:
	for target in _get_enemies_in_radius(radius):
		_deal_damage(target, amount)
		if slow_duration > 0.0 and target is CharacterBody3D:
			target.set("slowed_remaining", maxf(float(target.get("slowed_remaining")), slow_duration))

func _deal_damage(target: Node3D, amount: float) -> void:
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(amount * damage_multiplier, self)
		if String(target.get("unit_type")) == "hero":
			var arena := get_tree().get_first_node_in_group("brawl_arena")
			if arena != null and arena.has_method("notify_enemy_hero_attacked"):
				arena.notify_enemy_hero_attacked(self)

func _heal_allies_in_radius(radius: float, amount: float) -> void:
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if not is_instance_valid(candidate) or String(candidate.get("team_id")) != team_id:
			continue
		if String(candidate.get("unit_type")) != "hero" or _planar_distance_to(candidate) > radius:
			continue
		var old_health := float(candidate.get("current_health"))
		var max_value := float(candidate.get("max_health"))
		candidate.set("current_health", minf(max_value, old_health + amount))
		if candidate.has_method("_update_health_bar"):
			candidate._update_health_bar()
		candidate.health_changed.emit(float(candidate.get("current_health")), max_value)

func _move_toward(destination: Vector3, speed: float) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity = direction * speed * (0.55 if slowed_remaining > 0.0 else 1.0)
		if mesh_root != null:
			mesh_root.rotation.y = atan2(-direction.x, -direction.z)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func _on_defeated(_source: Node) -> void:
	visible = false
	set_physics_process(false)
	remove_from_group("brawl_units")
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree():
		return
	global_position = Vector3(-23.0 if team_id == "blue" else 23.0, 0.0, randf_range(-2.0, 2.0))
	current_health = max_health
	current_mana = max_mana
	damage_reduction = 0.0
	_defeated = false
	visible = true
	set_physics_process(true)
	add_to_group("brawl_units")
	if collision != null:
		collision.set_deferred("disabled", false)
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

func _build_hero() -> void:
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
	var team_color := Color(0.20, 0.62, 0.95) if team_id == "blue" else Color(0.88, 0.25, 0.28)
	_add_box_visual("Body", Vector3(0.0, 1.0, 0.0), Vector3(0.66, 0.9, 0.42), _base_color)
	_add_sphere_visual("Head", Vector3(0.0, 1.72, 0.0), 0.25, Color(0.78, 0.70, 0.60))
	_add_box_visual("TeamStripe", Vector3(0.0, 1.30, 0.23), Vector3(0.54, 0.12, 0.05), team_color, true)
	var nameplate := Label3D.new()
	nameplate.name = "HeroNameplate"
	nameplate.text = "%s  |  %s" % [combatant_name if not combatant_name.is_empty() else hero_name, role_name]
	nameplate.position.y = 2.75
	nameplate.font_size = 20
	nameplate.outline_size = 4
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_root.add_child(nameplate)

func _add_box_visual(node_name: String, local_position: Vector3, size: Vector3, tint: Color, emissive: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	mesh_instance.material_override = _make_hero_material(tint, emissive)
	mesh_root.add_child(mesh_instance)

func _add_sphere_visual(node_name: String, local_position: Vector3, radius: float, tint: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.position = local_position
	mesh_instance.material_override = _make_hero_material(tint)
	mesh_root.add_child(mesh_instance)

func _make_hero_material(tint: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.76
	if emissive:
		material.emission_enabled = true
		material.emission = tint
	return material
