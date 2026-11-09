class_name PublicHUD
extends CanvasLayer

const C = preload("res://scripts/GameConstants.gd")
const CHANNEL_DURATION: float = C.CHANNEL_DURATION

var game_manager: Node
var town_map: Node2D
var player: CharacterBody2D
var main_scene: Node
var all_residents: Array = []

var hud_drawer: Control
var clickable_buttons: Array[Dictionary] = []
var hovered_button_id: String = ""

func _ready() -> void:
	hud_drawer = Control.new()
	hud_drawer.name = "HUDDrawer"
	hud_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_drawer.draw.connect(_on_hud_draw)
	add_child(hud_drawer)

func _process(_delta: float) -> void:
	if hud_drawer != null:
		var m_pos := hud_drawer.get_local_mouse_position()
		hovered_button_id = ""
		for btn in clickable_buttons:
			if btn["rect"].has_point(m_pos):
				hovered_button_id = btn["id"]
				break
		hud_drawer.queue_redraw()

func _input(event: InputEvent) -> void:
	if game_manager == null or hud_drawer == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m_pos := hud_drawer.get_local_mouse_position()
		for btn in clickable_buttons:
			if btn["rect"].has_point(m_pos):
				if game_manager.evidence_journal_open and String(btn["id"]) != "toggle_journal" and not String(btn["id"]).begins_with("journal") and not String(btn["id"]).begins_with("table_"):
					return
				_activate_ui_button(btn["id"])
				get_viewport().set_input_as_handled()
				return

func _activate_ui_button(btn_id: String) -> void:
	if btn_id.begins_with("table_item:"):
		game_manager.table_clue_by_id(int(player.resident_id), btn_id.trim_prefix("table_item:"))
		return
	if btn_id.begins_with("alibi:"):
		game_manager.set_player_alibi_region(btn_id.trim_prefix("alibi:"), int(player.resident_id), all_residents)
		return
	match btn_id:
		"pref_random":
			game_manager.player_role_pref = "random"
		"pref_ecology":
			game_manager.player_role_pref = "ecology"
		"pref_technology":
			game_manager.player_role_pref = "technology"
		"pref_civilian":
			game_manager.player_role_pref = "civilian"
		"cycle_kit_pref":
			game_manager.cycle_player_kit_pref()
		"cycle_civic_job":
			game_manager.cycle_player_civic_job(all_residents)
		"start_match":
			if main_scene != null and main_scene.has_method("start_new_match"):
				main_scene.start_new_match()
		"close_dossier":
			if game_manager.current_phase == game_manager.Phase.BRIEFING:
				game_manager.advance_to_next_phase()
			else:
				game_manager.dossier_open = false
		"toggle_dossier":
			if game_manager.current_phase != game_manager.Phase.LOBBY and game_manager.current_phase != game_manager.Phase.MATCH_OVER:
				game_manager.dossier_open = not game_manager.dossier_open
		"use_shove":
			if player != null:
				player.try_civic_shove()
		"use_civic":
			if player != null:
				player.try_civic_ability()
		"use_special":
			if player != null:
				player.try_faction_ability()
		"use_inspect":
			if player != null:
				player.try_inspect_site()
		"toggle_journal":
			game_manager.evidence_journal_open = not game_manager.evidence_journal_open
		"toggle_settings":
			if main_scene != null and main_scene.has_method("toggle_settings_menu"):
				main_scene.toggle_settings_menu()
		"table_all":
			game_manager.table_player_clues(int(player.resident_id), true)
		"motion_1":
			game_manager.cast_player_motion_vote(1)
		"motion_2":
			game_manager.cast_player_motion_vote(2)
		"motion_3":
			game_manager.cast_player_motion_vote(3)
		"archive_loyal":
			game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_LOYAL)
		"archive_whistleblower":
			game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_WHISTLEBLOWER)
		"archive_entrust_eco":
			game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_ENTRUST_ECO)
		"archive_entrust_tech":
			game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_ENTRUST_TECH)
		"archive_reserve_cw":
			game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_RESERVE_CW)
		"next_phase":
			game_manager.advance_to_next_phase()
		"toggle_drain":
			game_manager.toggle_drain()
		"return_lobby":
			if main_scene != null and main_scene.has_method("reset_sandbox"):
				main_scene.reset_sandbox()
		"court_2-2":
			game_manager.set_court_preview_mode("2-2", all_residents)
		"court_3-1_eco":
			game_manager.set_court_preview_mode("3-1_eco", all_residents)
		"court_3-1_tech":
			game_manager.set_court_preview_mode("3-1_tech", all_residents)
		"court_4-0_eco":
			game_manager.set_court_preview_mode("4-0_eco", all_residents)
		"court_4-0_tech":
			game_manager.set_court_preview_mode("4-0_tech", all_residents)
		"court_vote_eco":
			game_manager.cast_player_court_ballot("Ecology")
		"court_vote_tech":
			game_manager.cast_player_court_ballot("Technology")
		"court_fast_forward":
			game_manager.court_fast_forward = true
		"strat_confrontation":
			game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_CONFRONTATION)
		"strat_peace":
			game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_PEACE)
		"strat_resolve_now":
			game_manager.resolve_strategic_decision()
		"charter_term_power":
			game_manager.cycle_charter_term("power")
		"charter_term_land":
			game_manager.cycle_charter_term("land")
		"charter_term_med":
			game_manager.cycle_charter_term("med")

func _register_button(id: String, rect: Rect2) -> bool:
	clickable_buttons.append({"id": id, "rect": rect})
	return hovered_button_id == id

func _on_hud_draw() -> void:
	if game_manager == null or town_map == null or player == null:
		return

	clickable_buttons.clear()
	var font := ThemeDB.fallback_font
	var vp_size := hud_drawer.get_viewport_rect().size

	# 1. TOP BAR: Phase, Clock, Water, Town Stability, Scrap, Common Works
	var top_bar := Rect2(16, 12, vp_size.x - 32, 74)
	hud_drawer.draw_rect(top_bar, Color(0.08, 0.10, 0.13, 0.92), true)
	hud_drawer.draw_rect(top_bar, Color(0.32, 0.38, 0.46, 0.9), false, 2.0)

	var mins := int(game_manager.time_remaining) / 60
	var secs := int(game_manager.time_remaining) % 60
	var clock_str := "%02d:%02d" % [mins, secs]
	hud_drawer.draw_string(font, Vector2(28, 38), game_manager.get_phase_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.84, 0.96))
	hud_drawer.draw_string(font, Vector2(28, 68), clock_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.96, 0.98, 1.0))

	_draw_meter(
		Vector2(235, 24),
		Vector2(215, 22),
		"WATER (Irrigation)",
		game_manager.water,
		game_manager.MAX_WATER,
		Color(0.28, 0.72, 0.96),
		game_manager.water <= 0.1
	)

	_draw_meter(
		Vector2(475, 24),
		Vector2(215, 22),
		"TOWN STABILITY (Crops)",
		game_manager.stability,
		game_manager.MAX_STABILITY,
		Color(0.38, 0.86, 0.52),
		game_manager.stability <= 0.1
	)

	var scrap_rect := Rect2(705, 20, 115, 58)
	hud_drawer.draw_rect(scrap_rect, Color(0.14, 0.14, 0.16, 0.95), true)
	hud_drawer.draw_rect(scrap_rect, Color(0.85, 0.64, 0.32, 0.85), false, 1.5)
	hud_drawer.draw_string(font, Vector2(715, 38), "TOWN SCRAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.75, 0.48))
	hud_drawer.draw_string(font, Vector2(715, 62), "%d / %d" % [game_manager.scrap, game_manager.MAX_SCRAP], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.88, 0.62))

	# Common Works 3-Track Sub-Meters + Total
	var cw_box := Rect2(830, 20, 310, 58)
	hud_drawer.draw_rect(cw_box, Color(0.12, 0.13, 0.18, 0.95), true)
	hud_drawer.draw_rect(cw_box, Color(0.55, 0.48, 0.72, 0.8), false, 1.5)

	var cw_tot: int = int(round(game_manager.common_works))
	hud_drawer.draw_string(font, cw_box.position + Vector2(8, 16), "COMMON WORKS: %d%%" % cw_tot, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.88, 1.0))
	hud_drawer.draw_string(font, cw_box.position + Vector2(156, 16), game_manager.get_common_works_status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.78, 0.95, 0.82))

	# 3 Interdependent Sub-track mini-bars
	var mini_w := 94.0
	var eco_pct: float = clampf(game_manager.common_works_eco / 100.0, 0.0, 1.0)
	var tech_pct: float = clampf(game_manager.common_works_tech / 100.0, 0.0, 1.0)
	var struct_pct: float = clampf(game_manager.common_works_struct / 100.0, 0.0, 1.0)

	# Eco Mini-bar
	var eco_r := Rect2(cw_box.position.x + 8, cw_box.position.y + 24, mini_w, 12)
	hud_drawer.draw_rect(eco_r, Color(0.18, 0.22, 0.20), true)
	hud_drawer.draw_rect(Rect2(eco_r.position, Vector2(mini_w * eco_pct, 12)), Color(0.38, 0.88, 0.50), true)
	hud_drawer.draw_rect(eco_r, Color(0.48, 0.78, 0.58), false, 1.0)
	hud_drawer.draw_string(font, eco_r.position + Vector2(4, 10), "Eco:%d%%" % int(game_manager.common_works_eco), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 1.0, 0.95))

	# Tech Mini-bar
	var tech_r := Rect2(cw_box.position.x + 108, cw_box.position.y + 24, mini_w, 12)
	hud_drawer.draw_rect(tech_r, Color(0.24, 0.20, 0.16), true)
	hud_drawer.draw_rect(Rect2(tech_r.position, Vector2(mini_w * tech_pct, 12)), Color(0.95, 0.68, 0.32), true)
	hud_drawer.draw_rect(tech_r, Color(0.85, 0.65, 0.45), false, 1.0)
	hud_drawer.draw_string(font, tech_r.position + Vector2(4, 10), "Tech:%d%%" % int(game_manager.common_works_tech), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.98, 0.92))

	# Struct Mini-bar
	var struct_r := Rect2(cw_box.position.x + 208, cw_box.position.y + 24, mini_w, 12)
	hud_drawer.draw_rect(struct_r, Color(0.22, 0.18, 0.28), true)
	hud_drawer.draw_rect(Rect2(struct_r.position, Vector2(mini_w * struct_pct, 12)), Color(0.76, 0.62, 0.98), true)
	hud_drawer.draw_rect(struct_r, Color(0.72, 0.58, 0.88), false, 1.0)
	hud_drawer.draw_string(font, struct_r.position + Vector2(4, 10), "Str:%d%%" % int(game_manager.common_works_struct), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.98, 0.95, 1.0))

	# Overall combined bar
	var tot_bar := Rect2(cw_box.position.x + 8, cw_box.position.y + 42, 294, 8)
	hud_drawer.draw_rect(tot_bar, Color(0.16, 0.16, 0.20), true)
	var tot_pct: float = clampf(game_manager.common_works / 100.0, 0.0, 1.0)
	hud_drawer.draw_rect(Rect2(tot_bar.position, Vector2(tot_bar.size.x * tot_pct, 8)), Color(0.68, 0.58, 0.95), true)
	hud_drawer.draw_rect(tot_bar, Color(0.45, 0.40, 0.65), false, 1.0)

	var drain_box := Rect2(vp_size.x - 245, 22, 215, 52)
	var drain_hov := _register_button("toggle_drain", drain_box)
	var drain_col := Color(0.38, 0.82, 0.55) if game_manager.drain_enabled else Color(0.95, 0.78, 0.35)
	hud_drawer.draw_rect(drain_box, Color(0.18, 0.22, 0.28, 0.98) if drain_hov else Color(0.12, 0.14, 0.18, 0.95), true)
	hud_drawer.draw_rect(drain_box, drain_col.lightened(0.2) if drain_hov else drain_col, false, 2.0 if drain_hov else 1.5)
	hud_drawer.draw_string(font, drain_box.position + Vector2(12, 20), "CRISIS DRAIN [T / Click]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.80, 0.85, 0.92))
	var eff_mult: float = game_manager.get_drain_multiplier() * (1.25 if (game_manager.current_phase == game_manager.Phase.ESCALATION or game_manager.current_phase == game_manager.Phase.FINALE) else 1.0)
	var drain_txt := ("ON (x%.2f rate)" % eff_mult) if game_manager.drain_enabled else "PAUSED (Free Flow)"
	hud_drawer.draw_string(font, drain_box.position + Vector2(12, 42), drain_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, drain_col)

	# Escalation / Finale Contested Objectives Widget
	if game_manager.current_phase == game_manager.Phase.ESCALATION:
		var obj_w := Rect2(16, 92, 435, 42)
		hud_drawer.draw_rect(obj_w, Color(0.08, 0.10, 0.14, 0.94), true)
		hud_drawer.draw_rect(obj_w, Color(0.48, 0.65, 0.85, 0.85), false, 1.5)
		var gen_str: String = "Generator: %d%% Primed (Tech) | %d%% Stabilized (Eco)" % [int(game_manager.generator_tech_primed), int(game_manager.generator_eco_stabilized)]
		var bcn_str: String = "Beacon: %d%% Eco Freq | %d%% Tech Freq" % [int(game_manager.beacon_eco_freq), int(game_manager.beacon_tech_freq)]
		hud_drawer.draw_string(font, obj_w.position + Vector2(10, 16), "CONTESTED OBJECTIVES (Escalation Active):", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.85, 0.55))
		hud_drawer.draw_string(font, obj_w.position + Vector2(10, 32), "%s  •  %s" % [gen_str, bcn_str], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.92, 0.98))
	elif game_manager.current_phase == game_manager.Phase.FINALE:
		if game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION:
			_draw_confrontation_hud(font, vp_size)
		elif game_manager.finale_route == C.FINALE_ROUTE_PEACE:
			_draw_peace_hud(font, vp_size)

	if game_manager.is_active_play_phase() and (game_manager.water <= 0.1 or game_manager.stability <= 0.1):
		var warn_rect := Rect2(vp_size.x * 0.5 - 250, 96, 500, 34)
		hud_drawer.draw_rect(warn_rect, Color(0.45, 0.12, 0.12, 0.92), true)
		hud_drawer.draw_rect(warn_rect, Color(1.0, 0.42, 0.38, 1.0), false, 2.0)
		hud_drawer.draw_string(
			font,
			warn_rect.position + Vector2(22, 22),
			"CRITICAL SHORTAGE: Repair Pump or Tend Crops! (Session continues)",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(1.0, 0.88, 0.85)
		)

	# 2. TOP-RIGHT MINIMAP & ACTIVITY LOG
	var mm_rect := Rect2(vp_size.x - 246, 98, 230, 172)
	hud_drawer.draw_rect(mm_rect, Color(0.07, 0.09, 0.12, 0.92), true)
	hud_drawer.draw_rect(mm_rect, Color(0.36, 0.42, 0.52, 0.9), false, 2.0)
	var mm_scale := Vector2(mm_rect.size.x / 2400.0, mm_rect.size.y / 1800.0)
	var mm_center := mm_rect.position + mm_rect.size * 0.5

	for reg in town_map.regions:
		var rr: Rect2 = reg["rect"]
		var mini_r := Rect2(mm_center + rr.position * mm_scale, rr.size * mm_scale)
		hud_drawer.draw_rect(mini_r, reg["floor_color"].lightened(0.12), true)
		hud_drawer.draw_rect(mini_r, reg["border_color"], false, 1.0)

	for pad in town_map.task_pads:
		var p_pos: Vector2 = mm_center + pad["pos"] * mm_scale
		var p_col: Color = Color(1.0, 0.4, 0.35) if float(pad["jammed_timer"]) > 0.0 else (Color(0.45, 0.45, 0.5) if pad["cooldown"] > 0.0 else pad["color"])
		hud_drawer.draw_circle(p_pos, 3.5, p_col)

	for res in all_residents:
		if res == null:
			continue
		var r_pos: Vector2 = mm_center + res.global_position * mm_scale
		if res.is_player:
			hud_drawer.draw_circle(r_pos, 4.5, Color(1.0, 1.0, 1.0, 1.0))
		else:
			hud_drawer.draw_circle(r_pos, 3.0, Color(0.55, 0.78, 0.95, 0.9))

	hud_drawer.draw_string(font, mm_rect.position + Vector2(8, 15), "TOWN MINIMAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.88, 0.95))

	var log_rect := Rect2(vp_size.x - 356, 280, 340, 150)
	hud_drawer.draw_rect(log_rect, Color(0.07, 0.09, 0.12, 0.84), true)
	hud_drawer.draw_rect(log_rect, Color(0.28, 0.34, 0.42, 0.8), false, 1.5)
	hud_drawer.draw_string(font, log_rect.position + Vector2(10, 20), "PUBLIC TOWN LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.80, 0.90))
	for i in range(mini(6, game_manager.recent_events.size())):
		var ev: Dictionary = game_manager.recent_events[i]
		hud_drawer.draw_string(
			font,
			log_rect.position + Vector2(10, 40 + i * 19),
			ev["text"],
			HORIZONTAL_ALIGNMENT_LEFT,
			324,
			12,
			ev["color"]
		)

	# 3. BOTTOM-LEFT: PUBLIC IDENTITY, STAMINA, REGION & NEARBY STATION PROMPT (100% Faction-Neutral)
	var bl_rect := Rect2(16, vp_size.y - 138, 435, 122)
	hud_drawer.draw_rect(bl_rect, Color(0.08, 0.10, 0.13, 0.92), true)
	hud_drawer.draw_rect(bl_rect, Color(0.32, 0.38, 0.46, 0.9), false, 2.0)

	var reg_name: String = town_map.get_region_name_at(player.global_position)
	var stam_str := ("RECOVERING %.1fs" % player.respawn_timer) if player.is_incapacitated else ("Stamina: %d / 100" % int(round(player.stamina)))
	hud_drawer.draw_string(font, bl_rect.position + Vector2(16, 24), "PUBLIC RESIDENT HUD (Identical for all 10 Residents)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.76, 0.86))
	hud_drawer.draw_string(font, bl_rect.position + Vector2(16, 46), "%s  •  %s  •  %s" % [player.resident_name, player.civic_job, stam_str], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.98, 1.0))
	hud_drawer.draw_string(font, bl_rect.position + Vector2(16, 70), "Location: %s" % reg_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.86, 0.98))

	var near_pad: Dictionary = town_map.get_nearest_pad(player.global_position)
	var prompt_str := "Move near any glowing station pad to work."
	var prompt_col := Color(0.75, 0.80, 0.86)
	if player.is_incapacitated:
		prompt_str = "Exhausted! Recovering at Town Square Clinic (%.1fs)..." % player.respawn_timer
		prompt_col = Color(1.0, 0.62, 0.55)
	elif player.is_channeling and not player.active_pad.is_empty():
		var rem := maxf(0.0, CHANNEL_DURATION - player.channel_progress)
		prompt_str = "Channeling %s... (%.1fs)" % [player.active_pad["label"], rem]
		prompt_col = Color(0.52, 0.98, 0.65)
	elif not near_pad.is_empty():
		if float(near_pad.get("jammed_timer", 0.0)) > 0.0:
			prompt_str = "%s — JAMMED (%.1fs)" % [near_pad["label"], float(near_pad["jammed_timer"])]
			prompt_col = Color(1.0, 0.52, 0.45)
		elif near_pad["cooldown"] > 0.0:
			prompt_str = "%s — Cooling down (%.1fs)" % [near_pad["label"], near_pad["cooldown"]]
			prompt_col = Color(0.95, 0.72, 0.45)
		elif near_pad["active_user"] != null and near_pad["active_user"] != player:
			prompt_str = "%s — In use by another resident" % near_pad["label"]
			prompt_col = Color(0.95, 0.72, 0.45)
		else:
			prompt_str = "Press [E] or [Space] -> %s" % near_pad["label"]
			prompt_col = Color(0.55, 0.98, 0.68)

	hud_drawer.draw_string(font, bl_rect.position + Vector2(16, 98), prompt_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, prompt_col)

	# 4. BOTTOM-CENTER / RIGHT: 3 ABILITY SLOTS ([Q], [F], [C]) & SESSION CONTROLS
	var bc_rect := Rect2(466, vp_size.y - 118, vp_size.x - 482, 102)
	hud_drawer.draw_rect(bc_rect, Color(0.08, 0.10, 0.13, 0.92), true)
	hud_drawer.draw_rect(bc_rect, Color(0.32, 0.38, 0.46, 0.9), false, 2.0)

	hud_drawer.draw_string(font, bc_rect.position + Vector2(16, 20), "ABILITY KITS & SESSION CONTROLS ([WASD / R-Click] Move • [E / Space] Work • Click or Press Keys):", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.76, 0.86))

	# Row 1: Clickable [Q] Civic Shove, [F] Public Civic Kit, [C] Neutral Special Slot
	var q_rect := Rect2(bc_rect.position.x + 16, bc_rect.position.y + 28, 225, 30)
	var q_hov := _register_button("use_shove", q_rect)
	var q_ready: bool = float(player.shove_cooldown_left) <= 0.01
	var q_txt := "[Q] Civic Shove: READY" if q_ready else ("[Q] Civic Shove: %.1fs" % float(player.shove_cooldown_left))
	hud_drawer.draw_rect(q_rect, Color(0.18, 0.28, 0.24, 0.95) if (q_ready and q_hov) else Color(0.13, 0.17, 0.22, 0.95), true)
	hud_drawer.draw_rect(q_rect, Color(0.55, 0.95, 0.68) if q_ready else Color(0.45, 0.50, 0.58), false, 1.4)
	hud_drawer.draw_string(font, q_rect.position + Vector2(8, 20), q_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 1.0, 0.92) if q_ready else Color(0.82, 0.72, 0.62))

	var civic_meta: Dictionary = C.CIVIC_KIT_INFO.get(player.civic_job, {})
	var civic_ab_name: String = String(civic_meta.get("ability_name", "Civic Kit"))
	var f_rect := Rect2(bc_rect.position.x + 250, bc_rect.position.y + 28, 255, 30)
	var f_hov := _register_button("use_civic", f_rect)
	var f_ready: bool = float(player.civic_cooldown_left) <= 0.01
	var f_txt := ("[F] %s: READY" % civic_ab_name) if f_ready else ("[F] %s: %.1fs" % [civic_ab_name, float(player.civic_cooldown_left)])
	hud_drawer.draw_rect(f_rect, Color(0.18, 0.28, 0.36, 0.95) if (f_ready and f_hov) else Color(0.13, 0.17, 0.22, 0.95), true)
	hud_drawer.draw_rect(f_rect, Color(0.52, 0.88, 1.0) if f_ready else Color(0.45, 0.50, 0.58), false, 1.4)
	hud_drawer.draw_string(font, f_rect.position + Vector2(8, 20), f_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.96, 1.0) if f_ready else Color(0.82, 0.72, 0.62))

	# Strictly neutral [C] Special Slot on the public HUD bar (kit name stays private inside [B] Dossier)
	var c_rect := Rect2(bc_rect.position.x + 514, bc_rect.position.y + 28, 265, 30)
	var c_hov := _register_button("use_special", c_rect)
	var c_txt := "[C] Special Slot: See [B] Dossier"
	var c_border := Color(0.48, 0.54, 0.64)
	if player.operative_kit != "none" and player.secret_role != "civilian":
		if player.faction_cooldown_left > 0.01:
			c_txt = "[C] Special Action: %.1fs" % player.faction_cooldown_left
		elif game_manager.current_phase == game_manager.Phase.OPEN_TOWN:
			c_txt = "[C] Special Action: COVERT (Risk)"
			c_border = Color(0.95, 0.78, 0.42)
		else:
			c_txt = "[C] Special Action: READY"
			c_border = Color(0.62, 0.88, 0.96)
	hud_drawer.draw_rect(c_rect, Color(0.20, 0.24, 0.32, 0.95) if c_hov else Color(0.13, 0.17, 0.22, 0.95), true)
	hud_drawer.draw_rect(c_rect, c_border, false, 1.4)
	hud_drawer.draw_string(font, c_rect.position + Vector2(8, 20), c_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.94, 0.98))

	var v_rect := Rect2(bc_rect.position.x + 784, bc_rect.position.y + 28, 150, 30)
	var v_hov := _register_button("use_inspect", v_rect)
	var inspect_target: Dictionary = town_map.get_inspection_target(player.global_position, 100.0)
	var v_txt := "[V] Inspect Site" if not inspect_target.is_empty() else "[V] Inspect (nearby)"
	hud_drawer.draw_rect(v_rect, Color(0.18, 0.28, 0.36, 0.95) if v_hov else Color(0.13, 0.17, 0.22, 0.95), true)
	hud_drawer.draw_rect(v_rect, Color(0.52, 0.88, 1.0) if not inspect_target.is_empty() else Color(0.45, 0.50, 0.58), false, 1.4)
	hud_drawer.draw_string(font, v_rect.position + Vector2(8, 20), v_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.96, 1.0))

	# Row 2: Session navigation pills
	if game_manager.current_phase != game_manager.Phase.LOBBY:
		var b_dossier := Rect2(bc_rect.position.x + 16, bc_rect.position.y + 66, 185, 26)
		var h_dos := _register_button("toggle_dossier", b_dossier)
		hud_drawer.draw_rect(b_dossier, Color(0.22, 0.32, 0.44, 0.95) if h_dos else Color(0.14, 0.18, 0.24, 0.95), true)
		hud_drawer.draw_rect(b_dossier, Color(0.65, 0.88, 1.0), false, 1.2)
		hud_drawer.draw_string(font, b_dossier.position + Vector2(10, 18), "[B] Private Dossier & Kits", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.96, 1.0))

		var b_next := Rect2(bc_rect.position.x + 212, bc_rect.position.y + 66, 165, 26)
		var h_nxt := _register_button("next_phase", b_next)
		hud_drawer.draw_rect(b_next, Color(0.22, 0.38, 0.30, 0.95) if h_nxt else Color(0.14, 0.22, 0.18, 0.95), true)
		hud_drawer.draw_rect(b_next, Color(0.55, 0.95, 0.68), false, 1.2)
		hud_drawer.draw_string(font, b_next.position + Vector2(10, 18), "[N] Next Phase >>", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 1.0, 0.92))

		var b_lobby := Rect2(bc_rect.position.x + 388, bc_rect.position.y + 66, 155, 26)
		var h_lob := _register_button("return_lobby", b_lobby)
		hud_drawer.draw_rect(b_lobby, Color(0.36, 0.22, 0.22, 0.95) if h_lob else Color(0.20, 0.14, 0.15, 0.95), true)
		hud_drawer.draw_rect(b_lobby, Color(0.92, 0.62, 0.58), false, 1.2)
		hud_drawer.draw_string(font, b_lobby.position + Vector2(10, 18), "[R] Return to Lobby", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.88, 0.86))

		var b_journal := Rect2(bc_rect.position.x + 550, bc_rect.position.y + 66, 180, 26)
		var h_journal := _register_button("toggle_journal", b_journal)
		hud_drawer.draw_rect(b_journal, Color(0.22, 0.32, 0.44, 0.95) if h_journal else Color(0.14, 0.18, 0.24, 0.95), true)
		hud_drawer.draw_rect(b_journal, Color(0.65, 0.88, 1.0), false, 1.2)
		hud_drawer.draw_string(font, b_journal.position + Vector2(10, 18), "[J] Evidence Journal", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.96, 1.0))

		var b_settings := Rect2(bc_rect.position.x + 738, bc_rect.position.y + 66, 175, 26)
		var h_settings := _register_button("toggle_settings", b_settings)
		hud_drawer.draw_rect(b_settings, Color(0.26, 0.24, 0.36, 0.95) if h_settings else Color(0.15, 0.14, 0.20, 0.95), true)
		hud_drawer.draw_rect(b_settings, Color(0.75, 0.70, 0.92), false, 1.2)
		hud_drawer.draw_string(font, b_settings.position + Vector2(10, 18), "[Esc] Settings & Audio", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.94, 0.92, 1.0))

	# 5. OVERLAYS BY PHASE OR DOSSIER TOGGLE
	if game_manager.current_phase == game_manager.Phase.LOBBY:
		_draw_lobby_overlay(font, vp_size)
	elif game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL:
		_draw_first_council_overlay(font, vp_size)
	elif game_manager.current_phase == game_manager.Phase.COURT:
		_draw_court_overlay(font, vp_size)
	elif game_manager.current_phase == game_manager.Phase.MATCH_OVER:
		_draw_match_over_overlay(font, vp_size)

	if game_manager.dossier_open and game_manager.current_phase != game_manager.Phase.LOBBY and game_manager.current_phase != game_manager.Phase.MATCH_OVER:
		_draw_private_dossier_overlay(font, vp_size)
	if game_manager.evidence_journal_open and game_manager.current_phase != game_manager.Phase.LOBBY and game_manager.current_phase != game_manager.Phase.MATCH_OVER:
		_draw_evidence_journal_overlay(font, vp_size)
	if game_manager.archive_dilemma_open:
		_draw_archive_dilemma_overlay(font, vp_size)
	if game_manager.strategic_decision_active:
		_draw_strategic_decision_overlay(font, vp_size)

func _draw_lobby_overlay(font: Font, vp_size: Vector2) -> void:
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.03, 0.05, 0.08, 0.72), true)
	var modal := Rect2(vp_size.x * 0.5 - 390, vp_size.y * 0.5 - 265, 780, 535)
	hud_drawer.draw_rect(modal, Color(0.09, 0.12, 0.16, 0.98), true)
	hud_drawer.draw_rect(modal, Color(0.52, 0.70, 0.92, 1.0), false, 3.0)

	hud_drawer.draw_string(font, modal.position + Vector2(28, 36), "THE GRAY SYNTHESIS — 10-PLAYER SESSION LOBBY (MILESTONE 3: MOBA KITS)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.98, 1.0))
	hud_drawer.draw_string(font, modal.position + Vector2(28, 60), "Local Session with Bot Fill: 3 Hidden Ecology • 3 Hidden Technology • 4 Unaffiliated Civilians", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.84, 0.95))

	hud_drawer.draw_string(font, modal.position + Vector2(28, 92), "TOWN ROSTER (Public Identity & Shared [F] Civic Job Kit):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.90, 0.96))
	for i in range(all_residents.size()):
		var res: Node = all_residents[i]
		var col_idx := i / 5
		var row_idx := i % 5
		var cell := modal.position + Vector2(28 + col_idx * 365, 102 + row_idx * 32)
		hud_drawer.draw_rect(Rect2(cell, Vector2(345, 26)), Color(0.13, 0.16, 0.21, 0.95), true)
		var slot_tag := "YOU" if res.is_player else "BOT"
		var c_info: Dictionary = C.CIVIC_KIT_INFO.get(res.civic_job, {})
		var ab_short: String = String(c_info.get("ability_name", ""))
		var txt := "%d. %s — %s (%s) [%s]" % [i + 1, res.resident_name, res.civic_job, ab_short, slot_tag]
		var t_col := Color(0.58, 0.96, 0.72) if res.is_player else Color(0.84, 0.88, 0.94)
		hud_drawer.draw_string(font, cell + Vector2(8, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, t_col)

	hud_drawer.draw_string(font, modal.position + Vector2(28, 286), "SOLO PLAYTEST ROLE & KIT SELECTORS (Click Any Box or Press [1] - [6]):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.86, 0.55))
	var prefs := [
		{"id": "pref_random", "key": "random", "label": "[1] Role: Random (3/3/4 Draw)"},
		{"id": "pref_ecology", "key": "ecology", "label": "[2] Role: Force Ecology Operative"},
		{"id": "pref_technology", "key": "technology", "label": "[3] Role: Force Technology Operative"},
		{"id": "pref_civilian", "key": "civilian", "label": "[4] Role: Force Unaffiliated Civilian"}
	]
	for p_idx in range(prefs.size()):
		var p: Dictionary = prefs[p_idx]
		var active: bool = (game_manager.player_role_pref == p["key"])
		var btn_r := Rect2(modal.position.x + 28 + (p_idx % 2) * 365, modal.position.y + 298 + (p_idx / 2) * 36, 345, 30)
		var hov := _register_button(p["id"], btn_r)
		var bg_col := Color(0.24, 0.38, 0.52, 0.98) if active else (Color(0.20, 0.25, 0.32, 0.98) if hov else Color(0.13, 0.16, 0.20, 0.95))
		hud_drawer.draw_rect(btn_r, bg_col, true)
		hud_drawer.draw_rect(btn_r, Color(0.65, 0.95, 0.75) if (active or hov) else Color(0.35, 0.40, 0.48), false, 2.0 if (active or hov) else 1.0)
		hud_drawer.draw_string(font, btn_r.position + Vector2(10, 20), p["label"] + ("  ✓" if active else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 1.0, 0.98) if active else Color(0.80, 0.85, 0.92))

	# [5] Operative Kit Selector & [6] Resident 1 Civic Job Selector
	var kit_btn := Rect2(modal.position.x + 28, modal.position.y + 376, 345, 32)
	var kit_hov := _register_button("cycle_kit_pref", kit_btn)
	hud_drawer.draw_rect(kit_btn, Color(0.24, 0.32, 0.46, 0.98) if kit_hov else Color(0.15, 0.20, 0.28, 0.96), true)
	hud_drawer.draw_rect(kit_btn, Color(0.72, 0.88, 1.0), false, 1.8 if kit_hov else 1.2)
	hud_drawer.draw_string(font, kit_btn.position + Vector2(10, 21), game_manager.get_player_kit_pref_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.96, 1.0))

	var job_btn := Rect2(modal.position.x + 393, modal.position.y + 376, 345, 32)
	var job_hov := _register_button("cycle_civic_job", job_btn)
	var p_job_meta: Dictionary = C.CIVIC_KIT_INFO.get(player.civic_job, {})
	var p_job_ab: String = String(p_job_meta.get("ability_name", ""))
	hud_drawer.draw_rect(job_btn, Color(0.24, 0.36, 0.40, 0.98) if job_hov else Color(0.15, 0.22, 0.26, 0.96), true)
	hud_drawer.draw_rect(job_btn, Color(0.58, 0.95, 0.88), false, 1.8 if job_hov else 1.2)
	hud_drawer.draw_string(font, job_btn.position + Vector2(10, 21), "[6] Your Job [F]: %s (%s)" % [player.civic_job, p_job_ab], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 1.0, 0.96))

	hud_drawer.draw_string(font, modal.position + Vector2(28, 430), "Controls: [Q] Civic Shove • [F] Public Civic Kit • [C] Operative Kit (Covert in Open Town, Open in Escalation)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.82, 0.90))

	var start_rect := Rect2(modal.position.x + 28, modal.position.y + 446, 710, 46)
	var start_hov := _register_button("start_match", start_rect)
	hud_drawer.draw_rect(start_rect, Color(0.22, 0.52, 0.34, 0.98) if start_hov else Color(0.16, 0.38, 0.25, 0.98), true)
	hud_drawer.draw_rect(start_rect, Color(0.58, 1.0, 0.72), false, 2.5 if start_hov else 2.0)
	hud_drawer.draw_string(font, start_rect.position + Vector2(125, 29), "▶  CLICK HERE or PRESS [SPACE] / [ENTER] TO START MATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 1.0, 0.97))

func _draw_private_dossier_overlay(font: Font, vp_size: Vector2) -> void:
	var modal := Rect2(vp_size.x * 0.5 - 350, vp_size.y * 0.5 - 215, 700, 430)
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.52), true)
	hud_drawer.draw_rect(modal, Color(0.10, 0.13, 0.18, 0.98), true)

	var role: String = player.secret_role
	var border_col := Color(0.42, 0.88, 0.54) if role == "ecology" else (Color(0.38, 0.78, 0.98) if role == "technology" else Color(0.88, 0.82, 0.55))
	hud_drawer.draw_rect(modal, border_col, false, 3.0)

	hud_drawer.draw_string(font, modal.position + Vector2(26, 34), "PRIVATE BRIEFING DOSSIER (Eyes Only — Hidden from Public HUD)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.84, 0.92))
	hud_drawer.draw_string(font, modal.position + Vector2(26, 62), "YOUR SECRET ROLE: %s" % game_manager.get_role_display_name(role), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, border_col.lightened(0.2))

	# Public Civic Kit [F] description
	var c_meta: Dictionary = C.CIVIC_KIT_INFO.get(player.civic_job, {})
	hud_drawer.draw_string(font, modal.position + Vector2(26, 92), "PUBLIC JOB KIT [F]: %s — %s (%.0fs CD)" % [player.civic_job, String(c_meta.get("ability_name", "")), float(c_meta.get("cooldown", 14.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.92, 1.0))
	hud_drawer.draw_string(font, modal.position + Vector2(38, 112), "• " + String(c_meta.get("full_desc", "")), HORIZONTAL_ALIGNMENT_LEFT, 636, 12, Color(0.86, 0.90, 0.95))

	# Secret Operative Kit [C] description
	var op_meta: Dictionary = C.OPERATIVE_KIT_INFO.get(player.operative_kit, C.OPERATIVE_KIT_INFO["none"])
	if role == "ecology" or role == "technology":
		hud_drawer.draw_string(font, modal.position + Vector2(26, 146), "SECRET OPERATIVE KIT [C]: %s — %s (%.0fs CD)" % [String(op_meta.get("kit_title", "")), String(op_meta.get("ability_name", "")), float(op_meta.get("cooldown", 16.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, border_col.lightened(0.25))
		hud_drawer.draw_string(font, modal.position + Vector2(38, 166), "• " + String(op_meta.get("full_desc", "")), HORIZONTAL_ALIGNMENT_LEFT, 636, 12, Color(0.90, 0.94, 0.98))
		hud_drawer.draw_string(font, modal.position + Vector2(38, 202), "• Cover Rule: Using [C] during Phase 2 (Open Town) within 260px clear sightline of another resident logs a vague regional disturbance. Unlocks openly at Phase 4 (Escalation).", HORIZONTAL_ALIGNMENT_LEFT, 636, 12, Color(0.98, 0.82, 0.48))

		var partners: Array = game_manager.get_partner_names_for(player, all_residents)
		hud_drawer.draw_string(font, modal.position + Vector2(26, 246), "KNOWN FACTION PARTNERS (2 Operatives on your team):", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.90, 0.65))
		for idx in range(partners.size()):
			hud_drawer.draw_string(font, modal.position + Vector2(38, 270 + idx * 22), "• " + String(partners[idx]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, border_col.lightened(0.3))
	else:
		hud_drawer.draw_string(font, modal.position + Vector2(26, 148), "CIVILIAN STATUS: Unaffiliated Town Resident (1 of 4 Court Voters)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.90, 0.65))
		hud_drawer.draw_string(font, modal.position + Vector2(38, 172), "• You have no covert [C] faction kit. Use your [F] Public Civic Kit and [Q] Civic Shove.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.90, 0.94))
		hud_drawer.draw_string(font, modal.position + Vector2(38, 196), "• Watch for regional disturbance alerts during Open Town and station clashes in Escalation.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.90, 0.94))
		hud_drawer.draw_string(font, modal.position + Vector2(38, 220), "• At Civilian Court, the 4 Civilians vote sequentially to decide the town's alignment.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.90, 0.94))

	hud_drawer.draw_string(font, modal.position + Vector2(26, 342), "Public Crisis: Irrigation pump is failing while crop blight threatens town stability.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.84, 0.96))

	var close_rect := Rect2(modal.position.x + 26, modal.position.y + 364, 648, 44)
	var close_hov := _register_button("close_dossier", close_rect)
	hud_drawer.draw_rect(close_rect, Color(0.22, 0.50, 0.34, 0.98) if close_hov else Color(0.16, 0.36, 0.25, 0.98), true)
	hud_drawer.draw_rect(close_rect, Color(0.58, 1.0, 0.72), false, 2.0)
	var close_hint := "▶  CLICK HERE or PRESS [SPACE] TO BEGIN OPEN TOWN" if game_manager.current_phase == game_manager.Phase.BRIEFING else "▶  CLICK HERE or PRESS [B] TO CLOSE PRIVATE DOSSIER"
	hud_drawer.draw_string(font, close_rect.position + Vector2(115, 28), close_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 1.0, 0.97))

func _draw_first_council_overlay(font: Font, vp_size: Vector2) -> void:
	var modal := Rect2(vp_size.x * 0.5 - 490, 58, 980, minf(vp_size.y - 116, 790))
	hud_drawer.draw_rect(modal, Color(0.10, 0.13, 0.18, 0.95), true)
	hud_drawer.draw_rect(modal, Color(0.95, 0.82, 0.45, 0.95), false, 2.5)
	hud_drawer.draw_string(font, modal.position + Vector2(22, 30), "PHASE 3: FIRST COUNCIL — ALIBIS, EVIDENCE & TOWN MOTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98, 0.90, 0.58))
	hud_drawer.draw_string(font, modal.position + Vector2(22, 54), "Claims cover the 04:00–03:00 crisis window. Only witnessed facts can conflict; physical traces identify no resident.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.84, 0.92))
	hud_drawer.draw_string(font, modal.position + Vector2(22, 78), "Town: Water %d  •  Stability %d  •  Scrap %d  •  Common Works %d%%" % [int(game_manager.water), int(game_manager.stability), game_manager.scrap, int(game_manager.common_works)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.92, 1.0))
	var regions := ["Town Square / Common Works", "Greenhouse & Fields", "Salvage Yard", "Pump & Generator Station"]
	hud_drawer.draw_string(font, modal.position + Vector2(22, 108), "YOUR PUBLIC ALIBI — choose the region you claim:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.86, 0.62))
	for i in range(regions.size()):
		var ar := Rect2(modal.position.x + 22 + i * 235, modal.position.y + 118, 225, 30)
		var active: bool = String(game_manager.player_alibi_region) == regions[i]
		var hov := _register_button("alibi:" + regions[i], ar)
		hud_drawer.draw_rect(ar, Color(0.25, 0.35, 0.42) if active else Color(0.14, 0.18, 0.23), true)
		hud_drawer.draw_rect(ar, Color(0.70, 0.90, 0.78) if active else Color(0.38, 0.45, 0.52), false, 1.2)
		hud_drawer.draw_string(font, ar.position + Vector2(7, 20), regions[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.93, 0.96, 0.98))
	var claims_y := 160.0
	hud_drawer.draw_string(font, modal.position + Vector2(22, claims_y), "ALL 10 PUBLIC ALIBI STATEMENTS (unverified until contradicted by a direct sighting):", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.84, 0.78, 0.96))
	for i in range(mini(all_residents.size(), 10)):
		var resident: Node = all_residents[i]
		var claim: Dictionary = game_manager.alibi_statements.get(int(resident.resident_id), {})
		var col: int = i / 5
		var row: int = i % 5
		hud_drawer.draw_string(font, modal.position + Vector2(28 + col * 470, claims_y + 20 + row * 16), "%s: %s" % [resident.resident_name, claim.get("text", "No statement")], HORIZONTAL_ALIGNMENT_LEFT, 450, 10, Color(0.82, 0.84, 0.90))
	var board_y := 265.0
	hud_drawer.draw_string(font, modal.position + Vector2(22, board_y), "ALIBI CONFLICTS (requires a tabled direct sighting):", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.72, 0.54))
	if game_manager.alibi_conflicts.is_empty():
		hud_drawer.draw_string(font, modal.position + Vector2(28, board_y + 22), "No verified contradiction currently tabled.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.78, 0.86))
	else:
		for i in range(mini(3, game_manager.alibi_conflicts.size())):
			var cf: Dictionary = game_manager.alibi_conflicts[i]
			hud_drawer.draw_string(font, modal.position + Vector2(28, board_y + 22 + i * 18), "%s claimed %s; sighting places them in %s (%s)." % [cf.resident, cf.claim, cf.seen, cf.time], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.77, 0.62))
	var evidence_y := 330.0
	hud_drawer.draw_string(font, modal.position + Vector2(22, evidence_y), "TABLED EVIDENCE (%d items) — open [J] to table your private clues:" % game_manager.tabled_evidence.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.90, 1.0))
	for i in range(mini(6, game_manager.tabled_evidence.size())):
		var item: Dictionary = game_manager.tabled_evidence[i]
		var color := Color(1.0, 0.76, 0.42) if item.tier == C.EVIDENCE_FACT else (Color(0.52, 0.88, 1.0) if item.tier == C.EVIDENCE_TRACE else Color(0.80, 0.68, 1.0))
		hud_drawer.draw_string(font, modal.position + Vector2(30, evidence_y + 22 + i * 19), "[%s] %s — %s (%s)" % [C.EVIDENCE_TIER_LABELS.get(item.tier, item.tier), item.text, item.region, item.time], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	var motion_y := 470.0
	hud_drawer.draw_string(font, modal.position + Vector2(22, motion_y), "VOTE FOR ONE TOWN MOTION — select by click or [1] [2] [3]. Bots have voted.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.86, 0.62))
	var motion_names := ["Station Watch: beacons log station access", "Scrap Subsidy: +3 Scrap to Common Works", "Crop Remediation: 25% less stability drain"]
	var vote_counts := [0, 0, 0]
	for ballot in game_manager.council_ballots:
		if int(ballot) >= 1 and int(ballot) <= 3:
			vote_counts[int(ballot) - 1] += 1
	for i in range(3):
		var mr := Rect2(modal.position.x + 22, modal.position.y + motion_y + 10 + i * 36, 640, 30)
		var hov := _register_button("motion_%d" % (i + 1), mr)
		var active: bool = int(game_manager.player_motion_vote) == i + 1
		hud_drawer.draw_rect(mr, Color(0.24, 0.35, 0.40) if active else Color(0.14, 0.18, 0.23), true)
		hud_drawer.draw_rect(mr, Color(0.66, 0.92, 0.80) if active or hov else Color(0.38, 0.45, 0.52), false, 1.2)
		hud_drawer.draw_string(font, mr.position + Vector2(9, 20), "[%d] %s — %d/10 votes" % [i + 1, motion_names[i], vote_counts[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.96, 0.98))
	var tie_hint := "Tie rule: lowest resource first (Water ≤40, Scrap ≤2, Stability ≤40); otherwise your vote."
	hud_drawer.draw_string(font, modal.position + Vector2(22, 610), tie_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.78, 0.86))
	var btn_r := Rect2(modal.position.x + 22, modal.position.y + modal.size.y - 62, 936, 42)
	var btn_hov := _register_button("next_phase", btn_r)
	hud_drawer.draw_rect(btn_r, Color(0.22, 0.48, 0.34, 0.98) if btn_hov else Color(0.16, 0.35, 0.25, 0.98), true)
	hud_drawer.draw_rect(btn_r, Color(0.58, 0.98, 0.70), false, 2.0)
	var winner := "Motion %d" % game_manager.council_motion_winner if game_manager.council_motion_resolved else "Choose your motion first"
	hud_drawer.draw_string(font, btn_r.position + Vector2(18, 27), "▶  [N] Enact council result & continue to Escalation — %s" % winner, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 1.0, 0.97))

func _draw_evidence_journal_overlay(font: Font, vp_size: Vector2) -> void:
	var modal := Rect2(vp_size.x * 0.5 - 410, vp_size.y * 0.5 - 315, 820, 630)
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.58), true)
	hud_drawer.draw_rect(modal, Color(0.08, 0.12, 0.17, 0.99), true)
	hud_drawer.draw_rect(modal, Color(0.58, 0.82, 0.96), false, 2.5)
	hud_drawer.draw_string(font, modal.position + Vector2(24, 34), "PRIVATE EVIDENCE JOURNAL — only you see unshared findings", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.94, 1.0))
	hud_drawer.draw_string(font, modal.position + Vector2(24, 58), "[OBSERVED FACT] amber: witnessed event • [VERIFIED TRACE] cyan: physical clue • [UNVERIFIED CLAIM] purple: statement", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.76, 0.82, 0.90))
	var journal: Dictionary = game_manager.get_player_journal(int(player.resident_id))
	var entries: Array = []
	entries.append_array(journal.get("observed", []))
	entries.append_array(journal.get("traces", []))
	var y := 92.0
	for i in range(mini(entries.size(), 17)):
		var item: Dictionary = entries[entries.size() - 1 - i]
		var tier: String = String(item.get("tier", ""))
		var color := Color(1.0, 0.76, 0.42) if tier == C.EVIDENCE_FACT else (Color(0.52, 0.88, 1.0) if tier == C.EVIDENCE_TRACE else Color(0.80, 0.68, 1.0))
		var row_y := modal.position.y + y + i * 27
		hud_drawer.draw_string(font, Vector2(modal.position.x + 24, row_y + 12), "[%s] %s | %s | %s" % [C.EVIDENCE_TIER_LABELS.get(tier, tier), item.get("time", ""), item.get("region", ""), item.get("text", "")], HORIZONTAL_ALIGNMENT_LEFT, 770, 10, color)
		if game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL and not bool(item.get("tabled", false)):
			var tr := Rect2(modal.position.x + 698, row_y + 13, 92, 22)
			var hov := _register_button("table_item:" + String(item.get("id", "")), tr)
			hud_drawer.draw_rect(tr, Color(0.20, 0.40, 0.46) if hov else Color(0.14, 0.22, 0.28), true)
			hud_drawer.draw_string(font, tr.position + Vector2(8, 15), "Table clue", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.90, 0.96, 1.0))
	if entries.is_empty():
		hud_drawer.draw_string(font, modal.position + Vector2(24, 112), "No evidence recorded yet. Inspect a station or disturbance site with [V].", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.76, 0.82, 0.90))
	if game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL:
		var table_rect := Rect2(modal.position.x + 24, modal.position.y + 560, 280, 38)
		var table_hov := _register_button("table_all", table_rect)
		hud_drawer.draw_rect(table_rect, Color(0.20, 0.40, 0.46) if table_hov else Color(0.14, 0.22, 0.28), true)
		hud_drawer.draw_string(font, table_rect.position + Vector2(14, 24), "Table all remaining clues", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.96, 1.0))
	var close_rect := Rect2(modal.position.x + 680, modal.position.y + 560, 116, 38)
	_register_button("toggle_journal", close_rect)
	hud_drawer.draw_rect(close_rect, Color(0.25, 0.30, 0.38), true)
	hud_drawer.draw_string(font, close_rect.position + Vector2(20, 24), "[J] Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.96, 1.0))

func _draw_court_overlay(font: Font, vp_size: Vector2) -> void:
	var modal := Rect2(vp_size.x * 0.5 - 380, vp_size.y * 0.5 - 260, 760, 520)
	hud_drawer.draw_rect(modal, Color(0.09, 0.12, 0.18, 0.98), true)
	hud_drawer.draw_rect(modal, Color(0.86, 0.72, 1.0, 0.95), false, 2.5)

	# Title & Ceremony subtitle
	hud_drawer.draw_string(font, modal.position + Vector2(28, 34), "PHASE 5: CIVILIAN COURT OF ACCORD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.82, 1.0))
	hud_drawer.draw_string(font, modal.position + Vector2(28, 56), "The 4 Unaffiliated Civilians publicly step to the podium to decide town alignment.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.88, 0.95))

	# Live Running Tally Bar
	var eco_count := 0
	var tech_count := 0
	for b in game_manager.court_ballot_records:
		if b["vote"] == "Ecology":
			eco_count += 1
		elif b["vote"] == "Technology":
			tech_count += 1

	var tally_box := Rect2(modal.position.x + 28, modal.position.y + 70, 704, 38)
	hud_drawer.draw_rect(tally_box, Color(0.14, 0.16, 0.22, 0.96), true)
	hud_drawer.draw_rect(tally_box, Color(0.45, 0.52, 0.65), false, 1.2)

	var tally_str := "LIVE COURT TALLY:  %d ECOLOGY  vs  %d TECHNOLOGY  (Turn %d of 4)" % [
		eco_count, tech_count, mini(4, game_manager.court_voter_index + 1)
	]
	hud_drawer.draw_string(font, tally_box.position + Vector2(16, 24), tally_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.92, 0.65))

	# Visual Split Bar inside tally_box
	var bar_w: float = 240.0
	var bar_r := Rect2(tally_box.position.x + tally_box.size.x - bar_w - 16, tally_box.position.y + 11, bar_w, 16)
	hud_drawer.draw_rect(bar_r, Color(0.10, 0.12, 0.16), true)
	var total_cast := eco_count + tech_count
	var eco_w: float = (bar_w * (float(eco_count) / 4.0)) if total_cast > 0 else 0.0
	var tech_w: float = (bar_w * (float(tech_count) / 4.0)) if total_cast > 0 else 0.0
	if eco_w > 0.0:
		hud_drawer.draw_rect(Rect2(bar_r.position, Vector2(eco_w, bar_r.size.y)), Color(0.45, 0.92, 0.58), true)
	if tech_w > 0.0:
		hud_drawer.draw_rect(Rect2(bar_r.position.x + bar_r.size.x - tech_w, bar_r.position.y, tech_w, bar_r.size.y), Color(0.42, 0.82, 0.98), true)
	hud_drawer.draw_rect(bar_r, Color(0.65, 0.72, 0.82), false, 1.0)

	# 4 Voter Cards (Horizontal layout: 4 cards side by side, width ~168 each)
	var card_w: float = 168.0
	var card_h: float = 180.0
	var start_x: float = modal.position.x + 28.0
	var card_y: float = modal.position.y + 120.0

	for i in range(4):
		var cr := Rect2(start_x + i * (card_w + 10.0), card_y, card_w, card_h)
		var civ_res: Node = game_manager.court_civilians[i] if i < game_manager.court_civilians.size() else null
		var is_active: bool = (i == int(game_manager.court_voter_index) and bool(game_manager.court_ceremony_active))
		var has_voted: bool = (i < game_manager.court_ballot_records.size())
		var b_data: Dictionary = game_manager.court_ballot_records[i] if has_voted else {}

		var bg_col := Color(0.12, 0.15, 0.20, 0.95)
		var border_col := Color(0.35, 0.40, 0.48)
		if is_active:
			bg_col = Color(0.22, 0.22, 0.32, 0.98)
			border_col = Color(1.0, 0.85, 0.40)
		elif has_voted:
			if b_data.get("vote") == "Ecology":
				bg_col = Color(0.12, 0.22, 0.16, 0.95)
				border_col = Color(0.45, 0.92, 0.58)
			else:
				bg_col = Color(0.12, 0.18, 0.26, 0.95)
				border_col = Color(0.42, 0.82, 0.98)

		hud_drawer.draw_rect(cr, bg_col, true)
		hud_drawer.draw_rect(cr, border_col, false, 2.0 if is_active else 1.2)

		# Card text
		var slot_str := "CIVILIAN #%d" % (i + 1)
		if i == 3:
			slot_str += " (PIVOTAL)"
		hud_drawer.draw_string(font, cr.position + Vector2(10, 20), slot_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.82, 0.90))

		var name_str: String = String(civ_res.resident_name) if civ_res != null else ("Civilian %d" % (i + 1))
		if civ_res != null and civ_res.is_player:
			name_str += " (YOU)"
		hud_drawer.draw_string(font, cr.position + Vector2(10, 38), name_str, HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 12, Color(1.0, 0.95, 0.70) if (civ_res != null and civ_res.is_player) else Color(0.95, 0.97, 1.0))

		var job_str: String = String(civ_res.civic_job) if civ_res != null else "Town Resident"
		hud_drawer.draw_string(font, cr.position + Vector2(10, 54), job_str, HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 10, Color(0.72, 0.78, 0.86))

		# Status / Result
		if is_active:
			var pulse: float = (sin(float(game_manager.match_elapsed) * 6.0) + 1.0) * 0.5
			var act_col := Color(1.0, 0.85, 0.35).lerp(Color(1.0, 1.0, 0.8), pulse)
			hud_drawer.draw_string(font, cr.position + Vector2(10, 80), "▶ AT PODIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, act_col)
			hud_drawer.draw_string(font, cr.position + Vector2(10, 100), "Time: %.1fs" % float(game_manager.court_turn_timer), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.90, 0.75))
		elif has_voted:
			var vote_str: String = b_data.get("vote", "")
			var v_col := Color(0.45, 0.92, 0.58) if vote_str == "Ecology" else Color(0.42, 0.82, 0.98)
			hud_drawer.draw_string(font, cr.position + Vector2(10, 82), "VOTED %s" % vote_str.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, v_col)
			if b_data.get("defaulted", false):
				hud_drawer.draw_string(font, cr.position + Vector2(10, 100), "[TIMEOUT DEFAULT]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.65, 0.45))
			var q_preview: String = "\"" + String(b_data.get("reason", "")).left(65) + "...\""
			hud_drawer.draw_string(font, cr.position + Vector2(10, 120), q_preview, HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 9, Color(0.85, 0.88, 0.92))
		else:
			hud_drawer.draw_string(font, cr.position + Vector2(10, 82), "Awaiting Turn", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.60, 0.68))

	# Active Voter Area (Lower Section: modal.position.y + 312 to 500)
	var active_civ: Node = game_manager.get_active_court_voter()
	var act_rect := Rect2(modal.position.x + 28, modal.position.y + 312, 704, 150)
	hud_drawer.draw_rect(act_rect, Color(0.12, 0.15, 0.20, 0.95), true)
	hud_drawer.draw_rect(act_rect, Color(0.45, 0.55, 0.70), false, 1.2)

	if game_manager.court_ceremony_active and active_civ != null:
		if active_civ.is_player:
			# Player turn controls
			var def_v: String = game_manager.get_player_timeout_default_vote()
			hud_drawer.draw_string(font, act_rect.position + Vector2(16, 26), "YOUR TURN AT THE PODIUM — CAST YOUR BINDING BALLOT:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.90, 0.48))
			var def_rule := "Timeout Default (%.1fs): %s  (Formula: Water ≤ Stability → Ecology; Water > Stability → Technology)" % [
				game_manager.court_turn_timer, def_v
			]
			hud_drawer.draw_string(font, act_rect.position + Vector2(16, 46), def_rule, HORIZONTAL_ALIGNMENT_LEFT, 672, 11, Color(0.85, 0.90, 0.98))

			var b1_r := Rect2(act_rect.position.x + 16, act_rect.position.y + 60, 326, 68)
			var b1_hov := _register_button("court_vote_eco", b1_r)
			hud_drawer.draw_rect(b1_r, Color(0.16, 0.32, 0.22, 0.98) if b1_hov else Color(0.12, 0.24, 0.16, 0.95), true)
			hud_drawer.draw_rect(b1_r, Color(0.45, 0.95, 0.60) if b1_hov else Color(0.35, 0.70, 0.45), false, 2.0 if b1_hov else 1.2)
			hud_drawer.draw_string(font, b1_r.position + Vector2(14, 28), "[1] VOTE ECOLOGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.98, 0.70))
			hud_drawer.draw_string(font, b1_r.position + Vector2(14, 50), "Back Biosphere Preservation & Aquifer Safeties", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.80, 0.92, 0.85))

			var b2_r := Rect2(act_rect.position.x + 360, act_rect.position.y + 60, 326, 68)
			var b2_hov := _register_button("court_vote_tech", b2_r)
			hud_drawer.draw_rect(b2_r, Color(0.16, 0.28, 0.38, 0.98) if b2_hov else Color(0.12, 0.20, 0.30, 0.95), true)
			hud_drawer.draw_rect(b2_r, Color(0.45, 0.85, 1.0) if b2_hov else Color(0.35, 0.65, 0.80), false, 2.0 if b2_hov else 1.2)
			hud_drawer.draw_string(font, b2_r.position + Vector2(14, 28), "[2] VOTE TECHNOLOGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.45, 0.85, 1.0))
			hud_drawer.draw_string(font, b2_r.position + Vector2(14, 50), "Back Electrical Grid Restoration & Machinery Revival", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.80, 0.90, 0.98))
		else:
			# Bot turn display
			var active_name: String = String(active_civ.resident_name)
			var active_job: String = String(active_civ.civic_job)
			hud_drawer.draw_string(font, act_rect.position + Vector2(16, 26), "ACTIVE VOTER: %s (%s) — AT THE PODIUM" % [active_name, active_job], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.90, 0.48))
			var q_text: String = String(game_manager.court_active_speaker_reason)
			if q_text == "":
				q_text = "Deliberating town conditions and survival priorities..."
			hud_drawer.draw_string(font, act_rect.position + Vector2(16, 54), "\"%s\"" % q_text, HORIZONTAL_ALIGNMENT_LEFT, 672, 12, Color(0.92, 0.95, 0.98))

			var ff_r := Rect2(act_rect.position.x + 16, act_rect.position.y + 92, 672, 42)
			var ff_hov := _register_button("court_fast_forward", ff_r)
			hud_drawer.draw_rect(ff_r, Color(0.20, 0.28, 0.38, 0.98) if ff_hov else Color(0.15, 0.20, 0.28, 0.95), true)
			hud_drawer.draw_rect(ff_r, Color(0.55, 0.85, 1.0) if ff_hov else Color(0.40, 0.55, 0.70), false, 1.5)
			hud_drawer.draw_string(font, ff_r.position + Vector2(170, 26), "▶  PRESS [SPACE] / [ENTER] OR CLICK TO FAST-FORWARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.98, 1.0))
	else:
		# Ceremony finished / Verdict text
		hud_drawer.draw_string(font, act_rect.position + Vector2(16, 32), "COURT VERDICT: " + game_manager.court_alignment_summary, HORIZONTAL_ALIGNMENT_LEFT, 672, 14, Color(1.0, 0.90, 0.45))
		var sub_v: String = "Advancing to Final Resolution..." if bool(game_manager.court_is_unanimous) else "Advancing to Strategic War-or-Peace Deliberation (15s)..."
		hud_drawer.draw_string(font, act_rect.position + Vector2(16, 62), sub_v, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.90, 0.98))

	# Discrete developer debug footer
	var dev_str := "Developer debug overrides: Hold [Shift] + [1]-[5] to force test splits (2-2, 3-1, 4-0)"
	hud_drawer.draw_string(font, modal.position + Vector2(28, 492), dev_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.60, 0.68))

func _draw_match_over_overlay(font: Font, vp_size: Vector2) -> void:
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.68), true)
	var modal := Rect2(vp_size.x * 0.5 - 385, vp_size.y * 0.5 - 255, 770, 510)
	hud_drawer.draw_rect(modal, Color(0.09, 0.12, 0.17, 0.98), true)
	hud_drawer.draw_rect(modal, game_manager.match_ending_color, false, 3.0)

	hud_drawer.draw_string(font, modal.position + Vector2(28, 36), game_manager.match_ending_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, game_manager.match_ending_color.lightened(0.2))
	hud_drawer.draw_string(font, modal.position + Vector2(28, 58), game_manager.match_ending_subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.90, 0.96))

	var stats_line := "Water: %d • Stability: %d • CW: %d%% (E:%d T:%d S:%d) • Tasks: %d • Kits [F]/[C]: %d/%d • Shoves: %d" % [
		int(game_manager.water), int(game_manager.stability), int(game_manager.common_works),
		int(game_manager.common_works_eco), int(game_manager.common_works_tech), int(game_manager.common_works_struct),
		game_manager.total_tasks_completed, game_manager.civic_abilities_used, game_manager.faction_abilities_used,
		game_manager.shoves_used
	]
	hud_drawer.draw_string(font, modal.position + Vector2(28, 80), stats_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.86, 0.96))

	var extra_y: float = modal.position.y + 100
	if game_manager.whistleblower_summary != "":
		hud_drawer.draw_string(font, Vector2(modal.position.x + 28, extra_y), game_manager.whistleblower_summary, HORIZONTAL_ALIGNMENT_LEFT, 714, 11, Color(1.0, 0.85, 0.40))
		extra_y += 18
	elif game_manager.civilian_commendation != "":
		hud_drawer.draw_string(font, Vector2(modal.position.x + 28, extra_y), game_manager.civilian_commendation, HORIZONTAL_ALIGNMENT_LEFT, 714, 11, Color(0.70, 0.95, 0.80))
		extra_y += 18

	var archive_str: String = "Old-World Archive: Undiscovered"
	if game_manager.archive_opened:
		archive_str = "Old-World Archive: Recovered at %s by %s • %s" % [game_manager.archive_open_time, game_manager.archive_finder_name, game_manager.archive_choice_details]
	hud_drawer.draw_string(font, Vector2(modal.position.x + 28, extra_y), archive_str, HORIZONTAL_ALIGNMENT_LEFT, 714, 11, Color(1.0, 0.90, 0.55))

	hud_drawer.draw_string(font, modal.position + Vector2(28, 142), "POST-MATCH SECRET ROLE & OPERATIVE KIT REVEAL:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.58))
	for i in range(all_residents.size()):
		var res: Node = all_residents[i]
		var col_idx := i / 5
		var row_idx := i % 5
		var cell := modal.position + Vector2(28 + col_idx * 360, 156 + row_idx * 52)
		var r_col := Color(0.42, 0.88, 0.54) if res.secret_role == "ecology" else (Color(0.38, 0.78, 0.98) if res.secret_role == "technology" else Color(0.86, 0.84, 0.68))
		hud_drawer.draw_rect(Rect2(cell, Vector2(346, 44)), Color(0.13, 0.16, 0.21, 0.95), true)
		hud_drawer.draw_rect(Rect2(cell, Vector2(346, 44)), r_col * Color(1, 1, 1, 0.55), false, 1.2)
		var name_str := "%s%s — %s" % [res.resident_name, " (YOU)" if res.is_player else "", res.civic_job]
		var k_meta: Dictionary = C.OPERATIVE_KIT_INFO.get(res.operative_kit, C.OPERATIVE_KIT_INFO["none"])
		var kit_tag: String = (" • Kit: %s (%s)" % [String(k_meta.get("kit_title", "")), String(k_meta.get("ability_name", ""))]) if res.operative_kit != "none" else ""
		hud_drawer.draw_string(font, cell + Vector2(10, 18), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.97, 1.0))
		hud_drawer.draw_string(font, cell + Vector2(10, 34), game_manager.get_role_display_name(res.secret_role) + kit_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, r_col.lightened(0.15))

	var ret_rect := Rect2(modal.position.x + 28, modal.position.y + 438, 714, 46)
	var ret_hov := _register_button("return_lobby", ret_rect)
	hud_drawer.draw_rect(ret_rect, Color(0.22, 0.48, 0.34, 0.98) if ret_hov else Color(0.16, 0.35, 0.25, 0.98), true)
	hud_drawer.draw_rect(ret_rect, Color(0.58, 0.98, 0.70), false, 2.0)
	hud_drawer.draw_string(font, ret_rect.position + Vector2(170, 29), "▶  CLICK HERE or PRESS [R] / [N] TO RETURN TO LOBBY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 1.0, 0.97))

func _draw_strategic_decision_overlay(font: Font, vp_size: Vector2) -> void:
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.04, 0.07, 0.85), true)
	var modal := Rect2(vp_size.x * 0.5 - 380, vp_size.y * 0.5 - 240, 760, 480)
	hud_drawer.draw_rect(modal, Color(0.09, 0.12, 0.17, 0.98), true)
	hud_drawer.draw_rect(modal, Color(0.95, 0.82, 0.42), false, 3.0)

	hud_drawer.draw_string(font, modal.position + Vector2(28, 38), "STRATEGIC COLD-WAR DECISION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.90, 0.48))
	hud_drawer.draw_string(font, modal.position + Vector2(28, 62), "Civilian Court Split (%s) • Both factions secretly deliberate endgame route." % game_manager.court_split_summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.88, 0.95))

	var timer_rect := Rect2(modal.position.x + 28, modal.position.y + 78, 704, 32)
	hud_drawer.draw_rect(timer_rect, Color(0.14, 0.18, 0.24, 0.95), true)
	hud_drawer.draw_rect(timer_rect, Color(0.55, 0.75, 0.95), false, 1.2)
	hud_drawer.draw_string(font, timer_rect.position + Vector2(16, 21), "Decision Closes In: %.1fs  (Default on Tie/Timeout: CONFRONTATION)" % game_manager.strategic_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.45))

	var is_op: bool = (player.secret_role != "civilian")

	if is_op:
		hud_drawer.draw_string(font, modal.position + Vector2(28, 134), "Your Operative Faction: %s — Cast Your Secret Alignment Ballot:" % player.secret_role.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.97, 1.0))

		var c1_rect := Rect2(modal.position.x + 28, modal.position.y + 150, 342, 190)
		var c1_hov := _register_button("strat_confrontation", c1_rect)
		var c1_selected: bool = (String(game_manager.player_strategic_choice) == C.STRATEGIC_CHOICE_CONFRONTATION)
		var c1_bg := Color(0.28, 0.16, 0.16, 0.98) if (c1_selected or c1_hov) else Color(0.16, 0.13, 0.14, 0.95)
		var c1_border := Color(1.0, 0.45, 0.38) if c1_selected else (Color(0.85, 0.55, 0.45) if c1_hov else Color(0.55, 0.35, 0.35))
		hud_drawer.draw_rect(c1_rect, c1_bg, true)
		hud_drawer.draw_rect(c1_rect, c1_border, false, 2.5 if c1_selected else 1.5)
		hud_drawer.draw_string(font, c1_rect.position + Vector2(14, 28), "[1] CONFRONTATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.65, 0.55))
		hud_drawer.draw_string(font, c1_rect.position + Vector2(14, 52), "Objective War for Subterranean Machine", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.78, 0.75))
		hud_drawer.draw_string(font, c1_rect.position + Vector2(14, 76), "• Buried Generator Tug-of-War (0-100%)\n• Overdrive (Tech) vs Biosphere Lock (Eco)\n• Beacon tuning grants +15% speed buff\n• Clock expiry resolved by Beacon & Water", HORIZONTAL_ALIGNMENT_LEFT, 314, 11, Color(0.85, 0.88, 0.92))
		if c1_selected:
			hud_drawer.draw_string(font, c1_rect.position + Vector2(14, 172), "▶ SELECTED [1]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.35))

		var c2_rect := Rect2(modal.position.x + 390, modal.position.y + 150, 342, 190)
		var c2_hov := _register_button("strat_peace", c2_rect)
		var c2_selected: bool = (String(game_manager.player_strategic_choice) == C.STRATEGIC_CHOICE_PEACE)
		var c2_bg := Color(0.16, 0.26, 0.20, 0.98) if (c2_selected or c2_hov) else Color(0.12, 0.17, 0.14, 0.95)
		var c2_border := Color(0.48, 0.95, 0.62) if c2_selected else (Color(0.55, 0.85, 0.65) if c2_hov else Color(0.35, 0.55, 0.40))
		hud_drawer.draw_rect(c2_rect, c2_bg, true)
		hud_drawer.draw_rect(c2_rect, c2_border, false, 2.5 if c2_selected else 1.5)
		hud_drawer.draw_string(font, c2_rect.position + Vector2(14, 28), "[2] PEACE (CHARTER)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.98, 0.70))
		hud_drawer.draw_string(font, c2_rect.position + Vector2(14, 52), "Common Works Synthesis Accord", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.88, 0.80))
		hud_drawer.draw_string(font, c2_rect.position + Vector2(14, 76), "• Both factions must ratify at Consoles\n• Carried Common Works progress preserved\n• Cooperative crisis holdout (60-90s)\n• Mitigate Blight & Steam leaks together", HORIZONTAL_ALIGNMENT_LEFT, 314, 11, Color(0.85, 0.88, 0.92))
		if c2_selected:
			hud_drawer.draw_string(font, c2_rect.position + Vector2(14, 172), "▶ SELECTED [2]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.35))
	else:
		var civ_box := Rect2(modal.position.x + 28, modal.position.y + 140, 704, 190)
		hud_drawer.draw_rect(civ_box, Color(0.13, 0.16, 0.22, 0.95), true)
		hud_drawer.draw_rect(civ_box, Color(0.45, 0.55, 0.68), false, 1.5)
		hud_drawer.draw_string(font, civ_box.position + Vector2(20, 36), "CIVILIAN OBSERVER BRIEFING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.90, 0.98))
		hud_drawer.draw_string(font, civ_box.position + Vector2(20, 68), "As a town Civilian, you have cast your Court ballot. Operatives in Ecology and Technology are currently deliberating whether to ratify the Gray Synthesis Charter or plunge the town into open Confrontation over the Buried Generator.", HORIZONTAL_ALIGNMENT_LEFT, 664, 13, Color(0.88, 0.92, 0.96))
		hud_drawer.draw_string(font, civ_box.position + Vector2(20, 130), "• If BOTH factions independently ratify Peace (>50%% each), Route B begins.\n• If EITHER faction votes for war or ties, Route A Confrontation begins immediately.", HORIZONTAL_ALIGNMENT_LEFT, 664, 12, Color(0.75, 0.85, 0.95))

	var rule_lbl := "Requirement: Peace requires majority (>50%) from BOTH factions. Any tie or unilateral veto defaults to Confrontation."
	hud_drawer.draw_string(font, modal.position + Vector2(28, 368), rule_lbl, HORIZONTAL_ALIGNMENT_LEFT, 704, 11, Color(0.85, 0.88, 0.92))

	var ff_rect := Rect2(modal.position.x + 28, modal.position.y + 400, 704, 46)
	var ff_hov := _register_button("strat_resolve_now", ff_rect)
	hud_drawer.draw_rect(ff_rect, Color(0.22, 0.35, 0.48, 0.98) if ff_hov else Color(0.15, 0.24, 0.35, 0.98), true)
	hud_drawer.draw_rect(ff_rect, Color(0.55, 0.85, 1.0), false, 2.0)
	hud_drawer.draw_string(font, ff_rect.position + Vector2(170, 29), "▶  PRESS [SPACE] / [N] or CLICK TO COMMIT & RESOLVE NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.98, 1.0))

func _draw_confrontation_hud(font: Font, vp_size: Vector2) -> void:
	var hud_box := Rect2(vp_size.x * 0.5 - 280, 88, 560, 58)
	hud_drawer.draw_rect(hud_box, Color(0.08, 0.10, 0.14, 0.96), true)
	var border_c := Color(1.0, 0.42, 0.35) if game_manager.confrontation_overtime else Color(0.85, 0.58, 0.45)
	hud_drawer.draw_rect(hud_box, border_c, false, 2.0)

	var title := "CONFRONTATION: BURIED GENERATOR TUG-OF-WAR"
	if game_manager.confrontation_overtime:
		title = "CRISIS OVERTIME: SUDDEN DEATH (FAILED CHARTER FALLBACK)"
	hud_drawer.draw_string(font, hud_box.position + Vector2(14, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, border_c.lightened(0.2))

	var bar_r := Rect2(hud_box.position.x + 14, hud_box.position.y + 24, 532, 16)
	hud_drawer.draw_rect(bar_r, Color(0.12, 0.14, 0.18, 0.98), true)

	var tug: float = clampf(game_manager.generator_tug_meter, 0.0, 100.0)
	var fill_w: float = bar_r.size.x * (tug / 100.0)

	hud_drawer.draw_rect(Rect2(bar_r.position, Vector2(fill_w, bar_r.size.y)), Color(0.38, 0.82, 0.98), true)
	hud_drawer.draw_rect(Rect2(bar_r.position.x + fill_w, bar_r.position.y, bar_r.size.x - fill_w, bar_r.size.y), Color(0.38, 0.88, 0.52), true)

	hud_drawer.draw_line(Vector2(bar_r.position.x + bar_r.size.x * 0.5, bar_r.position.y - 3), Vector2(bar_r.position.x + bar_r.size.x * 0.5, bar_r.end.y + 3), Color(1.0, 1.0, 1.0, 0.9), 2.0)
	hud_drawer.draw_rect(bar_r, Color(0.55, 0.65, 0.75), false, 1.2)

	hud_drawer.draw_string(font, hud_box.position + Vector2(14, 52), "◀ ECO CONTAINMENT (0%)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.95, 0.65))
	var mid_str := "METER: %.0f%%" % tug
	hud_drawer.draw_string(font, hud_box.position + Vector2(hud_box.size.x * 0.5 - 35, 52), mid_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.95, 0.70))
	hud_drawer.draw_string(font, hud_box.position + Vector2(hud_box.size.x - 170, 52), "TECH OVERDRIVE (100%) ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.85, 1.0))

func _draw_peace_hud(font: Font, vp_size: Vector2) -> void:
	var hud_box := Rect2(vp_size.x * 0.5 - 340, 88, 680, 58)
	hud_drawer.draw_rect(hud_box, Color(0.08, 0.12, 0.12, 0.96), true)
	hud_drawer.draw_rect(hud_box, Color(0.48, 0.95, 0.65), false, 2.0)

	if not game_manager.charter_ratified:
		hud_drawer.draw_string(font, hud_box.position + Vector2(14, 18), "GRAY SYNTHESIS CHARTER: RATIFICATION AT CONSOLES REQUIRED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.98, 0.85))
		var e_txt: String = "[ECO CONSOLE: RATIFIED]" if game_manager.charter_eco_ratified else "[ECO: CHANNEL WEST CONSOLE]"
		var t_txt: String = "[TECH CONSOLE: RATIFIED]" if game_manager.charter_tech_ratified else "[TECH: CHANNEL EAST CONSOLE]"
		var e_col: Color = Color(0.45, 0.95, 0.62) if game_manager.charter_eco_ratified else Color(1.0, 0.75, 0.45)
		var t_col: Color = Color(0.42, 0.82, 0.98) if game_manager.charter_tech_ratified else Color(1.0, 0.75, 0.45)
		hud_drawer.draw_string(font, hud_box.position + Vector2(14, 36), e_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, e_col)
		hud_drawer.draw_string(font, hud_box.position + Vector2(250, 36), t_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, t_col)

		var p_lbl := "Pwr: Low [1]" if game_manager.charter_power == C.CHARTER_POWER_LOW else "Pwr: High [1]"
		var l_lbl := "Land: Open [2]" if game_manager.charter_land == C.CHARTER_LAND_OPEN else "Land: Restr [2]"
		var m_lbl := "Med: Auto [3]" if game_manager.charter_med == C.CHARTER_MED_AUTOMATED else "Med: Sched [3]"
		hud_drawer.draw_string(font, hud_box.position + Vector2(14, 52), "TERMS:  %s  |  %s  |  %s" % [p_lbl, l_lbl, m_lbl], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.92, 0.98))
	else:
		var sec_rem: int = int(game_manager.holdout_timer)
		var cw_pct: int = int(game_manager.common_works)
		hud_drawer.draw_string(font, hud_box.position + Vector2(14, 18), "CRISIS HOLDOUT: %d SECONDS REMAINING • INTEGRITY: %d%%" % [sec_rem, cw_pct], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.90, 0.45))
		var haz_count: int = game_manager.active_hazards.size()
		if haz_count > 0:
			var haz_desc := ""
			for h in game_manager.active_hazards:
				haz_desc += "[⚠ %s in %s] " % [String(h["label"]), String(h["region"])]
			hud_drawer.draw_string(font, hud_box.position + Vector2(14, 40), haz_desc, HORIZONTAL_ALIGNMENT_LEFT, 650, 11, Color(1.0, 0.48, 0.40))
		else:
			hud_drawer.draw_string(font, hud_box.position + Vector2(14, 40), "All systems stable. Keep Common Works staffed and defend Town integrity!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.95, 0.75))

func _draw_archive_dilemma_overlay(font: Font, vp_size: Vector2) -> void:
	hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.04, 0.07, 0.78), true)
	var modal := Rect2(vp_size.x * 0.5 - 340, vp_size.y * 0.5 - 200, 680, 400)
	hud_drawer.draw_rect(modal, Color(0.09, 0.12, 0.17, 0.98), true)
	hud_drawer.draw_rect(modal, Color(0.95, 0.82, 0.42), false, 3.0)

	hud_drawer.draw_string(font, modal.position + Vector2(28, 38), "OLD-WORLD ARCHIVE DISCOVERED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.90, 0.48))
	hud_drawer.draw_string(font, modal.position + Vector2(28, 62), "Secluded pre-collapse container unsealed from bedrock • A decisive choice awaits you.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.88, 0.95))

	var is_op: bool = player.secret_role != "civilian"
	var desc_rect := Rect2(modal.position.x + 28, modal.position.y + 78, 624, 76)
	hud_drawer.draw_rect(desc_rect, Color(0.13, 0.16, 0.22, 0.92), true)
	hud_drawer.draw_rect(desc_rect, Color(0.38, 0.46, 0.58), false, 1.0)

	if is_op:
		var lore_op := "You recovered emergency infrastructure failsafe keys and classified schematics for %s. You hold the power to empower your faction's machinery, or expose catastrophic design flaws to force a peaceful Gray Synthesis." % player.secret_role.capitalize()
		hud_drawer.draw_string(font, desc_rect.position + Vector2(12, 24), lore_op, HORIZONTAL_ALIGNMENT_LEFT, 600, 12, Color(0.90, 0.94, 0.98))

		# Option 1: Loyal
		var b1 := Rect2(modal.position.x + 28, modal.position.y + 172, 624, 82)
		var h1 := _register_button("archive_loyal", b1)
		hud_drawer.draw_rect(b1, Color(0.20, 0.32, 0.44, 0.98) if h1 else Color(0.14, 0.20, 0.28, 0.95), true)
		hud_drawer.draw_rect(b1, Color(0.48, 0.85, 1.0) if h1 else Color(0.38, 0.52, 0.70), false, 2.0 if h1 else 1.2)
		hud_drawer.draw_string(font, b1.position + Vector2(16, 26), "[1] STAY LOYAL TO YOUR FACTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.98, 1.0))
		hud_drawer.draw_string(font, b1.position + Vector2(16, 50), "Empowers your covert operative cell: Grants +12% objective interaction speed in Finale.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
		hud_drawer.draw_string(font, b1.position + Vector2(16, 70), "Click here or Press [1]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.75, 0.92))

		# Option 2: Whistleblower
		var b2 := Rect2(modal.position.x + 28, modal.position.y + 270, 624, 82)
		var h2 := _register_button("archive_whistleblower", b2)
		hud_drawer.draw_rect(b2, Color(0.34, 0.24, 0.44, 0.98) if h2 else Color(0.22, 0.16, 0.28, 0.95), true)
		hud_drawer.draw_rect(b2, Color(0.85, 0.68, 1.0) if h2 else Color(0.60, 0.45, 0.75), false, 2.0 if h2 else 1.2)
		hud_drawer.draw_string(font, b2.position + Vector2(16, 26), "[2] BECOME A WHISTLEBLOWER (TOWN RECONCILIATION)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 1.0))
		hud_drawer.draw_string(font, b2.position + Vector2(16, 50), "Exposes your faction's catastrophic flaw: Changes your personal victory condition to Gray Synthesis.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.80, 1.0))
		hud_drawer.draw_string(font, b2.position + Vector2(16, 70), "Click here or Press [2]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.65, 0.92))
	else:
		var lore_civ := "You recovered master power grid override codes. As an unaffiliated civilian, your choice determines who wields this leverage, or whether to dedicate it directly to the Common Works."
		hud_drawer.draw_string(font, desc_rect.position + Vector2(12, 24), lore_civ, HORIZONTAL_ALIGNMENT_LEFT, 600, 12, Color(0.90, 0.94, 0.98))

		# Option 1: Entrust to Ecology
		var b1 := Rect2(modal.position.x + 28, modal.position.y + 168, 304, 84)
		var h1 := _register_button("archive_entrust_eco", b1)
		hud_drawer.draw_rect(b1, Color(0.16, 0.32, 0.22, 0.98) if h1 else Color(0.12, 0.22, 0.16, 0.95), true)
		hud_drawer.draw_rect(b1, Color(0.55, 0.95, 0.68) if h1 else Color(0.35, 0.65, 0.48), false, 2.0 if h1 else 1.2)
		hud_drawer.draw_string(font, b1.position + Vector2(12, 24), "[1] ENTRUST TO ECOLOGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 1.0, 0.90))
		hud_drawer.draw_string(font, b1.position + Vector2(12, 46), "+12% advantage if you vote Ecology at Court.", HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color(0.72, 0.92, 0.78))
		hud_drawer.draw_string(font, b1.position + Vector2(12, 72), "Click here or Press [1]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.85, 0.65))

		# Option 2: Entrust to Technology
		var b2 := Rect2(modal.position.x + 348, modal.position.y + 168, 304, 84)
		var h2 := _register_button("archive_entrust_tech", b2)
		hud_drawer.draw_rect(b2, Color(0.16, 0.26, 0.38, 0.98) if h2 else Color(0.12, 0.18, 0.26, 0.95), true)
		hud_drawer.draw_rect(b2, Color(0.52, 0.88, 1.0) if h2 else Color(0.35, 0.58, 0.75), false, 2.0 if h2 else 1.2)
		hud_drawer.draw_string(font, b2.position + Vector2(12, 24), "[2] ENTRUST TO TECHNOLOGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.96, 1.0))
		hud_drawer.draw_string(font, b2.position + Vector2(12, 46), "+12% advantage if you vote Technology at Court.", HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color(0.72, 0.85, 0.98))
		hud_drawer.draw_string(font, b2.position + Vector2(12, 72), "Click here or Press [2]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.75, 0.95))

		# Option 3: Reserve for Common Works
		var b3 := Rect2(modal.position.x + 28, modal.position.y + 266, 624, 84)
		var h3 := _register_button("archive_reserve_cw", b3)
		hud_drawer.draw_rect(b3, Color(0.32, 0.22, 0.44, 0.98) if h3 else Color(0.20, 0.15, 0.28, 0.95), true)
		hud_drawer.draw_rect(b3, Color(0.85, 0.68, 1.0) if h3 else Color(0.60, 0.45, 0.75), false, 2.0 if h3 else 1.2)
		hud_drawer.draw_string(font, b3.position + Vector2(16, 26), "[3] RESERVE FOR COMMON WORKS (CIVIC PEACE)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 1.0))
		hud_drawer.draw_string(font, b3.position + Vector2(16, 48), "Directly integrates into infrastructure: Immediately grants +15% progress across all 3 tracks!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.80, 1.0))
		hud_drawer.draw_string(font, b3.position + Vector2(16, 70), "Click here or Press [3]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.65, 0.92))

func _draw_meter(pos: Vector2, size: Vector2, title: String, val: float, max_val: float, fill_col: Color, is_critical: bool) -> void:
	var font := ThemeDB.fallback_font
	hud_drawer.draw_string(font, pos + Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.90, 0.96))
	var bar_rect := Rect2(pos + Vector2(0, 20), size)
	hud_drawer.draw_rect(bar_rect, Color(0.14, 0.16, 0.20, 0.95), true)
	var ratio := clampf(val / max_val, 0.0, 1.0)
	hud_drawer.draw_rect(Rect2(bar_rect.position, Vector2(size.x * ratio, size.y)), fill_col, true)
	var border_col := Color(1.0, 0.38, 0.35, 1.0) if is_critical else Color(0.45, 0.52, 0.62, 0.9)
	hud_drawer.draw_rect(bar_rect, border_col, false, 1.5)
	hud_drawer.draw_string(font, bar_rect.position + Vector2(8, 16), "%d / %d" % [int(round(val)), int(max_val)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.98, 0.99, 1.0))
