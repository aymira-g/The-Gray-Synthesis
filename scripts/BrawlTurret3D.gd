extends Node3D

@export var team_id: String = "blue"
@export var attack_range: float = 10.0
@export var attack_damage: float = 18.0
@export var attack_cooldown: float = 1.2
@export var minion_support_radius: float = 8.0
@export var unsupported_damage_multiplier: float = 0.35

var unit_type: String = "turret"
var max_health: float = 500.0
var current_health: float = 500.0
var attack_cooldown_remaining: float = 0.0
var target: Node3D
var health_bar_fill: MeshInstance3D
var hero_aggro_target: Node3D

func _ready() -> void:
	add_to_group("brawl_units")
	_build_turret_health_bar()

func _process(delta: float) -> void:
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	target = select_target()
	if target != null and attack_cooldown_remaining <= 0.0:
		fire_at(target)

func select_target() -> Node3D:
	if hero_aggro_target != null and is_instance_valid(hero_aggro_target):
		if String(hero_aggro_target.get("team_id")) != team_id and String(hero_aggro_target.get("unit_type")) == "hero" and _planar_distance_to(hero_aggro_target) <= attack_range:
			return hero_aggro_target
	hero_aggro_target = null
	var selected: Node3D
	var selected_distance := attack_range
	var selected_is_minion := false
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if String(candidate.get("team_id")) == team_id:
			continue
		if String(candidate.get("unit_type")) in ["turret", "core"]:
			continue
		var candidate_distance := _planar_distance_to(candidate)
		if candidate_distance > attack_range:
			continue
		var is_minion := String(candidate.get("unit_type")) == "minion"
		if selected == null or (is_minion and not selected_is_minion) or (is_minion == selected_is_minion and candidate_distance < selected_distance):
			selected = candidate
			selected_distance = candidate_distance
			selected_is_minion = is_minion
	return selected

func notify_enemy_hero_attacked(attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("brawl_units"):
		return
	if String(attacker.get("team_id")) == team_id or String(attacker.get("unit_type")) != "hero":
		return
	if _planar_distance_to(attacker) <= attack_range:
		hero_aggro_target = attacker

func fire_at(victim: Node3D) -> bool:
	if victim == null or not is_instance_valid(victim) or not victim.is_in_group("brawl_units"):
		return false
	if String(victim.get("team_id")) == team_id or _planar_distance_to(victim) > attack_range:
		return false
	if attack_cooldown_remaining > 0.0:
		return false
	attack_cooldown_remaining = attack_cooldown
	victim.take_damage(attack_damage, self)
	_spawn_projectile(victim)
	return true

func take_damage(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var applied_damage := amount
	var arena := get_tree().get_first_node_in_group("brawl_arena")
	if arena == null or not arena.has_attacking_minion_support(self, source, minion_support_radius):
		applied_damage *= unsupported_damage_multiplier
	current_health = maxf(0.0, current_health - applied_damage)
	_update_turret_health_bar()
	if arena != null and arena.has_method("show_damage_number"):
		arena.show_damage_number(self, applied_damage, Color(1.0, 0.82, 0.68))
	if current_health <= 0.0:
		visible = false
		set_process(false)
		remove_from_group("brawl_units")
		var collision := get_node_or_null("CollisionShape3D")
		if collision != null:
			collision.set_deferred("disabled", true)
		if arena != null and arena.has_method("notify_turret_destroyed"):
			arena.notify_turret_destroyed(self, source)

func _planar_distance_to(other: Node3D) -> float:
	var offset := global_position - other.global_position
	offset.y = 0.0
	return offset.length()

func _build_turret_health_bar() -> void:
	var root := Node3D.new()
	root.name = "TurretHealthBar"
	root.position.y = 4.6
	add_child(root)
	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(2.0, 0.16, 0.05)
	background.mesh = background_mesh
	background.material_override = _make_bar_material(Color(0.07, 0.08, 0.10))
	root.add_child(background)
	health_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.9, 0.11, 0.055)
	health_bar_fill.mesh = fill_mesh
	health_bar_fill.position.z = -0.03
	health_bar_fill.material_override = _make_bar_material(Color(0.30, 0.88, 0.52))
	root.add_child(health_bar_fill)
	_update_turret_health_bar()

func _update_turret_health_bar() -> void:
	if health_bar_fill == null:
		return
	var fraction := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	health_bar_fill.scale.x = fraction
	health_bar_fill.position.x = -0.95 * (1.0 - fraction)

func _spawn_projectile(victim: Node3D) -> void:
	var arena := get_tree().get_first_node_in_group("brawl_arena")
	if arena != null and arena.has_method("spawn_turret_projectile"):
		arena.spawn_turret_projectile(self, victim)

func _make_bar_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
