extends PanelContainer

# ==============================================================================
# The Gray Synthesis - Player Settings & Audio Mixer Modal
# ==============================================================================
# Full-featured, player-accessible settings and audio mixing panel:
# - Centered overlay accessible via [Esc] or HUD Settings [⚙] button
# - 4 independent volume sliders with live percentage readouts:
#   * Master Volume (0% - 100%)
#   * SFX & Footsteps Volume (0% - 100%)
#   * Sector Ambience Volume (0% - 100%)
#   * Music & Ceremonial Stingers Volume (0% - 100%)
# - Quick audio actions:
#   * Audio cue test tone preview
#   * Global mute / unmute toggle
#   * Default volume reset
# - Atmospheric sector soundscape reference guide
# - Complete controls quick reference
# - Strictly player-facing: zero developer god-mode cheats or role leaks
# ==============================================================================

var game_manager: Node
var audio_manager: Node
var main_3d: Node3D

# UI Nodes
var title_label: Label
var subtitle_label: Label
var close_btn: Button

# Volume Sliders & Labels
var master_slider: HSlider
var master_val_label: Label

var sfx_slider: HSlider
var sfx_val_label: Label

var ambient_slider: HSlider
var ambient_val_label: Label

var music_slider: HSlider
var music_val_label: Label

# Action Buttons
var test_sound_btn: Button
var mute_toggle_btn: Button
var reset_defaults_btn: Button
var resume_btn: Button

var _is_updating_ui: bool = false
var _is_setup: bool = false

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(620, 600)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -310.0
	offset_top = -300.0
	offset_right = 310.0
	offset_bottom = 300.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.14, 0.97)
	style.border_color = Color(0.38, 0.58, 0.88, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

func setup(gm: Node, audio_mgr: Node, m3d: Node3D = null) -> void:
	game_manager = gm
	audio_manager = audio_mgr
	main_3d = m3d
	if not _is_setup:
		_build_ui()
		_is_setup = true
	_refresh_display()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 1. Header with Close Button
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	title_label = Label.new()
	title_label.text = "SETTINGS & AUDIO MIXER"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.modulate = Color(0.92, 0.96, 1.0)
	title_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Soundscape balance, atmosphere cues, and controls reference"
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.modulate = Color(0.68, 0.78, 0.90)
	title_vbox.add_child(subtitle_label)

	close_btn = Button.new()
	close_btn.text = " [X] Close "
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_menu)
	header_hbox.add_child(close_btn)

	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# 2. Audio Mixer Controls
	var mixer_header := Label.new()
	mixer_header.text = "AUDIO CHANNELS & VOLUME MIXER"
	mixer_header.add_theme_font_size_override("font_size", 13)
	mixer_header.modulate = Color(0.95, 0.82, 0.45)
	main_vbox.add_child(mixer_header)

	var sliders_box := VBoxContainer.new()
	sliders_box.add_theme_constant_override("separation", 8)
	main_vbox.add_child(sliders_box)

	# Master Volume
	var master_row := _create_slider_row("Master Volume", 1.0)
	master_slider = master_row["slider"]
	master_val_label = master_row["label"]
	master_slider.value_changed.connect(_on_master_slider_changed)
	sliders_box.add_child(master_row["container"])

	# SFX & Footsteps Volume
	var sfx_row := _create_slider_row("SFX & Footsteps", 1.0)
	sfx_slider = sfx_row["slider"]
	sfx_val_label = sfx_row["label"]
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	sliders_box.add_child(sfx_row["container"])

	# Ambience Volume
	var amb_row := _create_slider_row("Sector Ambience", 0.75)
	ambient_slider = amb_row["slider"]
	ambient_val_label = amb_row["label"]
	ambient_slider.value_changed.connect(_on_ambient_slider_changed)
	sliders_box.add_child(amb_row["container"])

	# Music & Ceremonial Stingers
	var music_row := _create_slider_row("Music & Stingers", 0.80)
	music_slider = music_row["slider"]
	music_val_label = music_row["label"]
	music_slider.value_changed.connect(_on_music_slider_changed)
	sliders_box.add_child(music_row["container"])

	# Audio Quick Actions Row
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(actions_hbox)

	test_sound_btn = Button.new()
	test_sound_btn.text = "▶ Test Sound Cue"
	test_sound_btn.focus_mode = Control.FOCUS_NONE
	test_sound_btn.pressed.connect(_on_test_sound_pressed)
	actions_hbox.add_child(test_sound_btn)

	mute_toggle_btn = Button.new()
	mute_toggle_btn.text = "Mute All Audio"
	mute_toggle_btn.focus_mode = Control.FOCUS_NONE
	mute_toggle_btn.pressed.connect(_on_mute_toggle_pressed)
	actions_hbox.add_child(mute_toggle_btn)

	reset_defaults_btn = Button.new()
	reset_defaults_btn.text = "↺ Reset Audio Defaults"
	reset_defaults_btn.focus_mode = Control.FOCUS_NONE
	reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)
	actions_hbox.add_child(reset_defaults_btn)

	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# 3. Sector Audio & Atmospheric Guide
	var guide_panel := PanelContainer.new()
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = Color(0.04, 0.06, 0.09, 0.85)
	g_style.border_color = Color(0.25, 0.35, 0.48, 0.7)
	g_style.border_width_left = 1
	g_style.border_width_top = 1
	g_style.border_width_right = 1
	g_style.border_width_bottom = 1
	g_style.corner_radius_top_left = 6
	g_style.corner_radius_top_right = 6
	g_style.corner_radius_bottom_left = 6
	g_style.corner_radius_bottom_right = 6
	guide_panel.add_theme_stylebox_override("panel", g_style)
	main_vbox.add_child(guide_panel)

	var g_margin := MarginContainer.new()
	g_margin.add_theme_constant_override("margin_left", 14)
	g_margin.add_theme_constant_override("margin_top", 10)
	g_margin.add_theme_constant_override("margin_right", 14)
	g_margin.add_theme_constant_override("margin_bottom", 10)
	guide_panel.add_child(g_margin)

	var g_vbox := VBoxContainer.new()
	g_vbox.add_theme_constant_override("separation", 4)
	g_margin.add_child(g_vbox)

	var g_title := Label.new()
	g_title.text = "SECTOR SOUNDSCAPE IDENTITY & AUDIO CUES"
	g_title.add_theme_font_size_override("font_size", 12)
	g_title.modulate = Color(0.55, 0.85, 0.95)
	g_vbox.add_child(g_title)

	var lines := [
		"• Town Square: Slate click footsteps & gentle plaza breeze",
		"• Pump Station: Resonant steel steps & 60Hz industrial dynamo hum",
		"• Greenhouse: Soft loam thuds & subtle bio-luminescent flora hum",
		"• Salvage Yard: Crushed slag footsteps & metallic scrap wind shimmer"
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.82, 0.88, 0.94)
		g_vbox.add_child(lbl)

	# 4. Controls Summary
	var ctrl_header := Label.new()
	ctrl_header.text = "KEYBOARD SHORTCUTS"
	ctrl_header.add_theme_font_size_override("font_size", 12)
	ctrl_header.modulate = Color(0.72, 0.82, 0.92)
	main_vbox.add_child(ctrl_header)

	var ctrl_lbl := Label.new()
	ctrl_lbl.text = "Move: [WASD] • Sprint: [Shift] • Channel: [E] • Inspect: [V] • Shove: [R]\nHero ability: [F] • Operative ability: [C] • Journal: [J] • Zoom: [Z/Wheel] • Help: [H] • Settings: [Esc]"
	ctrl_lbl.add_theme_font_size_override("font_size", 11)
	ctrl_lbl.modulate = Color(0.74, 0.78, 0.85)
	main_vbox.add_child(ctrl_lbl)

	# 5. Bottom Resume Game Button
	resume_btn = Button.new()
	resume_btn.text = "◀  Resume Game [Esc]"
	resume_btn.custom_minimum_size = Vector2(0, 36)
	resume_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.pressed.connect(close_menu)
	main_vbox.add_child(resume_btn)

func _create_slider_row(label_text: String, default_val: float) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.custom_minimum_size = Vector2(160, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(0.88, 0.92, 0.98)
	hbox.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(round(default_val * 100.0))
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.modulate = Color(0.75, 0.92, 0.80)
	hbox.add_child(val_lbl)

	return {"container": hbox, "slider": slider, "label": val_lbl}

func open_menu() -> void:
	visible = true
	if game_manager != null:
		game_manager.settings_menu_open = true
	_refresh_display()
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_click", 1.0, -6.0)

func close_menu() -> void:
	visible = false
	if game_manager != null:
		game_manager.settings_menu_open = false
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_click", 0.9, -6.0)

func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()

func _refresh_display() -> void:
	if audio_manager == null:
		return
	_is_updating_ui = true

	var m_vol: float = audio_manager.master_volume if "master_volume" in audio_manager else 1.0
	var s_vol: float = audio_manager.sfx_volume if "sfx_volume" in audio_manager else 1.0
	var a_vol: float = audio_manager.ambient_volume if "ambient_volume" in audio_manager else 0.75
	var mus_vol: float = audio_manager.music_volume if "music_volume" in audio_manager else 0.80
	var is_muted: bool = audio_manager.is_muted if "is_muted" in audio_manager else false

	if master_slider != null:
		master_slider.value = m_vol
		master_val_label.text = "%d%%" % int(round(m_vol * 100.0))
	if sfx_slider != null:
		sfx_slider.value = s_vol
		sfx_val_label.text = "%d%%" % int(round(s_vol * 100.0))
	if ambient_slider != null:
		ambient_slider.value = a_vol
		ambient_val_label.text = "%d%%" % int(round(a_vol * 100.0))
	if music_slider != null:
		music_slider.value = mus_vol
		music_val_label.text = "%d%%" % int(round(mus_vol * 100.0))

	if mute_toggle_btn != null:
		mute_toggle_btn.text = "Unmute Audio" if is_muted else "Mute All Audio"
		mute_toggle_btn.modulate = Color(1.0, 0.6, 0.6) if is_muted else Color(1.0, 1.0, 1.0)

	_is_updating_ui = false

func set_master_slider_value(val: float) -> void:
	if master_slider != null:
		master_slider.value = val
	_on_master_slider_changed(val)

func set_sfx_slider_value(val: float) -> void:
	if sfx_slider != null:
		sfx_slider.value = val
	_on_sfx_slider_changed(val)

func set_ambient_slider_value(val: float) -> void:
	if ambient_slider != null:
		ambient_slider.value = val
	_on_ambient_slider_changed(val)

func set_music_slider_value(val: float) -> void:
	if music_slider != null:
		music_slider.value = val
	_on_music_slider_changed(val)

func _on_master_slider_changed(value: float) -> void:
	if _is_updating_ui or audio_manager == null:
		return
	audio_manager.set_master_volume(value)
	if master_val_label != null:
		master_val_label.text = "%d%%" % int(round(value * 100.0))
	if mute_toggle_btn != null:
		var is_muted: bool = audio_manager.is_muted if "is_muted" in audio_manager else false
		mute_toggle_btn.text = "Unmute Audio" if is_muted else "Mute All Audio"

func _on_sfx_slider_changed(value: float) -> void:
	if _is_updating_ui or audio_manager == null:
		return
	audio_manager.set_sfx_volume(value)
	if sfx_val_label != null:
		sfx_val_label.text = "%d%%" % int(round(value * 100.0))

func _on_ambient_slider_changed(value: float) -> void:
	if _is_updating_ui or audio_manager == null:
		return
	audio_manager.set_ambient_volume(value)
	if ambient_val_label != null:
		ambient_val_label.text = "%d%%" % int(round(value * 100.0))

func _on_music_slider_changed(value: float) -> void:
	if _is_updating_ui or audio_manager == null:
		return
	audio_manager.set_music_volume(value)
	if music_val_label != null:
		music_val_label.text = "%d%%" % int(round(value * 100.0))

func _on_test_sound_pressed() -> void:
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("test_tone", 1.0, 0.0)

func _on_mute_toggle_pressed() -> void:
	if audio_manager == null:
		return
	var muted: bool = audio_manager.toggle_mute()
	_refresh_display()

func _on_reset_defaults_pressed() -> void:
	if audio_manager == null:
		return
	audio_manager.reset_to_defaults()
	_refresh_display()
	if audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_click", 1.2, -4.0)
