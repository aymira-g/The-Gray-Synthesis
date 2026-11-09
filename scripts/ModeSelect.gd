extends Control

const TOWN_SCENE_PATH := "res://scenes/Main3D.tscn"
const BRAWL_SCENE_PATH := "res://scenes/BrawlArena3D.tscn"

var town_match_button: Button
var brawl_button: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.08)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(700, 0)
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)

	var title := Label.new()
	title.text = "THE GRAY SYNTHESIS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.86, 0.93, 1.0)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DEVELOPER PREVIEW ONLY — NOT THE PLAYER-FACING GAME FLOW"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.55, 0.84, 0.96)
	content.add_child(subtitle)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 20)
	content.add_child(mode_row)

	town_match_button = _create_mode_button(
		"Town Match",
		"Social deduction in a contested settlement.\nInvestigate, complete civic work, and decide the town's future.",
		Color(0.18, 0.36, 0.48)
	)
	town_match_button.name = "TownMatchButton"
	town_match_button.pressed.connect(_start_town_match)
	mode_row.add_child(town_match_button)

	brawl_button = _create_mode_button(
		"One-Lane Brawl Preview",
		"Developer-only battle sandbox.\nThe match now launches this battle from its confrontation finale.",
		Color(0.34, 0.25, 0.48)
	)
	brawl_button.name = "BrawlButton"
	brawl_button.pressed.connect(_start_brawl)
	mode_row.add_child(brawl_button)

	var footer := Label.new()
	footer.text = "DEV PREVIEW ONLY — NORMAL GAMEPLAY STARTS IN TOWN MATCH"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.modulate = Color(0.68, 0.73, 0.82)
	content.add_child(footer)

func _create_mode_button(title_text: String, description: String, accent: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(320, 190)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = "%s\n\n%s" % [title_text, description]
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.58)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 18.0
	normal.content_margin_bottom = 18.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.38)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.25)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _start_town_match() -> void:
	_start_mode(TOWN_SCENE_PATH)

func _start_brawl() -> void:
	_start_mode(BRAWL_SCENE_PATH)

func _start_mode(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not launch game mode '%s': %s" % [scene_path, error_string(error)])
