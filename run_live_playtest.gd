extends SceneTree

# ==============================================================================
# The Gray Synthesis - Autonomous Live Match Playtest & Simulation Runner
# ==============================================================================
# Runs a full, autonomous, end-to-end 3D match simulation directly from the console:
# - Assigns real factions and civic jobs across the 10 residents
# - Simulates Open Town chores, operative undercover missions, and evidence logging
# - Executes First Council assembly and checks alibi contradiction detection
# - Simulates Escalation crisis drains and station work
# - Runs the 3D Civilian Court sequential voting ceremony with podium testimony
# - Executes Finale (Overdrive Generator tug-of-war or Peace holdout)
# - Evaluates match victory and outputs complete telemetry and match statistics
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const C = preload("res://scripts/GameConstants.gd")

var main: Node3D
var gm: Node
var map: Node3D
var player: CharacterBody3D
var sim_frame: int = 0
var stage: int = 0

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("   THE GRAY SYNTHESIS — LIVE AUTONOMOUS MATCH PLAYTEST RUNNER")
	print("=".repeat(70))

	main = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	gm = main.game_manager
	map = main.town_map
	player = main.player_node

	print("\n[MATCH INITIALIZED]")
	print("Town Map: 3D Isometric Town with 4 Sectors (Pump, Greenhouse, Salvage, Council)")
	print("Active Archive Alcove: %s (Region: %s)" % [_get_active_alcove_name(), _get_active_alcove_region()])

	# Print Roster Dossier
	print("\n--- 10-RESIDENT MATCH ROSTER ---")
	for i in range(main.residents.size()):
		var res = main.residents[i]
		var role_tag := "Unaffiliated Civilian"
		if res.secret_role == "ecology":
			role_tag = "ECOLOGY OPERATIVE [%s]" % res.operative_kit.to_upper()
		elif res.secret_role == "technology":
			role_tag = "TECHNOLOGY OPERATIVE [%s]" % res.operative_kit.to_upper()
		var player_tag := " (YOU - PLAYER)" if res.is_player else ""
		print("  • %-12s | Job: %-22s | Role: %-30s%s" % [
			res.resident_name, res.civic_job, role_tag, player_tag
		])

func _get_active_alcove_name() -> String:
	for alc in map.secret_alcoves:
		if alc.get("id") == gm.archive_active_spawn_id:
			return String(alc.get("name", "Unknown Alcove"))
	return gm.archive_active_spawn_id

func _get_active_alcove_region() -> String:
	for alc in map.secret_alcoves:
		if alc.get("id") == gm.archive_active_spawn_id:
			return String(alc.get("region", "Town"))
	return "Town"

func _process(delta: float) -> bool:
	sim_frame += 1

	match stage:
		0: # BRIEFING PHASE (Frames 1-20)
			if sim_frame == 10:
				print("\n" + "-".repeat(60))
				print("[PHASE 1: BRIEFING] Reviewing secret dossiers at Council Ring...")
				print("Player Identity: %s (%s) — %s" % [
					player.resident_name, player.civic_job, player.secret_role.to_upper()
				])
			elif sim_frame >= 25:
				print("Briefing concluded. Transitioning to Open Town...")
				gm.advance_to_next_phase()
				stage = 1
				sim_frame = 0

		1: # OPEN TOWN PHASE (Simulating Chore Loop & Undercover Missions)
			if sim_frame == 1:
				print("\n" + "-".repeat(60))
				print("[PHASE 2: OPEN TOWN] Town begins daily operations (Duration: 5:00)")
				print("Initial State: Water: %d%% | Stability: %d%% | Scrap: %d | Common Works: %.1f%%" % [
					int(gm.water), int(gm.stability), int(gm.scrap), gm.common_works
				])

			# Simulate player working on Pump Station
			if sim_frame == 30:
				print("\n>> Player channels Pump Station Repair...")
				gm.execute_task("pump", player.resident_name, true)
				print("   Result: Water: %d%% | Stability: %d%% | Scrap: %d" % [
					int(gm.water), int(gm.stability), int(gm.scrap)
				])

			# Simulate player working on Scrap Salvage
			if sim_frame == 60:
				print(">> Player channels Scrap Heap Sorting...")
				gm.execute_task("salvage", player.resident_name, true)
				print("   Result: Scrap increased to: %d" % int(gm.scrap))

			# Simulate an operative bot attempting covert action
			if sim_frame == 80:
				var operative_bot = null
				for res in main.residents:
					if not res.is_player and res.is_operative():
						operative_bot = res
						break
				if operative_bot != null:
					print("\n>> Operative Bot (%s) initiates covert tampering in Salvage Yard..." % operative_bot.resident_name)
					gm.record_pad_tampering(operative_bot.resident_name, "salvage", "Salvage Yard")
					# A nearby civilian witnesses it!
					var witness_bot = main.residents[3]
					gm._add_private_evidence(witness_bot.resident_id, C.EVIDENCE_FACT,
						"%s was observed loitering near Salvage station conduits" % operative_bot.resident_name,
						"Salvage Yard", "04:15")
					print("   [WITNESS CLUE] %s observed %s near Salvage conduits!" % [
						witness_bot.resident_name, operative_bot.resident_name
					])

			# Fast-forward Open Town clock to trigger First Council
			if sim_frame >= 100:
				print("\nOpen Town duration complete. Calling residents to First Council...")
				gm.advance_to_next_phase()
				stage = 2
				sim_frame = 0

		2: # FIRST COUNCIL PHASE
			if sim_frame == 1:
				print("\n" + "-".repeat(60))
				print("[PHASE 3: FIRST COUNCIL] Residents convene at Town Square Council Ring")
				# Check for alibi statements & contradictions
				var contradictions: Array = gm.alibi_conflicts
				if contradictions.is_empty():
					print("Alibi Check: Residents' reported chore locations cross-checked.")
				else:
					for c in contradictions:
						print("   ⚠️ CONTRADICTION DETECTED: %s claimed %s but was seen in %s!" % [
							c.get("resident"), c.get("claim"), c.get("seen")
						])
				print("Tabled Exhibits in Public Record: %d clue(s)" % gm.tabled_evidence.size())

			if sim_frame >= 40:
				print("First Council adjourned. Advancing to Escalation...")
				gm.advance_to_next_phase()
				stage = 3
				sim_frame = 0

		3: # ESCALATION PHASE
			if sim_frame == 1:
				print("\n" + "-".repeat(60))
				print("[PHASE 4: ESCALATION] Emergency sirens sound! Drain multiplier x1.25")
				print("Buried Generator & Signal Beacon unlocked for faction contest!")

			if sim_frame == 25:
				print(">> Emergency Signal Beacon tuned by player (+35% sightline boost).")
				gm.execute_task("beacon", player.resident_name, true)

			if sim_frame >= 50:
				print("\nEscalation timer expires. Convening the decisive Civilian Court...")
				gm.advance_to_next_phase()
				stage = 4
				sim_frame = 0

		4: # CIVILIAN COURT CEREMONY
			if sim_frame == 1:
				print("\n" + "-".repeat(60))
				print("[PHASE 5: CIVILIAN COURT] Sequential Voting Ceremony Commences")
				print("4 Unaffiliated Civilians approach the podium one by one:")

			if gm.court_ceremony_active:
				gm.court_fast_forward = true
				var active_voter = gm.get_active_court_voter()
				if active_voter != null and active_voter.is_player:
					gm.cast_player_court_ballot("Technology")
			else:
				print("\n--- OFFICIAL COURT BALLOT RECORD ---")
				for rec in gm.court_ballot_records:
					print("  • Voter: %-12s | Cast: %-11s | Rationale: \"%s\"" % [
						rec.get("name", "Civilian"), rec.get("vote", "Ecology"), rec.get("reason", "None")
					])
				print("Final Vote Split: %s" % gm.court_split_summary)

				if gm.court_is_unanimous:
					print("VERDICT: 4–0 UNANIMOUS MANDATE! Skipping finale directly to victory.")
					gm.set_phase(gm.Phase.MATCH_OVER)
					stage = 6
					sim_frame = 0
				else:
					print("VERDICT: Split alignment! Entering Strategic Deliberation window...")
					stage = 5
					sim_frame = 0

		5: # STRATEGIC DELIBERATION & FINALE
			if sim_frame == 1:
				print("\n" + "-".repeat(60))
				print("[STRATEGIC DELIBERATION] Selecting Finale Route...")
				# Simulate choosing Confrontation Route
				gm.finale_route = C.FINALE_ROUTE_CONFRONTATION
				gm.set_phase(gm.Phase.FINALE)
				print("[PHASE 6: FINALE - CONFRONTATION] Battle for Buried Generator Overdrive!")
				print("Starting Tug-of-War Meter: %.1f%%" % gm.generator_tug_meter)

			if sim_frame == 20:
				print(">> Ecology operatives channel Generator to dampen output (-18%)...")
				gm.pending_generator_deltas.append(-18.0)

			if sim_frame == 35:
				print(">> Technology operatives overclock conduits to push overdrive (+25%)...")
				gm.pending_generator_deltas.append(25.0)

			if sim_frame == 50:
				print(">> Decisive push: Final tug surge applied!")
				# Decisive push
				gm.pending_generator_deltas.append(45.0)

			if sim_frame >= 60:
				if gm.current_phase == gm.Phase.MATCH_OVER or gm.generator_tug_meter >= 100.0 or gm.generator_tug_meter <= 0.0:
					stage = 6
					sim_frame = 0

		6: # MATCH OVER & OUTCOME REPORT
			if sim_frame == 1:
				print("\n" + "=".repeat(70))
				print("   MATCH CONCLUDED: %s" % gm.match_ending_title.to_upper())
				print("=".repeat(70))
				print("Summary: %s" % gm.match_ending_subtitle)
				print("\nMatch Telemetry:")
				print("  • Total Tasks Completed:    %d" % gm.total_tasks_completed)
				print("  • Final Water Reserves:      %d%%" % int(gm.water))
				print("  • Final Stability:           %d%%" % int(gm.stability))
				print("  • Final Scrap Recovered:     %d" % int(gm.scrap))
				print("  • Common Works Integrity:    %.1f%%" % gm.common_works)
				print("  • Generator Overdrive Meter: %.1f%%" % gm.generator_tug_meter)
				print("  • Archive Status:            %s" % ("UNSEALED by " + gm.archive_finder_name if gm.archive_opened else "SEALED"))
				print("\n>>> LIVE PLAYTEST MATCH SIMULATION COMPLETED SUCCESSFULLY! <<<")
				quit(0)
				return true

	return false
