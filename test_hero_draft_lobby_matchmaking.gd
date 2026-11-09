extends SceneTree

# ==============================================================================
# The Gray Synthesis - Pre-Match 10-Hero Selection & Matchmaking Lobby Test Suite
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

var total_checks: int = 0
var passed_checks: int = 0
var failed_checks: int = 0

func _assert(cond: bool, desc: String) -> void:
	total_checks += 1
	if cond:
		passed_checks += 1
		print("  [PASS] %s" % desc)
	else:
		failed_checks += 1
		printerr("  [FAIL] %s" % desc)

func _initialize() -> void:
	print("==================================================================")
	print("  TEST SUITE: 10-HERO SELECTION & MATCHMAKING DRAFT LOBBY")
	print("==================================================================")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var gm: Node = main.game_manager
	var lobby: PanelContainer = main.hero_draft_lobby
	var residents: Array = main.residents
	var player = main.player_node

	# --------------------------------------------------------------------------
	# 1. Verify Lobby Initialization & Automatic Display in BRIEFING
	# --------------------------------------------------------------------------
	print("\n--- 1. Lobby Initialization & Automatic Display in BRIEFING ---")
	_assert(gm.current_phase == gm.Phase.BRIEFING, "Match starts in Phase.BRIEFING")
	_assert(lobby != null, "Main3D instantiates HeroDraftLobby3D")
	_assert(lobby.visible == true, "HeroDraftLobby3D is automatically visible during Phase.BRIEFING")
	_assert(lobby.hero_card_buttons.size() == 10, "Lobby displays 10 interactive Hero selection cards")
	_assert(lobby.lobby_slot_labels.size() == 10, "Lobby displays 10 Matchmaking Roster slots (1 Local Player + 9 AI Bots)")
	_assert(lobby.random_hero_btn != null and lobby.lock_in_btn != null, "Lobby includes Random Hero and Lock In & Start Match buttons")

	# --------------------------------------------------------------------------
	# 2. Verify Selecting Each of the 10 Heroes & 9-Bot Auto-Fill (Zero Duplicates)
	# --------------------------------------------------------------------------
	print("\n--- 2. Selecting Each of the 10 Heroes & 9-Bot Matchmaking Auto-Fill ---")
	var initial_player_secret_role: String = player.secret_role
	var initial_player_op_kit: String = player.operative_kit

	for hero_idx in range(10):
		var expected_hero: Dictionary = C.get_hero_by_index(hero_idx)
		var expected_id: String = str(expected_hero.get("hero_id", ""))
		var expected_name: String = str(expected_hero.get("name", ""))
		var expected_job: String = str(expected_hero.get("civic_job", ""))
		var expected_act: String = str(expected_hero.get("active_name", ""))
		var expected_pas: String = str(expected_hero.get("passive_name", ""))

		main.select_player_hero_by_index(hero_idx)

		_assert(lobby.selected_hero_index == hero_idx and lobby.selected_hero_id == expected_id,
			"Drafting Hero %d selects '%s' (%s)" % [hero_idx + 1, expected_name, expected_id])
		_assert(player.hero_id == expected_id and player.resident_name == expected_name and player.civic_job == expected_job,
			"Player node (Slot 1) updated to %s (%s)" % [expected_name, expected_job])
		_assert(lobby.inspector_hero_name_label.text.find(expected_name) != -1,
			"Inspector header displays '%s'" % expected_name)
		_assert(lobby.inspector_active_title_label.text.find(expected_act) != -1,
			"Inspector displays [F] Active '%s'" % expected_act)
		_assert(lobby.inspector_passive_title_label.text.find(expected_pas) != -1,
			"Inspector displays Passive '%s'" % expected_pas)
		_assert(lobby.lobby_slot_labels[0].text.find(expected_name) != -1,
			"Matchmaking Slot 1 [YOU] displays '%s'" % expected_name)

		# Verify all 10 residents in the match have 10 unique Heroes (zero duplicates) and 2x5 job balance
		var active_hero_ids := {}
		var job_counts := {}
		for r in residents:
			active_hero_ids[r.hero_id] = true
			job_counts[r.civic_job] = int(job_counts.get(r.civic_job, 0)) + 1

		_assert(active_hero_ids.size() == 10,
			"When player picks %s, all 10 unique Heroes are present across Player + 9 Bots (0 duplicates)" % expected_name)
		_assert(job_counts.get("Pump Technician", 0) == 2 and job_counts.get("Crop Tender", 0) == 2 and job_counts.get("Salvage Quartermaster", 0) == 2 and job_counts.get("Field Medic", 0) == 2 and job_counts.get("Town Watch", 0) == 2,
			"When player picks %s, exact 2x5 Civic Job balance is preserved across all 10 slots" % expected_name)
		_assert(player.secret_role == initial_player_secret_role and player.operative_kit == initial_player_op_kit,
			"Picking %s preserves dealt secret role (%s) with zero role leakage" % [expected_name, initial_player_secret_role])

	# --------------------------------------------------------------------------
	# 3. Verify Keyboard Hotkeys [1]-[9],[0] & [Tab] Random Hero in BRIEFING
	# --------------------------------------------------------------------------
	print("\n--- 3. Keyboard Hotkeys [1]-[9],[0] & [Tab] Random Hero in BRIEFING ---")
	var key_6 := InputEventKey.new()
	key_6.pressed = true
	key_6.keycode = KEY_6
	main._unhandled_input(key_6)
	_assert(player.hero_id == "mira_solis" and player.resident_name == "Mira Solis",
		"Pressing [6] in Briefing selects Hero 6: Mira Solis (Aquifer Diver)")

	var key_0 := InputEventKey.new()
	key_0.pressed = true
	key_0.keycode = KEY_0
	main._unhandled_input(key_0)
	_assert(player.hero_id == "nyx_calder" and player.resident_name == "Nyx Calder",
		"Pressing [0] in Briefing selects Hero 10: Nyx Calder (Signal & Recon Officer)")

	var prev_idx: int = lobby.selected_hero_index
	var key_tab := InputEventKey.new()
	key_tab.pressed = true
	key_tab.keycode = KEY_TAB
	main._unhandled_input(key_tab)
	_assert(lobby.selected_hero_index != prev_idx and lobby.selected_hero_index >= 0 and lobby.selected_hero_index < 10,
		"Pressing [Tab] in Briefing rolls a different Random Hero (%s)" % player.resident_name)

	# --------------------------------------------------------------------------
	# 4. Verify Lock In & Start Match Transition to OPEN_TOWN
	# --------------------------------------------------------------------------
	print("\n--- 4. Lock In Hero & Start Match Transition to OPEN_TOWN ---")
	main.select_player_hero_by_id("clara_vale")
	_assert(player.hero_id == "clara_vale" and player.resident_name == "Clara Vale",
		"Selected Clara Vale before locking in")

	lobby.confirm_and_start_match()
	_assert(lobby.is_locked_in == true, "Lobby marks draft as locked in (is_locked_in = true)")
	_assert(lobby.visible == false, "Lobby closes automatically upon locking in")
	_assert(gm.current_phase == gm.Phase.OPEN_TOWN, "Locking in advances match from BRIEFING to OPEN_TOWN")
	_assert(player.hero_id == "clara_vale" and player.hero_active_id == "adrenaline_tonic" and player.hero_passive_id == "apothecarys_aura",
		"Player deploys into OPEN_TOWN as Clara Vale with Adrenaline Tonic [F] and Apothecary's Aura passive")

	# --------------------------------------------------------------------------
	# 5. Verify Mid-Match Hero Roster Reference Toggle [Tab] & New Match Reset
	# --------------------------------------------------------------------------
	print("\n--- 5. Mid-Match Hero Roster Reference Toggle [Tab] & New Match Reset ---")
	main._unhandled_input(key_tab)
	_assert(lobby.visible == true, "Pressing [Tab] during OPEN_TOWN opens Hero Roster Reference overlay")
	main._unhandled_input(key_tab)
	_assert(lobby.visible == false, "Pressing [Tab] again closes Hero Roster Reference overlay")

	# Reset player back to default Hero 0 (Kaelen Vance) and verify start_new_match re-opens lobby in BRIEFING
	main.select_player_hero_by_index(0)
	main.start_new_match()
	_assert(gm.current_phase == gm.Phase.BRIEFING and lobby.visible == true,
		"start_new_match() returns to BRIEFING and re-opens Hero Selection Lobby")

	print("==================================================================")
	print("  RESULTS: %d PASSED, %d FAILED (Total: %d)" % [passed_checks, failed_checks, total_checks])
	print("==================================================================")
	quit(0 if failed_checks == 0 else 1)
