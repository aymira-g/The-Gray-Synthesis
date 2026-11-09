extends Node2D

const PlayerControllerScript = preload("res://scripts/PlayerController.gd")
const BotControllerScript = preload("res://scripts/BotController.gd")

const CIVIC_JOBS: Array[String] = [
	"Pump Technician",
	"Crop Tender",
	"Salvage Quartermaster",
	"Field Medic",
	"Town Watch",
	"Pump Technician",
	"Crop Tender",
	"Salvage Quartermaster",
	"Field Medic",
	"Town Watch"
]

var game_manager: Node
var town_map: Node2D
var public_hud: CanvasLayer

var residents: Array = []
var bot_controllers: Array = []
var spawn_positions: Array[Vector2] = []

func _ready() -> void:
	randomize()

	game_manager = $GameManager
	town_map = $TownMap
	public_hud = $PublicHUD

	town_map.game_manager = game_manager
	game_manager.phase_changed.connect(_on_phase_changed)

	var resident_scene := preload("res://scenes/Resident.tscn")
	var residents_root := Node2D.new()
	residents_root.name = "Residents"
	add_child(residents_root)

	# 10 evenly spaced spawn positions around the Council Ring in Town Square
	var ring_center := Vector2(0, 120)
	var ring_radius := 135.0
	for i in range(10):
		var angle := (TAU / 10.0) * float(i) - PI * 0.5
		var pos := ring_center + Vector2(cos(angle), sin(angle)) * ring_radius
		spawn_positions.append(pos)

		var res: CharacterBody2D = resident_scene.instantiate()
		res.resident_id = i + 1
		res.resident_name = "Resident %d" % (i + 1)
		res.civic_job = CIVIC_JOBS[i]
		res.is_player = (i == 0)
		res.spawn_position = pos
		res.global_position = pos
		res.town_map = town_map
		res.game_manager = game_manager
		residents_root.add_child(res)
		residents.append(res)

		if i == 0:
			var pc: Node2D = PlayerControllerScript.new()
			pc.name = "PlayerController"
			pc.resident = res
			pc.game_manager = game_manager
			pc.main_scene = self
			res.add_child(pc)
		else:
			var bc: Node = BotControllerScript.new()
			bc.name = "BotController"
			res.add_child(bc)
			bc.setup(res, town_map, game_manager, 0.35 * float(i))
			bot_controllers.append(bc)

	for res in residents:
		res.all_residents = residents
		res.reset_to_spawn(res.spawn_position)
	town_map.all_residents = residents

	public_hud.game_manager = game_manager
	public_hud.town_map = town_map
	public_hud.player = residents[0]
	public_hud.main_scene = self
	public_hud.all_residents = residents

func start_new_match() -> void:
	town_map.reset_pads()
	for i in range(residents.size()):
		residents[i].reset_to_spawn(spawn_positions[i])
	for b_idx in range(bot_controllers.size()):
		bot_controllers[b_idx].reset_bot(0.35 * float(b_idx + 1))
	game_manager.start_match(residents)

func reset_sandbox() -> void:
	town_map.reset_pads()
	for i in range(residents.size()):
		residents[i].reset_to_spawn(spawn_positions[i])
	for b_idx in range(bot_controllers.size()):
		bot_controllers[b_idx].reset_bot(0.35 * float(b_idx + 1))
	game_manager.enter_lobby()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F3:
			get_tree().change_scene_to_file("res://scenes/Main3D.tscn")

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == game_manager.Phase.FIRST_COUNCIL or new_phase == game_manager.Phase.COURT:
		town_map.reset_pads()
		for i in range(residents.size()):
			residents[i].gather_at_council_ring(spawn_positions[i])
		for b_idx in range(bot_controllers.size()):
			bot_controllers[b_idx].reset_bot(0.35 * float(b_idx + 1))
		if new_phase == game_manager.Phase.COURT:
			game_manager.prepare_court_preview(residents)
		elif new_phase == game_manager.Phase.FIRST_COUNCIL:
			game_manager.prepare_first_council(residents, town_map)
