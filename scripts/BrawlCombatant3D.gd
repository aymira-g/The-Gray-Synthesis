extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal mana_changed(current_mana: float, maximum_mana: float)
signal defeated(combatant: Node)

@export var team_id: String = "blue"
@export var unit_type: String = "unit"
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var attack_damage: float = 20.0
@export var attack_range: float = 2.8
@export var attack_cooldown: float = 0.8
@export var health_bar_height: float = 2.2
@export var mana_regen_per_second: float = 4.0
@export var damage_multiplier: float = 1.0

var current_health: float = 100.0
var current_mana: float = 100.0
var attack_cooldown_remaining: float = 0.0
var slowed_remaining: float = 0.0
var stunned_remaining: float = 0.0
var damage_reduction: float = 0.0
var health_bar_fill: MeshInstance3D
var _defeated: bool = false

func _ready() -> void:
	current_health = max_health
	current_mana = max_mana
	add_to_group("brawl_units")
	_build_health_bar()
	health_changed.emit(current_health, max_health)

func _process(delta: float) -> void:
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	slowed_remaining = maxf(0.0, slowed_remaining - delta)
	stunned_remaining = maxf(0.0, stunned_remaining - delta)
	var previous_mana := current_mana
	current_mana = minf(max_mana, current_mana + mana_regen_per_second * delta)
	if not is_equal_approx(previous_mana, current_mana):
		mana_changed.emit(current_mana, max_mana)

func can_attack_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or _defeated:
		return false
	if not target.is_in_group("brawl_units") or not target.has_method("take_damage"):
		return false
	if String(target.get("team_id")) == team_id:
		return false
	return _planar_distance_to(target) <= attack_range

func try_basic_attack(target: Node3D) -> bool:
	if attack_cooldown_remaining > 0.0 or not can_attack_target(target):
		return false
	attack_cooldown_remaining = attack_cooldown
	target.take_damage(attack_damage * damage_multiplier, self)
	if String(target.get("unit_type")) == "hero":
		var arena := get_tree().get_first_node_in_group("brawl_arena")
		if arena != null and arena.has_method("notify_enemy_hero_attacked"):
			arena.notify_enemy_hero_attacked(self)
	return true

func take_damage(amount: float, source: Node = null) -> void:
	if _defeated or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount * (1.0 - damage_reduction))
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	var arena := get_tree().get_first_node_in_group("brawl_arena")
	if arena != null and arena.has_method("show_damage_number"):
		arena.show_damage_number(self, amount, Color(1.0, 0.82, 0.68))
	if current_health <= 0.0:
		_defeated = true
		defeated.emit(self)
		_on_defeated(source)

func _on_defeated(_source: Node) -> void:
	queue_free()

func _planar_distance_to(target: Node3D) -> float:
	var offset := global_position - target.global_position
	offset.y = 0.0
	return offset.length()

func _build_health_bar() -> void:
	var root := Node3D.new()
	root.name = "HealthBar"
	root.position.y = health_bar_height
	root.set_as_top_level(false)
	add_child(root)

	var background := MeshInstance3D.new()
	background.name = "Background"
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(1.15, 0.11, 0.035)
	background.mesh = background_mesh
	background.material_override = _make_bar_material(Color(0.07, 0.08, 0.10))
	root.add_child(background)

	health_bar_fill = MeshInstance3D.new()
	health_bar_fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.08, 0.07, 0.04)
	health_bar_fill.mesh = fill_mesh
	health_bar_fill.position.z = -0.025
	health_bar_fill.material_override = _make_bar_material(Color(0.24, 0.88, 0.46))
	root.add_child(health_bar_fill)
	_update_health_bar()

func _update_health_bar() -> void:
	if health_bar_fill == null:
		return
	var fraction := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	health_bar_fill.scale.x = fraction
	health_bar_fill.position.x = -0.54 * (1.0 - fraction)

func _make_bar_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
