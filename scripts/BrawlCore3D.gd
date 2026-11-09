extends Node3D

@export var team_id: String = "blue"
@export var max_health: float = 1800.0
@export var minion_support_radius: float = 8.0
@export var unsupported_damage_multiplier: float = 0.35

var unit_type: String = "core"
var current_health: float = 1800.0
var health_bar_fill: MeshInstance3D
var _destroyed: bool = false

func _ready() -> void:
	current_health = max_health
	add_to_group("brawl_units")
	_build_core_health_bar()

func take_damage(amount: float, source: Node = null) -> void:
	if _destroyed or amount <= 0.0:
		return
	var applied_damage := amount
	var arena := get_tree().get_first_node_in_group("brawl_arena")
	if arena == null or not arena.has_attacking_minion_support(self, source, minion_support_radius):
		applied_damage *= unsupported_damage_multiplier
	current_health = maxf(0.0, current_health - applied_damage)
	_update_core_health_bar()
	if arena != null and arena.has_method("show_damage_number"):
		arena.show_damage_number(self, applied_damage, Color(1.0, 0.82, 0.68))
	if arena != null and arena.has_method("notify_core_damaged"):
		arena.notify_core_damaged(self, source, applied_damage)
	if current_health <= 0.0:
		_destroyed = true
		remove_from_group("brawl_units")
		visible = false
		if arena != null and arena.has_method("notify_core_destroyed"):
			arena.notify_core_destroyed(self, source)

func _build_core_health_bar() -> void:
	var root := Node3D.new()
	root.name = "CoreHealthBar"
	root.position.y = 5.2
	add_child(root)
	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(2.6, 0.18, 0.06)
	background.mesh = background_mesh
	background.material_override = _make_bar_material(Color(0.06, 0.07, 0.1))
	root.add_child(background)
	health_bar_fill = MeshInstance3D.new()
	health_bar_fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(2.45, 0.12, 0.065)
	health_bar_fill.mesh = fill_mesh
	health_bar_fill.position.z = -0.035
	health_bar_fill.material_override = _make_bar_material(Color(0.34, 0.84, 0.52))
	root.add_child(health_bar_fill)
	_update_core_health_bar()

func _update_core_health_bar() -> void:
	if health_bar_fill == null:
		return
	var fraction := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	health_bar_fill.scale.x = fraction
	health_bar_fill.position.x = -1.225 * (1.0 - fraction)

func _make_bar_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
