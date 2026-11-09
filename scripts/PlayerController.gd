class_name PlayerController
extends Node2D

const C = preload("res://scripts/GameConstants.gd")
const MOVE_SPEED: float = C.MOVE_SPEED

var resident: CharacterBody2D
var camera: Camera2D
var game_manager: Node
var main_scene: Node

var has_click_target: bool = false
var click_target: Vector2 = Vector2.ZERO
var target_marker_timer: float = 0.0
var is_overview_zoom: bool = false
var target_zoom: float = 0.95

func _ready() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.5
	camera.zoom = Vector2(target_zoom, target_zoom)
	add_child(camera)

func _input(event: InputEvent) -> void:
	if resident == null or game_manager == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode

		# Lobby controls
		if game_manager.current_phase == game_manager.Phase.LOBBY:
			match k:
				KEY_1, KEY_KP_1:
					game_manager.player_role_pref = "random"
				KEY_2, KEY_KP_2:
					game_manager.player_role_pref = "ecology"
				KEY_3, KEY_KP_3:
					game_manager.player_role_pref = "technology"
				KEY_4, KEY_KP_4:
					game_manager.player_role_pref = "civilian"
				KEY_5, KEY_KP_5:
					game_manager.cycle_player_kit_pref()
				KEY_6, KEY_KP_6:
					if main_scene != null:
						game_manager.cycle_player_civic_job(main_scene.residents)
				KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_N:
					if main_scene != null and main_scene.has_method("start_new_match"):
						main_scene.start_new_match()
			return

		# Global session shortcuts
		if game_manager.archive_dilemma_open:
			var is_op: bool = resident.secret_role != "civilian"
			match k:
				KEY_1, KEY_KP_1:
					if is_op:
						game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_LOYAL)
					else:
						game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_ENTRUST_ECO)
					return
				KEY_2, KEY_KP_2:
					if is_op:
						game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_WHISTLEBLOWER)
					else:
						game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_ENTRUST_TECH)
					return
				KEY_3, KEY_KP_3:
					if not is_op:
						game_manager.resolve_player_archive_choice(C.ARCHIVE_CHOICE_RESERVE_CW)
					return
			return

		if k == KEY_R:
			has_click_target = false
			if main_scene != null and main_scene.has_method("reset_sandbox"):
				main_scene.reset_sandbox()
			return
		elif k == KEY_TAB or k == KEY_M:
			is_overview_zoom = not is_overview_zoom
			target_zoom = 0.56 if is_overview_zoom else 0.95
			return
		elif k == KEY_B:
			game_manager.dossier_open = not game_manager.dossier_open
			return
		elif k == KEY_J:
			game_manager.evidence_journal_open = not game_manager.evidence_journal_open
			return
		elif game_manager.evidence_journal_open:
			return

		# Strategic Decision Window (15s cold-war vote after split court)
		# Evaluated before [N] and Court preview controls so choices [1],[2] and commit [Space]/[N] are not intercepted
		if game_manager.strategic_decision_active:
			match k:
				KEY_1, KEY_KP_1:
					game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_CONFRONTATION)
					return
				KEY_2, KEY_KP_2:
					game_manager.cast_player_strategic_choice(C.STRATEGIC_CHOICE_PEACE)
					return
				KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_N:
					game_manager.resolve_strategic_decision()
					return
			return

		if k == KEY_N:
			has_click_target = false
			game_manager.advance_to_next_phase()
			return

		# Briefing phase: Space/Enter starts Open Town
		if game_manager.current_phase == game_manager.Phase.BRIEFING:
			if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
				game_manager.advance_to_next_phase()
			return

		if game_manager.current_phase == game_manager.Phase.FIRST_COUNCIL:
			match k:
				KEY_1, KEY_KP_1:
					game_manager.cast_player_motion_vote(1)
				KEY_2, KEY_KP_2:
					game_manager.cast_player_motion_vote(2)
				KEY_3, KEY_KP_3:
					game_manager.cast_player_motion_vote(3)
			return

		# Court phase: Sequential Civilian Voting Ceremony & Developer Debug Overrides
		if game_manager.current_phase == game_manager.Phase.COURT and not game_manager.strategic_decision_active:
			# Developer debug shortcuts (Shift + [1]-[5])
			if event.shift_pressed and main_scene != null:
				match k:
					KEY_1, KEY_KP_1:
						game_manager.set_court_preview_mode("2-2", main_scene.residents)
						return
					KEY_2, KEY_KP_2:
						game_manager.set_court_preview_mode("3-1_eco", main_scene.residents)
						return
					KEY_3, KEY_KP_3:
						game_manager.set_court_preview_mode("3-1_tech", main_scene.residents)
						return
					KEY_4, KEY_KP_4:
						game_manager.set_court_preview_mode("4-0_eco", main_scene.residents)
						return
					KEY_5, KEY_KP_5:
						game_manager.set_court_preview_mode("4-0_tech", main_scene.residents)
						return
					KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
						game_manager.advance_to_next_phase()
						return
				return

			# Live Sequential Court Ceremony
			if game_manager.court_ceremony_active:
				var active_civ: Node = game_manager.get_active_court_voter()
				if active_civ != null and active_civ.is_player:
					match k:
						KEY_1, KEY_KP_1:
							game_manager.cast_player_court_ballot("Ecology")
							return
						KEY_2, KEY_KP_2:
							game_manager.cast_player_court_ballot("Technology")
							return
					return
				else:
					# Bot turn: Space/Enter/N fast-forwards deliberation delay
					if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_N:
						game_manager.court_fast_forward = true
						return
					return
			return

		# Peace Finale: Term cycling shortcuts before ratification
		if game_manager.current_phase == game_manager.Phase.FINALE and game_manager.finale_route == C.FINALE_ROUTE_PEACE and not game_manager.charter_ratified:
			match k:
				KEY_1, KEY_KP_1:
					game_manager.cycle_charter_term("power")
					return
				KEY_2, KEY_KP_2:
					game_manager.cycle_charter_term("land")
					return
				KEY_3, KEY_KP_3:
					game_manager.cycle_charter_term("med")
					return

		# Active play controls
		if not game_manager.is_active_play_phase() or resident.is_incapacitated:
			return

		match k:
			KEY_E, KEY_SPACE:
				has_click_target = false
				resident.try_start_channel()
			KEY_Q:
				resident.try_civic_shove()
			KEY_F:
				resident.try_civic_ability()
			KEY_C:
				resident.try_faction_ability()
			KEY_V:
				resident.try_inspect_site()
			KEY_T:
				game_manager.toggle_drain()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and not game_manager.evidence_journal_open and not game_manager.archive_dilemma_open and not game_manager.strategic_decision_active and game_manager.is_active_play_phase() and not resident.is_incapacitated:
			click_target = resident.get_global_mouse_position()
			has_click_target = true
			target_marker_timer = 0.65
			resident.cancel_channeling()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom + 0.08, 0.52, 1.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom - 0.08, 0.52, 1.35)

func _process(delta: float) -> void:
	if resident == null or game_manager == null:
		return

	if camera != null:
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 8.0 * delta)

	if not game_manager.is_active_play_phase() or resident.is_incapacitated or game_manager.archive_dilemma_open or game_manager.strategic_decision_active:
		if has_click_target:
			has_click_target = false
			queue_redraw()
		resident.desired_velocity = Vector2.ZERO
		return

	if target_marker_timer > 0.0:
		target_marker_timer = maxf(0.0, target_marker_timer - delta)
		queue_redraw()

	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	if input_vec.length_squared() > 0.01:
		has_click_target = false
		resident.desired_velocity = input_vec.normalized() * MOVE_SPEED
	elif has_click_target:
		var diff: Vector2 = click_target - resident.global_position
		if diff.length() <= 14.0:
			has_click_target = false
			resident.desired_velocity = Vector2.ZERO
			var near_pad: Dictionary = resident.town_map.get_nearest_pad(resident.global_position, 54.0)
			if not near_pad.is_empty():
				resident.try_start_channel()
		else:
			resident.desired_velocity = diff.normalized() * MOVE_SPEED
	else:
		resident.desired_velocity = Vector2.ZERO

func _draw() -> void:
	if has_click_target and resident != null:
		var local_target: Vector2 = click_target - resident.global_position
		draw_arc(local_target, 14.0, 0.0, TAU, 24, Color(0.55, 0.92, 1.0, 0.75), 2.0)
		draw_circle(local_target, 4.0, Color(0.55, 0.92, 1.0, 0.85))
