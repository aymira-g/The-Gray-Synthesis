extends SceneTree

const Main3DScene = preload("res://scenes/Main3D.tscn")
const BrawlMinionScript = preload("res://scripts/BrawlMinion3D.gd")
const C = preload("res://scripts/GameConstants.gd")

var passed := 0
var failed := 0

func _init() -> void:
	print("==================================================================")
	print("--- STARTING BRAWL FINALE STAGE 4 VERIFICATION ---")
	print("==================================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_developer_f1_warp()

	var timeout_match := _make_match(["Ecology", "Ecology", "Ecology", "Technology"])
	await process_frame
	var timeout_manager: Node = timeout_match.game_manager
	var timeout_arena: Node3D = timeout_match.brawl_arena
	var timeout_player: Node = timeout_arena.player
	_check(timeout_arena != null, "Split-court confrontation launches the integrated brawl")
	_check(timeout_manager.brawl_active and timeout_manager.time_remaining > 599.0 and timeout_manager.time_remaining <= 600.0, "Integrated finale starts with the 10-minute brawl timer")
	var timer_before_manager_tick := float(timeout_manager.time_remaining)
	timeout_manager._process(30.0)
	_check(is_equal_approx(timeout_manager.time_remaining, timer_before_manager_tick), "Normal finale countdown does not prematurely end the brawl")
	_check(not timeout_match.town_map.visible and not timeout_match.ui_layer.visible, "Town and its HUD are hidden while the arena is active")
	_check(_team_hero_count(timeout_arena, "blue") == 6 and _team_hero_count(timeout_arena, "red") == 4, "Resident allegiances produce the correct 6v4 teams")
	_check(String(timeout_player.get("combatant_name")) == String(timeout_match.player_node.get("resident_name")), "Player-controlled hero represents the town player")
	var player_faction := String(timeout_manager.get_resident_alignment(timeout_match.player_node))
	var expected_player_team := "blue" if player_faction == "ecology" else "red"
	_check(String(timeout_player.get("team_id")) == expected_player_team, "Player hero joins its actual faction")
	_check(String(timeout_player.get("hero_id")) == String(timeout_arena.call("_hero_id_for_resident", timeout_match.player_node)), "Player keeps the resident's mapped combat kit")
	_check(_drafted_identities_match(timeout_match, timeout_arena), "All ten drafted hero identities remain visible in their brawl teams")
	_check(String(timeout_arena.get_node("BrawlHUD/ControlsLabel").text).contains("Drafted in Town Match"), "Finale controls HUD reflects the locked drafted hero")
	_check(float(timeout_arena.blue_core.get("max_health")) > 1800.0, "Faction preparation improves its core health")
	var world_root: Node = timeout_arena.get_node("Arena")
	var west_wall := world_root.get_node_or_null("WestBoundaryCollision")
	var east_wall := world_root.get_node_or_null("EastBoundaryCollision")
	_check(west_wall is StaticBody3D and east_wall is StaticBody3D and west_wall.get_child(0) is CollisionShape3D and east_wall.get_child(0) is CollisionShape3D, "Arena has collidable east and west end walls")

	var blue_hero := _first_team_hero(timeout_arena, "blue")
	var red_hero := _first_team_hero(timeout_arena, "red")
	var red_turret: Node3D = timeout_arena.get_node("Arena/RedTurret")
	var blue_turret: Node3D = timeout_arena.get_node("Arena/BlueTurret")
	_check(red_turret.get_node_or_null("StructureCollision/CollisionShape3D") != null and timeout_arena.blue_core.get_node_or_null("StructureCollision/CollisionShape3D") != null, "Turrets and cores have functional structure collision shapes")
	blue_hero.global_position = red_turret.global_position + Vector3(-2.0, 0.0, 0.0)
	blue_hero.set("attack_cooldown_remaining", 0.0)
	_check(bool(blue_hero.call("can_attack_target", red_turret)), "Heroes can basic-attack enemy turrets")
	var turret_health_before := float(red_turret.get("current_health"))
	red_turret.call("take_damage", 100.0, blue_hero)
	_check(is_equal_approx(turret_health_before - float(red_turret.get("current_health")), 35.0), "Enemy turret reduces damage by 65% without a siege minion")

	var support_minion := CharacterBody3D.new()
	support_minion.set_script(BrawlMinionScript)
	support_minion.set("team_id", "blue")
	support_minion.set("lane_direction", 1.0)
	support_minion.position = red_turret.position + Vector3(-3.0, 0.0, 0.0)
	timeout_arena.add_child(support_minion)
	turret_health_before = float(red_turret.get("current_health"))
	red_turret.call("take_damage", 100.0, blue_hero)
	_check(is_equal_approx(turret_health_before - float(red_turret.get("current_health")), 100.0), "Attacking minion support removes turret damage reduction")

	var blue_core: Node3D = timeout_arena.blue_core
	var health_before := float(blue_core.get("current_health"))
	blue_core.call("take_damage", 100.0, red_hero)
	_check(is_equal_approx(health_before, float(blue_core.get("current_health"))), "Core is invulnerable while its defending turret stands")
	support_minion.set("team_id", "red")
	support_minion.position = blue_turret.position + Vector3(3.0, 0.0, 0.0)
	blue_turret.call("take_damage", 10000.0, red_hero)
	_check(timeout_arena.call("is_team_turret_destroyed", "blue"), "Destroying a turret unlocks its team's core")
	for unit in timeout_arena.get_tree().get_nodes_in_group("brawl_units"):
		if String(unit.get("unit_type")) == "hero" and String(unit.get("team_id")) == "blue":
			unit.global_position = Vector3(0.0, 0.0, 12.0)
		elif String(unit.get("unit_type")) == "minion" and String(unit.get("team_id")) == "blue":
			unit.global_position = Vector3(0.0, 0.0, 12.0)
	support_minion.position = blue_core.position + Vector3(1.5, 0.0, 0.0)
	support_minion.set("lane_direction", -1.0)
	health_before = float(blue_core.get("current_health"))
	support_minion.set("attack_cooldown_remaining", 0.0)
	support_minion.call("_physics_process", 0.016)
	_check(float(blue_core.get("current_health")) < health_before, "Minions advance past the old lane stop and attack an unlocked core")
	support_minion.position = blue_core.position + Vector3(12.0, 0.0, 0.0)
	health_before = float(blue_core.get("current_health"))
	blue_core.call("take_damage", 100.0, red_hero)
	var unsupported_damage := health_before - float(blue_core.get("current_health"))
	_check(is_equal_approx(unsupported_damage, 35.0), "Enemy core reduces damage by 65% without a siege minion")

	support_minion.position = blue_core.position + Vector3(3.0, 0.0, 0.0)
	health_before = float(blue_core.get("current_health"))
	blue_core.call("take_damage", 100.0, red_hero)
	_check(is_equal_approx(health_before - float(blue_core.get("current_health")), 100.0), "Attacking minion support removes the core damage reduction")
	timeout_arena.call("_toggle_pause")
	_check(bool(timeout_arena.get("_paused")) and paused, "Finale pause freezes the active brawl")
	_check(not timeout_arena.return_to_modes_button.visible, "Integrated finale cannot abandon the Town Match from pause")
	timeout_arena.call("_return_to_mode_select")
	_check(timeout_match.game_manager.current_phase == timeout_match.game_manager.Phase.FINALE, "Pause menu cannot discard the active Town Match")
	timeout_arena.call("_toggle_pause")
	_check(not paused, "Finale can resume normally from pause")
	var locked_hero_id := String(timeout_player.get("hero_id"))
	_check(not bool(timeout_player.call("select_hero", "nyx_calder")), "Direct hero selection is disabled during the actual finale")
	var swap_event := InputEventKey.new()
	swap_event.pressed = true
	swap_event.keycode = KEY_2
	timeout_player.call("_unhandled_input", swap_event)
	_check(String(timeout_player.get("hero_id")) == locked_hero_id, "Developer hero-swap hotkeys are ignored during the actual finale")

	var red_core: Node3D = timeout_arena.red_core
	blue_core.set("current_health", float(blue_core.get("max_health")) * 0.6)
	red_core.set("current_health", float(red_core.get("max_health")) * 0.4)
	timeout_arena.call("_resolve_timeout")
	_check(timeout_manager.current_phase == timeout_manager.Phase.MATCH_OVER, "Higher remaining core health resolves the timed finale")
	_check(timeout_manager.brawl_winner_faction == "ecology" and timeout_manager.brawl_end_reason == "timeout", "Timeout awards the winner by normalized core health")
	_check(timeout_match.brawl_arena == null and timeout_match.town_map.visible and timeout_match.ui_layer.visible, "Town Match and its result UI are restored after the brawl")

	var sudden_death_match := _make_match(["Ecology", "Ecology", "Technology", "Technology"])
	await process_frame
	var sudden_death_manager: Node = sudden_death_match.game_manager
	var sudden_death_arena: Node3D = sudden_death_match.brawl_arena
	var blue_sudden_core: Node3D = sudden_death_arena.blue_core
	var red_sudden_core: Node3D = sudden_death_arena.red_core
	sudden_death_arena.get_node("Arena/BlueTurret").set("current_health", 0.0)
	blue_sudden_core.set("current_health", float(blue_sudden_core.get("max_health")) * 0.5)
	red_sudden_core.set("current_health", float(red_sudden_core.get("max_health")) * 0.5)
	sudden_death_arena.call("_resolve_timeout")
	_check(bool(sudden_death_arena.get("_sudden_death")), "Tied core health triggers sudden death")
	var red_sudden_hero := _first_team_hero(sudden_death_arena, "red")
	blue_sudden_core.call("take_damage", 10.0, red_sudden_hero)
	_check(sudden_death_manager.current_phase == sudden_death_manager.Phase.MATCH_OVER, "First enemy core damage ends sudden death")
	_check(sudden_death_manager.brawl_winner_faction == "technology" and sudden_death_manager.brawl_end_reason == "sudden_death", "Sudden-death result maps to the correct faction")

	var destruction_match := _make_match(["Ecology", "Ecology", "Technology", "Technology"])
	await process_frame
	var destruction_manager: Node = destruction_match.game_manager
	var destruction_arena: Node3D = destruction_match.brawl_arena
	_check(_team_hero_count(destruction_arena, "blue") == 5 and _team_hero_count(destruction_arena, "red") == 5, "Even Court split produces balanced 5v5 teams")
	var blue_attacker := _first_team_hero(destruction_arena, "blue")
	var destruction_red_core: Node3D = destruction_arena.red_core
	var siege_minion := CharacterBody3D.new()
	siege_minion.set_script(BrawlMinionScript)
	siege_minion.set("team_id", "blue")
	siege_minion.position = destruction_red_core.position + Vector3(-3.0, 0.0, 0.0)
	destruction_arena.add_child(siege_minion)
	destruction_arena.get_node("Arena/RedTurret").set("current_health", 0.0)
	destruction_red_core.call("take_damage", 10000.0, blue_attacker)
	_check(destruction_manager.current_phase == destruction_manager.Phase.MATCH_OVER, "Destroying the opposing core ends the match")
	_check(destruction_manager.brawl_winner_faction == "ecology" and destruction_manager.brawl_end_reason == "core_destroyed", "Core destruction reports the correct winner and result")
	_check(String(destruction_manager.match_ending_title).contains("ENEMY CORE DESTROYED"), "Town result screen explains the core-destruction victory")

	var defeated_match := _make_match(["Ecology", "Ecology", "Technology", "Technology"])
	await process_frame
	var defeated_player: Node = defeated_match.brawl_arena.player
	defeated_player.call("take_damage", float(defeated_player.get("max_health")) * 2.0)
	var mana_before := float(defeated_player.get("current_mana"))
	_check(not bool(defeated_player.call("use_ability", "Q")) and is_equal_approx(float(defeated_player.get("current_mana")), mana_before), "Defeated heroes cannot cast abilities")
	var defeated_hero_id := String(defeated_player.get("hero_id"))
	defeated_player.call("_unhandled_input", swap_event)
	_check(String(defeated_player.get("hero_id")) == defeated_hero_id, "Defeated heroes cannot swap combat kits")

	timeout_match.queue_free()
	sudden_death_match.queue_free()
	destruction_match.queue_free()
	defeated_match.queue_free()
	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================================")
	quit(0 if failed == 0 else 1)

func _test_developer_f1_warp() -> void:
	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	await process_frame
	main.game_manager.court_preview_votes.clear()
	main.playtest_tuning_panel._warp_to_finale(C.FINALE_ROUTE_CONFRONTATION)
	await process_frame
	var heroes := 0
	for unit in main.brawl_arena.get_tree().get_nodes_in_group("brawl_units"):
		if main.brawl_arena.is_ancestor_of(unit) and String(unit.get("unit_type")) == "hero":
			heroes += 1
	_check(heroes == 10, "Pre-Court F1 warp creates a full 5v5 brawl roster")
	_check(main.game_manager.court_preview_votes.size() == 4, "F1 warp fills every missing civilian ballot for deterministic testing")
	main.queue_free()

func _make_match(civilian_votes: Array) -> Node3D:
	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	if not main.is_inside_tree():
		main._ready()
	var manager: Node = main.game_manager
	manager.court_preview_votes.clear()
	var vote_index := 0
	for resident_index in range(main.residents.size()):
		var resident: Node = main.residents[resident_index]
		resident.set("hero_id", String(C.HERO_ROSTER[resident_index].get("hero_id")))
		if String(resident.get("secret_role")) != "civilian":
			continue
		manager.court_preview_votes.append({
			"name": String(resident.get("resident_name")),
			"vote": String(civilian_votes[vote_index])
		})
		vote_index += 1
	manager.court_is_unanimous = false
	manager.generator_eco_stabilized = 80.0
	manager.generator_tech_primed = 20.0
	manager.common_works = 40.0
	manager.finale_route = C.FINALE_ROUTE_CONFRONTATION
	manager.set_phase(manager.Phase.FINALE)
	return main

func _drafted_identities_match(main: Node3D, arena: Node3D) -> bool:
	var matched := 0
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if not arena.is_ancestor_of(unit) or String(unit.get("unit_type")) != "hero":
			continue
		for resident in main.residents:
			if String(resident.get("resident_name")) != String(unit.get("combatant_name")):
				continue
			var expected_name := ""
			for profile in C.HERO_ROSTER:
				if String(profile.get("hero_id")) == String(resident.get("hero_id")):
					expected_name = String(profile.get("name"))
					break
			if expected_name.is_empty() or String(unit.get("drafted_hero_name")) != expected_name or String(unit.get("hero_name")) != expected_name:
				return false
			matched += 1
			break
	return matched == main.residents.size()

func _team_hero_count(arena: Node3D, team: String) -> int:
	var count := 0
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if not arena.is_ancestor_of(unit):
			continue
		if String(unit.get("unit_type")) == "hero" and String(unit.get("team_id")) == team:
			count += 1
	return count

func _first_team_hero(arena: Node3D, team: String) -> Node:
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if not arena.is_ancestor_of(unit):
			continue
		if String(unit.get("unit_type")) == "hero" and String(unit.get("team_id")) == team:
			return unit
	return null

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] ", description)
	else:
		failed += 1
		print("  [FAIL] *** ", description, " ***")
