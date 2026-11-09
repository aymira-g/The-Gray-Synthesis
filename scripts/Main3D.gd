extends Node3D

# ==============================================================================
# The Gray Synthesis - Main 3D Game Coordinator (Phase 3 Full Match Loop)
# ==============================================================================
# Orchestrates the complete match lifecycle in 3D:
# - Briefing -> Open Town -> First Council -> Escalation -> 3D Court Ceremony
#   -> Strategic Deliberation Window -> Finale (Confrontation/Peace) -> Match Over.
# - Cinematic Director Camera: Isometric follow, Master Council Ring, Podium close-up, Celebration.
# - Integrated 3D Court: 4 Civilians physically walk to the podium, deliver spoken testimony in 3D
#   speech balloons, and cast live ballots with dynamic tally displays.
# - 3D Finale: Overdrive Generator tug-of-war meter and Common Works crisis holdout.
# - Full-screen 3D Victory / Defeat ceremony and match statistics.
# ==============================================================================

const Resident3DScene = preload("res://scenes/Resident3D.tscn")
const BotControllerClass = preload("res://scripts/ResidentBotController3D.gd")
const AudioManagerClass = preload("res://scripts/AudioManager.gd")
const RadarMinimapClass = preload("res://scripts/RadarMinimap3D.gd")
const EvidenceJournalClass = preload("res://scripts/EvidenceJournal3D.gd")
const PlaytestTuningPanelClass = preload("res://scripts/PlaytestTuningPanel3D.gd")
const SettingsMenuClass = preload("res://scripts/SettingsMenu3D.gd")
const HeroDraftLobbyClass = preload("res://scripts/HeroDraftLobby3D.gd")
const C = preload("res://scripts/GameConstants.gd")

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
var town_map: Node3D
var audio_manager: Node
var camera: Camera3D
var residents_root: Node3D

var residents: Array = []
var bot_controllers: Array = []
var spawn_positions: Array[Vector3] = []
var player_node: CharacterBody3D

# Camera Director Modes: "follow_player", "wide_council", "court_podium", "podium_celebration"
var camera_mode: String = "wide_council"
var active_podium_speaker: Node = null
var camera_zoom: float = 1.0 # 0.55 to 1.35 zoom factor (immediate control)
var target_camera_zoom: float = 1.0
var smooth_camera_zoom: float = 1.0
var sprint_zoom_mult: float = 1.0 # expands to 1.10 during sprint

# Velocity look-ahead lead
var look_ahead_lead: Vector3 = Vector3.ZERO
var target_look_ahead_lead: Vector3 = Vector3.ZERO

# Trauma-based camera shake decay system (quadratic falloff)
var camera_trauma: float = 0.0
var trauma_decay: float = 1.35
var max_shake_offset: Vector3 = Vector3(0.55, 0.35, 0.55)
var max_shake_rotation: Vector3 = Vector3(0.015, 0.022, 0.015)
var current_shake_offset: Vector3 = Vector3.ZERO
var current_shake_rotation: Vector3 = Vector3.ZERO

# Dynamic FOV
var target_camera_fov: float = 70.0

# Telemetry tracking for events
var _prev_archive_opened: bool = false
var _prev_tug_diff: float = 0.0

# HUD elements
var ui_layer: CanvasLayer
var clock_label: Label
var resource_label: Label
var role_label: Label
var status_label: Label

# Interactive Overlays
var phase_banner: PanelContainer
var phase_banner_title: Label
var phase_banner_subtitle: Label
var phase_banner_timer: float = 0.0

var council_overlay: PanelContainer
var council_title_label: Label
var council_speaker_label: Label
var council_statement_label: Label
var council_speaker_idx: int = 0
var council_speaker_timer: float = 0.0
var council_motion_header_label: Label
var council_motion_btn_container: HBoxContainer
var council_motion_btn_1: Button
var council_motion_btn_2: Button
var council_motion_btn_3: Button
var council_tally_label: Label
var council_hint_label: Label

var channel_bar_container: PanelContainer
var channel_action_label: Label
var channel_progress_bar: ProgressBar

var help_overlay: PanelContainer
var radar_minimap: Control
var evidence_journal: PanelContainer
var playtest_tuning_panel: PanelContainer
var settings_menu: PanelContainer
var hero_draft_lobby: PanelContainer

var court_overlay: PanelContainer
var court_speaker_label: Label
var court_speech_label: Label
var court_tally_label: Label

var strategic_overlay: PanelContainer
var strategic_text_label: Label

var finale_overlay: PanelContainer
var finale_meter_label: Label

var game_over_overlay: PanelContainer
var game_over_title: Label
var game_over_subtitle: Label
var game_over_stats: Label
var game_over_roster: Label

# Archive Discovery Dilemma Modal UI (Blueprint Section 6 & 11)
var archive_dilemma_overlay: PanelContainer
var archive_dilemma_options_container: VBoxContainer
var archive_dilemma_title: Label
var archive_dilemma_desc: Label
var archive_dilemma_timer_label: Label
var archive_dilemma_timer: float = 25.0

var _is_initialized: bool = false
var bot_seed: int = -1
var _match_bot_seed: int = 0

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	randomize()
	_match_bot_seed = bot_seed if bot_seed >= 0 else randi()

	game_manager = $GameManager
	town_map = $TownMap3D
	camera = $Camera3D
	residents_root = $Residents

	audio_manager = get_node_or_null("AudioManager")
	if audio_manager == null:
		audio_manager = AudioManagerClass.new()
		audio_manager.name = "AudioManager"
		add_child(audio_manager)

	town_map.game_manager = game_manager
	town_map.audio_manager = audio_manager
	town_map._ready()

	_setup_session_residents()
	_setup_hud()

	# Connect GameManager lifecycle signals
	game_manager.phase_changed.connect(_on_phase_changed)
	game_manager.state_updated.connect(_on_state_updated)

	# Start official match in GameManager (distributes 3 Eco, 3 Tech, 4 Civilians)
	game_manager.start_match(residents)
	town_map._sync_active_alcove()

	for res in residents:
		res.refresh_identity_labels()
		var bot_controller: Node = res.get("bot_controller")
		if bot_controller != null:
			bot_controller.refresh_personal_memory()

	_on_phase_changed(game_manager.current_phase)

func _setup_session_residents() -> void:
	# 10 evenly spaced spawn positions around the Council Ring in Town Square (radius 5.5m)
	var ring_radius := 5.5
	for i in range(10):
		var angle := (TAU / 10.0) * float(i) - PI * 0.5
		var pos := Vector3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius)
		spawn_positions.append(pos)

		var res: CharacterBody3D = Resident3DScene.instantiate()
		res.resident_id = i + 1
		res.is_player = (i == 0)
		res.set_hero_by_index(i)
		res.spawn_position = pos
		res.position = pos
		res.town_map = town_map
		res.game_manager = game_manager
		res.audio_manager = audio_manager
		res.trauma_impact_requested.connect(_on_resident_trauma_impact)
		residents_root.add_child(res)
		residents.append(res)

		if i == 0:
			player_node = res
		else:
			var bc: Node = BotControllerClass.new()
			bc.name = "BotController3D"
			res.add_child(bc)
			res.bot_controller = bc
			bc.set_bot_seed(_match_bot_seed + int(res.resident_id))
			bc.setup(res, town_map, game_manager, 0.25 * float(i))
			bot_controllers.append(bc)

	for res in residents:
		res.all_residents = residents
	town_map.all_residents = residents

func refresh_bot_memories() -> void:
	for bot_controller in bot_controllers:
		if bot_controller != null and bot_controller.has_method("refresh_personal_memory"):
			bot_controller.refresh_personal_memory()

func _setup_hud() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# 1. Top Header Panel
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 20.0
	top_panel.offset_top = 16.0
	top_panel.offset_right = -20.0
	top_panel.offset_bottom = 90.0
	ui_layer.add_child(top_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_panel.add_child(hbox)

	clock_label = Label.new()
	clock_label.text = "CLOCK: 05:00 [OPEN TOWN]"
	clock_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(clock_label)

	var sep1 := VSeparator.new()
	sep1.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(sep1)

	resource_label = Label.new()
	resource_label.text = "WATER: 50%  |  STABILITY: 50%  |  SCRAP: 3"
	resource_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(resource_label)

	var sep2 := VSeparator.new()
	sep2.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(sep2)

	role_label = Label.new()
	role_label.text = "YOU: Resident 1 (Pump Technician) [Ecology Operative]"
	role_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(role_label)

	var sep3 := VSeparator.new()
	sep3.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(sep3)

	var hero_draft_btn := Button.new()
	hero_draft_btn.name = "TopBarHeroDraftButton"
	hero_draft_btn.text = " ★ Heroes [Tab] "
	hero_draft_btn.focus_mode = Control.FOCUS_NONE
	hero_draft_btn.pressed.connect(toggle_hero_draft_lobby)
	hbox.add_child(hero_draft_btn)

	var settings_btn := Button.new()
	settings_btn.name = "TopBarSettingsButton"
	settings_btn.text = " ⚙ Settings [Esc] "
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(toggle_settings_menu)
	hbox.add_child(settings_btn)

	# 2. Bottom Status / Controls Banner
	status_label = Label.new()
	status_label.text = "WASD: Move | Shift: Sprint | [E] Task | [V] Inspect | [R] Shove | [F] Civic | [C] Special | [J] Journal | [Z] Zoom | [H] Help | [Esc] Settings"
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_left = 20.0
	status_label.offset_bottom = -16.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(0.88, 0.92, 1.0, 0.95)
	ui_layer.add_child(status_label)

	# 3. Phase Banner Announcement
	phase_banner = PanelContainer.new()
	phase_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_banner.offset_top = 110.0
	phase_banner.offset_left = -340.0
	phase_banner.offset_right = 340.0
	phase_banner.offset_bottom = 200.0
	phase_banner.visible = false
	ui_layer.add_child(phase_banner)

	var pb_vbox := VBoxContainer.new()
	pb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_banner.add_child(pb_vbox)

	phase_banner_title = Label.new()
	phase_banner_title.text = "PHASE ANNOUNCEMENT"
	phase_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_banner_title.add_theme_font_size_override("font_size", 22)
	pb_vbox.add_child(phase_banner_title)

	phase_banner_subtitle = Label.new()
	phase_banner_subtitle.text = ""
	phase_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_banner_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_banner_subtitle.add_theme_font_size_override("font_size", 15)
	pb_vbox.add_child(phase_banner_subtitle)

	# 4. First Council Deliberations Overlay
	council_overlay = PanelContainer.new()
	council_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	council_overlay.offset_top = 55.0
	council_overlay.offset_left = -460.0
	council_overlay.offset_right = 460.0
	council_overlay.offset_bottom = 345.0
	council_overlay.visible = false
	ui_layer.add_child(council_overlay)

	var co_style := StyleBoxFlat.new()
	co_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	co_style.border_color = Color(0.92, 0.78, 0.42, 0.9)
	co_style.border_width_left = 2
	co_style.border_width_top = 2
	co_style.border_width_right = 2
	co_style.border_width_bottom = 2
	co_style.corner_radius_top_left = 6
	co_style.corner_radius_top_right = 6
	co_style.corner_radius_bottom_left = 6
	co_style.corner_radius_bottom_right = 6
	council_overlay.add_theme_stylebox_override("panel", co_style)

	var co_margin := MarginContainer.new()
	co_margin.add_theme_constant_override("margin_left", 16)
	co_margin.add_theme_constant_override("margin_top", 12)
	co_margin.add_theme_constant_override("margin_right", 16)
	co_margin.add_theme_constant_override("margin_bottom", 12)
	council_overlay.add_child(co_margin)

	var co_vbox := VBoxContainer.new()
	co_vbox.add_theme_constant_override("separation", 6)
	co_margin.add_child(co_vbox)

	council_title_label = Label.new()
	council_title_label.text = "★ FIRST COUNCIL IN SESSION: TOWN DELIBERATIONS ★"
	council_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_title_label.add_theme_font_size_override("font_size", 17)
	council_title_label.modulate = Color(1.0, 0.88, 0.45)
	co_vbox.add_child(council_title_label)

	council_speaker_label = Label.new()
	council_speaker_label.text = "SPEAKER: Resident 1 (Pump Technician)"
	council_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_speaker_label.add_theme_font_size_override("font_size", 14)
	council_speaker_label.modulate = Color(0.60, 0.90, 1.0)
	co_vbox.add_child(council_speaker_label)

	council_statement_label = Label.new()
	council_statement_label.text = "\"Between 04:00 and 03:00, I was in Town Square.\""
	council_statement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	council_statement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_statement_label.add_theme_font_size_override("font_size", 13)
	co_vbox.add_child(council_statement_label)

	var co_sep1 := HSeparator.new()
	co_vbox.add_child(co_sep1)

	council_motion_header_label = Label.new()
	council_motion_header_label.text = "CIVIC MOTION BALLOT (Takes effect at Escalation — Choose 1):"
	council_motion_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_motion_header_label.add_theme_font_size_override("font_size", 13)
	council_motion_header_label.modulate = Color(0.95, 0.82, 0.45)
	co_vbox.add_child(council_motion_header_label)

	council_motion_btn_container = HBoxContainer.new()
	council_motion_btn_container.add_theme_constant_override("separation", 10)
	co_vbox.add_child(council_motion_btn_container)

	council_motion_btn_1 = Button.new()
	council_motion_btn_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	council_motion_btn_1.custom_minimum_size = Vector2(0, 52)
	council_motion_btn_1.tooltip_text = "Deploy surveillance sensors at Pump Station & Greenhouse. Logs station accesses into evidence journals."
	council_motion_btn_1.pressed.connect(func(): _cast_first_council_motion(1))
	council_motion_btn_container.add_child(council_motion_btn_1)

	council_motion_btn_2 = Button.new()
	council_motion_btn_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	council_motion_btn_2.custom_minimum_size = Vector2(0, 52)
	council_motion_btn_2.tooltip_text = "Requisitions emergency industrial reserves, adding +3 Scrap to town stockpiles immediately at Escalation."
	council_motion_btn_2.pressed.connect(func(): _cast_first_council_motion(2))
	council_motion_btn_container.add_child(council_motion_btn_2)

	council_motion_btn_3 = Button.new()
	council_motion_btn_3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	council_motion_btn_3.custom_minimum_size = Vector2(0, 52)
	council_motion_btn_3.tooltip_text = "Mandates emergency soil conditioning, reducing town stability crisis decay by 25% during Escalation."
	council_motion_btn_3.pressed.connect(func(): _cast_first_council_motion(3))
	council_motion_btn_container.add_child(council_motion_btn_3)

	council_tally_label = Label.new()
	council_tally_label.text = "Council Ballot Tally: Beacons (0) | Scrap (0) | Remediation (0)"
	council_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_tally_label.add_theme_font_size_override("font_size", 12)
	council_tally_label.modulate = Color(0.85, 0.90, 0.98)
	co_vbox.add_child(council_tally_label)

	var co_sep2 := HSeparator.new()
	co_vbox.add_child(co_sep2)

	council_hint_label = Label.new()
	council_hint_label.text = "[1], [2], [3] Vote on Civic Motion  |  [J] Table Evidence Clues  |  [Space] Advance to Escalation"
	council_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	council_hint_label.add_theme_font_size_override("font_size", 13)
	council_hint_label.modulate = Color(0.55, 0.95, 0.70)
	co_vbox.add_child(council_hint_label)

	# 5. Channeling HUD Progress Bar
	channel_bar_container = PanelContainer.new()
	channel_bar_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	channel_bar_container.offset_top = -125.0
	channel_bar_container.offset_bottom = -65.0
	channel_bar_container.offset_left = -220.0
	channel_bar_container.offset_right = 220.0
	channel_bar_container.visible = false
	ui_layer.add_child(channel_bar_container)

	var cb_vbox := VBoxContainer.new()
	channel_bar_container.add_child(cb_vbox)

	channel_action_label = Label.new()
	channel_action_label.text = "Channeling..."
	channel_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_action_label.add_theme_font_size_override("font_size", 15)
	channel_action_label.modulate = Color(0.45, 0.88, 1.0)
	cb_vbox.add_child(channel_action_label)

	channel_progress_bar = ProgressBar.new()
	channel_progress_bar.min_value = 0.0
	channel_progress_bar.max_value = 100.0
	channel_progress_bar.value = 0.0
	channel_progress_bar.show_percentage = false
	channel_progress_bar.custom_minimum_size = Vector2(0, 16)
	cb_vbox.add_child(channel_progress_bar)

	# 6. Help & Field Manual Overlay [H]
	help_overlay = PanelContainer.new()
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	help_overlay.offset_left = -420.0
	help_overlay.offset_top = -240.0
	help_overlay.offset_right = 420.0
	help_overlay.offset_bottom = 240.0
	help_overlay.visible = false
	ui_layer.add_child(help_overlay)

	var h_vbox := VBoxContainer.new()
	help_overlay.add_child(h_vbox)

	var h_title := Label.new()
	h_title.text = "THE GRAY SYNTHESIS - FIELD MANUAL & CONTROLS"
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_size_override("font_size", 20)
	h_title.modulate = Color(1.0, 0.85, 0.35)
	h_vbox.add_child(h_title)

	var h_sep := HSeparator.new()
	h_vbox.add_child(h_sep)

	var h_text := Label.new()
	h_text.text = """[CONTROLS]
WASD: Direct Movement  |  Shift: Sprint (Consumes Stamina)
[E]: Channel Civic Station (Restore Water, Stability, Scrap, or Common Works)
[V]: Inspect Secluded Bedrock Alcove (Locate hidden Archive Failsafe Key)
[R]: Civic Shove (Knockback target, 35 Stamina Dmg, 5s Cooldown)
[F]: Use Civic Job Kit  |  [C]: Use Faction Operative Kit
[J]: Open Private Evidence Journal & Alibi Analysis
Mouse Wheel / [Z]: Zoom Camera In / Out
[H]: Toggle this Field Manual

[MATCH PROGRESSION & OBJECTIVES]
1. Briefing -> 2. Open Town -> 3. First Council -> 4. Escalation -> 5. Court -> 6. Finale
- Ecology: Prime generators, stabilize biosphere, win Court vote, or overload 0%
- Technology: Overclock stations, governor tuning, win Court vote, or prime 100%
- Civilian Peace: Complete Common Works (100%) or broker Peace Charter
- Archive Key: 1 of 4 secluded alcoves holds the unseal key to secure victory!"""
	h_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_text.add_theme_font_size_override("font_size", 14)
	h_vbox.add_child(h_text)

	var h_close := Label.new()
	h_close.text = "\n[Press H or ESC to Close]"
	h_close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_close.add_theme_font_size_override("font_size", 15)
	h_close.modulate = Color(0.7, 0.7, 0.75)
	h_vbox.add_child(h_close)

	# 6.5 Tactical Radar Minimap
	radar_minimap = RadarMinimapClass.new()
	radar_minimap.name = "RadarMinimap3D"
	radar_minimap.town_map = town_map
	radar_minimap.player_node = player_node
	radar_minimap.all_residents = residents
	radar_minimap.game_manager = game_manager
	ui_layer.add_child(radar_minimap)
	radar_minimap._ready()

	# 6.6 Investigative Evidence Journal [J]
	evidence_journal = EvidenceJournalClass.new()
	evidence_journal.name = "EvidenceJournal3D"
	evidence_journal.game_manager = game_manager
	evidence_journal.player_node = player_node
	evidence_journal.all_residents = residents
	evidence_journal.town_map = town_map
	ui_layer.add_child(evidence_journal)
	evidence_journal._ready()

	# 6.7 Milestone 8 Playtest & Developer Tuning Console [F1] / [~]
	playtest_tuning_panel = PlaytestTuningPanelClass.new()
	playtest_tuning_panel.name = "PlaytestTuningPanel3D"
	ui_layer.add_child(playtest_tuning_panel)
	playtest_tuning_panel.setup(game_manager, town_map, player_node, self, residents, bot_controllers)

	# 6.8 Player Settings & Audio Mixer [Esc] / [⚙]
	settings_menu = SettingsMenuClass.new()
	settings_menu.name = "SettingsMenu3D"
	ui_layer.add_child(settings_menu)
	settings_menu.setup(game_manager, audio_manager, self)

	# 6.9 Pre-Match 10-Hero Selection & Matchmaking Lobby [Tab]
	hero_draft_lobby = HeroDraftLobbyClass.new()
	hero_draft_lobby.name = "HeroDraftLobby3D"
	ui_layer.add_child(hero_draft_lobby)
	hero_draft_lobby.setup(self, game_manager, audio_manager)

	# 7. Court Ceremony Dialogue & Tally Overlay
	court_overlay = PanelContainer.new()
	court_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	court_overlay.offset_top = 100.0
	court_overlay.offset_left = -380.0
	court_overlay.offset_right = 380.0
	court_overlay.offset_bottom = 260.0
	court_overlay.visible = false
	ui_layer.add_child(court_overlay)

	var c_vbox := VBoxContainer.new()
	court_overlay.add_child(c_vbox)

	court_speaker_label = Label.new()
	court_speaker_label.text = "CIVILIAN AT THE PODIUM"
	court_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	court_speaker_label.add_theme_font_size_override("font_size", 18)
	court_speaker_label.modulate = Color(1.0, 0.88, 0.45)
	c_vbox.add_child(court_speaker_label)

	court_speech_label = Label.new()
	court_speech_label.text = "\"Listening to deliberations...\""
	court_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	court_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	court_speech_label.add_theme_font_size_override("font_size", 16)
	c_vbox.add_child(court_speech_label)

	court_tally_label = Label.new()
	court_tally_label.text = "RUNNING BALLOT SPLIT: [Ecology: 0  |  Technology: 0]"
	court_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	court_tally_label.add_theme_font_size_override("font_size", 17)
	court_tally_label.modulate = Color(0.50, 0.90, 1.0)
	c_vbox.add_child(court_tally_label)

	# 4. Strategic Deliberation Window Overlay
	strategic_overlay = PanelContainer.new()
	strategic_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	strategic_overlay.offset_left = -400.0
	strategic_overlay.offset_top = -140.0
	strategic_overlay.offset_right = 400.0
	strategic_overlay.offset_bottom = 140.0
	strategic_overlay.visible = false
	ui_layer.add_child(strategic_overlay)

	var s_vbox := VBoxContainer.new()
	strategic_overlay.add_child(s_vbox)

	var s_head := Label.new()
	s_head.text = "CIVILIAN COURT SPLIT DELIBERATION"
	s_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_head.add_theme_font_size_override("font_size", 20)
	s_head.modulate = Color(1.0, 0.85, 0.35)
	s_vbox.add_child(s_head)

	strategic_text_label = Label.new()
	strategic_text_label.text = "Choose your faction route for the Finale:\n\n[1] Route A: Confrontation (Buried Generator Overdrive Tug-of-War)\n[2] Route B: Peace (Common Works Crisis Holdout & Charter Ratification)\n\nPress [1] or [2] to select, then [N] or [Enter] to Confirm."
	strategic_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategic_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strategic_text_label.add_theme_font_size_override("font_size", 16)
	s_vbox.add_child(strategic_text_label)

	# 5. Finale Tug-of-War / Holdout Overlay
	finale_overlay = PanelContainer.new()
	finale_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	finale_overlay.offset_top = 100.0
	finale_overlay.offset_left = -320.0
	finale_overlay.offset_right = 320.0
	finale_overlay.offset_bottom = 160.0
	finale_overlay.visible = false
	ui_layer.add_child(finale_overlay)

	finale_meter_label = Label.new()
	finale_meter_label.text = "FINALE STATUS"
	finale_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finale_meter_label.add_theme_font_size_override("font_size", 18)
	finale_overlay.add_child(finale_meter_label)

	# 6. Full-screen Match Over Modal
	game_over_overlay = PanelContainer.new()
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_overlay.offset_left = -460.0
	game_over_overlay.offset_top = -250.0
	game_over_overlay.offset_right = 460.0
	game_over_overlay.offset_bottom = 250.0
	game_over_overlay.visible = false
	ui_layer.add_child(game_over_overlay)

	var go_vbox := VBoxContainer.new()
	game_over_overlay.add_child(go_vbox)

	game_over_title = Label.new()
	game_over_title.text = "MATCH CONCLUDED"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 24)
	go_vbox.add_child(game_over_title)

	game_over_subtitle = Label.new()
	game_over_subtitle.text = ""
	game_over_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_subtitle.add_theme_font_size_override("font_size", 16)
	go_vbox.add_child(game_over_subtitle)

	var go_sep := HSeparator.new()
	go_sep.custom_minimum_size = Vector2(0, 10)
	go_vbox.add_child(go_sep)

	game_over_stats = Label.new()
	game_over_stats.text = ""
	game_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_stats.add_theme_font_size_override("font_size", 15)
	go_vbox.add_child(game_over_stats)

	var go_sep2 := HSeparator.new()
	go_sep2.custom_minimum_size = Vector2(0, 10)
	go_vbox.add_child(go_sep2)

	game_over_roster = Label.new()
	game_over_roster.text = ""
	game_over_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_roster.add_theme_font_size_override("font_size", 13)
	go_vbox.add_child(game_over_roster)

	var play_again_lbl := Label.new()
	play_again_lbl.text = "[Press R to Play Again]"
	play_again_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_again_lbl.add_theme_font_size_override("font_size", 16)
	play_again_lbl.modulate = Color(0.55, 0.95, 0.70)
	go_vbox.add_child(play_again_lbl)

	# 7. Old-World Archive Discovery Dilemma Overlay (Blueprint Section 6 & 11)
	archive_dilemma_overlay = PanelContainer.new()
	archive_dilemma_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	archive_dilemma_overlay.offset_left = -380.0
	archive_dilemma_overlay.offset_top = -220.0
	archive_dilemma_overlay.offset_right = 380.0
	archive_dilemma_overlay.offset_bottom = 220.0
	archive_dilemma_overlay.visible = false
	ui_layer.add_child(archive_dilemma_overlay)

	var arc_style := StyleBoxFlat.new()
	arc_style.bg_color = Color(0.08, 0.11, 0.17, 0.96)
	arc_style.border_color = Color(0.95, 0.82, 0.42)
	arc_style.border_width_left = 2
	arc_style.border_width_top = 2
	arc_style.border_width_right = 2
	arc_style.border_width_bottom = 2
	arc_style.corner_radius_top_left = 6
	arc_style.corner_radius_top_right = 6
	arc_style.corner_radius_bottom_left = 6
	arc_style.corner_radius_bottom_right = 6
	archive_dilemma_overlay.add_theme_stylebox_override("panel", arc_style)

	var arc_margin := MarginContainer.new()
	arc_margin.add_theme_constant_override("margin_left", 22)
	arc_margin.add_theme_constant_override("margin_top", 18)
	arc_margin.add_theme_constant_override("margin_right", 22)
	arc_margin.add_theme_constant_override("margin_bottom", 18)
	archive_dilemma_overlay.add_child(arc_margin)

	var arc_vbox := VBoxContainer.new()
	arc_vbox.add_theme_constant_override("separation", 12)
	arc_margin.add_child(arc_vbox)

	archive_dilemma_title = Label.new()
	archive_dilemma_title.text = "★ OLD-WORLD ARCHIVE DISCOVERED ★"
	archive_dilemma_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_dilemma_title.add_theme_font_size_override("font_size", 20)
	archive_dilemma_title.modulate = Color(1.0, 0.88, 0.45)
	arc_vbox.add_child(archive_dilemma_title)

	archive_dilemma_desc = Label.new()
	archive_dilemma_desc.text = "You unsealed a secluded pre-collapse vault containing an active failsafe control key.\nChoose how to exercise this decisive discovery:"
	archive_dilemma_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	archive_dilemma_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_dilemma_desc.add_theme_font_size_override("font_size", 13)
	archive_dilemma_desc.modulate = Color(0.85, 0.90, 0.98)
	arc_vbox.add_child(archive_dilemma_desc)

	archive_dilemma_options_container = VBoxContainer.new()
	archive_dilemma_options_container.add_theme_constant_override("separation", 8)
	arc_vbox.add_child(archive_dilemma_options_container)

	archive_dilemma_timer_label = Label.new()
	archive_dilemma_timer_label.text = "⏱️ Time remaining: 25s (Auto-resolves to default if expired)"
	archive_dilemma_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_dilemma_timer_label.add_theme_font_size_override("font_size", 12)
	archive_dilemma_timer_label.modulate = Color(0.92, 0.78, 0.42)
	arc_vbox.add_child(archive_dilemma_timer_label)

func _refresh_archive_dilemma_overlay() -> void:
	if game_manager == null or player_node == null or archive_dilemma_options_container == null:
		return
	archive_dilemma_timer = 25.0

	for child in archive_dilemma_options_container.get_children():
		archive_dilemma_options_container.remove_child(child)
		child.queue_free()

	var is_op: bool = (player_node.secret_role != "civilian")
	if is_op:
		var faction_name: String = player_node.secret_role.capitalize()
		archive_dilemma_desc.text = "As a %s Operative, you hold the ancient control key.\nYou can deliver the secret to empower your faction handlers, or expose catastrophic flaws to enforce the Gray Synthesis peace." % faction_name

		var opt1_btn := Button.new()
		opt1_btn.text = "[1] ★ Stay Loyal to Faction (+12% Speed in Finale)"
		opt1_btn.tooltip_text = "Deliver the failsafe key to your faction handlers. Grants +12% objective channeling speed in Finale."
		opt1_btn.custom_minimum_size = Vector2(0, 44)
		opt1_btn.pressed.connect(func(): _choose_archive_dilemma(C.ARCHIVE_CHOICE_LOYAL))
		archive_dilemma_options_container.add_child(opt1_btn)

		var opt2_btn := Button.new()
		opt2_btn.text = "[2] 🕊️ Whistleblower (Personal Goal: Gray Synthesis Reconciliation)"
		opt2_btn.tooltip_text = "Expose catastrophic design flaws in your faction's extreme plan. Changes your personal victory condition to Gray Synthesis Reconciliation without switching your team."
		opt2_btn.custom_minimum_size = Vector2(0, 44)
		opt2_btn.pressed.connect(func(): _choose_archive_dilemma(C.ARCHIVE_CHOICE_WHISTLEBLOWER))
		archive_dilemma_options_container.add_child(opt2_btn)
	else:
		archive_dilemma_desc.text = "As an Unaffiliated Civilian, you discovered the town's most powerful secret.\nYou can entrust the key to a faction you support, or reserve it for the Common Works to aid town reconciliation."

		var opt1_btn := Button.new()
		opt1_btn.text = "[1] 🌿 Entrust to Ecology Operatives (+12% Advantage if Voted at Court)"
		opt1_btn.tooltip_text = "Entrust the failsafe key to Ecology. Grants +12% advantage if you vote for Ecology at Court."
		opt1_btn.custom_minimum_size = Vector2(0, 38)
		opt1_btn.pressed.connect(func(): _choose_archive_dilemma(C.ARCHIVE_CHOICE_ENTRUST_ECO))
		archive_dilemma_options_container.add_child(opt1_btn)

		var opt2_btn := Button.new()
		opt2_btn.text = "[2] ⚡ Entrust to Technology Operatives (+12% Advantage if Voted at Court)"
		opt2_btn.tooltip_text = "Entrust the failsafe key to Technology. Grants +12% advantage if you vote for Technology at Court."
		opt2_btn.custom_minimum_size = Vector2(0, 38)
		opt2_btn.pressed.connect(func(): _choose_archive_dilemma(C.ARCHIVE_CHOICE_ENTRUST_TECH))
		archive_dilemma_options_container.add_child(opt2_btn)

		var opt3_btn := Button.new()
		opt3_btn.text = "[3] 🏛️ Reserve for Common Works (+15% to All 3 Tracks, Personal Peace Medal)"
		opt3_btn.tooltip_text = "Channel the ancient power directly into the Common Works: +15% to all 3 tracks, and grants you a Civic Peace Medal if Gray Synthesis is achieved."
		opt3_btn.custom_minimum_size = Vector2(0, 38)
		opt3_btn.pressed.connect(func(): _choose_archive_dilemma(C.ARCHIVE_CHOICE_RESERVE_CW))
		archive_dilemma_options_container.add_child(opt3_btn)

func _choose_archive_dilemma(choice: String) -> void:
	if game_manager == null:
		return
	if audio_manager != null:
		audio_manager.play_sfx("task_complete", 1.0, 0.4)
	game_manager.resolve_player_archive_choice(choice)
	if archive_dilemma_overlay != null:
		archive_dilemma_overlay.visible = false
	_update_hud()

func _choose_archive_dilemma_default() -> void:
	if game_manager == null or not game_manager.archive_dilemma_open:
		return
	if audio_manager != null:
		audio_manager.play_sfx("task_complete", 0.9, 0.2)
	game_manager.resolve_default_archive_choice()
	if archive_dilemma_overlay != null:
		archive_dilemma_overlay.visible = false
	_update_hud()

func _update_archive_dilemma(delta: float) -> void:
	if game_manager == null or not game_manager.archive_dilemma_open:
		return
	archive_dilemma_timer = maxf(0.0, archive_dilemma_timer - delta)
	if archive_dilemma_timer_label != null:
		var is_op: bool = (player_node != null and player_node.secret_role != "civilian")
		var def_name: String = "Faction Loyalty" if is_op else "Reserve Common Works"
		archive_dilemma_timer_label.text = "⏱️ Time remaining: %ds (Defaults to %s if time expires)" % [ceili(archive_dilemma_timer), def_name]
	if archive_dilemma_timer <= 0.0:
		_choose_archive_dilemma_default()

func _cast_first_council_motion(motion_id: int) -> void:
	if game_manager == null or game_manager.current_phase != game_manager.Phase.FIRST_COUNCIL:
		return
	if audio_manager != null:
		audio_manager.play_sfx("task_tick", 1.1, -4.0)
	game_manager.cast_player_motion_vote(motion_id)
	_refresh_council_motion_ballot()
	_update_hud()

func _refresh_council_motion_ballot() -> void:
	if game_manager == null or council_motion_btn_1 == null or council_motion_btn_2 == null or council_motion_btn_3 == null:
		return

	var counts: Array[int] = game_manager.get_council_motion_counts() if game_manager.has_method("get_council_motion_counts") else [0, 0, 0]
	var player_vote: int = game_manager.player_motion_vote

	var btn_configs: Array[Dictionary] = [
		{
			"btn": council_motion_btn_1,
			"id": 1,
			"title": "Station Watch Beacons",
			"sub": "Pump & Greenhouse Sensors",
			"count": counts[0]
		},
		{
			"btn": council_motion_btn_2,
			"id": 2,
			"title": "Emergency Scrap Subsidy",
			"sub": "+3 Scrap to Common Reserves",
			"count": counts[1]
		},
		{
			"btn": council_motion_btn_3,
			"id": 3,
			"title": "Crop Blight Remediation",
			"sub": "-25% Stability Crisis Decay",
			"count": counts[2]
		}
	]

	for cfg in btn_configs:
		var btn: Button = cfg["btn"]
		var id: int = cfg["id"]
		var is_voted: bool = (player_vote == id)
		var prefix: String = "★ " if is_voted else ""
		var suffix: String = " [YOUR VOTE] ★" if is_voted else ""
		btn.text = "%s[%d] %s (%d votes)%s\n%s" % [prefix, id, cfg["title"], cfg["count"], suffix, cfg["sub"]]
		if is_voted:
			btn.modulate = Color(1.0, 0.92, 0.45)
		else:
			btn.modulate = Color(0.85, 0.88, 0.95)

	if council_tally_label != null:
		var leading_id: int = 1
		var max_v: int = counts[0]
		for i in range(1, 3):
			if counts[i] > max_v:
				max_v = counts[i]
				leading_id = i + 1
		council_tally_label.text = "Council Ballot Tally: Beacons (%d) | Scrap (%d) | Remediation (%d)  ➔  Motion %d Leading" % [
			counts[0], counts[1], counts[2], leading_id
		]

# ------------------------------------------------------------------------------
# Phase Lifecycle Coordination
# ------------------------------------------------------------------------------
func _on_phase_changed(new_phase: int) -> void:
	if game_manager == null:
		return

	if council_overlay != null:
		council_overlay.visible = false
	if hero_draft_lobby != null:
		hero_draft_lobby.close_lobby()
	court_overlay.visible = false
	strategic_overlay.visible = false
	finale_overlay.visible = false
	game_over_overlay.visible = false

	# Apply dynamic atmospheric lighting progression matching narrative phase
	if town_map != null and town_map.has_method("apply_phase_lighting"):
		town_map.apply_phase_lighting(new_phase)

	# Preserve pending Archive Dilemma across normal phase transitions (e.g. Open Town -> First Council).
	# The player keeps their critical choice across the transition.
	# Only force default resolution if the match concludes (MATCH_OVER).
	if new_phase == game_manager.Phase.MATCH_OVER:
		if game_manager != null and game_manager.archive_dilemma_open:
			game_manager.resolve_default_archive_choice()
		if archive_dilemma_overlay != null:
			archive_dilemma_overlay.visible = false

	match new_phase:
		game_manager.Phase.BRIEFING:
			camera_mode = "wide_council"
			for i in range(residents.size()):
				residents[i].gather_at_council_ring(spawn_positions[i])
			if hero_draft_lobby != null:
				hero_draft_lobby.is_locked_in = false
				hero_draft_lobby.open_lobby()
			_show_phase_banner("PHASE 1: TOWN BRIEFING", "Select your Hero identity & review your secret role before morning deployment", Color(1.0, 0.88, 0.45))

		game_manager.Phase.OPEN_TOWN:
			camera_mode = "follow_player"
			refresh_bot_memories()
			town_map.release_reservations_for(player_node)
			_show_phase_banner("PHASE 2: OPEN TOWN", "Tend civic stations, monitor sectors, and observe suspicious movements", Color(0.55, 0.95, 0.70))

		game_manager.Phase.FIRST_COUNCIL:
			camera_mode = "wide_council"
			for i in range(residents.size()):
				residents[i].gather_at_council_ring(spawn_positions[i])
			town_map.reset_pads()
			game_manager.prepare_first_council(residents, town_map)
			council_speaker_idx = 0
			council_speaker_timer = 0.5
			if council_overlay != null:
				council_overlay.visible = true
			_refresh_council_motion_ballot()
			_show_phase_banner("FIRST COUNCIL IN SESSION", "Residents assemble at the council ring to debate observations", Color(1.0, 0.85, 0.35))

		game_manager.Phase.ESCALATION:
			camera_mode = "follow_player"
			town_map.update_escalation_unlocks()
			add_camera_trauma(0.35)
			if audio_manager != null:
				audio_manager.play_phase_stinger("escalation")
			_show_phase_banner("PHASE 4: TOWN ESCALATION", "Buried Generator & Signal Beacon unlocked! Covert faction struggles commence", Color(1.0, 0.55, 0.35))

		game_manager.Phase.COURT:
			camera_mode = "court_podium"
			for i in range(residents.size()):
				residents[i].gather_at_council_ring(spawn_positions[i])
			town_map.reset_pads()
			court_overlay.visible = true
			if audio_manager != null:
				audio_manager.play_phase_stinger("court")
			_show_phase_banner("CIVILIAN COURT IN SESSION", "4 Unaffiliated Civilians take the podium to cast decisive alignment ballots", Color(0.50, 0.90, 1.0))

		game_manager.Phase.FINALE:
			camera_mode = "follow_player"
			finale_overlay.visible = true
			add_camera_trauma(0.45)
			if audio_manager != null:
				audio_manager.play_phase_stinger("finale")
			_show_phase_banner("PHASE 6: FINALE COMMENCED", "The town's destiny hangs in the balance — secure the decisive outcome!", Color(1.0, 0.40, 0.40))

		game_manager.Phase.MATCH_OVER:
			camera_mode = "podium_celebration"
			game_over_overlay.visible = true
			add_camera_trauma(0.20)
			_setup_game_over_display()
			_show_phase_banner("MATCH CONCLUDED", "All citizen dossiers revealed. Review final town history", Color(1.0, 0.85, 0.35))
			if audio_manager != null:
				var is_player_win := false
				if player_node != null and game_manager.has_method("get_resident_alignment"):
					var p_align: String = game_manager.get_resident_alignment(player_node).to_lower()
					var end_title: String = String(game_manager.get("match_ending_title")).to_lower()
					if end_title.find("gray synthesis") != -1:
						is_player_win = true
					elif p_align == "ecology" and end_title.find("ecology") != -1:
						is_player_win = true
					elif p_align == "technology" and end_title.find("technology") != -1:
						is_player_win = true
					elif p_align == "civilian" and (end_title.find("peace") != -1 or end_title.find("charter") != -1 or end_title.find("gray synthesis") != -1):
						is_player_win = true
				if is_player_win:
					audio_manager.play_phase_stinger("victory")
				else:
					audio_manager.play_phase_stinger("defeat")

	_update_hud()

func _show_phase_banner(title: String, subtitle: String, color: Color) -> void:
	if phase_banner == null:
		return
	phase_banner_title.text = title
	phase_banner_title.modulate = color
	phase_banner_subtitle.text = subtitle
	phase_banner_timer = 3.5
	phase_banner.modulate.a = 1.0
	phase_banner.visible = true

func _update_phase_banner(delta: float) -> void:
	if phase_banner == null or not phase_banner.visible:
		return
	if phase_banner_timer > 0.0:
		phase_banner_timer = maxf(0.0, phase_banner_timer - delta)
		if phase_banner_timer > 3.0:
			phase_banner.modulate.a = (3.5 - phase_banner_timer) / 0.5
		elif phase_banner_timer < 0.6:
			phase_banner.modulate.a = phase_banner_timer / 0.6
		else:
			phase_banner.modulate.a = 1.0
		if phase_banner_timer <= 0.0:
			phase_banner.visible = false

func _update_first_council_assembly(delta: float) -> void:
	if game_manager == null or game_manager.current_phase != game_manager.Phase.FIRST_COUNCIL:
		if council_overlay != null:
			council_overlay.visible = false
		return

	if council_overlay != null:
		council_overlay.visible = true

	council_speaker_timer -= delta
	if council_speaker_timer <= 0.0:
		council_speaker_timer = 3.2
		if residents.size() > 0:
			var res: CharacterBody3D = residents[council_speaker_idx]
			if res != null:
				var stmt_info: Dictionary = game_manager.alibi_statements.get(res.resident_id, {})
				var stmt_txt: String = stmt_info.get("text", "Between 04:00 and 03:00, I was in Town Square.")
				if council_speaker_label != null:
					council_speaker_label.text = "SPEAKER: %s (%s)" % [res.resident_name, res.civic_job]
				if council_statement_label != null:
					council_statement_label.text = "\"%s\"" % stmt_txt
				if res.has_method("show_speech_bubble"):
					res.show_speech_bubble(stmt_txt, 3.0)
				if audio_manager != null and is_inside_tree():
					audio_manager.play_sfx("channel_tick", 1.1, -8.0)
			council_speaker_idx = (council_speaker_idx + 1) % residents.size()

func _on_state_updated() -> void:
	if game_manager != null:
		if not _prev_archive_opened and game_manager.archive_opened:
			_prev_archive_opened = true
			add_camera_trauma(0.35)
		if game_manager.current_phase == game_manager.Phase.FINALE:
			var cur_tug_diff: float = absf(game_manager.generator_tech_primed - game_manager.generator_eco_stabilized)
			if absf(cur_tug_diff - _prev_tug_diff) >= 5.0:
				_prev_tug_diff = cur_tug_diff
				add_camera_trauma(0.22)
	_update_hud()

func add_camera_trauma(amount: float) -> void:
	camera_trauma = clampf(camera_trauma + amount, 0.0, 1.0)

func _on_resident_trauma_impact(amount: float, source_pos: Vector3) -> void:
	if player_node != null:
		var p_pos: Vector3 = player_node.global_position if player_node.is_inside_tree() else player_node.position
		var dist: float = p_pos.distance_to(source_pos)
		if dist < 4.0:
			add_camera_trauma(amount)
		elif dist < 26.0:
			var falloff: float = 1.0 - (dist / 26.0)
			add_camera_trauma(amount * falloff * 0.75)
	else:
		add_camera_trauma(amount * 0.5)

func _process(delta: float) -> void:
	_update_camera_director(delta)
	_update_phase_banner(delta)
	_update_first_council_assembly(delta)
	_update_open_town_sightings(delta)
	_update_court_ceremony(delta)
	_update_ambient_audio(delta)
	_update_archive_dilemma(delta)
	_update_hud()

var sighting_sample_timer: float = 0.0

func _update_open_town_sightings(delta: float) -> void:
	if game_manager == null or town_map == null:
		return
	if game_manager.current_phase != game_manager.Phase.OPEN_TOWN:
		return

	sighting_sample_timer += delta
	if sighting_sample_timer < 2.5:
		return
	sighting_sample_timer = 0.0

	var time_left: float = game_manager.time_remaining
	# 1. Sample regions for all residents
	for res in residents:
		if res == null:
			continue
		var r_pos: Vector3 = res.global_position if res.is_inside_tree() else res.position
		var sec_name: String = town_map.get_region_name_at_3d(r_pos)
		game_manager.record_resident_region_sample(int(res.resident_id), sec_name)

	# 2. If in 04:00 - 03:00 interval, generate natural mutual sightings between residents with LOS
	if time_left <= 240.0 and time_left >= 180.0:
		for i in range(residents.size()):
			var subject = residents[i]
			if subject == null or subject.is_incapacitated:
				continue
			var s_pos: Vector3 = subject.global_position if subject.is_inside_tree() else subject.position

			for j in range(residents.size()):
				if i == j:
					continue
				var observer = residents[j]
				if observer == null or observer.is_incapacitated:
					continue
				var o_pos: Vector3 = observer.global_position if observer.is_inside_tree() else observer.position
				if o_pos.distance_to(s_pos) > C.WITNESS_RADIUS:
					continue
				if town_map.has_method("has_clear_sightline_3d"):
					if town_map.has_clear_sightline_3d(o_pos, s_pos):
						var act_label := "was seen performing civic tasks"
						if subject.bot_controller != null and subject.bot_controller.covert_mission_type != "NONE":
							act_label = "was seen moving through perimeter bounds"
						game_manager.record_observed_sighting_3d(subject, s_pos, town_map, [observer], act_label)

func _update_ambient_audio(delta: float) -> void:
	if audio_manager == null or town_map == null:
		return
	var track_pos: Vector3 = player_node.global_position if (player_node != null and player_node.is_inside_tree()) else (camera.global_position if camera != null else Vector3.ZERO)
	var sec_id: String = town_map.get_region_id_at_3d(track_pos)
	audio_manager.set_ambient_sector(sec_id)
	audio_manager.update_ambient_crossfade(delta)

func _update_camera_director(delta: float) -> void:
	if camera == null:
		return

	# 1. Update trauma decay and compute shake offsets
	if camera_trauma > 0.0:
		camera_trauma = maxf(0.0, camera_trauma - trauma_decay * delta)
		var shake := camera_trauma * camera_trauma # quadratic falloff
		current_shake_offset = Vector3(
			(randf() * 2.0 - 1.0) * max_shake_offset.x,
			(randf() * 2.0 - 1.0) * max_shake_offset.y,
			(randf() * 2.0 - 1.0) * max_shake_offset.z
		) * shake
		current_shake_rotation = Vector3(
			(randf() * 2.0 - 1.0) * max_shake_rotation.x,
			(randf() * 2.0 - 1.0) * max_shake_rotation.y,
			(randf() * 2.0 - 1.0) * max_shake_rotation.z
		) * shake
	else:
		current_shake_offset = Vector3.ZERO
		current_shake_rotation = Vector3.ZERO

	# 2. Smooth zoom interpolation
	smooth_camera_zoom = lerpf(smooth_camera_zoom, camera_zoom, clampf(delta * 8.0, 0.0, 1.0))

	# 3. Sprint pull-back calculation
	var is_player_sprinting := false
	if player_node != null and (player_node.is_sprinting or player_node.velocity.length() > 6.5):
		is_player_sprinting = true
	var desired_sprint_zoom: float = 1.10 if is_player_sprinting else 1.0
	sprint_zoom_mult = lerpf(sprint_zoom_mult, desired_sprint_zoom, clampf(delta * 4.0, 0.0, 1.0))

	# 4. Velocity look-ahead lead in movement direction
	if camera_mode == "follow_player" and player_node != null:
		var p_vel: Vector3 = player_node.velocity
		var p_speed: float = p_vel.length()
		if p_speed > 0.5:
			var lead_dist: float = clampf(p_speed * 0.35, 0.0, 3.2)
			target_look_ahead_lead = p_vel.normalized() * lead_dist
		else:
			target_look_ahead_lead = Vector3.ZERO
	else:
		target_look_ahead_lead = Vector3.ZERO

	look_ahead_lead = look_ahead_lead.lerp(target_look_ahead_lead, clampf(delta * 3.5, 0.0, 1.0))

	# 5. Base target position, look target, and desired FOV
	var target_pos: Vector3 = Vector3.ZERO
	var target_look: Vector3 = Vector3.ZERO
	var desired_fov: float = 70.0

	match camera_mode:
		"wide_council":
			target_pos = Vector3(0.0, 16.0, 10.0)
			target_look = Vector3(0.0, 0.5, 0.0)
			desired_fov = 76.0
		"court_podium":
			target_pos = Vector3(0.0, 3.2, 5.6)
			target_look = Vector3(0.0, 1.2, 0.8)
			desired_fov = 56.0
		"podium_celebration":
			target_pos = Vector3(0.0, 7.5, 12.0)
			target_look = Vector3(0.0, 1.0, 0.0)
			desired_fov = 68.0
		_: # "follow_player"
			if player_node != null:
				var p_pos: Vector3 = player_node.global_position if player_node.is_inside_tree() else player_node.position
				var effective_zoom: float = smooth_camera_zoom * sprint_zoom_mult
				target_pos = p_pos + Vector3(0.0, 17.5 * effective_zoom, 9.5 * effective_zoom) + look_ahead_lead
				target_look = p_pos + Vector3(0.0, 0.5, 0.0) + look_ahead_lead
			var sprint_fov_boost: float = 2.5 if is_player_sprinting else 0.0
			desired_fov = 70.0 + sprint_fov_boost

	# 6. Smooth dynamic FOV interpolation
	target_camera_fov = desired_fov
	camera.fov = lerpf(camera.fov, target_camera_fov, clampf(delta * 4.5, 0.0, 1.0))

	# 7. Smooth camera position tracking & shake offset
	var cur_pos: Vector3 = camera.global_position if camera.is_inside_tree() else camera.position
	var weight: float = clampf(delta * 5.5, 0.0, 1.0)
	var new_pos: Vector3 = cur_pos.lerp(target_pos, weight)

	if camera.is_inside_tree():
		camera.global_position = new_pos + current_shake_offset
		if camera_mode == "follow_player":
			# In isometric follow mode, lock yaw and roll strictly to 0 to prevent rotation wobble
			var target_rot_x: float = deg_to_rad(-61.5)
			camera.rotation.x = lerp_angle(camera.rotation.x, target_rot_x, clampf(delta * 8.0, 0.0, 1.0))
			camera.rotation.y = lerp_angle(camera.rotation.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
			camera.rotation.z = 0.0
			camera.rotation += current_shake_rotation
		else:
			if target_look.distance_to(new_pos) > 0.1:
				camera.look_at(target_look, Vector3.UP)
				camera.rotation += current_shake_rotation
	else:
		camera.position = new_pos + current_shake_offset

func _update_court_ceremony(_delta: float) -> void:
	if game_manager == null or not game_manager.court_ceremony_active:
		return

	var active_voter: Node = game_manager.get_active_court_voter()
	if active_voter == null and active_podium_speaker != null:
		active_voter = active_podium_speaker

	if active_voter != active_podium_speaker:
		if active_podium_speaker != null and active_podium_speaker is CharacterBody3D:
			var prev_seat: Vector3 = active_podium_speaker.spawn_position
			active_podium_speaker.return_to_seat(prev_seat)

		active_podium_speaker = active_voter
		if active_voter != null and active_voter is CharacterBody3D:
			active_voter.walk_to_podium(Vector3(0.0, 0.25, 0.8))
			if audio_manager != null:
				audio_manager.play_sfx("phase_court", 1.25, -2.0)

	if active_voter != null:
		court_speaker_label.text = "AT THE PODIUM: %s (%s)" % [active_voter.resident_name, active_voter.civic_job]
		if active_voter.is_player:
			court_speech_label.text = "YOU ARE AT THE PODIUM!\nPress [1] to vote ECOLOGY  |  Press [2] to vote TECHNOLOGY"
		else:
			var speech_txt: String = game_manager.court_active_speaker_reason
			# Check if the active speaker has an alibi contradiction on record
			var speaker_has_conflict := false
			for cf in game_manager.alibi_conflicts:
				if cf.get("resident", "") == active_voter.resident_name:
					speaker_has_conflict = true
					break
			if speaker_has_conflict:
				speech_txt = "That sighting was an error! I never left my assigned post—someone is fabricating evidence against me!"
			elif speech_txt == "":
				speech_txt = "Considering town needs..."
			court_speech_label.text = "\"%s\"" % speech_txt
			if active_voter.has_method("show_speech_bubble"):
				active_voter.show_speech_bubble(speech_txt, 3.5)

	court_tally_label.text = "RUNNING BALLOT SPLIT: %s  |  CIVILIAN VOTE %d OF 4" % [
		game_manager.court_split_summary,
		mini(4, game_manager.court_voter_index + 1)
	]

func _setup_game_over_display() -> void:
	if game_manager == null:
		return
	game_over_title.text = game_manager.match_ending_title
	game_over_title.modulate = game_manager.match_ending_color
	game_over_subtitle.text = game_manager.match_ending_subtitle

	var finder_str: String = game_manager.archive_finder_name if game_manager.archive_opened else "Unopened"
	var route_str: String = "4-0 Mandate" if game_manager.court_is_unanimous else game_manager.finale_route.capitalize()
	game_over_stats.text = "Finale Route: %s  |  Archive: %s\nTasks Completed: %d  |  Disturbances: %d  |  Shoves: %d" % [
		route_str, finder_str,
		game_manager.total_tasks_completed,
		game_manager.witnessed_disturbances,
		game_manager.shoves_used
	]

	if game_over_roster != null:
		var roster_lines: Array[String] = ["--- CITIZEN ROSTER & TRUE ALIGNMENTS ---"]
		for res in residents:
			if res == null:
				continue
			var role_tag := "Unaffiliated Civilian"
			if res.secret_role == "ecology_operative" or res.secret_role == "ecology":
				role_tag = "Ecology Operative [%s]" % res.operative_kit.capitalize()
			elif res.secret_role == "technology_operative" or res.secret_role == "technology":
				role_tag = "Technology Operative [%s]" % res.operative_kit.capitalize()
			var you_tag := " [YOU]" if res.is_player else ""
			var slot_tag := "Resident %d" % res.resident_id
			var disp_name: String = ("%s (%s)" % [res.resident_name, slot_tag]) if res.resident_name != slot_tag else slot_tag
			roster_lines.append("%s%s — %s [F: %s | Passive: %s]: %s" % [
				disp_name, you_tag, res.civic_job, res.get("hero_active_name"), res.get("hero_passive_name"), role_tag
			])
		game_over_roster.text = "\n".join(roster_lines)

# ------------------------------------------------------------------------------
# Input Handling Across All Phases
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = maxf(0.55, camera_zoom - 0.08)
			target_camera_zoom = camera_zoom
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = minf(1.35, camera_zoom + 0.08)
			target_camera_zoom = camera_zoom
			return

	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	if game_manager == null:
		return

	# Milestone 8 Playtest & Tuning Panel toggle [F1] / [~] / Dismiss [ESC]
	if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
		if playtest_tuning_panel != null:
			playtest_tuning_panel.toggle_panel()
		return
	elif event.keycode == KEY_ESCAPE and playtest_tuning_panel != null and playtest_tuning_panel.visible:
		playtest_tuning_panel.close_panel()
		return

	# Evidence Journal toggle [J] / Dismiss [ESC]
	if event.keycode == KEY_J:
		if evidence_journal != null:
			evidence_journal.toggle_journal()
		return
	elif event.keycode == KEY_ESCAPE and evidence_journal != null and evidence_journal.visible:
		evidence_journal.close_journal()
		return

	# Help overlay toggle [H] / Dismiss [ESC]
	if event.keycode == KEY_H:
		if help_overlay != null:
			help_overlay.visible = not help_overlay.visible
		return
	elif event.keycode == KEY_ESCAPE and help_overlay != null and help_overlay.visible:
		help_overlay.visible = false
		return

	# Hero Draft / Roster Overlay toggle or Random Hero [Tab]
	if event.keycode == KEY_TAB:
		if hero_draft_lobby != null:
			if game_manager.current_phase == game_manager.Phase.BRIEFING and hero_draft_lobby.visible:
				hero_draft_lobby.select_random_hero(true)
			else:
				hero_draft_lobby.toggle_lobby()
		return

	# Player Settings & Audio Mixer toggle / dismiss [ESC]
	if event.keycode == KEY_ESCAPE:
		if settings_menu != null and settings_menu.visible:
			settings_menu.close_menu()
			return
		elif settings_menu != null and not settings_menu.visible:
			settings_menu.open_menu()
			return

	# Camera zoom toggle key [Z]
	if event.keycode == KEY_Z:
		camera_zoom = 0.65 if camera_zoom > 0.8 else 1.0
		target_camera_zoom = camera_zoom
		return

	# Archive Discovery Dilemma Choice [1], [2], [3] (Blueprint Section 6 & 11)
	if game_manager.archive_dilemma_open:
		var is_op: bool = (player_node != null and player_node.secret_role != "civilian")
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			_choose_archive_dilemma(C.ARCHIVE_CHOICE_LOYAL if is_op else C.ARCHIVE_CHOICE_ENTRUST_ECO)
			return
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			_choose_archive_dilemma(C.ARCHIVE_CHOICE_WHISTLEBLOWER if is_op else C.ARCHIVE_CHOICE_ENTRUST_TECH)
			return
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			if not is_op:
				_choose_archive_dilemma(C.ARCHIVE_CHOICE_RESERVE_CW)
				return
		return

	# 1. Briefing Phase: [1]-[9],[0] selects Hero in Matchmaking Lobby; Space, Enter, or WASD locks in and skips to Open Town
	if game_manager.current_phase == game_manager.Phase.BRIEFING:
		if hero_draft_lobby != null:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				hero_draft_lobby.select_hero_by_index(int(event.keycode - KEY_1), true)
				return
			elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
				hero_draft_lobby.select_hero_by_index(int(event.keycode - KEY_KP_1), true)
				return
			elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
				hero_draft_lobby.select_hero_by_index(9, true)
				return
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_W or event.keycode == KEY_A or event.keycode == KEY_S or event.keycode == KEY_D:
			if hero_draft_lobby != null and hero_draft_lobby.visible:
				hero_draft_lobby.confirm_and_start_match()
			else:
				game_manager.advance_to_next_phase()
			return

	# 2. First Council Phase: [1], [2], [3] cast civic motion ballot, Space/Enter advances to Escalation
	if game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			_cast_first_council_motion(1)
			return
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			_cast_first_council_motion(2)
			return
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			_cast_first_council_motion(3)
			return
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			game_manager.advance_to_next_phase()
			return

	# 3. Civilian Court Phase: 1 for Ecology, 2 for Technology, Space for Fast-Forward
	if game_manager.current_phase == game_manager.Phase.COURT:
		var active_voter: Node = game_manager.get_active_court_voter()
		if active_voter != null and active_voter.is_player:
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				if audio_manager != null:
					audio_manager.play_sfx("court_vote", 1.0, 0.5)
				game_manager.cast_player_court_ballot("Ecology")
				return
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				if audio_manager != null:
					audio_manager.play_sfx("court_vote", 1.0, 0.5)
				game_manager.cast_player_court_ballot("Technology")
				return
		elif event.keycode == KEY_SPACE:
			game_manager.court_fast_forward = true
			return

	# 4. Strategic Deliberation Window: 1 for Confrontation, 2 for Peace, N/Enter to Confirm
	if game_manager.strategic_decision_active:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_CONFRONTATION)
			_update_hud()
			return
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_PEACE)
			_update_hud()
			return
		elif event.keycode == KEY_N or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			game_manager.resolve_strategic_decision()
			return

	# 5. Match Over: R to Play Again
	if game_manager.current_phase == game_manager.Phase.MATCH_OVER:
		if event.keycode == KEY_R:
			start_new_match()
			return

	# 6. Active Gameplay Controls (Open Town, Escalation, Finale)
	if player_node != null and game_manager.is_active_play_phase():
		match event.keycode:
			KEY_E:
				player_node.try_start_channel()
			KEY_V:
				player_node.try_inspect_site()
			KEY_R:
				player_node.try_civic_shove()
			KEY_F:
				player_node.try_civic_ability()
			KEY_C:
				player_node.try_faction_ability()

# ------------------------------------------------------------------------------
# HUD Updates
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	if game_manager == null:
		return

	var mins := int(game_manager.time_remaining) / 60
	var secs := int(game_manager.time_remaining) % 60
	var phase_str: String = game_manager.get_phase_name()
	clock_label.text = "CLOCK: %02d:%02d [%s]" % [mins, secs, phase_str]

	# Clock urgency pulse when time is running low (< 30s)
	var time_left: float = game_manager.time_remaining
	if time_left <= 30.0 and time_left > 0.0 and game_manager.current_phase != game_manager.Phase.BRIEFING and game_manager.current_phase != game_manager.Phase.MATCH_OVER:
		var pulse: float = (sin(float(Time.get_ticks_msec()) * 0.008) + 1.0) * 0.5
		clock_label.modulate = Color(1.0, 0.25 + 0.5 * pulse, 0.25 + 0.5 * pulse)
	else:
		clock_label.modulate = Color.WHITE

	resource_label.text = "WATER: %d%%  |  STABILITY: %d%%  |  SCRAP: %d" % [
		int(game_manager.water), int(game_manager.stability), int(game_manager.scrap)
	]
	if game_manager.water < 25.0 or game_manager.stability < 25.0:
		resource_label.modulate = Color(1.0, 0.45, 0.45)
	else:
		resource_label.modulate = Color.WHITE

	if player_node != null:
		var p_pos: Vector3 = player_node.global_position if player_node.is_inside_tree() else player_node.position
		var reg: String = town_map.get_region_name_at_3d(p_pos) if town_map != null else "Town Square"
		var kit_tag: String = player_node.operative_kit.to_upper() if player_node.operative_kit != "none" else "CIVILIAN"
		role_label.text = "YOU: %s (%s | [F] %s | Passive: %s) [%s - %s] - %s" % [
			player_node.resident_name, player_node.civic_job,
			String(player_node.get("hero_active_name")), String(player_node.get("hero_passive_name")),
			player_node.secret_role.to_upper(), kit_tag, reg
		]

	# Update Channeling HUD Progress Bar
	if channel_bar_container != null:
		if player_node != null and player_node.is_channeling:
			channel_bar_container.visible = true
			var pad_name: String = String(player_node.active_pad.get("base_title", player_node.active_pad.get("name", "Task"))).split("\n")[0]
			var dur: float = float(player_node.active_pad.get("channel_duration", 3.0))
			var pct: int = clampi(int((player_node.channel_progress / maxf(0.1, dur)) * 100.0), 0, 100)
			channel_action_label.text = "Channeling %s (%d%%)" % [pad_name, pct]
			channel_action_label.modulate = Color(0.45, 0.88, 1.0)
			channel_progress_bar.value = pct
		elif player_node != null and player_node.is_inspecting:
			channel_bar_container.visible = true
			var pct: int = clampi(int((player_node.inspection_timer / 2.5) * 100.0), 0, 100)
			channel_action_label.text = "Inspecting Bedrock Alcove (%d%%)" % pct
			channel_action_label.modulate = Color(0.55, 0.95, 0.70)
			channel_progress_bar.value = pct
		else:
			channel_bar_container.visible = false

	# Update Strategic Decision Overlay
	if strategic_overlay != null:
		if game_manager.strategic_decision_active:
			strategic_overlay.visible = true
			var cur_choice := "None (Default: Confrontation)"
			if game_manager.player_strategic_choice == C.STRATEGIC_CHOICE_CONFRONTATION:
				cur_choice = "Confrontation (Buried Generator)"
			elif game_manager.player_strategic_choice == C.STRATEGIC_CHOICE_PEACE:
				cur_choice = "Peace (Common Works Holdout)"
			strategic_text_label.text = "CIVILIAN COURT SPLIT: %s\nYour Current Choice: %s\n\n[1] Route A: Confrontation (Generator Tug-of-War)\n[2] Route B: Peace (Common Works Crisis Holdout)\n\nPress [1] or [2] to choose, then [N] or [Enter] to Confirm." % [
				game_manager.court_split_summary, cur_choice
			]
		else:
			strategic_overlay.visible = false

	# Update Finale Overlay
	if finale_overlay != null:
		if game_manager.current_phase == game_manager.Phase.FINALE:
			finale_overlay.visible = true
			if game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION:
				var tech_pct := int(game_manager.generator_tug_meter)
				var eco_pct := 100 - tech_pct
				finale_meter_label.text = "FINALE: GENERATOR TUG-OF-WAR\n[ECOLOGY: %d%%]  <=====>  [TECHNOLOGY: %d%%]" % [eco_pct, tech_pct]
				finale_meter_label.modulate = Color(1.0, 0.65, 0.35)
			else:
				finale_meter_label.text = "FINALE: COMMON WORKS CHARTER HOLDOUT\nCrisis Defense: %.0fs  |  Common Works: %.0f%%" % [
					game_manager.time_remaining, game_manager.common_works
				]
				finale_meter_label.modulate = Color(0.55, 0.95, 0.70)
		else:
			finale_overlay.visible = false

	# Update Archive Discovery Dilemma Overlay (Blueprint Section 6 & 11)
	if archive_dilemma_overlay != null:
		if game_manager.archive_dilemma_open:
			if not archive_dilemma_overlay.visible:
				_refresh_archive_dilemma_overlay()
				archive_dilemma_overlay.visible = true
		else:
			if archive_dilemma_overlay.visible:
				archive_dilemma_overlay.visible = false

	# Update Bottom Status Banner
	if game_manager.archive_dilemma_open:
		var is_op: bool = (player_node != null and player_node.secret_role != "civilian")
		status_label.text = "[ARCHIVE DILEMMA] %s | Press [1], [2]%s to resolve choice" % [
			"Operative Dilemma: [1] Loyal  [2] Whistleblower" if is_op else "Civilian Dilemma: [1] Eco  [2] Tech  [3] Common Works",
			"" if is_op else " or [3]"
		]
	elif game_manager.current_phase == game_manager.Phase.BRIEFING:
		status_label.text = "[TOWN BRIEFING] Press [Space] or [Enter] to begin Open Town | Review your secret dossier | [H] Help"
	elif game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL:
		_refresh_council_motion_ballot()
		var m_name: String = "Motion 1 (Beacons)"
		if game_manager.player_motion_vote == 2:
			m_name = "Motion 2 (Scrap Subsidy)"
		elif game_manager.player_motion_vote == 3:
			m_name = "Motion 3 (Crop Remediation)"
		status_label.text = "[FIRST COUNCIL] Your Ballot: %s | Press [1], [2], [3] to vote on Civic Motion | [J] Table Clues | [Space] Advance to Escalation" % m_name
	elif game_manager.current_phase == game_manager.Phase.COURT:
		var active_civ: Node = game_manager.get_active_court_voter()
		if active_civ != null and active_civ.is_player:
			status_label.text = "[CIVILIAN COURT] IT IS YOUR TURN TO VOTE! Press [1] for Ecology  |  Press [2] for Technology"
		else:
			status_label.text = "[CIVILIAN COURT] %s speaking at podium | Press [Space] to Fast Forward | [H] Help" % (active_civ.resident_name if active_civ != null else "Civilian")
	elif game_manager.strategic_decision_active:
		status_label.text = "[STRATEGIC DECISION] Press [1] for Confrontation | [2] for Peace | [N] to Confirm | [H] Help"
	elif game_manager.current_phase == game_manager.Phase.FINALE:
		if game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION:
			status_label.text = "[FINALE: CONFRONTATION] Channel Overdrive Generator to pull the meter! [E] Channel | [H] Help"
		else:
			status_label.text = "[FINALE: PEACE] Protect Common Works! Clear hazards & hold out! [E] Channel | [H] Help"
	elif game_manager.current_phase == game_manager.Phase.MATCH_OVER:
		status_label.text = "[MATCH OVER] %s | Press [R] to Play Again" % game_manager.match_ending_title
	else:
		var p_pos: Vector3 = (player_node.global_position if player_node.is_inside_tree() else player_node.position) if player_node != null else Vector3.ZERO
		var near_pad: Dictionary = town_map.get_nearest_pad(p_pos, 3.8) if town_map != null else {}
		var near_alc: Dictionary = town_map.get_nearest_alcove(p_pos, 3.8) if town_map != null else {}

		if not near_pad.is_empty():
			var p_name: String = String(near_pad.get("base_title", near_pad.get("name", "Station"))).split("\n")[0]
			status_label.text = "[E] Channel %s | [R] Shove | [F] Civic | [C] Special | Shift: Sprint | [Z] Zoom | [H] Help | [F1] Tuning" % p_name
		elif not near_alc.is_empty():
			status_label.text = "[V] Inspect Bedrock Alcove | [R] Shove | [F] Civic | [C] Special | [Z] Zoom | [H] Help | [F1] Tuning"
		else:
			status_label.text = "WASD: Move | [E] Task | [V] Inspect | [R] Shove | [F] Civic | [C] Special | Shift: Sprint | [Z] Zoom | [H] Help | [F1] Tuning"

func start_new_match() -> void:
	if game_manager != null and game_manager.archive_dilemma_open:
		game_manager.resolve_default_archive_choice()
	if archive_dilemma_overlay != null:
		archive_dilemma_overlay.visible = false
	archive_dilemma_timer = 25.0
	if playtest_tuning_panel != null:
		playtest_tuning_panel.close_panel()
	if settings_menu != null:
		settings_menu.close_menu()
	if evidence_journal != null:
		evidence_journal.close_journal()
	if help_overlay != null:
		help_overlay.visible = false
	if council_overlay != null:
		council_overlay.visible = false
	if channel_bar_container != null:
		channel_bar_container.visible = false
	if phase_banner != null:
		phase_banner.visible = false
	phase_banner_timer = 0.0

	town_map.reset_pads()
	if bot_seed < 0:
		_match_bot_seed = randi()
	for i in range(residents.size()):
		residents[i].reset_to_spawn(spawn_positions[i])
	for b_idx in range(bot_controllers.size()):
		bot_controllers[b_idx].set_bot_seed(_match_bot_seed + int(bot_controllers[b_idx].resident.resident_id))
		bot_controllers[b_idx].reset_bot(0.25 * float(b_idx + 1))
	game_manager.start_match(residents)
	town_map._sync_active_alcove()
	for res in residents:
		res.refresh_identity_labels()
		var bot_controller: Node = res.get("bot_controller")
		if bot_controller != null:
			bot_controller.refresh_personal_memory()
	_on_phase_changed(game_manager.current_phase)

func toggle_settings_menu() -> void:
	if settings_menu != null:
		settings_menu.toggle_menu()

func toggle_hero_draft_lobby() -> void:
	if hero_draft_lobby != null:
		hero_draft_lobby.toggle_lobby()

func select_player_hero_by_index(hero_idx: int) -> void:
	if hero_draft_lobby != null:
		hero_draft_lobby.select_hero_by_index(hero_idx, false)

func select_player_hero_by_id(h_id: String) -> void:
	if hero_draft_lobby != null:
		hero_draft_lobby.select_hero_by_id(h_id, false)
