extends Node3D

const MODE_SELECT_PATH := "res://scenes/ModeSelect.tscn"
const BrawlPlayerScript = preload("res://scripts/BrawlPlayer3D.gd")
const BrawlHeroScript = preload("res://scripts/BrawlHero3D.gd")
const BrawlMinionScript = preload("res://scripts/BrawlMinion3D.gd")
const BrawlTurretScript = preload("res://scripts/BrawlTurret3D.gd")
const BrawlCoreScript = preload("res://scripts/BrawlCore3D.gd")
const C = preload("res://scripts/GameConstants.gd")
const MINION_WAVE_INTERVAL := 12.0
const MINIONS_PER_WAVE := 3
const BRAWL_DURATION := 600.0

var player: CharacterBody3D
var camera: Camera3D
var pause_overlay: PanelContainer
var return_to_modes_button: Button
var player_health_bar: ProgressBar
var player_mana_bar: ProgressBar
var player_health_label: Label
var player_mana_label: Label
var wave_status_label: Label
var ability_status_label: Label
var battle_timer_label: Label
var objective_status_label: Label
var result_overlay: PanelContainer
var result_title_label: Label
var blue_core: Node3D
var red_core: Node3D
var _paused: bool = false
var _wave_timer: float = MINION_WAVE_INTERVAL
var _wave_number: int = 0
var _match_manager: Node
var _match_residents: Array = []
var _player_resident: Node
var _is_match_finale: bool = false
var _player_team: String = "blue"
var _match_time_remaining: float = BRAWL_DURATION
var _sudden_death: bool = false
var _match_finished: bool = false

func configure_match_finale(manager: Node, session_residents: Array, active_player_resident: Node) -> void:
	_match_manager = manager
	_match_residents = session_residents.duplicate()
	_player_resident = active_player_resident
	_is_match_finale = true
	var allegiance := String(manager.get_resident_alignment(active_player_resident))
	_player_team = _team_for_faction(allegiance)

func _ready() -> void:
	add_to_group("brawl_arena")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	_build_arena()
	_spawn_player()
	_spawn_hero_bots()
	_setup_camera()
	_build_hud()
	_spawn_minion_wave()

func _process(_delta: float) -> void:
	if _paused or _match_finished:
		return
	_wave_timer -= _delta
	if _wave_timer <= 0.0:
		_spawn_minion_wave()
	else:
		_update_wave_status()
	_update_ability_status()
	_update_objective_status()
	if _is_match_finale and not _sudden_death:
		_match_time_remaining = maxf(0.0, _match_time_remaining - _delta)
		_match_manager.update_brawl_time_remaining(_match_time_remaining, _delta)
		_update_battle_timer()
		if _match_time_remaining <= 0.0:
			_resolve_timeout()
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
	_add_collision_box(world_root, "WestBoundary", Vector3(-33.0, 1.1, 0.0), Vector3(0.7, 2.2, 32.0), Color(0.16, 0.19, 0.23))
	_add_collision_box(world_root, "EastBoundary", Vector3(33.0, 1.1, 0.0), Vector3(0.7, 2.2, 32.0), Color(0.16, 0.19, 0.23))

	_add_collision_box(world_root, "NorthCoverWest", Vector3(-6.0, 0.7, -9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "NorthCoverEast", Vector3(7.0, 0.7, -9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "SouthCoverWest", Vector3(-7.0, 0.7, 9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))
	_add_collision_box(world_root, "SouthCoverEast", Vector3(6.0, 0.7, 9.0), Vector3(4.0, 1.4, 1.2), Color(0.31, 0.35, 0.39))

	_add_landmark(world_root, "BlueTurret", Vector3(-16.0, 0.0, 0.0), Color(0.18, 0.66, 0.96), "TURRET")
	_add_landmark(world_root, "RedTurret", Vector3(16.0, 0.0, 0.0), Color(0.96, 0.36, 0.34), "TURRET")
	_add_landmark(world_root, "BlueCore", Vector3(-28.0, 0.0, 0.0), Color(0.28, 0.78, 1.0), "BLUE CORE")
	_add_landmark(world_root, "RedCore", Vector3(28.0, 0.0, 0.0), Color(1.0, 0.42, 0.34), "RED CORE")
	blue_core = world_root.get_node("BlueCore")
	red_core = world_root.get_node("RedCore")

	_add_ground_ring(world_root, "CenterControlMarker", Vector3.ZERO, 4.0, Color(0.80, 0.72, 0.40))
	_add_ground_ring(world_root, "BlueSpawnMarker", Vector3(-22.0, 0.03, 0.0), 3.0, Color(0.20, 0.68, 0.98))
	_add_ground_ring(world_root, "RedSpawnMarker", Vector3(22.0, 0.03, 0.0), 3.0, Color(0.98, 0.35, 0.32))

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "BrawlPlayer"
	player.set_script(BrawlPlayerScript)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.set("team_id", _player_team)
	player.set("hero_id", _hero_id_for_resident(_player_resident) if _is_match_finale else "garrick_cole")
	player.set("combatant_name", String(_player_resident.get("resident_name")) if _is_match_finale else "")
	player.set("drafted_hero_name", _drafted_hero_name_for_resident(_player_resident) if _is_match_finale else "")
	player.set("allow_hero_selection", not _is_match_finale)
	player.set("damage_multiplier", _damage_multiplier_for_team(_player_team))
	player.position = Vector3(-22.0 if _player_team == "blue" else 22.0, 0.0, 2.0)
	add_child(player)

func _spawn_hero_bots() -> void:
	if _is_match_finale:
		_spawn_match_rosters()
		return
	var blue_roster := ["nyx_calder", "mira_solis", "aris_thorne", "garrick_cole"]
	var red_roster := ["garrick_cole", "nyx_calder", "mira_solis", "aris_thorne", "garrick_cole"]
	for team in ["blue", "red"]:
		var roster: Array = blue_roster if team == "blue" else red_roster
		for slot in range(roster.size()):
			var bot := CharacterBody3D.new()
			bot.name = "%sBot%d" % [team.capitalize(), slot + 1]
			bot.set_script(BrawlHeroScript)
			bot.process_mode = Node.PROCESS_MODE_PAUSABLE
			bot.set("team_id", team)
			bot.set("hero_id", roster[slot])
			bot.set("is_bot", true)
			bot.set("lane_direction", 1.0 if team == "blue" else -1.0)
			var lane_offset := float(slot - (roster.size() - 1) * 0.5) * 1.8
			bot.position = Vector3(-24.0 if team == "blue" else 24.0, 0.0, lane_offset)
			add_child(bot)

func _spawn_match_rosters() -> void:
	var blue_participants: Array = []
	var red_participants: Array = []
	for resident in _match_residents:
		if resident == null:
			continue
		var faction := String(_match_manager.get_resident_alignment(resident))
		if faction == "ecology":
			blue_participants.append(resident)
		elif faction == "technology":
			red_participants.append(resident)
	for team in ["blue", "red"]:
		var roster: Array = blue_participants if team == "blue" else red_participants
		var slot := 0
		for resident in roster:
			if resident == _player_resident:
				continue
			var bot := CharacterBody3D.new()
			bot.name = "%sFinaleResident%d" % [team.capitalize(), slot + 1]
			bot.set_script(BrawlHeroScript)
			bot.process_mode = Node.PROCESS_MODE_PAUSABLE
			bot.set("team_id", team)
			bot.set("hero_id", _hero_id_for_resident(resident))
			bot.set("combatant_name", String(resident.get("resident_name")))
			bot.set("drafted_hero_name", _drafted_hero_name_for_resident(resident))
			bot.set("is_bot", true)
			bot.set("allow_hero_selection", false)
			bot.set("lane_direction", 1.0 if team == "blue" else -1.0)
			bot.set("damage_multiplier", _damage_multiplier_for_team(team))
			var lane_offset := float(slot % 5 - 2) * 1.6
			bot.position = Vector3(-24.0 if team == "blue" else 24.0, 0.0, lane_offset)
			add_child(bot)
			slot += 1

func _hero_id_for_resident(resident: Node) -> String:
	if resident == null:
		return "garrick_cole"
	var resident_hero_id := String(resident.get("hero_id"))
	if BrawlHeroScript.HERO_KITS.has(resident_hero_id):
		return resident_hero_id
	match String(resident.get("civic_job")):
		"Field Medic":
			return "aris_thorne"
		"Pump Technician":
			return "mira_solis"
		"Town Watch":
			return "nyx_calder"
		_:
			return "garrick_cole"

func _drafted_hero_name_for_resident(resident: Node) -> String:
	if resident == null:
		return ""
	var resident_hero_id := String(resident.get("hero_id"))
	for profile in C.HERO_ROSTER:
		if String(profile.get("hero_id", "")) == resident_hero_id:
			return String(profile.get("name", ""))
	return ""

func _team_for_faction(faction: String) -> String:
	return "blue" if faction == "ecology" else "red"

func _faction_for_team(team: String) -> String:
	return "ecology" if team == "blue" else "technology"

func _damage_multiplier_for_team(team: String) -> float:
	if not _is_match_finale or _match_manager == null:
		return 1.0
	return float(_match_manager.get_archive_objective_speed_mult(_faction_for_team(team)))

func is_team_turret_destroyed(team: String) -> bool:
	var turret := get_node_or_null("Arena/%sTurret" % team.capitalize())
	return turret != null and float(turret.get("current_health")) <= 0.0

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
	title.text = "ONE-LANE BRAWL  |  CONFRONTATION FINALE" if _is_match_finale else "ONE-LANE BRAWL  |  DEVELOPER PREVIEW"
	title.position = Vector2(24.0, 20.0)
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.86, 0.93, 1.0)
	hud.add_child(title)

	battle_timer_label = Label.new()
	battle_timer_label.name = "BattleTimer"
	battle_timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	battle_timer_label.offset_top = 18.0
	battle_timer_label.offset_bottom = 48.0
	battle_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_timer_label.add_theme_font_size_override("font_size", 22)
	battle_timer_label.modulate = Color(1.0, 0.88, 0.58)
	hud.add_child(battle_timer_label)

	objective_status_label = Label.new()
	objective_status_label.name = "ObjectiveStatus"
	objective_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_status_label.offset_top = 52.0
	objective_status_label.offset_bottom = 84.0
	objective_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_status_label.add_theme_font_size_override("font_size", 15)
	objective_status_label.modulate = Color(0.82, 0.90, 1.0)
	hud.add_child(objective_status_label)

	var controls := Label.new()
	controls.name = "ControlsLabel"
	controls.text = "Move: WASD / Arrows    |    Attack: Space / Left Click    |    Q / E / R: Abilities    |    1-4: Select Hero"
	controls.position = Vector2(24.0, 54.0)
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(0.72, 0.82, 0.94)
	hud.add_child(controls)

	var player_status := VBoxContainer.new()
	player_status.name = "PlayerStatus"
	player_status.position = Vector2(24.0, 88.0)
	player_status.custom_minimum_size = Vector2(260.0, 0.0)
	player_status.add_theme_constant_override("separation", 3)
	hud.add_child(player_status)

	player_health_label = Label.new()
	player_health_label.name = "HealthLabel"
	player_health_label.text = "Health 600 / 600"
	player_status.add_child(player_health_label)
	player_health_bar = _create_status_bar(Color(0.24, 0.88, 0.46))
	player_health_bar.name = "HealthBar"
	player_status.add_child(player_health_bar)

	player_mana_label = Label.new()
	player_mana_label.name = "ManaLabel"
	player_mana_label.text = "Mana 100 / 100"
	player_status.add_child(player_mana_label)
	player_mana_bar = _create_status_bar(Color(0.27, 0.60, 1.0))
	player_mana_bar.name = "ManaBar"
	player_status.add_child(player_mana_bar)

	wave_status_label = Label.new()
	wave_status_label.name = "WaveStatus"
	wave_status_label.position = Vector2(24.0, 192.0)
	wave_status_label.add_theme_font_size_override("font_size", 15)
	wave_status_label.modulate = Color(0.88, 0.92, 0.98)
	hud.add_child(wave_status_label)

	ability_status_label = Label.new()
	ability_status_label.name = "AbilityStatus"
	ability_status_label.position = Vector2(24.0, 218.0)
	ability_status_label.add_theme_font_size_override("font_size", 13)
	ability_status_label.modulate = Color(0.74, 0.86, 0.96)
	hud.add_child(ability_status_label)

	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)
	player.hero_changed.connect(_on_player_hero_changed)
	_on_player_health_changed(player.get("current_health"), player.get("max_health"))
	_on_player_mana_changed(player.get("current_mana"), player.get("max_mana"))
	_update_wave_status()
	_update_ability_status()
	_update_battle_timer()
	_update_objective_status()
	_build_result_overlay(hud)

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
	return_to_modes_button.text = "Return to Developer Preview"
	return_to_modes_button.visible = not _is_match_finale
	return_to_modes_button.pressed.connect(_return_to_mode_select)
	pause_content.add_child(return_to_modes_button)

func _toggle_pause() -> void:
	_paused = not _paused
	pause_overlay.visible = _paused
	get_tree().paused = _paused

func _return_to_mode_select() -> void:
	if _is_match_finale:
		push_warning("Cannot leave an active Town Match from the brawl pause menu.")
		return
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(MODE_SELECT_PATH)
	if error != OK:
		push_error("Could not return to mode selection: %s" % error_string(error))

func _create_status_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(250.0, 16.0)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.07, 0.10, 0.92)
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _on_player_health_changed(current: float, maximum: float) -> void:
	if player_health_bar == null:
		return
	player_health_bar.value = current / maxf(maximum, 1.0) * 100.0
	player_health_label.text = "Health %d / %d" % [roundi(current), roundi(maximum)]

func _on_player_mana_changed(current: float, maximum: float) -> void:
	if player_mana_bar == null:
		return
	player_mana_bar.value = current / maxf(maximum, 1.0) * 100.0
	player_mana_label.text = "Mana %d / %d" % [roundi(current), roundi(maximum)]

func _on_player_hero_changed(_hero_name: String, _hero_id: String) -> void:
	_update_ability_status()

func _spawn_minion_wave() -> void:
	_wave_number += 1
	_wave_timer = MINION_WAVE_INTERVAL
	for team in ["blue", "red"]:
		for slot in range(MINIONS_PER_WAVE):
			var minion := CharacterBody3D.new()
			minion.name = "%sMinionWave%dUnit%d" % [team.capitalize(), _wave_number, slot + 1]
			minion.set_script(BrawlMinionScript)
			minion.process_mode = Node.PROCESS_MODE_PAUSABLE
			minion.set("team_id", team)
			minion.set("lane_direction", 1.0 if team == "blue" else -1.0)
			var lane_offset := float(slot - 1) * 1.25
			minion.position = Vector3(-23.5 if team == "blue" else 23.5, 0.0, lane_offset)
			add_child(minion)
	_update_wave_status()

func _update_wave_status() -> void:
	if wave_status_label != null:
		wave_status_label.text = "Wave %d  |  Next wave in %ds" % [_wave_number, ceili(_wave_timer)]

func _update_battle_timer() -> void:
	if battle_timer_label == null:
		return
	if not _is_match_finale:
		battle_timer_label.text = "DEVELOPER PREVIEW"
		return
	if _sudden_death:
		battle_timer_label.text = "SUDDEN DEATH — FIRST CORE HIT WINS"
		battle_timer_label.modulate = Color(1.0, 0.35, 0.3)
		return
	var total_seconds := ceili(_match_time_remaining)
	battle_timer_label.text = "CONFRONTATION  |  %02d:%02d" % [total_seconds / 60, total_seconds % 60]
	if total_seconds <= 60:
		battle_timer_label.modulate = Color(1.0, 0.35, 0.3)
	else:
		battle_timer_label.modulate = Color(1.0, 0.88, 0.58)

func _update_objective_status() -> void:
	if objective_status_label == null or blue_core == null or red_core == null:
		return
	var blue_fraction := float(blue_core.get("current_health")) / maxf(float(blue_core.get("max_health")), 1.0)
	var red_fraction := float(red_core.get("current_health")) / maxf(float(red_core.get("max_health")), 1.0)
	objective_status_label.text = "ECOLOGY CORE %d%%  |  Destroy the enemy turret and core  |  TECHNOLOGY CORE %d%%" % [
		roundi(blue_fraction * 100.0), roundi(red_fraction * 100.0)
	]

func _build_result_overlay(hud: CanvasLayer) -> void:
	result_overlay = PanelContainer.new()
	result_overlay.name = "BattleResultOverlay"
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_overlay.offset_left = -260.0
	result_overlay.offset_top = -110.0
	result_overlay.offset_right = 260.0
	result_overlay.offset_bottom = 110.0
	result_overlay.visible = false
	hud.add_child(result_overlay)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	result_overlay.add_child(content)
	result_title_label = Label.new()
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.add_theme_font_size_override("font_size", 24)
	content.add_child(result_title_label)
	var return_button := Button.new()
	return_button.text = "Return to Developer Preview"
	return_button.pressed.connect(_return_to_mode_select)
	content.add_child(return_button)

func _resolve_timeout() -> void:
	if _sudden_death or _match_finished:
		return
	var blue_fraction := float(blue_core.get("current_health")) / maxf(float(blue_core.get("max_health")), 1.0)
	var red_fraction := float(red_core.get("current_health")) / maxf(float(red_core.get("max_health")), 1.0)
	if not is_equal_approx(blue_fraction, red_fraction):
		var winner := "blue" if blue_fraction > red_fraction else "red"
		_finish_battle(_faction_for_team(winner), "timeout")
		return
	_sudden_death = true
	_update_battle_timer()
	_update_objective_status()
	if _match_manager != null:
		_match_manager.log_event("Brawl timeout tied on core health. Sudden death: first core hit wins.", Color(1.0, 0.45, 0.35))

func notify_core_damaged(core: Node3D, source: Node, applied_damage: float) -> void:
	if _sudden_death and applied_damage > 0.0 and source != null and is_instance_valid(source):
		if String(source.get("team_id")) != String(core.get("team_id")):
			_finish_battle(_faction_for_team(String(source.get("team_id"))), "sudden_death")
			return
	_update_objective_status()

func has_attacking_minion_support(objective: Node3D, source: Node, radius: float) -> bool:
	if objective == null or source == null or not is_instance_valid(source):
		return false
	var attacking_team := String(source.get("team_id"))
	if attacking_team == "" or attacking_team == String(objective.get("team_id")):
		return false
	for candidate in get_tree().get_nodes_in_group("brawl_units"):
		if not is_instance_valid(candidate) or String(candidate.get("unit_type")) != "minion":
			continue
		if String(candidate.get("team_id")) != attacking_team:
			continue
		var offset: Vector3 = objective.global_position - candidate.global_position
		offset.y = 0.0
		if offset.length() <= radius:
			return true
	return false

func notify_core_destroyed(core: Node3D, source: Node) -> void:
	var winner_team := String(source.get("team_id")) if source != null and is_instance_valid(source) else ""
	if winner_team == "" or winner_team == String(core.get("team_id")):
		return
	_finish_battle(_faction_for_team(winner_team), "core_destroyed")

func _finish_battle(winner_faction: String, end_reason: String) -> void:
	if _match_finished:
		return
	_match_finished = true
	for unit in get_tree().get_nodes_in_group("brawl_units"):
		if unit is Node:
			unit.set_process(false)
			unit.set_physics_process(false)
	if _is_match_finale and _match_manager != null:
		_match_manager.resolve_brawl_victory(winner_faction, end_reason)
		return
	var winner_name := winner_faction.capitalize()
	result_title_label.text = "%s WINS — %s" % [winner_name.to_upper(), "CORE DESTROYED" if end_reason == "core_destroyed" else ("SUDDEN DEATH" if end_reason == "sudden_death" else "CORE HEALTH LEAD")]
	result_title_label.modulate = Color(0.45, 0.92, 0.58) if winner_faction == "ecology" else Color(0.42, 0.80, 0.98)
	result_overlay.visible = true

func _update_ability_status() -> void:
	if ability_status_label == null or player == null:
		return
	var ability_names: Dictionary = {
		"garrick_cole": ["Cleave", "Fortify", "Slam"],
		"nyx_calder": ["Longshot", "Evasive Dash", "Volley"],
		"mira_solis": ["Pressure Blast", "Ground Slow", "Tidal Burst"],
		"aris_thorne": ["Healing Spray", "Stun Syringe", "Recovery Wave"]
	}
	var names: Array = ability_names.get(player.get("hero_id"), ability_names["garrick_cole"])
	ability_status_label.text = "%s  |  Q %s: %.0fs   E %s: %.0fs   R %s: %.0fs" % [
		player.get("hero_name"),
		names[0],
		player.get_ability_cooldown("Q"),
		names[1],
		player.get_ability_cooldown("E"),
		names[2],
		player.get_ability_cooldown("R")
	]

func show_damage_number(target: Node3D, amount: float, tint: Color) -> void:
	var floater := Label3D.new()
	floater.name = "DamageNumber"
	floater.add_to_group("brawl_damage_numbers")
	floater.text = "-%d" % roundi(amount)
	floater.font_size = 30
	floater.outline_size = 5
	floater.outline_modulate = Color(0.03, 0.035, 0.05, 1.0)
	floater.modulate = tint
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.position = target.global_position + Vector3(0.0, 2.0, 0.0)
	add_child(floater)
	var tween := create_tween()
	tween.tween_property(floater, "position:y", floater.position.y + 1.2, 0.65)
	tween.parallel().tween_property(floater, "modulate:a", 0.0, 0.65)
	tween.tween_callback(floater.queue_free)

func spawn_turret_projectile(source: Node3D, target: Node3D) -> void:
	var projectile := MeshInstance3D.new()
	projectile.name = "TurretProjectile"
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	projectile.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.34)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.54, 0.16)
	projectile.material_override = material
	projectile.position = source.global_position + Vector3(0.0, 2.8, 0.0)
	add_child(projectile)
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", target.global_position + Vector3(0.0, 0.8, 0.0), 0.18)
	tween.tween_callback(projectile.queue_free)

func notify_enemy_hero_attacked(attacker: Node3D) -> void:
	for turret in get_tree().get_nodes_in_group("brawl_units"):
		if String(turret.get("unit_type")) == "turret" and String(turret.get("team_id")) != String(attacker.get("team_id")):
			turret.notify_enemy_hero_attacked(attacker)

func notify_turret_destroyed(turret: Node3D, _source: Node) -> void:
	var label := Label3D.new()
	label.name = "TurretDestroyedLabel"
	label.text = "TURRET DESTROYED"
	label.font_size = 22
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = turret.global_position + Vector3(0.0, 5.0, 0.0)
	add_child(label)

func _add_landmark(parent: Node3D, node_name: String, world_position: Vector3, tint: Color, label_text: String) -> void:
	var landmark := Node3D.new()
	landmark.name = node_name
	landmark.position = world_position
	if node_name.ends_with("Turret"):
		landmark.set_script(BrawlTurretScript)
		landmark.process_mode = Node.PROCESS_MODE_PAUSABLE
		landmark.set("team_id", "blue" if node_name.begins_with("Blue") else "red")
	elif node_name.ends_with("Core"):
		var team := "blue" if node_name.begins_with("Blue") else "red"
		landmark.set_script(BrawlCoreScript)
		landmark.set("team_id", team)
		if _is_match_finale and _match_manager != null:
			var prep_value := float(_match_manager.generator_eco_stabilized if team == "blue" else _match_manager.generator_tech_primed)
			landmark.set("max_health", 1800.0 + prep_value * 2.0 + _match_manager.common_works * 0.25)
	parent.add_child(landmark)
	var structure_collision := StaticBody3D.new()
	structure_collision.name = "StructureCollision"
	landmark.add_child(structure_collision)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var collision_shape := CylinderShape3D.new()
	collision_shape.radius = 1.0
	collision_shape.height = 3.2
	collision.shape = collision_shape
	collision.position.y = 1.6
	structure_collision.add_child(collision)
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
