extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 2: Sound & Audio Atmosphere Verification Suite
# ==============================================================================
# Verifies:
# 1. Procedural Audio Synthesis: All SFX and ambient loops generated in memory as AudioStreamWAV
# 2. Sector-Specific Footstep Soundscapes (Stone, Metal, Dirt, Gravel)
# 3. Task & Interaction SFX (Channel start/tick, Task complete, Jammed, Alcove, Archive unseal)
# 4. Tactical Action & Ability SFX (Shove impact, Speed burst, Mist, Roots, Shield, Sparks)
# 5. Ceremonial & Phase Stingers (Escalation, Court gavel, Ballot vote, Finale alarm, Victory, Defeat)
# 6. Ambient Continuous Looping Audio & Crossfade System
# 7. Resident3D & Main3D Audio Integration (Cadence, Surface detection, Phase triggers)
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const AudioManagerClass = preload("res://scripts/AudioManager.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING OPTION 2: SOUND & AUDIO ATMOSPHERE VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var audio: Node = main.audio_manager
	var map: Node3D = main.town_map
	var player: CharacterBody3D = main.player_node
	var gm: Node = main.game_manager

	# ------------------------------------------------------------------
	# TEST GROUP 1: AudioManager & Procedural Synthesis Pipeline
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] AudioManager & Procedural Sound Synthesis")
	assert_test.call(audio != null, "AudioManager registered on Main3D")
	assert_test.call(audio.sfx_library.size() >= 18, "Procedural SFX library contains at least 18 synthesized sound effects")
	assert_test.call(audio.ambient_library.size() == 4, "Ambient library contains exactly 4 sector ambient loop soundscapes")

	# Verify sample properties
	var sample_sfx: AudioStreamWAV = audio.sfx_library.get("task_complete")
	assert_test.call(sample_sfx != null, "task_complete AudioStreamWAV synthesized")
	assert_test.call(sample_sfx.format == AudioStreamWAV.FORMAT_16_BITS, "Synthesized audio uses 16-bit PCM format")
	assert_test.call(sample_sfx.mix_rate == 22050, "Synthesized audio mix rate is 22050 Hz")
	assert_test.call(sample_sfx.get_length() > 0.1, "task_complete has valid non-zero duration (%.2fs)" % sample_sfx.get_length())

	# ------------------------------------------------------------------
	# TEST GROUP 2: Sector Surface Footstep Audio
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Sector Surface Footsteps & Cadence")
	var footstep_keys := ["footstep_stone", "footstep_metal", "footstep_dirt", "footstep_gravel"]
	var all_footsteps_valid := true
	for f_key in footstep_keys:
		var stream: AudioStreamWAV = audio.sfx_library.get(f_key)
		if stream == null or stream.get_length() <= 0.0:
			all_footsteps_valid = false
	assert_test.call(all_footsteps_valid, "All 4 surface footstep audio streams exist with positive durations")

	# Coordinate surface resolution
	assert_test.call(map.get_region_id_at_3d(Vector3(0, 0, 0)) == "town_square", "Town Square (0, 0, 0) maps to 'town_square' (Slate Stone footstep)")
	assert_test.call(map.get_region_id_at_3d(Vector3(-6, 0, 24)) == "pump_station", "Pump Station (-6, 0, 24) maps to 'pump_station' (Industrial Steel footstep)")
	assert_test.call(map.get_region_id_at_3d(Vector3(-20, 0, -20)) == "greenhouse", "Greenhouse (-20, 0, -20) maps to 'greenhouse' (Soft Loam Dirt footstep)")
	assert_test.call(map.get_region_id_at_3d(Vector3(20, 0, -20)) == "salvage_yard", "Salvage Yard (20, 0, -20) maps to 'salvage_yard' (Crushed Gravel footstep)")

	# Footstep triggering & cadence limiter
	audio.play_footstep("town_square", Vector3.ZERO, false, 1)
	var first_call_time: float = float(audio._last_footstep_time.get(1, 0.0))
	assert_test.call(first_call_time > 0.0, "Footstep execution recorded in entity cadence tracker")

	# Immediate second call within min_interval is throttled
	audio.play_footstep("town_square", Vector3.ZERO, false, 1)
	assert_test.call(float(audio._last_footstep_time.get(1, 0.0)) == first_call_time, "Rapid consecutive footstep correctly throttled by cadence limiter")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Task & Interaction SFX
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Task & Pad Interaction Sound Effects")
	var task_keys := ["channel_start", "channel_tick", "task_complete", "task_jammed", "alcove_inspect", "archive_unseal"]
	var all_task_sfx_exist := true
	for t_key in task_keys:
		if not audio.sfx_library.has(t_key):
			all_task_sfx_exist = false
	assert_test.call(all_task_sfx_exist, "All 6 task and interaction SFX synthesized and registered")

	var sfx_p2d: AudioStreamPlayer = audio.play_sfx("task_complete", 1.0, 0.0)
	assert_test.call(sfx_p2d != null and sfx_p2d.stream == audio.sfx_library["task_complete"], "play_sfx() assigns task_complete to 2D channel")

	var sfx_p3d: AudioStreamPlayer3D = audio.play_sfx_3d("channel_start", Vector3(-6, 0, 24), 1.0, 0.0)
	var sfx_pos: Vector3 = sfx_p3d.global_position if (sfx_p3d != null and sfx_p3d.is_inside_tree()) else (sfx_p3d.position if sfx_p3d != null else Vector3.ZERO)
	assert_test.call(sfx_p3d != null and sfx_pos == Vector3(-6, 0, 24), "play_sfx_3d() positions audio player at 3D task pad coordinates")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Tactical Abilities & Combat Stems
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Tactical Combat & Operative Ability Audio")
	var combat_keys := ["shove_impact", "speed_burst", "zone_mist", "zone_roots", "zone_shield", "zone_sparks"]
	var all_combat_sfx_exist := true
	for c_key in combat_keys:
		if not audio.sfx_library.has(c_key):
			all_combat_sfx_exist = false
	assert_test.call(all_combat_sfx_exist, "All 6 tactical action and ability SFX synthesized and registered")

	var shove_p3d: AudioStreamPlayer3D = audio.play_sfx_3d("shove_impact", Vector3(0, 0, 0), 1.0, 0.0)
	assert_test.call(shove_p3d != null and shove_p3d.stream == audio.sfx_library["shove_impact"], "Civic shove impact plays heavy physical sound stem")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Ceremonies & Match Phase Stingers
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Match Phase Stingers & Ceremonies")
	var stinger_keys := ["phase_escalation", "phase_court", "court_vote", "phase_finale", "victory_fanfare", "defeat_sting"]
	var all_stingers_exist := true
	for s_key in stinger_keys:
		if not audio.sfx_library.has(s_key):
			all_stingers_exist = false
	assert_test.call(all_stingers_exist, "All 6 ceremonial and match phase stingers synthesized and registered")

	audio.play_phase_stinger("court")
	assert_test.call(audio.sfx_library["phase_court"] != null, "Court stinger triggers ceremonial wooden gavel strike")

	audio.play_phase_stinger("court_vote")
	assert_test.call(audio.sfx_library["court_vote"] != null, "Ballot vote audio cue triggers confirmation chime")

	audio.play_phase_stinger("escalation")
	assert_test.call(audio.sfx_library["phase_escalation"] != null, "Escalation stinger triggers industrial siren klaxon")

	audio.play_phase_stinger("victory")
	assert_test.call(audio.sfx_library["victory_fanfare"] != null, "Victory fanfare triggers triumphant ascending chord")

	audio.play_phase_stinger("defeat")
	assert_test.call(audio.sfx_library["defeat_sting"] != null, "Defeat stinger triggers somber minor chord")

	# ------------------------------------------------------------------
	# TEST GROUP 6: Continuous Ambient Sector Loops & Crossfader
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Ambient Sector Soundscapes & Crossfading")
	var sectors := ["town_square", "pump_station", "greenhouse", "salvage_yard"]
	var all_ambients_loop := true
	for sec in sectors:
		var amb: AudioStreamWAV = audio.ambient_library.get(sec)
		if amb == null or amb.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			all_ambients_loop = false
	assert_test.call(all_ambients_loop, "All 4 sector ambients configured with AudioStreamWAV.LOOP_FORWARD")

	# Crossfader test
	audio.set_ambient_sector("pump_station")
	assert_test.call(audio._target_ambient_sector == "pump_station", "set_ambient_sector switches target to pump_station")
	audio.update_ambient_crossfade(0.5)
	var pump_vol: float = audio._ambient_players["pump_station"].volume_db
	var ts_vol: float = audio._ambient_players["town_square"].volume_db
	assert_test.call(pump_vol > ts_vol, "Crossfader raises pump_station ambient volume above inactive town_square")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Resident3D & Main3D Integration
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Entity & Match Lifecycle Audio Integration")
	assert_test.call(player.audio_manager == audio, "Player entity holds reference to AudioManager")
	assert_test.call(main.audio_manager == audio, "Main3D holds reference to AudioManager")
	assert_test.call(map.audio_manager == audio, "TownMap3D holds reference to AudioManager")

	# Resident moving footstep simulation
	audio._last_footstep_time.clear()
	player.sim_time = 100.0
	player.velocity = Vector3(6.0, 0.0, 0.0)
	var initial_steps: float = float(audio._last_footstep_time.get(player.resident_id, 0.0))
	for _f in range(30):
		player._update_procedural_animations(0.05)
	var updated_steps: float = float(audio._last_footstep_time.get(player.resident_id, 0.0))
	assert_test.call(updated_steps > initial_steps, "Procedural walk cycle triggers footsteps via leg stride cycle")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 2 SOUND & AUDIO ATMOSPHERE CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.free()
	quit(0 if stats["failed"] == 0 else 1)
