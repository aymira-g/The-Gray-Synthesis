extends PanelContainer

# ==============================================================================
# The Gray Synthesis - 3D Evidence Journal & Investigative Dossier
# ==============================================================================
# Full-featured investigative overlay modal toggled with [J] key:
# - Displays private observations, physical traces, and tabled exhibits
# - Color-coded evidence tiers: [OBSERVED FACT], [VERIFIED TRACE], [CLAIM]
# - Alibi conflict analysis highlighting contradictions between claims & sightings
# - Secluded Bedrock Alcove & Archive Key discovery status
# - Interactive individual and bulk clue tabling for Council and Court debates
# ==============================================================================

const C = preload("res://scripts/GameConstants.gd")

var game_manager: Node
var player_node: CharacterBody3D
var all_residents: Array = []
var town_map: Node3D

var current_filter: String = "ALL" # "ALL", "FACT", "TRACE", "ALIBI", "TABLED"

var title_label: Label
var subtitle_label: Label
var identity_label: Label
var entries_container: VBoxContainer
var alibi_container: VBoxContainer
var alcove_status_label: Label
var filter_buttons: Dictionary = {}
var table_all_btn: Button
var _is_setup: bool = false

func _ready() -> void:
	if _is_setup:
		return
	_is_setup = true
	custom_minimum_size = Vector2(880, 640)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -440.0
	offset_top = -320.0
	offset_right = 440.0
	offset_bottom = 320.0
	visible = false

	_setup_ui()

func _setup_ui() -> void:
	# Outer Styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.98)
	style.border_color = Color(0.48, 0.72, 0.95, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 1. Header
	title_label = Label.new()
	title_label.text = "INVESTIGATIVE EVIDENCE DOSSIER"
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.modulate = Color(0.92, 0.96, 1.0)
	main_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Private findings recorded exclusively to your journal • Clues remain confidential until tabled"
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.modulate = Color(0.68, 0.76, 0.86)
	main_vbox.add_child(subtitle_label)

	identity_label = Label.new()
	identity_label.text = "Dossier of: Resident 1 (Pump Technician) — Unaffiliated Civilian"
	identity_label.add_theme_font_size_override("font_size", 14)
	identity_label.modulate = Color(0.45, 0.88, 1.0)
	main_vbox.add_child(identity_label)

	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# 2. Filter Button Bar
	var filter_hbox := HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(filter_hbox)

	var filters := [
		{"id": "ALL", "label": "All Clues"},
		{"id": "FACT", "label": "Observed Facts"},
		{"id": "TRACE", "label": "Physical Traces"},
		{"id": "ALIBI", "label": "Alibi Conflicts"},
		{"id": "TABLED", "label": "Tabled Exhibits"}
	]

	for f_def in filters:
		var btn := Button.new()
		btn.text = f_def["label"]
		btn.custom_minimum_size = Vector2(130, 28)
		var fid: String = f_def["id"]
		btn.pressed.connect(func(): _set_filter(fid))
		filter_hbox.add_child(btn)
		filter_buttons[fid] = btn

	# 3. Main Scrollable Clue List Area
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 290)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	entries_container = VBoxContainer.new()
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_container.add_theme_constant_override("separation", 6)
	scroll.add_child(entries_container)

	# 4. Alibi Contradiction & Archive Panel
	var info_box := PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	info_style.border_color = Color(0.28, 0.35, 0.45)
	info_style.border_width_left = 1
	info_style.border_width_top = 1
	info_style.border_width_right = 1
	info_style.border_width_bottom = 1
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	info_box.add_theme_stylebox_override("panel", info_style)
	main_vbox.add_child(info_box)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 12)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 12)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	info_box.add_child(info_margin)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_margin.add_child(info_vbox)

	alcove_status_label = Label.new()
	alcove_status_label.text = "Archive Status: Sealed. 1 of 4 secluded bedrock alcoves holds the unseal key."
	alcove_status_label.add_theme_font_size_override("font_size", 13)
	alcove_status_label.modulate = Color(1.0, 0.88, 0.50)
	info_vbox.add_child(alcove_status_label)

	alibi_container = VBoxContainer.new()
	alibi_container.add_theme_constant_override("separation", 2)
	info_vbox.add_child(alibi_container)

	# 5. Footer Action Bar
	var footer_hbox := HBoxContainer.new()
	main_vbox.add_child(footer_hbox)

	table_all_btn = Button.new()
	table_all_btn.text = "Table All Remaining Clues"
	table_all_btn.custom_minimum_size = Vector2(210, 36)
	table_all_btn.pressed.connect(_on_table_all_clicked)
	footer_hbox.add_child(table_all_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Close Dossier [J / ESC]"
	close_btn.custom_minimum_size = Vector2(170, 36)
	close_btn.pressed.connect(close_journal)
	footer_hbox.add_child(close_btn)

func open_journal() -> void:
	if game_manager != null:
		game_manager.evidence_journal_open = true
	visible = true
	_refresh_journal()

func close_journal() -> void:
	if game_manager != null:
		game_manager.evidence_journal_open = false
	visible = false

func toggle_journal() -> void:
	if visible:
		close_journal()
	else:
		open_journal()

func _set_filter(f_id: String) -> void:
	current_filter = f_id
	_refresh_journal()

func _refresh_journal() -> void:
	if game_manager == null or player_node == null:
		return

	# Refresh identity ribbon
	var role_name := "Unaffiliated Civilian"
	if player_node.secret_role == "ecology":
		role_name = "Ecology Operative (%s)" % player_node.operative_kit
	elif player_node.secret_role == "technology":
		role_name = "Technology Operative (%s)" % player_node.operative_kit
	identity_label.text = "Dossier of: %s (%s) — %s" % [
		player_node.resident_name, player_node.civic_job, role_name
	]

	# Refresh Archive Secrecy Status (Zero-leak privacy for non-finders without evidence)
	var player_has_archive_intel := false
	var p_journal: Dictionary = game_manager.get_player_journal(player_node.resident_id)
	for bucket in ["observed", "traces"]:
		for entry in p_journal.get(bucket, []):
			var txt: String = String(entry.get("text", "")).to_lower()
			if txt.find("archive") != -1 or txt.find("failsafe key") != -1:
				player_has_archive_intel = true
				break
		if player_has_archive_intel:
			break

	if not player_has_archive_intel and game_manager.tabled_evidence != null:
		for entry in game_manager.tabled_evidence:
			var txt: String = String(entry.get("text", "")).to_lower()
			if txt.find("archive") != -1 or txt.find("failsafe key") != -1:
				player_has_archive_intel = true
				break

	if game_manager.archive_opened:
		if game_manager.archive_finder_name == player_node.resident_name or game_manager.archive_finder_id == player_node.resident_id:
			alcove_status_label.text = "★ DECISIVE KEY SECURED: You unsealed the hidden Archive failsafe key! Entrusted with the final mandate."
			alcove_status_label.modulate = Color(0.55, 0.98, 0.70)
		elif player_has_archive_intel:
			alcove_status_label.text = "Verified Intel: Archive failsafe key unsealed and extracted (Learned through evidence)."
			alcove_status_label.modulate = Color(1.0, 0.82, 0.45)
		else:
			alcove_status_label.text = "Archive Status: Unknown. 1 of 4 secluded bedrock alcoves holds the unseal key."
			alcove_status_label.modulate = Color(0.85, 0.85, 0.90)
	else:
		alcove_status_label.text = "Archive Status: Sealed. 1 of 4 secluded bedrock alcoves holds the unseal key."
		alcove_status_label.modulate = Color(0.85, 0.85, 0.90)

	# Update Footer Table All Button state based on phase
	var is_first_council: bool = (game_manager != null and game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL)
	if table_all_btn != null:
		if is_first_council:
			table_all_btn.disabled = false
			table_all_btn.text = "Table All Remaining Clues"
			table_all_btn.tooltip_text = "Present all private findings to the Town Council"
		else:
			table_all_btn.disabled = true
			table_all_btn.text = "Table Clues (First Council Only)"
			table_all_btn.tooltip_text = "Evidence can only be tabled during First Council"

	# Refresh Alibi Conflicts
	for child in alibi_container.get_children():
		alibi_container.remove_child(child)
		child.queue_free()

	if game_manager.alibi_conflicts.is_empty():
		var no_cf := Label.new()
		no_cf.text = "Alibi Analysis: No verified contradictions currently detected."
		no_cf.add_theme_font_size_override("font_size", 12)
		no_cf.modulate = Color(0.65, 0.72, 0.82)
		alibi_container.add_child(no_cf)
	else:
		for cf in game_manager.alibi_conflicts:
			var cf_lbl := Label.new()
			cf_lbl.text = "⚠️ CONTRADICTION: %s claimed %s at %s, but sighting placed them in %s!" % [
				cf.get("resident", "Resident"), cf.get("claim", "Sector"), cf.get("time", "Time"), cf.get("seen", "Sector")
			]
			cf_lbl.add_theme_font_size_override("font_size", 12)
			cf_lbl.modulate = Color(1.0, 0.55, 0.45)
			alibi_container.add_child(cf_lbl)

	# Fetch Player Clues
	var journal: Dictionary = game_manager.get_player_journal(player_node.resident_id)
	var observed: Array = journal.get("observed", [])
	var traces: Array = journal.get("traces", [])

	var all_clues: Array = []
	all_clues.append_array(observed)
	all_clues.append_array(traces)

	# Filter clues based on selected tab
	var displayed_clues: Array = []
	for clue in all_clues:
		var tier: String = String(clue.get("tier", ""))
		var is_tabled: bool = bool(clue.get("tabled", false))
		match current_filter:
			"ALL":
				displayed_clues.append(clue)
			"FACT":
				if tier == C.EVIDENCE_FACT:
					displayed_clues.append(clue)
			"TRACE":
				if tier == C.EVIDENCE_TRACE:
					displayed_clues.append(clue)
			"ALIBI":
				if tier == C.EVIDENCE_CLAIM or clue.get("text", "").find("claimed") != -1:
					displayed_clues.append(clue)
			"TABLED":
				if is_tabled:
					displayed_clues.append(clue)

	# Rebuild entries container
	for child in entries_container.get_children():
		entries_container.remove_child(child)
		child.queue_free()

	if displayed_clues.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No clues found in this category. Inspect secluded alcoves with [V], observe Open Town chores, or table exhibits."
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.modulate = Color(0.65, 0.70, 0.78)
		entries_container.add_child(empty_lbl)
		return

	for clue in displayed_clues:
		var card := _create_clue_card(clue)
		entries_container.add_child(card)

func _create_clue_card(clue: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.22, 0.85)
	card_style.border_color = Color(0.24, 0.32, 0.42)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Tier Badge
	var tier: String = String(clue.get("tier", ""))
	var tier_label := Label.new()
	tier_label.custom_minimum_size = Vector2(130, 0)
	tier_label.add_theme_font_size_override("font_size", 12)
	
	if tier == C.EVIDENCE_FACT:
		tier_label.text = "[OBSERVED FACT]"
		tier_label.modulate = Color(1.0, 0.78, 0.38)
	elif tier == C.EVIDENCE_TRACE:
		tier_label.text = "[VERIFIED TRACE]"
		tier_label.modulate = Color(0.45, 0.88, 1.0)
	else:
		tier_label.text = "[UNVERIFIED CLAIM]"
		tier_label.modulate = Color(0.80, 0.68, 1.0)
	hbox.add_child(tier_label)

	# Text and Details
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var desc := Label.new()
	desc.text = clue.get("text", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.95, 0.98, 1.0)
	vbox.add_child(desc)

	var meta := Label.new()
	meta.text = "Time: %s  •  Sector: %s" % [clue.get("time", "--:--"), clue.get("region", "Town")]
	meta.add_theme_font_size_override("font_size", 11)
	meta.modulate = Color(0.60, 0.68, 0.78)
	vbox.add_child(meta)

	# Table action button / Status
	var is_tabled: bool = bool(clue.get("tabled", false))
	if is_tabled:
		var tabled_tag := Label.new()
		tabled_tag.text = "✓ Tabled Exhibit"
		tabled_tag.custom_minimum_size = Vector2(110, 0)
		tabled_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tabled_tag.add_theme_font_size_override("font_size", 12)
		tabled_tag.modulate = Color(0.55, 0.95, 0.70)
		hbox.add_child(tabled_tag)
	else:
		var clue_id: String = String(clue.get("id", ""))
		var table_btn := Button.new()
		var is_first_council: bool = (game_manager != null and game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL)
		if is_first_council:
			table_btn.disabled = false
			table_btn.text = "Table Clue"
			table_btn.tooltip_text = "Table this clue for the Town Council debate"
		else:
			table_btn.disabled = true
			table_btn.text = "Council Only"
			table_btn.tooltip_text = "Evidence can only be tabled during First Council"
		table_btn.custom_minimum_size = Vector2(110, 28)
		table_btn.pressed.connect(func(): _on_table_clue_clicked(clue_id))
		hbox.add_child(table_btn)

	return card

func _on_table_clue_clicked(clue_id: String) -> void:
	if game_manager == null or player_node == null:
		return
	if game_manager.current_phase != game_manager.Phase.FIRST_COUNCIL:
		if player_node.has_method("show_popup"):
			player_node.show_popup("Evidence can only be tabled during First Council!", Color(1.0, 0.65, 0.45))
		return
	var success: bool = game_manager.table_clue_by_id(player_node.resident_id, clue_id)
	if success:
		_refresh_journal()

func _on_table_all_clicked() -> void:
	if game_manager == null or player_node == null:
		return
	if game_manager.current_phase != game_manager.Phase.FIRST_COUNCIL:
		if player_node.has_method("show_popup"):
			player_node.show_popup("Evidence can only be tabled during First Council!", Color(1.0, 0.65, 0.45))
		return
	game_manager.table_player_clues(player_node.resident_id, true)
	_refresh_journal()
