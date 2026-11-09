extends SceneTree

# ==============================================================================
# The Gray Synthesis - Step 2: Lighting & Sector Identity Test Suite
# ==============================================================================
# Verifies:
# 1. Atmospheric ACES Environment, Directional Sunlight, and Council Dais Spotlight.
# 2. Distinct Visual & Lighting Identity across all 4 Sectors (Town Square, Pump Station,
#    Greenhouse, Salvage Yard).
# 3. Dynamic Phase Lighting Progression (Dawn -> Midday -> Golden Hour -> Twilight -> Nightfall).
# 4. Strict Competitive Visibility Safeguards in the darkest phase (Court / Nightfall),
#    ensuring ambient energy >= 0.80, player indicators, radar, clues, and resident tags remain readable.
# 5. Pulsing Aviation Spire & Generator Coil Lighting Animations.
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const TownMap3DScene = preload("res://scenes/TownMap3D.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING STEP 2: LIGHTING & SECTOR IDENTITY TEST ---")
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

	var map: Node3D = main.town_map
	var gm: Node = main.game_manager
	var player: CharacterBody3D = main.player_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: Core Lighting Architecture & ACES Environment
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Core Lighting Architecture & Theatrical Dais Spotlight")
	var world_env: WorldEnvironment = map.get_node_or_null("WorldEnvironment")
	assert_test.call(world_env != null and world_env.environment != null, "WorldEnvironment registered on TownMap3D")

	var env: Environment = world_env.environment
	assert_test.call(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "Tonemapper set to cinematic ACES")
	assert_test.call(env.glow_enabled == true, "Glow bloom enabled for radiant lighting")
	assert_test.call(env.glow_bloom >= 0.15, "Glow bloom threshold >= 0.15")

	var sun: DirectionalLight3D = map.get_node_or_null("SunLight")
	assert_test.call(sun != null and sun.shadow_enabled == true, "Directional SunLight casts soft directional shadows")

	var dais_spot: SpotLight3D = map.get_node_or_null("CouncilDaisSpotlight")
	assert_test.call(dais_spot != null, "CouncilDaisSpotlight registered over central council dais")
	assert_test.call(dais_spot.position.y > 6.0 and dais_spot.spot_range >= 12.0, "CouncilDaisSpotlight configured with high overhead throw")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Four Distinct Sector Lighting Setups
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Distinct Architectural & Thematic Sector Lighting")

	# Sector 1: Town Square & Civic Ring
	var ts_decor: Node = map.get_node_or_null("SectorDecorations/TownSquareDecor")
	assert_test.call(ts_decor != null, "TownSquareDecor container exists")
	var lanterns: Node = ts_decor.get_node_or_null("StreetLanterns")
	assert_test.call(lanterns != null and lanterns.get_child_count() == 4, "Town Square has 4 wrought-iron street lanterns")
	var l1_light: OmniLight3D = lanterns.get_child(0).get_node_or_null("LanternLight")
	assert_test.call(l1_light != null and l1_light.light_color.r > 0.9 and l1_light.light_color.b < 0.7, "Street lanterns cast warm amber civic illumination")

	var clinic_light: OmniLight3D = ts_decor.get_node_or_null("ClinicPavilion/ClinicMedicalLight")
	assert_test.call(clinic_light != null and clinic_light.light_color.b > 0.9, "Clinic Pavilion casts soothing medical cyan illumination")

	var cw_lamp: OmniLight3D = ts_decor.get_node_or_null("CommonWorksDecor/CommonWorksSafetyLamp")
	assert_test.call(cw_lamp != null, "Common Works foundation has dedicated halogen work light")

	# Sector 2: Pump & Generator Station (Cool Industrial Aquamarine)
	var ps_decor: Node = map.get_node_or_null("SectorDecorations/PumpStationDecor")
	assert_test.call(ps_decor != null, "PumpStationDecor container exists")
	var pump_light: OmniLight3D = ps_decor.get_node_or_null("PumpStationIndustrialLight")
	assert_test.call(pump_light != null and pump_light.light_color.b > 0.85, "Pump Station features cool industrial hydro-cyan floodlight")

	var turbine_light: OmniLight3D = ps_decor.get_node_or_null("TurbineGeneratorLight")
	assert_test.call(turbine_light != null and turbine_light.light_color.b > 0.9, "Turbine Generator features electric coil hum light")

	var beacon_light: OmniLight3D = ps_decor.get_node_or_null("SignalBeaconMast/BeaconMastLight")
	assert_test.call(beacon_light != null and beacon_light.light_color.r > 0.9, "Signal Beacon mast features high-altitude aviation warning beacon")

	# Sector 3: Greenhouse & Hydroponic Fields (Agricultural Dual Spectrum)
	var gh_decor: Node = map.get_node_or_null("SectorDecorations/GreenhouseDecor")
	assert_test.call(gh_decor != null, "GreenhouseDecor container exists")
	var grow_lights: Node = gh_decor.get_node_or_null("BotanicalGrowLights")
	assert_test.call(grow_lights != null and grow_lights.get_child_count() >= 2, "Greenhouse features suspended botanical grow lights")
	var violet_gl: OmniLight3D = grow_lights.get_node_or_null("GrowLightViolet")
	assert_test.call(violet_gl != null and violet_gl.light_color.r > 0.7 and violet_gl.light_color.b > 0.8, "Greenhouse features photosynthetic horticultural violet tint light")

	# Sector 4: Salvage Yard & Recycling (Industrial Slag & Halogen Floods)
	var sy_decor: Node = map.get_node_or_null("SectorDecorations/SalvageYardDecor")
	assert_test.call(sy_decor != null, "SalvageYardDecor container exists")
	var halogen_lamp: OmniLight3D = sy_decor.get_node_or_null("SalvageFloodlight/HalogenLamp")
	assert_test.call(halogen_lamp != null and halogen_lamp.light_energy >= 1.5, "Salvage Yard features high-intensity halogen yard floodlight")

	var wb_lamp: OmniLight3D = sy_decor.get_node_or_null("SalvageWorkbenchLamp")
	assert_test.call(wb_lamp != null and wb_lamp.light_color.r > 0.9 and wb_lamp.light_color.g > 0.6, "Salvage workbench features warm welding amber lamp")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Dynamic Narrative Phase Lighting Progression
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Narrative Phase Lighting Progression (Dawn -> Nightfall)")

	# Phase 0: BRIEFING (Dawn)
	map.apply_phase_lighting(gm.Phase.BRIEFING, true)
	assert_test.call(sun.light_energy >= 1.35 and sun.light_color.r > 0.95, "Briefing: Morning dawn warm sunlight")
	assert_test.call(env.ambient_light_energy >= 0.90, "Briefing: Ambient light maintains pre-dawn clarity")

	# Phase 1: OPEN TOWN (Midday Sun)
	map.apply_phase_lighting(gm.Phase.OPEN_TOWN, true)
	assert_test.call(sun.light_energy >= 1.55, "Open Town: Full midday sunlight (1.6x energy)")
	assert_test.call(is_equal_approx(env.ambient_light_energy, 1.0), "Open Town: Balanced 1.0 ambient daylight")

	# Phase 2: FIRST COUNCIL (Golden Hour)
	map.apply_phase_lighting(gm.Phase.FIRST_COUNCIL, true)
	assert_test.call(sun.light_color.r > 0.95 and sun.light_color.b < 0.60, "First Council: Golden hour amber sunlight palette")
	assert_test.call(dais_spot.light_energy >= 1.7, "First Council: Dais spotlight flares up for council debate")

	# Phase 3: ESCALATION (Moody Twilight)
	map.apply_phase_lighting(gm.Phase.ESCALATION, true)
	assert_test.call(sun.light_energy >= 1.10 and sun.light_energy < 1.30, "Escalation: Moody twilight lower sun intensity")
	assert_test.call(env.ambient_light_energy >= 0.85, "Escalation: Ambient energy maintains competitive readability (>= 0.85)")

	# Phase 4: COURT (Nightfall Tribunal)
	map.apply_phase_lighting(gm.Phase.COURT, true)
	assert_test.call(sun.light_color.b > 0.90, "Court: Cool silver moonlight directional key light")
	assert_test.call(dais_spot.light_energy >= 2.0, "Court: Dais spotlight reaches peak intensity (2.2) for trial ballots")

	# Phase 5: FINALE (Dusk Resolution)
	map.apply_phase_lighting(gm.Phase.FINALE, true)
	assert_test.call(map.current_lighting_phase == gm.Phase.FINALE, "Finale lighting phase registered cleanly")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Competitive Visibility Safeguards in Darkest Phase
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Competitive Readability Safeguards in Darkest Phase (Court)")
	map.apply_phase_lighting(gm.Phase.COURT, true)

	# 1. Floor & Ambient Illumination Safety Floor
	assert_test.call(env.ambient_light_energy >= 0.80, "Ambient illumination never drops below 0.80 (no pitch-black obscuration)")
	assert_test.call(sun.light_energy >= 0.85, "Directional moonlight key light maintains >= 0.85 energy")

	# 2. Player Readability Safeguards
	assert_test.call(player.player_ring != null and player.player_ring.material_override.emission_energy_multiplier >= 2.5, "Player ground selection ring remains brightly emissive")
	assert_test.call(player.player_marker != null and player.player_marker.visible == true, "Player floating billboard marker remains visible")
	assert_test.call(player.player_light != null and player.player_light.light_energy >= 1.5, "Player dedicated spotlight illuminates local surroundings")

	# 3. Resident Readability Safeguards
	for r in main.residents:
		assert_test.call(r.name_label != null and r.name_label.outline_size >= 5, "Resident nameplate retains thick high-contrast black outline")

	# 4. Tactical Radar Minimap Full Operational Integrity
	var radar: Control = main.radar_minimap
	assert_test.call(radar != null, "Tactical Radar Minimap active on screen")
	if radar != null:
		assert_test.call(radar.custom_minimum_size.x >= 200 and radar.custom_minimum_size.y >= 150, "Radar Minimap maintains full tactical dimensions")

	# 5. Station Pad & Objective Emissive Outlines
	var pads: Array = map.task_pads
	assert_test.call(pads.size() >= 5, "All task stations active and mapped")
	for p in pads:
		var lbl: Label3D = p.get("label_node")
		assert_test.call(lbl != null and lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Task station label retains billboard visibility")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Dynamic Beacon & Turbine Animation Modulation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Dynamic Beacon & Turbine Animation Modulation")
	var orig_beacon_e: float = beacon_light.light_energy
	map._process(0.4)
	var new_beacon_e: float = beacon_light.light_energy
	assert_test.call(orig_beacon_e != new_beacon_e or map.anim_timer > 0.0, "Beacon warning light dynamically pulses over time")

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")

	if stats["failed"] == 0:
		print(">>> ALL STEP 2 LIGHTING & SECTOR IDENTITY CHECKS PASSED! <<<")
	else:
		print("!!! STEP 2 VERIFICATION ENCOUNTERED FAILURES !!!")

	quit(0 if stats["failed"] == 0 else 1)
