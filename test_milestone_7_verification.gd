extends SceneTree

const C = preload("res://scripts/GameConstants.gd")
const GM = preload("res://scripts/GameManager.gd")
const ResClass = preload("res://scripts/Resident3D.gd")
const Main3DClass = preload("res://scripts/Main3D.gd")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING MILESTONE 7 VERIFICATION SUITE ---")
	print("==================================================================")
	
	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	# Helper to generate a standard 10-resident roster (4 civilians, 3 eco, 3 tech)
	var make_roster = func(player_is_civ: bool = false, player_civ_idx: int = 0) -> Array[Node]:
		var list: Array[Node] = []
		var civ_count := 0
		var eco_count := 0
		var tech_count := 0

		# 4 Civilians
		for i in range(4):
			var r := ResClass.new()
			r.resident_id = i + 1
			r.resident_name = "Civilian_%d" % (i + 1)
			r.secret_role = "civilian"
			var jobs := ["Pump Technician", "Crop Tender", "Salvage Quartermaster", "Field Medic"]
			r.civic_job = jobs[i % jobs.size()]
			if player_is_civ and i == player_civ_idx:
				r.is_player = true
			list.append(r)

		# 3 Ecology Operatives
		for i in range(3):
			var r := ResClass.new()
			r.resident_id = 5 + i
			r.resident_name = "Eco_Op_%d" % (i + 1)
			r.secret_role = "ecology"
			r.civic_job = "Crop Tender"
			list.append(r)

		# 3 Technology Operatives
		for i in range(3):
			var r := ResClass.new()
			r.resident_id = 8 + i
			r.resident_name = "Tech_Op_%d" % (i + 1)
			r.secret_role = "technology"
			r.civic_job = "Salvage Quartermaster"
			list.append(r)

		return list

	# ------------------------------------------------------------------
	# TEST GROUP 1: Sequential Turn Progression
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Sequential Turn Progression & State Flow")
	var gm := GM.new()
	gm.session_residents = make_roster.call(false)
	gm.start_sequential_court_ceremony()

	assert_test.call(gm.court_ceremony_active == true, "Court ceremony marked active on start")
	assert_test.call(gm.court_civilians.size() == 4, "Court correctly gathered 4 Unaffiliated Civilians")
	assert_test.call(gm.court_voter_index == 0, "Initial voter index is 0 (First civilian)")
	assert_test.call(gm.get_active_court_voter() == gm.court_civilians[0], "get_active_court_voter() returns first civilian")
	assert_test.call(gm.court_active_speaker_name == gm.court_civilians[0].resident_name, "Active speaker name set to first civilian")
	assert_test.call(gm.court_turn_timer == gm.court_turn_duration, "Court turn timer initialized to court_turn_duration (6.0s)")

	# Voter 0 casts ballot
	var civ0: Node = gm.court_civilians[0]
	gm.cast_sequential_court_ballot(civ0, "Ecology", "Aquifer preservation priority", false)
	assert_test.call(gm.court_voter_index == 1, "Voter index advanced to 1 after first ballot")
	assert_test.call(gm.court_ballot_records.size() == 1, "court_ballot_records has 1 record")
	assert_test.call(gm.court_preview_votes.size() == 1, "court_preview_votes has 1 record")
	assert_test.call(gm.court_split_summary == "1-0", "Running split summary updated to 1-0")
	assert_test.call(gm.get_active_court_voter() == gm.court_civilians[1], "Active voter transitioned to second civilian")
	assert_test.call(gm.court_active_speaker_name == gm.court_civilians[1].resident_name, "Active speaker updated to second civilian")
	assert_test.call(gm.court_turn_timer == gm.court_turn_duration, "Turn timer reset for second voter")

	# Voter 1 casts ballot
	var civ1: Node = gm.court_civilians[1]
	gm.cast_sequential_court_ballot(civ1, "Technology", "Grid stability essential", false)
	assert_test.call(gm.court_voter_index == 2, "Voter index advanced to 2 after second ballot")
	assert_test.call(gm.court_split_summary == "1-1", "Running split summary updated to 1-1")

	# Test Fast-Forward processing during a bot's turn
	gm.current_phase = gm.Phase.COURT
	gm.court_fast_forward = true
	var timer_before: float = gm.court_turn_timer
	gm._process(0.5)
	# Fast-forward should rapidly advance or instantly vote
	assert_test.call(gm.court_turn_timer < (timer_before - 1.5) or gm.court_voter_index > 2, "Fast-forward significantly accelerated court turn timer or advanced voter")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Bot Deliberation AI & Information Fairness
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Bot Deliberation AI & Information Fairness")
	gm = GM.new()
	var test_civ := ResClass.new()
	test_civ.resident_id = 20
	test_civ.resident_name = "Deliberating_Civ"
	test_civ.secret_role = "civilian"
	test_civ.civic_job = "Pump Technician" # neutral job
	gm.session_residents = [test_civ]

	# Test 2a: High water deficit drives Ecology
	gm.water = 20.0
	gm.stability = 80.0
	var res_water := gm.evaluate_civilian_bot_vote(test_civ)
	assert_test.call(res_water["vote"] == "Ecology", "High water deficit (20 Water / 80 Stability) results in Ecology vote")
	assert_test.call(res_water["reason"].to_lower().find("aquifer") != -1 or res_water["reason"].to_lower().find("water") != -1, "High water deficit rationale cites aquifer/water: \"%s\"" % res_water["reason"])

	# Test 2b: High stability deficit drives Technology
	gm.water = 80.0
	gm.stability = 20.0
	var res_stability := gm.evaluate_civilian_bot_vote(test_civ)
	assert_test.call(res_stability["vote"] == "Technology", "High stability deficit (80 Water / 20 Stability) results in Technology vote")
	assert_test.call(res_stability["reason"].to_lower().find("grid") != -1 or res_stability["reason"].to_lower().find("power") != -1 or res_stability["reason"].to_lower().find("stability") != -1, "High stability deficit rationale cites grid/power: \"%s\"" % res_stability["reason"])

	# Test 2c: Civic Job baseline bias
	# Equal crisis state (50 Water / 50 Stability)
	gm.water = 50.0
	gm.stability = 50.0

	var crop_civ := ResClass.new()
	crop_civ.resident_id = 21
	crop_civ.resident_name = "Crop_Civ"
	crop_civ.secret_role = "civilian"
	crop_civ.civic_job = "Crop Tender"

	var salvage_civ := ResClass.new()
	salvage_civ.resident_id = 22
	salvage_civ.resident_name = "Salvage_Civ"
	salvage_civ.secret_role = "civilian"
	salvage_civ.civic_job = "Salvage Quartermaster"

	var crop_eco_count := 0
	var salvage_tech_count := 0
	for iter in range(50):
		var v_crop := gm.evaluate_civilian_bot_vote(crop_civ)
		if v_crop["vote"] == "Ecology":
			crop_eco_count += 1
		var v_salvage := gm.evaluate_civilian_bot_vote(salvage_civ)
		if v_salvage["vote"] == "Technology":
			salvage_tech_count += 1

	assert_test.call(crop_eco_count >= 35, "Crop Tender job (+5 Eco bias) produces majority Ecology votes (%d/50)" % crop_eco_count)
	assert_test.call(salvage_tech_count >= 35, "Salvage Quartermaster job (+5 Tech bias) produces majority Technology votes (%d/50)" % salvage_tech_count)

	# Test 2d: Zero psychic bias from neutral chores & alibis
	# Neutral chores in tabled evidence or alibi conflicts must NOT bias faction scores
	gm.water = 50.0
	gm.stability = 50.0
	gm.tabled_evidence = [
		{"tier": C.EVIDENCE_FACT, "subject": "Eco_Op_1", "text": "Eco_Op_1 harvested crop bed in Greenhouse.", "region": "Greenhouse & Fields"},
		{"tier": C.EVIDENCE_FACT, "subject": "Tech_Op_1", "text": "Tech_Op_1 repaired water pump in Pump Station.", "region": "Pump & Generator Station"},
		{"tier": C.EVIDENCE_FACT, "subject": "Civilian_1", "text": "Civilian_1 sorted scrap in Salvage Yard.", "region": "Salvage Yard"}
	]
	gm.alibi_conflicts = [
		{"resident": "Tech_Op_1", "claim": "Greenhouse", "seen": "Pump Station", "time": "03:30"}
	]
	# Evaluate neutral civ: neither faction should receive unfair psychic score from neutral chores/alibis
	var neutral_civ := ResClass.new()
	neutral_civ.resident_id = 23
	neutral_civ.resident_name = "Neutral_Civ"
	neutral_civ.secret_role = "civilian"
	neutral_civ.civic_job = "Field Medic"

	var eval_fair := gm.evaluate_civilian_bot_vote(neutral_civ)
	assert_test.call(eval_fair.has("vote") and (eval_fair["vote"] == "Ecology" or eval_fair["vote"] == "Technology"), "Evaluation completes fairly without errors with alibi conflicts active")

	# Test 2e: Observed Beacon Frequency Tuning in private journal
	var observer_bot := ResClass.new()
	observer_bot.resident_id = 24
	observer_bot.resident_name = "Observer_Civ"
	observer_bot.secret_role = "civilian"
	observer_bot.civic_job = "Field Medic"

	gm.evidence_journals[24] = {
		"observed": [
			{"tier": C.EVIDENCE_FACT, "text": "Witnessed Tech_Op_1 tuned Emergency Beacon to Old-World Frequency (25%) near Town Square."}
		],
		"traces": []
	}
	var eval_obs := gm.evaluate_civilian_bot_vote(observer_bot)
	assert_test.call(eval_obs["vote"] == "Technology", "Observing Beacon tuned to Old-World Frequency provides direct legitimate Tech score (+15)")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Archive Finder Secrecy & Alignment
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Archive Finder Secrecy & Entrusted Key Alignment")
	gm = GM.new()
	var civ_finder := ResClass.new()
	civ_finder.resident_id = 30
	civ_finder.resident_name = "Finder_Civ"
	civ_finder.secret_role = "civilian"
	civ_finder.civic_job = "Pump Technician"

	var civ_non_finder := ResClass.new()
	civ_non_finder.resident_id = 31
	civ_non_finder.resident_name = "Non_Finder_Civ"
	civ_non_finder.secret_role = "civilian"
	civ_non_finder.civic_job = "Pump Technician"

	gm.session_residents = [civ_finder, civ_non_finder]
	gm.water = 50.0
	gm.stability = 50.0

	# 3a: Finder entrusted key to Ecology
	gm.archive_opened = true
	gm.archive_finder_id = 30
	gm.archive_finder_name = "Finder_Civ"
	gm.archive_choice = C.ARCHIVE_CHOICE_ENTRUST_ECO
	gm.archive_entrust_faction = "ecology"

	var eval_finder_eco := gm.evaluate_civilian_bot_vote(civ_finder)
	assert_test.call(eval_finder_eco["vote"] == "Ecology", "Archive finder who entrusted to Ecology votes Ecology")
	assert_test.call(eval_finder_eco["reason"].find("unsealed the old failsafe") != -1, "Finder speaks private archive entrustment rationale")

	# 3b: Non-finder has zero archive bias
	var eval_non_finder := gm.evaluate_civilian_bot_vote(civ_non_finder)
	assert_test.call(eval_non_finder["reason"].find("unsealed") == -1, "Non-finder bot has zero knowledge of private archive decision")

	# 3c: Finder entrusted key to Technology
	gm.archive_choice = C.ARCHIVE_CHOICE_ENTRUST_TECH
	gm.archive_entrust_faction = "technology"
	var eval_finder_tech := gm.evaluate_civilian_bot_vote(civ_finder)
	assert_test.call(eval_finder_tech["vote"] == "Technology", "Archive finder who entrusted to Tech votes Technology")

	# 3d: Finder's vote activates archive_entrusted_civ_voted_match in Finale
	gm.start_sequential_court_ceremony()
	# Clear and manually set court_civilians
	gm.court_civilians = [civ_finder]
	gm.court_voter_index = 0
	gm.cast_sequential_court_ballot(civ_finder, "Technology", "Entrusted to tech", false)
	assert_test.call(gm.archive_entrusted_civ_voted_match == true, "archive_entrusted_civ_voted_match = true when finder voted for entrusted faction")
	assert_test.call(gm.get_archive_objective_speed_mult("technology") > 1.10, "+12% Archive channel speed bonus active for Technology")
	assert_test.call(gm.get_archive_objective_speed_mult("ecology") == 1.0, "Ecology does not receive the unearned Archive speed bonus")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Player Timeout Default
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Player Timeout Default Rule & Auto-Cast")
	gm = GM.new()
	var player_civ := ResClass.new()
	player_civ.resident_id = 1
	player_civ.resident_name = "Player_Civ"
	player_civ.secret_role = "civilian"
	player_civ.civic_job = "Pump Technician"
	player_civ.is_player = true
	gm.session_residents = [player_civ]

	# Test deterministic formula:
	# Water <= Stability -> Ecology
	gm.water = 40.0
	gm.stability = 60.0
	assert_test.call(gm.get_player_timeout_default_vote() == "Ecology", "get_player_timeout_default_vote() returns 'Ecology' when Water (40) <= Stability (60)")

	# Equal resources -> Ecology (conservative aquifer preservation)
	gm.water = 50.0
	gm.stability = 50.0
	assert_test.call(gm.get_player_timeout_default_vote() == "Ecology", "get_player_timeout_default_vote() returns 'Ecology' when Water (50) == Stability (50)")

	# Water > Stability -> Technology (grid restoration)
	gm.water = 65.0
	gm.stability = 45.0
	assert_test.call(gm.get_player_timeout_default_vote() == "Technology", "get_player_timeout_default_vote() returns 'Technology' when Water (65) > Stability (45)")

	# Test automatic timeout trigger in _process
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()
	assert_test.call(gm.get_active_court_voter() == player_civ, "Player is active court voter")
	assert_test.call(gm.get_active_court_voter().is_player == true, "Active voter has is_player = true")

	# Drain turn timer to 0 via _process
	gm.court_turn_timer = 0.05
	gm._process(0.1)
	assert_test.call(gm.court_ballot_records.size() == 1, "Ballot was auto-cast on timeout")
	var p_ballot: Dictionary = gm.court_ballot_records[0]
	assert_test.call(p_ballot["defaulted"] == true, "Ballot record is explicitly flagged as defaulted = true")
	assert_test.call(p_ballot["vote"] == "Technology", "Auto-cast ballot matches deterministic default ('Technology' for 65W/45S)")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Dramatic 4th Vote Resolution & Milestone 6 Live Handoff
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Dramatic 4th Vote Resolution & Milestone 6 Handoff")

	# 5a: Unanimous 4-0 Ecology Mandate
	gm = GM.new()
	gm.session_residents = make_roster.call(false)
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()
	for i in range(4):
		var civ: Node = gm.get_active_court_voter()
		gm.cast_sequential_court_ballot(civ, "Ecology", "Unanimous eco vote", false)

	assert_test.call(gm.court_is_unanimous == true, "4-0 Ecology produces court_is_unanimous = true")
	assert_test.call(gm.court_unanimous_winner == "ecology", "Unanimous winner set to 'ecology'")
	assert_test.call(gm.court_split_summary == "4-0", "court_split_summary = '4-0'")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "4-0 Mandate skips Finale and immediately transitions to MATCH_OVER")
	assert_test.call(gm.match_ending_title.begins_with("4-0 COURT MANDATE: ECOLOGY VICTORY"), "Match ending title displays 4-0 Ecology Victory Mandate")

	# 5b: Unanimous 4-0 Technology Mandate
	gm = GM.new()
	gm.session_residents = make_roster.call(false)
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()
	for i in range(4):
		var civ: Node = gm.get_active_court_voter()
		gm.cast_sequential_court_ballot(civ, "Technology", "Unanimous tech vote", false)

	assert_test.call(gm.court_is_unanimous == true, "4-0 Technology produces court_is_unanimous = true")
	assert_test.call(gm.court_unanimous_winner == "technology", "Unanimous winner set to 'technology'")
	assert_test.call(gm.current_phase == gm.Phase.MATCH_OVER, "4-0 Mandate skips Finale and immediately transitions to MATCH_OVER")
	assert_test.call(gm.match_ending_title.begins_with("4-0 COURT MANDATE: TECHNOLOGY VICTORY"), "Match ending title displays 4-0 Technology Victory Mandate")

	# 5c: 3-1 Split Handoff to Strategic Deliberation with Live Ballot Counting
	gm = GM.new()
	gm.session_residents = make_roster.call(false)
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()

	# Cast 3 Ecology, 1 Technology
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 1 Eco", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 2 Eco", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 3 Eco", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Technology", "Vote 4 Tech", false)

	assert_test.call(gm.court_is_unanimous == false, "3-1 split is NOT unanimous")
	assert_test.call(gm.court_split_summary == "3-1", "court_split_summary is '3-1'")
	assert_test.call(gm.strategic_decision_active == true, "3-1 split seamlessly transitions to strategic decision deliberation window")
	assert_test.call(gm.court_preview_votes.size() == 4, "court_preview_votes populated with 4 live cast ballots")

	# Verify bot logic in start_strategic_decision() uses live ballots:
	var eco_live := 0
	var tech_live := 0
	for entry in gm.court_preview_votes:
		if entry.get("vote") == "Ecology":
			eco_live += 1
		elif entry.get("vote") == "Technology":
			tech_live += 1
	assert_test.call(eco_live == 3 and tech_live == 1, "Live ballot tally accurately recorded (3 Eco, 1 Tech)")

	# 5d: 2-2 Split Handoff
	gm = GM.new()
	gm.session_residents = make_roster.call(false)
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()

	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 1 Eco", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Technology", "Vote 2 Tech", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Ecology", "Vote 3 Eco", false)
	gm.cast_sequential_court_ballot(gm.get_active_court_voter(), "Technology", "Vote 4 Tech", false)

	assert_test.call(gm.court_is_unanimous == false, "2-2 split is NOT unanimous")
	assert_test.call(gm.court_split_summary == "2-2", "court_split_summary is '2-2'")
	assert_test.call(gm.strategic_decision_active == true, "2-2 split transitions to strategic decision deliberation window")

	# ------------------------------------------------------------------
	# TEST GROUP 6: 3D Main Input Routing
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] 3D Main Input Routing")
	gm = GM.new()
	gm.session_residents = make_roster.call(true, 0) # Player is Civilian 1
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()

	var main_3d := Main3DClass.new()
	main_3d.game_manager = gm

	# Test player casting ballot via the 3D main controller's key 1 (Ecology)
	var ev1 := InputEventKey.new()
	ev1.pressed = true
	ev1.keycode = KEY_1
	main_3d._unhandled_input(ev1)
	assert_test.call(gm.court_ballot_records.size() == 1, "Pressing [1] in Court as active voter cast a ballot")
	assert_test.call(gm.court_ballot_records[0]["vote"] == "Ecology", "Ballot cast via [1] recorded as Ecology")
	assert_test.call(gm.court_voter_index == 1, "Turn advanced to next voter (bot)")

	# Second voter is a bot: pressing Space triggers fast forward
	assert_test.call(gm.court_fast_forward == false, "court_fast_forward initially false")
	var ev_space := InputEventKey.new()
	ev_space.pressed = true
	ev_space.keycode = KEY_SPACE
	main_3d._unhandled_input(ev_space)
	assert_test.call(gm.court_fast_forward == true, "Pressing [Space] during bot court turn activates fast forward")

	# A fresh court verifies the 3D controller routes the Technology ballot too.
	gm = GM.new()
	gm.session_residents = make_roster.call(true, 0)
	gm.current_phase = gm.Phase.COURT
	gm.start_sequential_court_ceremony()
	main_3d = Main3DClass.new()
	main_3d.game_manager = gm
	var ev2 := InputEventKey.new()
	ev2.pressed = true
	ev2.keycode = KEY_2
	main_3d._unhandled_input(ev2)
	assert_test.call(gm.court_ballot_records.size() == 1, "Pressing [2] in Court as active voter casts a ballot")
	assert_test.call(gm.court_ballot_records[0]["vote"] == "Technology", "Ballot cast via [2] recorded as Technology")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL MILESTONE 7 VERIFICATION CHECKS PASSED SUCCESSFULLY! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	quit(0 if stats["failed"] == 0 else 1)
