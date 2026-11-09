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
# - Player-only outfit palette selection saved locally
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
var player_node: Node
var cosmetic_config_path: String = "user://player_cosmetics.cfg"

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
var palette_selector: OptionButton
var accessory_selector: OptionButton
var preview_viewport: SubViewport
var preview_model: Node3D
var apply_cosmetics_btn: Button
var cancel_cosmetics_btn: Button
var cosmetic_status_label: Label

# Action Buttons
var test_sound_btn: Button
var mute_toggle_btn: Button
var reset_defaults_btn: Button
var resume_btn: Button

var _is_updating_ui: bool = false
var _is_setup: bool = false
var _committed_palette_id: String = "standard"
var _committed_accessory_id: String = "none"
var _pending_palette_id: String = "standard"
var _pending_accessory_id: String = "none"

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(620, 700)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -310.0
	offset_top = -350.0
	offset_right = 310.0
	offset_bottom = 350.0

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

func setup(gm: Node, audio_mgr: Node, m3d: Node3D = null, player: Node = null) -> void:
	game_manager = gm
	audio_manager = audio_mgr
	main_3d = m3d
	player_node = player
	if not _is_setup:
		_build_ui()
		_is_setup = true
	_load_player_cosmetics()
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

	var appearance_header := Label.new()
	appearance_header.text = "PLAYER APPEARANCE"
	appearance_header.add_theme_font_size_override("font_size", 13)
	appearance_header.modulate = Color(0.55, 0.85, 0.95)
	main_vbox.add_child(appearance_header)

	var appearance_content := HBoxContainer.new()
	appearance_content.add_theme_constant_override("separation", 12)
	main_vbox.add_child(appearance_content)

	var appearance_controls := VBoxContainer.new()
	appearance_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_controls.add_theme_constant_override("separation", 8)
	appearance_content.add_child(appearance_controls)

	palette_selector = _create_cosmetic_selector("Player Outfit Palette", "get_player_palette_options", appearance_controls)
	accessory_selector = _create_cosmetic_selector("Player Accessory", "get_player_accessory_options", appearance_controls)
	palette_selector.item_selected.connect(_on_cosmetic_selection_changed)
	accessory_selector.item_selected.connect(_on_cosmetic_selection_changed)

	var cosmetic_buttons := HBoxContainer.new()
	cosmetic_buttons.add_theme_constant_override("separation", 8)
	appearance_controls.add_child(cosmetic_buttons)

	apply_cosmetics_btn = Button.new()
	apply_cosmetics_btn.text = "Apply Outfit"
	apply_cosmetics_btn.focus_mode = Control.FOCUS_NONE
	apply_cosmetics_btn.pressed.connect(_on_apply_cosmetics_pressed)
	cosmetic_buttons.add_child(apply_cosmetics_btn)

	cancel_cosmetics_btn = Button.new()
	cancel_cosmetics_btn.text = "Cancel"
	cancel_cosmetics_btn.focus_mode = Control.FOCUS_NONE
	cancel_cosmetics_btn.pressed.connect(_on_cancel_cosmetics_pressed)
	cosmetic_buttons.add_child(cancel_cosmetics_btn)

	cosmetic_status_label = Label.new()
	cosmetic_status_label.text = "Preview changes before applying."
	cosmetic_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cosmetic_status_label.add_theme_font_size_override("font_size", 11)
	cosmetic_status_label.modulate = Color(0.72, 0.82, 0.92)
	appearance_controls.add_child(cosmetic_status_label)

	_setup_cosmetic_preview(appearance_content)

	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

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

	var sep3 := HSeparator.new()
	main_vbox.add_child(sep3)

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
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _create_cosmetic_selector(label_text: String, options_method: String, parent: VBoxContainer) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(145, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.88, 0.92, 0.98)
	row.add_child(label)

	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.focus_mode = Control.FOCUS_NONE
	if player_node != null and player_node.has_method(options_method):
		var options: Array = player_node.call(options_method)
		for option in options:
			selector.add_item(String(option["name"]))
			selector.set_item_metadata(selector.item_count - 1, String(option["id"]))
	else:
		selector.disabled = true
	row.add_child(selector)
	return selector

func _setup_cosmetic_preview(parent: HBoxContainer) -> void:
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(160, 155)
	parent.add_child(preview_panel)

	var preview_box := VBoxContainer.new()
	preview_panel.add_child(preview_box)

	var preview_title := Label.new()
	preview_title.text = "LIVE PREVIEW"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 11)
	preview_title.modulate = Color(0.55, 0.85, 0.95)
	preview_box.add_child(preview_title)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(150, 128)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	preview_box.add_child(viewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(300, 256)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.own_world_3d = true
	viewport_container.add_child(preview_viewport)

	var stage := Node3D.new()
	preview_viewport.add_child(stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.10, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.86)
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	stage.add_child(environment_node)

	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-28.0, -25.0, 0.0)
	preview_light.light_energy = 1.25
	stage.add_child(preview_light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.35, 4.0)
	camera.rotation.x = -atan2(0.27, 4.0)
	camera.current = true
	stage.add_child(camera)

	if player_node != null:
		var source_model := player_node.get("mesh_root") as Node3D
		if source_model != null:
			preview_model = source_model.duplicate() as Node3D
			preview_model.rotation.y = deg_to_rad(-18.0)
			stage.add_child(preview_model)

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

func set_player_palette(palette_id: String, persist: bool = true) -> bool:
	return _commit_player_cosmetics(palette_id, _committed_accessory_id, persist)

func set_player_accessory(accessory_id: String, persist: bool = true) -> bool:
	return _commit_player_cosmetics(_committed_palette_id, accessory_id, persist)

func _on_cosmetic_selection_changed(_index: int) -> void:
	if _is_updating_ui:
		return
	_pending_palette_id = _selected_cosmetic_id(palette_selector)
	_pending_accessory_id = _selected_cosmetic_id(accessory_selector)
	_update_cosmetic_preview()
	_update_cosmetic_buttons()

func _on_apply_cosmetics_pressed() -> void:
	_commit_player_cosmetics(_pending_palette_id, _pending_accessory_id, true)

func _on_cancel_cosmetics_pressed() -> void:
	_pending_palette_id = _committed_palette_id
	_pending_accessory_id = _committed_accessory_id
	_sync_cosmetic_selectors()
	_update_cosmetic_preview()
	_update_cosmetic_buttons()

func _commit_player_cosmetics(palette_id: String, accessory_id: String, persist: bool) -> bool:
	if player_node == null or not player_node.has_method("apply_player_palette") or not player_node.has_method("apply_player_accessory"):
		push_error("Cannot apply cosmetics: no compatible player is configured.")
		return false
	if preview_model == null or not player_node.has_method("apply_cosmetic_preview"):
		push_error("Cannot apply cosmetics: the live preview is not available.")
		return false
	if not bool(player_node.call("apply_cosmetic_preview", preview_model, palette_id, accessory_id)):
		push_warning("Ignoring unknown cosmetic selection '%s' / '%s'." % [palette_id, accessory_id])
		return false
	if not bool(player_node.call("apply_player_palette", palette_id)) or not bool(player_node.call("apply_player_accessory", accessory_id)):
		push_error("Could not apply the selected player cosmetics.")
		return false
	_committed_palette_id = palette_id
	_committed_accessory_id = accessory_id
	_pending_palette_id = palette_id
	_pending_accessory_id = accessory_id
	_sync_cosmetic_selectors()
	_update_cosmetic_buttons()
	if persist:
		_save_player_cosmetics(palette_id, accessory_id)
	return true

func _selected_cosmetic_id(selector: OptionButton) -> String:
	if selector == null or selector.selected < 0:
		return ""
	return String(selector.get_item_metadata(selector.selected))

func _sync_cosmetic_selectors() -> void:
	_sync_cosmetic_selector(palette_selector, _pending_palette_id)
	_sync_cosmetic_selector(accessory_selector, _pending_accessory_id)

func _sync_cosmetic_selector(selector: OptionButton, cosmetic_id: String) -> void:
	if selector == null:
		return
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == cosmetic_id:
			selector.select(index)
			return

func _update_cosmetic_preview() -> void:
	if preview_model == null or player_node == null:
		return
	if not bool(player_node.call("apply_cosmetic_preview", preview_model, _pending_palette_id, _pending_accessory_id)):
		push_warning("Could not preview cosmetic selection '%s' / '%s'." % [_pending_palette_id, _pending_accessory_id])

func _update_cosmetic_buttons() -> void:
	var has_pending_changes := _pending_palette_id != _committed_palette_id or _pending_accessory_id != _committed_accessory_id
	if apply_cosmetics_btn != null:
		apply_cosmetics_btn.disabled = not has_pending_changes
	if cancel_cosmetics_btn != null:
		cancel_cosmetics_btn.disabled = not has_pending_changes
	if cosmetic_status_label != null:
		cosmetic_status_label.text = "Unapplied preview" if has_pending_changes else "Current outfit"

func _load_player_cosmetics() -> void:
	if player_node == null or not player_node.has_method("apply_player_palette") or not player_node.has_method("apply_player_accessory"):
		return
	var config := ConfigFile.new()
	var error := config.load(cosmetic_config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Could not load player cosmetics '%s': %s" % [cosmetic_config_path, error_string(error)])
	var palette_id: String = String(config.get_value("cosmetics", "player_palette", "standard")) if error == OK else "standard"
	var accessory_id: String = String(config.get_value("cosmetics", "player_accessory", "none")) if error == OK else "none"
	if preview_model == null or not player_node.has_method("apply_cosmetic_preview") or not bool(player_node.call("apply_cosmetic_preview", preview_model, palette_id, accessory_id)):
		push_warning("Saved player cosmetics were invalid; using the default outfit.")
		palette_id = "standard"
		accessory_id = "none"
	_commit_player_cosmetics(palette_id, accessory_id, false)

func _save_player_cosmetics(palette_id: String, accessory_id: String) -> void:
	var config := ConfigFile.new()
	var error := config.load(cosmetic_config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Could not load player cosmetics '%s' before saving: %s" % [cosmetic_config_path, error_string(error)])
		return
	config.set_value("cosmetics", "player_palette", palette_id)
	config.set_value("cosmetics", "player_accessory", accessory_id)
	error = config.save(cosmetic_config_path)
	if error != OK:
		push_error("Could not save player cosmetics '%s': %s" % [cosmetic_config_path, error_string(error)])

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
