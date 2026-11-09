class_name FirstMatchGuide3D
extends PanelContainer

const PROGRESS_SECTION := "onboarding"
const PROGRESS_KEY := "first_match_guide_completed"

const GUIDE_STEPS: Array[Dictionary] = [
	{
		"title": "1 / 4 — Find your first station",
		"body": "Move with WASD. Head to a glowing station and get close enough to interact. Hold Shift to sprint."
	},
	{
		"title": "2 / 4 — Complete a task",
		"body": "At a station, press E to begin channeling. Stay nearby until the task completes; moving away interrupts it."
	},
	{
		"title": "3 / 4 — Review your private clues",
		"body": "Press J to open your evidence journal. Your findings are private; they become public only when you table them at First Council."
	},
	{
		"title": "4 / 4 — Share evidence at First Council",
		"body": "At First Council, open J and table useful clues individually or with Table All. Then vote on a civic motion with 1, 2, or 3."
	}
]

var progress_file_path: String = "user://player_progress.cfg"
var guide_completed: bool = false
var first_run_active: bool = false
var replay_active: bool = false
var current_step: int = -1

var _movement_origin: Vector3 = Vector3.ZERO
var _title_label: Label
var _body_label: Label
var _primary_button: Button
var _skip_button: Button
var _display_mode: String = ""

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(620.0, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -310.0
	offset_top = -205.0
	offset_right = 310.0
	offset_bottom = -18.0
	_load_progress()
	_build_ui()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.97)
	style.border_color = Color(0.38, 0.86, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.modulate = Color(0.55, 0.92, 1.0)
	content.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 14)
	_body_label.modulate = Color(0.88, 0.92, 0.98)
	content.add_child(_body_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)

	_skip_button = Button.new()
	_skip_button.text = "Skip Guide"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(skip_guide)
	buttons.add_child(_skip_button)

	_primary_button = Button.new()
	_primary_button.text = "Got it"
	_primary_button.focus_mode = Control.FOCUS_NONE
	_primary_button.pressed.connect(_on_primary_pressed)
	buttons.add_child(_primary_button)

func begin_first_match(player_position: Vector3) -> void:
	if guide_completed or first_run_active:
		return
	first_run_active = true
	replay_active = false
	_display_mode = "first_run"
	current_step = 0
	_movement_origin = player_position
	_show_step()

func notify_player_position(player_position: Vector3) -> void:
	if first_run_active and current_step == 0 and player_position.distance_to(_movement_origin) >= 2.0:
		_advance_first_run()

func notify_task_completed() -> void:
	if first_run_active and current_step == 1:
		_advance_first_run()

func notify_journal_opened() -> void:
	if first_run_active and current_step == 2:
		_advance_first_run()

func reach_first_council() -> void:
	if not first_run_active:
		return
	first_run_active = false
	current_step = GUIDE_STEPS.size() - 1
	_display_mode = "first_run"
	guide_completed = true
	_save_progress()
	_show_step()

func replay_guide() -> void:
	first_run_active = false
	replay_active = true
	_display_mode = "replay"
	current_step = 0
	_show_step()

func reset_for_match_restart() -> void:
	first_run_active = false
	replay_active = false
	_display_mode = ""
	current_step = -1
	visible = false

func skip_guide() -> void:
	first_run_active = false
	replay_active = false
	_display_mode = ""
	guide_completed = true
	_save_progress()
	visible = false

func _advance_first_run() -> void:
	current_step = mini(current_step + 1, GUIDE_STEPS.size() - 1)
	_show_step()

func _on_primary_pressed() -> void:
	if replay_active:
		if current_step + 1 >= GUIDE_STEPS.size():
			replay_active = false
			_display_mode = ""
			visible = false
			return
		current_step += 1
		_show_step()
		return

	visible = false

func _show_step() -> void:
	if current_step < 0 or current_step >= GUIDE_STEPS.size():
		visible = false
		return
	var step: Dictionary = GUIDE_STEPS[current_step]
	_title_label.text = String(step["title"])
	_body_label.text = String(step["body"])
	if replay_active:
		_primary_button.text = "Next" if current_step + 1 < GUIDE_STEPS.size() else "Done"
		_skip_button.visible = false
	else:
		_primary_button.text = "Got it" if first_run_active else "Done"
		_skip_button.visible = first_run_active
	visible = true

func _load_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load(progress_file_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Could not load onboarding progress '%s': %s" % [progress_file_path, error_string(error)])
		return
	guide_completed = bool(config.get_value(PROGRESS_SECTION, PROGRESS_KEY, false))

func _save_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load(progress_file_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Could not load onboarding progress '%s' before saving: %s" % [progress_file_path, error_string(error)])
		return
	config.set_value(PROGRESS_SECTION, PROGRESS_KEY, guide_completed)
	error = config.save(progress_file_path)
	if error != OK:
		push_error("Could not save onboarding progress '%s': %s" % [progress_file_path, error_string(error)])
