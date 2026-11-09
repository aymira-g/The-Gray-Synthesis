extends PanelContainer

# ==============================================================================
# The Gray Synthesis - Pre-Match 10-Hero Selection & Matchmaking Draft Lobby
# ==============================================================================
# Allows the local player to browse and select any of the 10 unique Heroes
# (each with 1 unique [F] Active Ability + 1 unique Passive Trait), inspect
# full ability/passive/lore details, and watch the 9 AI Bots automatically fill
# the remaining 9 Hero slots before deploying into Open Town.
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

signal hero_selected(hero_index: int, hero_id: String)
signal draft_locked_in(hero_index: int, hero_id: String)

var main_node: Node = null
var game_manager: Node = null
var audio_manager: Node = null

var selected_hero_index: int = 0
var selected_hero_id: String = "kaelen_vance"
var is_locked_in: bool = false
var draft_assignments: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

# UI Nodes
var header_title_label: Label
var header_subtitle_label: Label
var hero_grid: GridContainer
var hero_card_buttons: Array[Button] = []

# Inspector Nodes
var inspector_hero_name_label: Label
var inspector_job_badge_label: Label
var inspector_swatch_torso: ColorRect
var inspector_swatch_accent: ColorRect
var inspector_active_title_label: Label
var inspector_active_desc_label: Label
var inspector_passive_title_label: Label
var inspector_passive_desc_label: Label
var inspector_lore_label: Label
var inspector_secret_deal_label: Label

# Matchmaking Roster Nodes (1 Local Player + 9 AI Bots)
var lobby_status_label: Label
var lobby_slot_labels: Array[Label] = []

# Bottom Action Buttons
var random_hero_btn: Button
var lock_in_btn: Button
var close_preview_btn: Button

var _is_built: bool = false

func _init() -> void:
	name = "HeroDraftLobby3D"

func setup(p_main: Node, p_gm: Node, p_audio: Node = null) -> void:
	main_node = p_main
	game_manager = p_gm
	audio_manager = p_audio
	if not _is_built:
		_build_ui()
	select_hero_by_index(selected_hero_index, false)

func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -560.0
	offset_top = -305.0
	offset_right = 560.0
	offset_bottom = 305.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	panel_style.border_color = Color(0.38, 0.86, 1.0, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel_style)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 18)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_right", 18)
	root_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(main_vbox)

	# --------------------------------------------------------------------------
	# 1. Header Banner
	# --------------------------------------------------------------------------
	header_title_label = Label.new()
	header_title_label.name = "HeaderTitleLabel"
	header_title_label.text = "★ MATCHMAKING & 10-HERO SELECTION LOBBY (LOCAL + 9 AI BOTS) ★"
	header_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title_label.add_theme_font_size_override("font_size", 19)
	header_title_label.modulate = Color(1.0, 0.90, 0.45)
	main_vbox.add_child(header_title_label)

	header_subtitle_label = Label.new()
	header_subtitle_label.name = "HeaderSubtitleLabel"
	header_subtitle_label.text = "Choose your Hero (1 Unique [F] Active + 1 Unique Passive). Keys [1]-[9],[0] Select Hero | [Tab] Random | [Space/Enter] Lock In & Start"
	header_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_subtitle_label.add_theme_font_size_override("font_size", 12)
	header_subtitle_label.modulate = Color(0.75, 0.88, 0.98)
	main_vbox.add_child(header_subtitle_label)

	var top_sep := HSeparator.new()
	main_vbox.add_child(top_sep)

	# --------------------------------------------------------------------------
	# 2. Main 3-Section Body (Left: 10-Hero Grid | Center: Kit Inspector | Right: 10-Slot Matchmaking)
	# --------------------------------------------------------------------------
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body_hbox)

	# --- Section A: 10-Hero Roster Grid (2 columns x 5 rows) ---
	var grid_vbox := VBoxContainer.new()
	grid_vbox.custom_minimum_size = Vector2(410, 0)
	grid_vbox.add_theme_constant_override("separation", 6)
	body_hbox.add_child(grid_vbox)

	var grid_header := Label.new()
	grid_header.text = "10-HERO ROSTER (2 PER CIVIC JOB)"
	grid_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_header.add_theme_font_size_override("font_size", 13)
	grid_header.modulate = Color(0.55, 0.92, 1.0)
	grid_vbox.add_child(grid_header)

	hero_grid = GridContainer.new()
	hero_grid.name = "HeroGrid"
	hero_grid.columns = 2
	hero_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_grid.add_theme_constant_override("h_separation", 8)
	hero_grid.add_theme_constant_override("v_separation", 6)
	grid_vbox.add_child(hero_grid)

	hero_card_buttons.clear()
	for idx in range(C.HERO_ROSTER.size()):
		var h: Dictionary = C.HERO_ROSTER[idx]
		var card_btn := Button.new()
		card_btn.name = "HeroCard_%d" % idx
		card_btn.custom_minimum_size = Vector2(200, 74)
		card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_btn.focus_mode = Control.FOCUS_NONE
		var hotkey_str: String = str((idx + 1) % 10)
		card_btn.text = "[%s] %s\n%s\n[F] %s | P: %s" % [
			hotkey_str,
			str(h.get("name", "")),
			str(h.get("civic_job", "")),
			str(h.get("active_name", "")),
			str(h.get("passive_name", ""))
		]
		card_btn.add_theme_font_size_override("font_size", 11)
		var captured_idx := idx
		card_btn.pressed.connect(func(): _on_hero_card_pressed(captured_idx))
		hero_grid.add_child(card_btn)
		hero_card_buttons.append(card_btn)

	# --- Section B: Selected Hero Dossier & Kit Inspector ---
	var inspector_panel := PanelContainer.new()
	inspector_panel.name = "HeroInspectorPanel"
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var insp_style := StyleBoxFlat.new()
	insp_style.bg_color = Color(0.09, 0.13, 0.20, 0.95)
	insp_style.border_color = Color(0.45, 0.78, 0.95, 0.65)
	insp_style.border_width_left = 1
	insp_style.border_width_top = 1
	insp_style.border_width_right = 1
	insp_style.border_width_bottom = 1
	insp_style.corner_radius_top_left = 6
	insp_style.corner_radius_top_right = 6
	insp_style.corner_radius_bottom_left = 6
	insp_style.corner_radius_bottom_right = 6
	inspector_panel.add_theme_stylebox_override("panel", insp_style)
	body_hbox.add_child(inspector_panel)

	var insp_margin := MarginContainer.new()
	insp_margin.add_theme_constant_override("margin_left", 14)
	insp_margin.add_theme_constant_override("margin_top", 12)
	insp_margin.add_theme_constant_override("margin_right", 14)
	insp_margin.add_theme_constant_override("margin_bottom", 12)
	inspector_panel.add_child(insp_margin)

	var insp_vbox := VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 8)
	insp_margin.add_child(insp_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	insp_vbox.add_child(title_row)

	inspector_swatch_torso = ColorRect.new()
	inspector_swatch_torso.name = "InspectorSwatchTorso"
	inspector_swatch_torso.custom_minimum_size = Vector2(22, 22)
	title_row.add_child(inspector_swatch_torso)

	inspector_swatch_accent = ColorRect.new()
	inspector_swatch_accent.name = "InspectorSwatchAccent"
	inspector_swatch_accent.custom_minimum_size = Vector2(12, 22)
	title_row.add_child(inspector_swatch_accent)

	inspector_hero_name_label = Label.new()
	inspector_hero_name_label.name = "InspectorHeroNameLabel"
	inspector_hero_name_label.text = "Kaelen Vance — Chief Hydro-Engineer"
	inspector_hero_name_label.add_theme_font_size_override("font_size", 16)
	inspector_hero_name_label.modulate = Color(1.0, 0.92, 0.50)
	title_row.add_child(inspector_hero_name_label)

	inspector_job_badge_label = Label.new()
	inspector_job_badge_label.name = "InspectorJobBadgeLabel"
	inspector_job_badge_label.text = "Civic Job: Pump Technician  |  Max Stamina: 100"
	inspector_job_badge_label.add_theme_font_size_override("font_size", 13)
	inspector_job_badge_label.modulate = Color(0.60, 0.92, 1.0)
	insp_vbox.add_child(inspector_job_badge_label)

	insp_vbox.add_child(HSeparator.new())

	inspector_active_title_label = Label.new()
	inspector_active_title_label.name = "InspectorActiveTitleLabel"
	inspector_active_title_label.text = "⚡ [F] ACTIVE ABILITY: Field Calibrator (14.0s CD)"
	inspector_active_title_label.add_theme_font_size_override("font_size", 14)
	inspector_active_title_label.modulate = Color(0.45, 0.98, 0.72)
	insp_vbox.add_child(inspector_active_title_label)

	inspector_active_desc_label = Label.new()
	inspector_active_desc_label.name = "InspectorActiveDescLabel"
	inspector_active_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_active_desc_label.add_theme_font_size_override("font_size", 12)
	inspector_active_desc_label.modulate = Color(0.90, 0.94, 0.98)
	insp_vbox.add_child(inspector_active_desc_label)

	insp_vbox.add_child(HSeparator.new())

	inspector_passive_title_label = Label.new()
	inspector_passive_title_label.name = "InspectorPassiveTitleLabel"
	inspector_passive_title_label.text = "🛡️ PASSIVE TRAIT: Hydro-Mastery"
	inspector_passive_title_label.add_theme_font_size_override("font_size", 14)
	inspector_passive_title_label.modulate = Color(0.98, 0.82, 0.42)
	insp_vbox.add_child(inspector_passive_title_label)

	inspector_passive_desc_label = Label.new()
	inspector_passive_desc_label.name = "InspectorPassiveDescLabel"
	inspector_passive_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_passive_desc_label.add_theme_font_size_override("font_size", 12)
	inspector_passive_desc_label.modulate = Color(0.90, 0.94, 0.98)
	insp_vbox.add_child(inspector_passive_desc_label)

	insp_vbox.add_child(HSeparator.new())

	inspector_lore_label = Label.new()
	inspector_lore_label.name = "InspectorLoreLabel"
	inspector_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_lore_label.add_theme_font_size_override("font_size", 12)
	inspector_lore_label.modulate = Color(0.76, 0.82, 0.90)
	insp_vbox.add_child(inspector_lore_label)

	insp_vbox.add_child(HSeparator.new())

	inspector_secret_deal_label = Label.new()
	inspector_secret_deal_label.name = "InspectorSecretDealLabel"
	inspector_secret_deal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_secret_deal_label.add_theme_font_size_override("font_size", 12)
	inspector_secret_deal_label.modulate = Color(0.98, 0.78, 0.48)
	insp_vbox.add_child(inspector_secret_deal_label)

	# --- Section C: Live 10-Slot Matchmaking Roster (Local + 9 AI Bots) ---
	var roster_panel := PanelContainer.new()
	roster_panel.name = "MatchmakingRosterPanel"
	roster_panel.custom_minimum_size = Vector2(285, 0)
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_panel.add_theme_stylebox_override("panel", insp_style)
	body_hbox.add_child(roster_panel)

	var roster_margin := MarginContainer.new()
	roster_margin.add_theme_constant_override("margin_left", 10)
	roster_margin.add_theme_constant_override("margin_top", 10)
	roster_margin.add_theme_constant_override("margin_right", 10)
	roster_margin.add_theme_constant_override("margin_bottom", 10)
	roster_panel.add_child(roster_margin)

	var roster_vbox := VBoxContainer.new()
	roster_vbox.add_theme_constant_override("separation", 5)
	roster_margin.add_child(roster_vbox)

	lobby_status_label = Label.new()
	lobby_status_label.name = "LobbyStatusLabel"
	lobby_status_label.text = "👥 MATCH LOBBY (1 PLAYER + 9 BOTS)"
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status_label.add_theme_font_size_override("font_size", 13)
	lobby_status_label.modulate = Color(0.55, 0.95, 0.78)
	roster_vbox.add_child(lobby_status_label)

	roster_vbox.add_child(HSeparator.new())

	lobby_slot_labels.clear()
	for slot_i in range(10):
		var slot_lbl := Label.new()
		slot_lbl.name = "LobbySlot_%d" % (slot_i + 1)
		slot_lbl.add_theme_font_size_override("font_size", 11)
		roster_vbox.add_child(slot_lbl)
		lobby_slot_labels.append(slot_lbl)

	# --------------------------------------------------------------------------
	# 3. Bottom Action Bar
	# --------------------------------------------------------------------------
	main_vbox.add_child(HSeparator.new())

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btn_hbox)

	random_hero_btn = Button.new()
	random_hero_btn.name = "RandomHeroButton"
	random_hero_btn.text = " 🎲 Random Hero [Tab] "
	random_hero_btn.custom_minimum_size = Vector2(210, 40)
	random_hero_btn.focus_mode = Control.FOCUS_NONE
	random_hero_btn.pressed.connect(func(): select_random_hero())
	btn_hbox.add_child(random_hero_btn)

	lock_in_btn = Button.new()
	lock_in_btn.name = "LockInHeroButton"
	lock_in_btn.text = " ✓ Lock In Hero & Start Match [Space / Enter] "
	lock_in_btn.custom_minimum_size = Vector2(340, 40)
	lock_in_btn.focus_mode = Control.FOCUS_NONE
	lock_in_btn.modulate = Color(0.55, 1.0, 0.78)
	lock_in_btn.pressed.connect(func(): confirm_and_start_match())
	btn_hbox.add_child(lock_in_btn)

	close_preview_btn = Button.new()
	close_preview_btn.name = "ClosePreviewButton"
	close_preview_btn.text = " ✕ Hide Overlay "
	close_preview_btn.custom_minimum_size = Vector2(150, 40)
	close_preview_btn.focus_mode = Control.FOCUS_NONE
	close_preview_btn.pressed.connect(func(): close_lobby())
	btn_hbox.add_child(close_preview_btn)

func _on_hero_card_pressed(hero_idx: int) -> void:
	select_hero_by_index(hero_idx, true)

func select_hero_by_id(h_id: String, play_sound: bool = false) -> void:
	for i in range(C.HERO_ROSTER.size()):
		if str(C.HERO_ROSTER[i].get("hero_id", "")) == h_id:
			select_hero_by_index(i, play_sound)
			return
	select_hero_by_index(0, play_sound)

func select_hero_by_index(hero_idx: int, play_sound: bool = false) -> void:
	if C.HERO_ROSTER.is_empty():
		return
	var clamped_idx: int = clampi(hero_idx, 0, C.HERO_ROSTER.size() - 1)
	selected_hero_index = clamped_idx
	var profile: Dictionary = C.get_hero_by_index(selected_hero_index)
	selected_hero_id = str(profile.get("hero_id", "kaelen_vance"))

	# Compute 10-slot matchmaking assignment:
	# Slot 0 (Player) gets selected_hero_index; Slot `selected_hero_index` gets 0; all other slots keep their index.
	draft_assignments.clear()
	for slot in range(10):
		if slot == 0:
			draft_assignments.append(selected_hero_index)
		elif slot == selected_hero_index:
			draft_assignments.append(0)
		else:
			draft_assignments.append(slot)

	apply_draft_to_residents()
	refresh_ui()

	if play_sound and audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_click", 1.05, -3.0)

	hero_selected.emit(selected_hero_index, selected_hero_id)

func select_random_hero(play_sound: bool = true) -> int:
	var count: int = C.HERO_ROSTER.size()
	if count <= 1:
		select_hero_by_index(0, play_sound)
		return 0
	var next_idx: int = randi() % count
	if next_idx == selected_hero_index:
		next_idx = (selected_hero_index + 1) % count
	select_hero_by_index(next_idx, play_sound)
	return selected_hero_index

func apply_draft_to_residents() -> void:
	if main_node == null:
		return
	var res_list: Array = main_node.get("residents") if main_node.get("residents") != null else []
	if res_list.size() < 10 or draft_assignments.size() < 10:
		return

	for slot in range(10):
		var res = res_list[slot]
		if res != null and res.has_method("set_hero_by_index"):
			res.set_hero_by_index(draft_assignments[slot])

	if main_node.has_method("refresh_bot_memories"):
		main_node.refresh_bot_memories()
	if main_node.has_method("_update_hud"):
		main_node._update_hud()

func confirm_and_start_match() -> void:
	is_locked_in = true
	apply_draft_to_residents()
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("task_complete", 1.05, 0.2)
	draft_locked_in.emit(selected_hero_index, selected_hero_id)
	close_lobby()
	if game_manager != null and game_manager.current_phase == game_manager.Phase.BRIEFING:
		game_manager.advance_to_next_phase()

func open_lobby() -> void:
	if not _is_built:
		_build_ui()
	visible = true
	refresh_ui()

func close_lobby() -> void:
	visible = false

func toggle_lobby() -> void:
	if visible:
		close_lobby()
	else:
		open_lobby()

func refresh_ui() -> void:
	if not _is_built:
		return

	var in_briefing: bool = (game_manager == null or game_manager.current_phase == game_manager.Phase.BRIEFING)
	if random_hero_btn != null:
		random_hero_btn.disabled = not in_briefing
	if lock_in_btn != null:
		lock_in_btn.text = " ✓ Lock In Hero & Start Match [Space / Enter] " if in_briefing else " ✓ Return to Match [Tab] "

	# 1. Highlight selected Hero card
	for i in range(hero_card_buttons.size()):
		var btn: Button = hero_card_buttons[i]
		var h: Dictionary = C.HERO_ROSTER[i]
		var is_sel: bool = (i == selected_hero_index)
		var c_style := StyleBoxFlat.new()
		var t_col: Color = h.get("torso_color", Color(0.3, 0.35, 0.4))
		var a_col: Color = h.get("accent_color", Color(0.5, 0.85, 1.0))
		if is_sel:
			c_style.bg_color = t_col.darkened(0.15)
			c_style.border_color = Color(0.35, 1.0, 0.90)
			c_style.border_width_left = 3
			c_style.border_width_top = 3
			c_style.border_width_right = 3
			c_style.border_width_bottom = 3
			btn.modulate = Color(1.0, 1.0, 1.0)
		else:
			c_style.bg_color = t_col.darkened(0.45)
			c_style.border_color = a_col.darkened(0.25)
			c_style.border_width_left = 1
			c_style.border_width_top = 1
			c_style.border_width_right = 1
			c_style.border_width_bottom = 1
			btn.modulate = Color(0.88, 0.92, 0.96)
		c_style.corner_radius_top_left = 5
		c_style.corner_radius_top_right = 5
		c_style.corner_radius_bottom_left = 5
		c_style.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", c_style)
		btn.add_theme_stylebox_override("hover", c_style)
		btn.add_theme_stylebox_override("pressed", c_style)

	# 2. Populate Hero Inspector
	var sel_h: Dictionary = C.get_hero_by_index(selected_hero_index)
	inspector_swatch_torso.color = sel_h.get("torso_color", Color(0.4, 0.4, 0.4))
	inspector_swatch_accent.color = sel_h.get("accent_color", Color(0.4, 0.8, 1.0))
	inspector_hero_name_label.text = "%s — %s" % [str(sel_h.get("name", "")), str(sel_h.get("title", ""))]
	var max_stam: int = 125 if str(sel_h.get("passive_id", "")) == "heavy_frame" else 100
	inspector_job_badge_label.text = "Civic Job: %s  |  Max Stamina: %d" % [str(sel_h.get("civic_job", "")), max_stam]
	inspector_active_title_label.text = "⚡ [F] ACTIVE: %s (%.0fs CD)" % [
		str(sel_h.get("active_name", "")),
		float(sel_h.get("active_cd", 14.0))
	]
	inspector_active_desc_label.text = str(sel_h.get("active_desc", ""))
	inspector_passive_title_label.text = "🛡️ PASSIVE: %s" % str(sel_h.get("passive_name", ""))
	inspector_passive_desc_label.text = str(sel_h.get("passive_desc", ""))
	inspector_lore_label.text = "📖 Lore: \"%s\"" % str(sel_h.get("lore", ""))

	# Secret Role Deal status for Local Player
	var p_node = main_node.get("player_node") if main_node != null else null
	if p_node != null:
		var s_role: String = str(p_node.get("secret_role")).to_upper()
		var op_kit: String = str(p_node.get("operative_kit")).to_upper()
		var kit_note: String = (" | Covert [C] Kit: %s" % op_kit) if op_kit != "NONE" else " | Court Voter (1 of 4)"
		inspector_secret_deal_label.text = "🔒 YOUR SECRET DEAL: %s%s\n(Your public Hero kit never leaks your secret alignment)" % [s_role, kit_note]
	else:
		inspector_secret_deal_label.text = "🔒 SECRET ALIGNMENT: Dealt independently at Match Start (Zero Role Leakage)"

	# 3. Populate 10-Slot Matchmaking Roster (Slot 1 = YOU, Slots 2..10 = 9 AI Bots)
	for slot in range(mini(10, lobby_slot_labels.size())):
		var h_idx: int = draft_assignments[slot] if slot < draft_assignments.size() else slot
		var h_info: Dictionary = C.get_hero_by_index(h_idx)
		var lbl: Label = lobby_slot_labels[slot]
		if slot == 0:
			lbl.text = "★ 1 [YOU]: %s (%s)" % [str(h_info.get("name", "")), str(h_info.get("civic_job", ""))]
			lbl.modulate = Color(0.35, 1.0, 0.90)
		else:
			lbl.text = "🤖 %d [BOT]: %s (%s)" % [slot + 1, str(h_info.get("name", "")), str(h_info.get("civic_job", ""))]
			lbl.modulate = Color(0.84, 0.88, 0.94)
