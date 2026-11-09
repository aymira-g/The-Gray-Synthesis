extends PanelContainer

# ==============================================================================
# The Gray Synthesis - Milestone 8 Playtest & Developer Tuning Console
# ==============================================================================
# Comprehensive developer and playtesting dashboard for Milestone 8:
# - Match Clock & Engine Speedwarp (0.5x, 1x, 2x, 5x, Pause, +/-30s, Set 10s)
# - Phase Navigation / Warp (Briefing, Open Town, First Council, Escalation, Court,
#   Finale Brawl, Finale Peace, Match Over)
# - Live Crisis & Resource Mutations (Water, Stability, Scrap, Common Works, Tug Meter, Drain Multiplier)
# - Resident & Role Inspector (Zero-guessing view of all 10 roles, kits, AI states, and teleportation)
# - Bedrock Alcove & Archive Secrecy Controls (Reveal active alcove, Teleport, Force unseal)
# - Gameplay Tuning Knobs (Channeling duration, Court deliberation delay, Shove cooldown, Sprint drain)
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")
const Resident3DClass = preload("res://scripts/Resident3D.gd")

var game_manager: Node
var town_map: Node3D
var player_node: CharacterBody3D
var main_3d: Node3D
var all_residents: Array = []
var bot_controllers: Array = []

# UI Nodes
var header_title: Label
var header_status: Label
var current_tab: String = "PHASE"

# Containers
var tab_content_container: VBoxContainer
var phase_tab_box: VBoxContainer
var crisis_tab_box: VBoxContainer
var roster_tab_box: VBoxContainer
var tuning_tab_box: VBoxContainer

# Live status labels
var speed_status_label: Label
var crisis_status_label: Label
var tuning_status_label: Label
var alcove_info_label: Label

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(440, 560)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 24.0
	offset_top = 70.0
	offset_right = 484.0
	offset_bottom = 660.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	panel_style.border_color = Color(0.35, 0.55, 0.85, 0.90)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", panel_style)

func setup(gm: Node, map: Node3D, p_node: CharacterBody3D, m3d: Node3D, res_list: Array, bots: Array) -> void:
	game_manager = gm
	town_map = map
	player_node = p_node
	main_3d = m3d
	all_residents = res_list
	bot_controllers = bots
	_build_ui()

func open_panel() -> void:
	visible = true
	if game_manager != null:
		game_manager.dev_panel_open = true
	_refresh_display()

func close_panel() -> void:
	visible = false
	if game_manager != null:
		game_manager.dev_panel_open = false

func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()

func _process(_delta: float) -> void:
	if visible:
		_update_header_stats()

func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# --- Header Bar ---
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	header_title = Label.new()
	header_title.text = "🛠️ PLAYTEST & TUNING CONSOLE (M8)"
	header_title.add_theme_font_size_override("font_size", 15)
	header_title.modulate = Color(0.45, 0.88, 1.0)
	title_vbox.add_child(header_title)

	header_status = Label.new()
	header_status.text = "Phase: -- | Clock: --:-- | FPS: --"
	header_status.add_theme_font_size_override("font_size", 11)
	header_status.modulate = Color(0.70, 0.78, 0.88)
	title_vbox.add_child(header_status)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(close_panel)
	header_hbox.add_child(close_btn)

	# --- Navigation Tabs ---
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(tabs_hbox)

	var tab_phase := Button.new()
	tab_phase.text = "Phases & Time"
	tab_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_phase.pressed.connect(func(): _switch_tab("PHASE"))
	tabs_hbox.add_child(tab_phase)

	var tab_crisis := Button.new()
	tab_crisis.text = "Crisis & Res"
	tab_crisis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_crisis.pressed.connect(func(): _switch_tab("CRISIS"))
	tabs_hbox.add_child(tab_crisis)

	var tab_roster := Button.new()
	tab_roster.text = "Roster & Roles"
	tab_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_roster.pressed.connect(func(): _switch_tab("ROSTER"))
	tabs_hbox.add_child(tab_roster)

	var tab_tuning := Button.new()
	tab_tuning.text = "Tuning Dials"
	tab_tuning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_tuning.pressed.connect(func(): _switch_tab("TUNING"))
	tabs_hbox.add_child(tab_tuning)

	# Separator
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# --- Scrollable Content Container ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(410, 410)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	tab_content_container = VBoxContainer.new()
	tab_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_content_container.add_theme_constant_override("separation", 10)
	scroll.add_child(tab_content_container)

	_build_phase_tab()
	_build_crisis_tab()
	_build_roster_tab()
	_build_tuning_tab()

	_switch_tab("PHASE")

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	phase_tab_box.visible = (tab_name == "PHASE")
	crisis_tab_box.visible = (tab_name == "CRISIS")
	roster_tab_box.visible = (tab_name == "ROSTER")
	tuning_tab_box.visible = (tab_name == "TUNING")
	_refresh_display()

func _update_header_stats() -> void:
	if game_manager == null:
		return
	var phase_names: Array[String] = ["Lobby", "Briefing", "Open Town", "First Council", "Escalation", "Court", "Finale", "Match Over"]
	var p_name: String = phase_names[game_manager.current_phase] if game_manager.current_phase < phase_names.size() else "Phase %d" % game_manager.current_phase
	var mins := int(game_manager.time_remaining) / 60
	var secs := int(game_manager.time_remaining) % 60
	var fps: int = int(Engine.get_frames_per_second())
	header_status.text = "Phase: %s | Clock: %02d:%02d | Speed: %.1fx | FPS: %d" % [
		p_name, mins, secs, Engine.time_scale, fps
	]

# ==============================================================================
# TAB 1: PHASES & TIME CONTROLS
# ==============================================================================
func _build_phase_tab() -> void:
	phase_tab_box = VBoxContainer.new()
	phase_tab_box.add_theme_constant_override("separation", 8)
	tab_content_container.add_child(phase_tab_box)

	var speed_sec := Label.new()
	speed_sec.text = "⚡ ENGINE TIME WARP (SPEED)"
	speed_sec.add_theme_font_size_override("font_size", 12)
	speed_sec.modulate = Color(0.95, 0.85, 0.40)
	phase_tab_box.add_child(speed_sec)

	var speed_hbox := HBoxContainer.new()
	phase_tab_box.add_child(speed_hbox)

	for spd in [0.5, 1.0, 2.0, 5.0]:
		var s_btn := Button.new()
		s_btn.text = "%.1fx" % spd if spd != 1.0 else "1.0x (Normal)"
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_btn.pressed.connect(func(): _set_engine_speed(spd))
		speed_hbox.add_child(s_btn)

	var clock_sec := Label.new()
	clock_sec.text = "⏱️ MATCH CLOCK FAST-FORWARD"
	clock_sec.add_theme_font_size_override("font_size", 12)
	clock_sec.modulate = Color(0.95, 0.85, 0.40)
	phase_tab_box.add_child(clock_sec)

	var clock_hbox := HBoxContainer.new()
	phase_tab_box.add_child(clock_hbox)

	var btn_sub30 := Button.new()
	btn_sub30.text = "-30s Clock"
	btn_sub30.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sub30.pressed.connect(func(): _adjust_clock(-30.0))
	clock_hbox.add_child(btn_sub30)

	var btn_add30 := Button.new()
	btn_add30.text = "+30s Clock"
	btn_add30.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add30.pressed.connect(func(): _adjust_clock(30.0))
	clock_hbox.add_child(btn_add30)

	var btn_set10 := Button.new()
	btn_set10.text = "Set 10s (Advance Soon)"
	btn_set10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_set10.pressed.connect(func(): _set_clock(10.0))
	clock_hbox.add_child(btn_set10)

	var warp_sec := Label.new()
	warp_sec.text = "🚀 DIRECT PHASE WARP"
	warp_sec.add_theme_font_size_override("font_size", 12)
	warp_sec.modulate = Color(0.95, 0.85, 0.40)
	phase_tab_box.add_child(warp_sec)

	var phase_grid := GridContainer.new()
	phase_grid.columns = 2
	phase_tab_box.add_child(phase_grid)

	_add_phase_btn(phase_grid, "1. Town Briefing", func(): _warp_to_phase(1))
	_add_phase_btn(phase_grid, "2. Open Town", func(): _warp_to_phase(2))
	_add_phase_btn(phase_grid, "3. First Council", func(): _warp_to_phase(3))
	_add_phase_btn(phase_grid, "4. Escalation", func(): _warp_to_phase(4))
	_add_phase_btn(phase_grid, "5. Civilian Court", func(): _warp_to_phase(5))
	_add_phase_btn(phase_grid, "6. Finale: Brawl", func(): _warp_to_finale(C.FINALE_ROUTE_CONFRONTATION))
	_add_phase_btn(phase_grid, "7. Finale: Peace", func(): _warp_to_finale(C.FINALE_ROUTE_PEACE))
	_add_phase_btn(phase_grid, "8. Match Over", func(): _warp_to_phase(7))

func _add_phase_btn(parent: Node, label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(195, 30)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _set_engine_speed(spd: float) -> void:
	Engine.time_scale = spd
	_show_popup_feedback("Engine speed set to %.1fx" % spd)

func _adjust_clock(delta_time: float) -> void:
	if game_manager != null:
		game_manager.time_remaining = maxf(1.0, game_manager.time_remaining + delta_time)
		_show_popup_feedback("Match clock adjusted (%+.0fs)" % delta_time)

func _set_clock(target_time: float) -> void:
	if game_manager != null:
		game_manager.time_remaining = target_time
		_show_popup_feedback("Match clock set to %.0fs" % target_time)

func _warp_to_phase(target_phase: int) -> void:
	if game_manager == null:
		return
	game_manager.set_phase(target_phase)
	_show_popup_feedback("Warped to Phase %d" % target_phase)

func _warp_to_finale(route: String) -> void:
	if game_manager == null:
		return
	game_manager.finale_route = route
	if route == C.FINALE_ROUTE_CONFRONTATION:
		_complete_unvoted_court_ballots_for_test_warp()
	game_manager.set_phase(game_manager.Phase.FINALE)
	_show_popup_feedback("Warped to Finale (%s)" % route.capitalize())

func _complete_unvoted_court_ballots_for_test_warp() -> void:
	var ecology_votes := 0
	var technology_votes := 0
	var recorded_names: Dictionary = {}
	for ballot in game_manager.court_preview_votes:
		var voter_name := String(ballot.get("name", ""))
		if not voter_name.is_empty():
			recorded_names[voter_name] = true
		match String(ballot.get("vote", "")):
			"Ecology":
				ecology_votes += 1
			"Technology":
				technology_votes += 1

	for resident in all_residents:
		if resident == null or String(resident.get("secret_role")) != "civilian":
			continue
		var resident_name := String(resident.get("resident_name"))
		if recorded_names.has(resident_name):
			continue
		var vote := "Ecology"
		if ecology_votes >= 2 or (technology_votes < 2 and technology_votes < ecology_votes):
			vote = "Technology"
		game_manager.court_preview_votes.append({
			"name": resident_name,
			"job": String(resident.get("civic_job")),
			"vote": vote
		})
		recorded_names[resident_name] = true
		if vote == "Ecology":
			ecology_votes += 1
		else:
			technology_votes += 1

# ==============================================================================
# TAB 2: CRISIS & RESOURCE CONTROLS
# ==============================================================================
func _build_crisis_tab() -> void:
	crisis_tab_box = VBoxContainer.new()
	crisis_tab_box.add_theme_constant_override("separation", 8)
	tab_content_container.add_child(crisis_tab_box)

	crisis_status_label = Label.new()
	crisis_status_label.text = "Resources: Water: -- | Stability: -- | Scrap: -- | Works: --"
	crisis_status_label.add_theme_font_size_override("font_size", 12)
	crisis_status_label.modulate = Color(0.50, 0.90, 1.0)
	crisis_tab_box.add_child(crisis_status_label)

	# Water
	var w_lbl := Label.new()
	w_lbl.text = "💧 WATER SUPPLY ADJUSTMENT"
	w_lbl.add_theme_font_size_override("font_size", 12)
	w_lbl.modulate = Color(0.40, 0.85, 1.0)
	crisis_tab_box.add_child(w_lbl)

	var w_hbox := HBoxContainer.new()
	crisis_tab_box.add_child(w_hbox)
	_add_res_btn(w_hbox, "-15% Water", func(): _adjust_water(-15.0))
	_add_res_btn(w_hbox, "+15% Water", func(): _adjust_water(15.0))
	_add_res_btn(w_hbox, "Crisis (20%)", func(): _set_water(20.0))
	_add_res_btn(w_hbox, "Fill (100%)", func(): _set_water(100.0))

	# Stability
	var s_lbl := Label.new()
	s_lbl.text = "⚡ STABILITY / GRID INTEGRITY"
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.modulate = Color(0.95, 0.75, 0.40)
	crisis_tab_box.add_child(s_lbl)

	var s_hbox := HBoxContainer.new()
	crisis_tab_box.add_child(s_hbox)
	_add_res_btn(s_hbox, "-15% Stability", func(): _adjust_stability(-15.0))
	_add_res_btn(s_hbox, "+15% Stability", func(): _adjust_stability(15.0))
	_add_res_btn(s_hbox, "Crisis (20%)", func(): _set_stability(20.0))
	_add_res_btn(s_hbox, "Fill (100%)", func(): _set_stability(100.0))

	# Scrap & Common Works
	var sc_lbl := Label.new()
	sc_lbl.text = "🔧 SCRAP & COMMON WORKS"
	sc_lbl.add_theme_font_size_override("font_size", 12)
	sc_lbl.modulate = Color(0.65, 0.95, 0.70)
	crisis_tab_box.add_child(sc_lbl)

	var sc_hbox := HBoxContainer.new()
	crisis_tab_box.add_child(sc_hbox)
	_add_res_btn(sc_hbox, "+5 Scrap", func(): _adjust_scrap(5))
	_add_res_btn(sc_hbox, "+20 Scrap", func(): _adjust_scrap(20))
	_add_res_btn(sc_hbox, "+15% Works", func(): _adjust_works(15.0))
	_add_res_btn(sc_hbox, "Set 99% Works", func(): _set_works(99.9))

	# Crisis Drain Multiplier
	var d_lbl := Label.new()
	d_lbl.text = "⏳ CRISIS DECAY DRAIN MULTIPLIER"
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.modulate = Color(1.0, 0.60, 0.50)
	crisis_tab_box.add_child(d_lbl)

	var d_hbox := HBoxContainer.new()
	crisis_tab_box.add_child(d_hbox)
	_add_res_btn(d_hbox, "0x (Frozen)", func(): _set_drain_scale(0.0))
	_add_res_btn(d_hbox, "0.5x (Gentle)", func(): _set_drain_scale(0.5))
	_add_res_btn(d_hbox, "1.0x (Default)", func(): _set_drain_scale(1.0))
	_add_res_btn(d_hbox, "2.0x (Intense)", func(): _set_drain_scale(2.0))

	# Confrontation Tug of War
	var tug_lbl := Label.new()
	tug_lbl.text = "⚔️ GENERATOR OVERDRIVE TUG (CONFRONTATION)"
	tug_lbl.add_theme_font_size_override("font_size", 12)
	tug_lbl.modulate = Color(1.0, 0.50, 0.50)
	crisis_tab_box.add_child(tug_lbl)

	var tug_hbox := HBoxContainer.new()
	crisis_tab_box.add_child(tug_hbox)
	_add_res_btn(tug_hbox, "15% (Eco Win)", func(): _set_tug_meter(15.0))
	_add_res_btn(tug_hbox, "50% (Tied)", func(): _set_tug_meter(50.0))
	_add_res_btn(tug_hbox, "85% (Tech Win)", func(): _set_tug_meter(85.0))

func _add_res_btn(parent: Node, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _adjust_water(delta: float) -> void:
	if game_manager != null:
		game_manager.water = clampf(game_manager.water + delta, 0.0, 100.0)
		game_manager.state_updated.emit()
		_refresh_display()

func _set_water(val: float) -> void:
	if game_manager != null:
		game_manager.water = val
		game_manager.state_updated.emit()
		_refresh_display()

func _adjust_stability(delta: float) -> void:
	if game_manager != null:
		game_manager.stability = clampf(game_manager.stability + delta, 0.0, 100.0)
		game_manager.state_updated.emit()
		_refresh_display()

func _set_stability(val: float) -> void:
	if game_manager != null:
		game_manager.stability = val
		game_manager.state_updated.emit()
		_refresh_display()

func _adjust_scrap(delta: int) -> void:
	if game_manager != null:
		game_manager.scrap = maxi(0, game_manager.scrap + delta)
		game_manager.state_updated.emit()
		_refresh_display()

func _adjust_works(delta: float) -> void:
	if game_manager != null:
		game_manager.common_works = clampf(game_manager.common_works + delta, 0.0, 100.0)
		game_manager.state_updated.emit()
		_refresh_display()

func _set_works(val: float) -> void:
	if game_manager != null:
		game_manager.common_works = val
		game_manager.state_updated.emit()
		_refresh_display()

func _set_drain_scale(scale: float) -> void:
	if game_manager != null:
		game_manager.crisis_drain_scale = scale
		_show_popup_feedback("Crisis decay multiplier: %.1fx" % scale)

func _set_tug_meter(val: float) -> void:
	if game_manager != null:
		game_manager.generator_tug_meter = val
		game_manager.state_updated.emit()
		_show_popup_feedback("Generator tug meter set to %.0f%%" % val)

# ==============================================================================
# TAB 3: ROSTER & SECRET ROLES INSPECTOR
# ==============================================================================
func _build_roster_tab() -> void:
	roster_tab_box = VBoxContainer.new()
	roster_tab_box.add_theme_constant_override("separation", 8)
	tab_content_container.add_child(roster_tab_box)

	alcove_info_label = Label.new()
	alcove_info_label.text = "Active Archive Alcove: --"
	alcove_info_label.add_theme_font_size_override("font_size", 12)
	alcove_info_label.modulate = Color(1.0, 0.85, 0.40)
	roster_tab_box.add_child(alcove_info_label)

	var alc_hbox := HBoxContainer.new()
	roster_tab_box.add_child(alc_hbox)

	var btn_tp_alc := Button.new()
	btn_tp_alc.text = "📍 Teleport to Active Alcove"
	btn_tp_alc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tp_alc.pressed.connect(_teleport_to_active_alcove)
	alc_hbox.add_child(btn_tp_alc)

	var btn_unseal := Button.new()
	btn_unseal.text = "🔑 Force Unseal Archive (Player)"
	btn_unseal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_unseal.pressed.connect(_force_unseal_archive_player)
	alc_hbox.add_child(btn_unseal)

	var roster_sec := Label.new()
	roster_sec.text = "👥 10-RESIDENT DOSSIER INSPECTOR (GOD-VIEW)"
	roster_sec.add_theme_font_size_override("font_size", 12)
	roster_sec.modulate = Color(0.50, 0.90, 1.0)
	roster_tab_box.add_child(roster_sec)

func _rebuild_roster_list() -> void:
	# Clear previous entries after the static controls
	while roster_tab_box.get_child_count() > 3:
		var ch = roster_tab_box.get_child(roster_tab_box.get_child_count() - 1)
		roster_tab_box.remove_child(ch)
		ch.queue_free()

	if game_manager != null and town_map != null:
		var act_id: String = game_manager.archive_active_spawn_id
		var alc_name := "Unknown"
		for alc in town_map.secret_alcoves:
			if alc.get("id") == act_id:
				alc_name = "%s (%s)" % [alc.get("name", "Alcove"), alc.get("region", "Town")]
				break
		var unseal_status := " [SEALED]"
		if game_manager.archive_opened:
			unseal_status = " [UNSEALED by %s]" % game_manager.archive_finder_name
		alcove_info_label.text = "Active Archive Alcove: %s%s" % [alc_name, unseal_status]

	for i in range(all_residents.size()):
		var res = all_residents[i]
		if res == null:
			continue

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.10, 0.14, 0.20, 0.75)
		card_style.border_color = Color(0.25, 0.35, 0.48)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card.add_theme_stylebox_override("panel", card_style)
		roster_tab_box.add_child(card)

		var c_hbox := HBoxContainer.new()
		card.add_child(c_hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_hbox.add_child(info_vbox)

		var role_tag := "Civilian"
		var tag_col := Color(0.85, 0.85, 0.90)
		if res.secret_role == "ecology":
			role_tag = "ECOLOGY OPERATIVE (%s)" % res.operative_kit
			tag_col = Color(0.45, 0.95, 0.65)
		elif res.secret_role == "technology":
			role_tag = "TECHNOLOGY OPERATIVE (%s)" % res.operative_kit
			tag_col = Color(0.45, 0.85, 1.0)

		var name_lbl := Label.new()
		name_lbl.text = "%s [%s] — %s" % [res.resident_name, res.civic_job, role_tag]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.modulate = tag_col
		info_vbox.add_child(name_lbl)

		var ai_state_txt := "Player Controlled" if res.is_player else "AI Bot"
		if not res.is_player and i < bot_controllers.size() and bot_controllers[i] != null:
			var bot = bot_controllers[i]
			var st_name: String = String(bot.get("state")) if bot.get("state") != null else "IDLE"
			ai_state_txt = "AI State: %s" % st_name
			if st_name == "COVERT_WORKING":
				var cov_type: String = String(bot.get("covert_mission_type")) if bot.get("covert_mission_type") != null else "NONE"
				ai_state_txt += " (Covert: %s)" % cov_type
		if res.is_incapacitated:
			ai_state_txt += " [INCAPACITATED - CLINIC]"

		var state_lbl := Label.new()
		state_lbl.text = ai_state_txt
		state_lbl.add_theme_font_size_override("font_size", 10)
		state_lbl.modulate = Color(0.70, 0.75, 0.85)
		info_vbox.add_child(state_lbl)

		if not res.is_player:
			var tp_btn := Button.new()
			tp_btn.text = "Teleport"
			tp_btn.custom_minimum_size = Vector2(75, 24)
			var target_res = res
			tp_btn.pressed.connect(func(): _teleport_player_to(target_res.position if not target_res.is_inside_tree() else target_res.global_position))
			c_hbox.add_child(tp_btn)

func _teleport_player_to(pos: Vector3) -> void:
	if player_node != null:
		player_node.position = pos + Vector3(0.0, 0.1, 0.0)
		if player_node.is_inside_tree():
			player_node.global_position = pos + Vector3(0.0, 0.1, 0.0)
		_show_popup_feedback("Teleported to position (%.1f, %.1f)" % [pos.x, pos.z])

func _teleport_to_active_alcove() -> void:
	if game_manager == null or town_map == null or player_node == null:
		return
	var act_id: String = game_manager.archive_active_spawn_id
	for alc in town_map.secret_alcoves:
		if alc.get("id") == act_id:
			var alc_pos: Vector3 = alc.get("pos", Vector3.ZERO)
			_teleport_player_to(alc_pos)
			return

func _force_unseal_archive_player() -> void:
	if game_manager == null or town_map == null or player_node == null:
		return
	var act_id: String = game_manager.archive_active_spawn_id
	for alc in town_map.secret_alcoves:
		if alc.get("id") == act_id:
			town_map.complete_site_inspection(player_node, alc)
			_show_popup_feedback("Player unsealed the active bedrock alcove!")
			_refresh_display()
			return

# ==============================================================================
# TAB 4: LIVE TUNING KNOBS (PACING & BALANCE)
# ==============================================================================
func _build_tuning_tab() -> void:
	tuning_tab_box = VBoxContainer.new()
	tuning_tab_box.add_theme_constant_override("separation", 8)
	tab_content_container.add_child(tuning_tab_box)

	tuning_status_label = Label.new()
	tuning_status_label.text = "Pacing Parameters"
	tuning_status_label.add_theme_font_size_override("font_size", 12)
	tuning_status_label.modulate = Color(0.50, 0.90, 1.0)
	tuning_tab_box.add_child(tuning_status_label)

	# 1. Task Channel Duration
	var ch_lbl := Label.new()
	ch_lbl.text = "⏱️ TASK CHANNELING DURATION"
	ch_lbl.add_theme_font_size_override("font_size", 12)
	ch_lbl.modulate = Color(0.95, 0.85, 0.40)
	tuning_tab_box.add_child(ch_lbl)

	var ch_hbox := HBoxContainer.new()
	tuning_tab_box.add_child(ch_hbox)
	_add_tuning_btn(ch_hbox, "1.0s (Fast)", func(): _set_channel_scale(0.50))
	_add_tuning_btn(ch_hbox, "1.5s", func(): _set_channel_scale(0.75))
	_add_tuning_btn(ch_hbox, "2.0s (Default)", func(): _set_channel_scale(1.00))
	_add_tuning_btn(ch_hbox, "3.0s (Slow)", func(): _set_channel_scale(1.50))

	# 2. Bot Court Turn Deliberation Delay
	var court_lbl := Label.new()
	court_lbl.text = "⚖️ BOT COURT CEREMONY DELAY"
	court_lbl.add_theme_font_size_override("font_size", 12)
	court_lbl.modulate = Color(0.95, 0.85, 0.40)
	tuning_tab_box.add_child(court_lbl)

	var court_hbox := HBoxContainer.new()
	tuning_tab_box.add_child(court_hbox)
	_add_tuning_btn(court_hbox, "0.5s (Brisk)", func(): _set_court_bot_delay(0.5))
	_add_tuning_btn(court_hbox, "1.5s", func(): _set_court_bot_delay(1.5))
	_add_tuning_btn(court_hbox, "2.5s (Default)", func(): _set_court_bot_delay(2.5))
	_add_tuning_btn(court_hbox, "4.5s (Cinematic)", func(): _set_court_bot_delay(4.5))

	# 3. Civic Shove Cooldown
	var shove_lbl := Label.new()
	shove_lbl.text = "💥 CIVIC SHOVE COOLDOWN"
	shove_lbl.add_theme_font_size_override("font_size", 12)
	shove_lbl.modulate = Color(0.95, 0.85, 0.40)
	tuning_tab_box.add_child(shove_lbl)

	var shove_hbox := HBoxContainer.new()
	tuning_tab_box.add_child(shove_hbox)
	_add_tuning_btn(shove_hbox, "1.0s (Brawl)", func(): _set_shove_cooldown(1.0))
	_add_tuning_btn(shove_hbox, "2.0s (Brisk)", func(): _set_shove_cooldown(2.0))
	_add_tuning_btn(shove_hbox, "4.0s (Default)", func(): _set_shove_cooldown(4.0))
	_add_tuning_btn(shove_hbox, "6.0s (Tactical)", func(): _set_shove_cooldown(6.0))

	# 4. Player Sprint Stamina Drain
	var st_lbl := Label.new()
	st_lbl.text = "🏃 PLAYER SPRINT STAMINA DRAIN"
	st_lbl.add_theme_font_size_override("font_size", 12)
	st_lbl.modulate = Color(0.95, 0.85, 0.40)
	tuning_tab_box.add_child(st_lbl)

	var st_hbox := HBoxContainer.new()
	tuning_tab_box.add_child(st_hbox)
	_add_tuning_btn(st_hbox, "0 (Infinite)", func(): _set_stamina_drain(0.0))
	_add_tuning_btn(st_hbox, "14 (Half)", func(): _set_stamina_drain(14.0))
	_add_tuning_btn(st_hbox, "28 (Default)", func(): _set_stamina_drain(28.0))

	# 5. Quick Teleport Locations
	var tp_lbl := Label.new()
	tp_lbl.text = "🧭 TOWN SECTOR TELEPORT"
	tp_lbl.add_theme_font_size_override("font_size", 12)
	tp_lbl.modulate = Color(0.55, 0.95, 0.70)
	tuning_tab_box.add_child(tp_lbl)

	var tp_grid := GridContainer.new()
	tp_grid.columns = 2
	tuning_tab_box.add_child(tp_grid)
	_add_phase_btn(tp_grid, "Town Square", func(): _teleport_player_to(Vector3(0.0, 0.05, 0.0)))
	_add_phase_btn(tp_grid, "Pump Station", func(): _teleport_player_to(Vector3(-6.0, 0.05, 24.0)))
	_add_phase_btn(tp_grid, "Greenhouse Fields", func(): _teleport_player_to(Vector3(-20.0, 0.05, -20.0)))
	_add_phase_btn(tp_grid, "Salvage Yard", func(): _teleport_player_to(Vector3(20.0, 0.05, -20.0)))

func _add_tuning_btn(parent: Node, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _set_channel_scale(scale: float) -> void:
	Resident3DClass.task_channel_scale = scale
	_show_popup_feedback("Task channeling scale set to %.2fx" % scale)
	_refresh_display()

func _set_court_bot_delay(delay: float) -> void:
	if game_manager != null:
		game_manager.court_bot_deliberation_delay = delay
		_show_popup_feedback("Court bot delay set to %.1fs" % delay)
		_refresh_display()

func _set_shove_cooldown(cd: float) -> void:
	Resident3DClass.shove_cooldown_override = cd
	_show_popup_feedback("Civic shove cooldown set to %.1fs" % cd)
	_refresh_display()

func _set_stamina_drain(drain: float) -> void:
	if player_node != null:
		player_node.stamina_drain = drain
		_show_popup_feedback("Player sprint drain set to %.0f/s" % drain)

func _refresh_display() -> void:
	if game_manager != null and crisis_status_label != null:
		crisis_status_label.text = "Resources: Water: %d%% | Stability: %d%% | Scrap: %d | Works: %.1f%%" % [
			int(game_manager.water), int(game_manager.stability), int(game_manager.scrap), game_manager.common_works
		]
	if tuning_status_label != null:
		var court_d: float = game_manager.court_bot_deliberation_delay if game_manager != null else 2.5
		tuning_status_label.text = "Channel: %.2fx | Shove CD: %.1fs | Court Delay: %.1fs | Drain: %.1fx" % [
			Resident3DClass.task_channel_scale, Resident3DClass.shove_cooldown_override, court_d, (game_manager.crisis_drain_scale if game_manager != null else 1.0)
		]
	if current_tab == "ROSTER":
		_rebuild_roster_list()

func _show_popup_feedback(msg: String) -> void:
	if player_node != null and player_node.has_method("show_popup"):
		player_node.show_popup(msg, Color(0.45, 0.95, 1.0))
