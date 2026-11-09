# The Gray Synthesis

## Initial Build Blueprint

The design target is a 10-player online game set in one post-apocalyptic town. Three hidden Ecology operatives and three hidden Technology operatives work toward opposing plans while four unaffiliated civilians carry out ordinary survival work. At Court, the civilians choose a side. If all four back the same faction, that faction wins immediately. Any other split creates an uneven or even alignment, after which the factions choose whether to fight or negotiate peace. The game combines MOBA movement, character abilities, map objectives, social deduction, and a high-stakes final choice.

> **Scope note:** This is the original product blueprint, not a description of the current build. The current workspace is a local 3D prototype with one player and AI-controlled residents; no online multiplayer implementation was found in the inspected scripts. Online multiplayer remains a design target, not a verified current feature.

| Build target | Recommendation |
| --- | --- |
| Target format | Online multiplayer with one shared town map |
| Match size | 10 players: 3 hidden Ecology operatives, 3 hidden Technology operatives, and 4 unaffiliated civilians |
| Session length | 18–22 minutes for the first playable target |
| Genre promise | MOBA-style action and objectives wrapped around social deduction, a consequential civilian Court, and a war-or-peace finale |
| Primary test | Can players investigate and deceive during active team play, make a consequential secret discovery, then choose between faction loyalty, whistleblowing, war, and peace? |
| Build principle | Make one complete match work before adding maps, heroes, progression, or live-service features. |

## 1. Product premise

Ten residents live in a fragile post-apocalyptic town. Three are secretly working to restore the technology era: they gather components, repair old systems, and prepare to reactivate a buried generator. Three Ecology operatives are trying to uncover and stop that plan before it puts the town and its surrounding land at risk. The remaining four are ordinary civilians with no starting faction. They work to keep the town alive and will decide at Court which faction to support.

The Technology faction believes advanced tools can end shortages and restore medicine, power, and comfort. The Ecology faction believes unchecked restoration will exhaust the soil and water that keep the town alive. Both sides want people to survive. They disagree over acceptable risks, who should control powerful systems, and what the town should become.

All ten players move through the same town in real time. Everyone completes public civic tasks and can use shared civic abilities. The six operatives investigate, conceal, or advance their secret agendas; the four civilians gather evidence about both sides and decide what the town should support. Faction powers are held back until Escalation or used early at the cost of exposing the player to nearby witnesses.

As the crisis worsens, the match reaches Court. The four civilians cast their support votes one at a time, with the running tally visible. If all four choose Ecology or all four choose Technology, that faction wins immediately. A 3–1 civilian split creates a 6–4 alignment; a 2–2 split creates a 5–5 alignment. In either case, the aligned sides may fight over the machinery or attempt a negotiated settlement through the Common Works and its Charter. Peace requires concrete actions from both sides and can still collapse under pressure.

## 2. The core experience

The game should feel like four connected activities, not separate modes:

1. **Town life and deduction:** players share a readable space, complete useful tasks, notice irregularities, discuss evidence, and conceal or explain their actions.
2. **MOBA-style map play:** teams rotate between town regions, contest resources and strategic sites, and use distinct abilities to protect allies, interrupt enemies, gather information, or secure objectives.
3. **Secret discovery:** one randomly placed old-world secret can be found by any player. The finder privately chooses whether to stay loyal or become a whistleblower and pursue a personal Gray Synthesis objective.
4. **Endgame choice:** the town's accumulated evidence, resources, alliances, discoveries, and damage shape whether players can force a confrontation or negotiate a fragile peace.

The MOBA layer supplies movement and tactical objectives. The deduction layer gives those actions social meaning. The Court puts the town's civilians in a consequential position, while the hidden discovery adds a personal loyalty test inside the factions. The finale makes the ideological conflict playable rather than resolving it with a routine vote-out.

## 3. Players and starting information

| Group | Count | Public role | Private goal | Starting knowledge |
| --- | --- | --- | --- | --- |
| Ecology operatives | 3 | Town residents with ordinary survival duties. | Uncover the Tech plan; stop unsafe activation or win a limited Charter. | Know their own faction and the other two Ecology operatives. |
| Technology operatives | 3 | Town residents with ordinary survival duties. | Restore the generator; activate it or negotiate acceptable operating terms. | Know their own faction and the other two Technology operatives. |
| Civilians | 4 | Ordinary residents focused on keeping the town alive. | Gather enough information to choose which faction to support at Court. | Know they are civilians; do not know the operatives' identities. |

Faction identity stays hidden from the opposing faction and civilians. All ten residents share the same public appearance and civic jobs. Operatives know their two faction partners, which gives each secret team enough coordination to act while leaving the opposing operatives hidden among six people. Civilians begin unaffiliated and must make their own judgments at Court. All residents use the same public HUD layout and civic task labels; civilian status is private and cannot be verified from the interface.

The prototype uses five public civic job types, with each job assigned to two players. Civic jobs grant shared abilities and cover duties; they do not reveal faction. Faction-specific abilities are separate and either unlock at Escalation or expose the user to nearby witnesses if used earlier.

Public appearance must stay neutral: no faction colors, faction task labels, civilian badges, or telltale job titles. Everyone uses the same public HUD layout and civic task labels, so operatives can plausibly claim to be civilians. Either faction can repair the pump, move supplies, or inspect crops. Players infer identities from accumulated evidence and behavior. The four civilians become publicly identifiable through their Court votes, when the match is moving into open alignment.

Use five civic job kits shared across the whole town and three faction ability kits per faction. Public abilities support ordinary work and short defensive interactions. Faction abilities support investigation or covert restoration, but can reveal the user when witnesses are nearby. Keep all effects readable and counterable.

## 4. Match structure

Target a continuous real-time match with short discussion pauses at two decision points. Avoid long static day/night rounds that interrupt MOBA movement.

| Phase | Approx. time | What players do | What changes |
| --- | --- | --- | --- |
| Town briefing | 1 min | Learn the public crisis, civic job controls, and private role. | The irrigation pump is failing as crop blight spreads. Operatives learn their two partners; civilians learn they are unaffiliated. |
| Open town | 6 min | Complete civic tasks, patrol regions, gather resources, investigate, quietly advance faction objectives, and search points of interest. | Missing components and suspicious traces accumulate; one player may uncover the hidden old-world secret. |
| First council | 2 min | Share evidence, challenge explanations, request an inspection, or allocate town resources. | The town may restrict access or authorize a watch. No one is eliminated; civilian votes are reserved for Court. |
| Escalation | 5 min | Contest the pump, salvage yard, greenhouse, and generator access; prepare Common Works or covert activation. | Crisis peaks, and each faction's plan becomes harder to hide. |
| Court | 2 min | The four civilians cast public, sequential votes for Ecology or Technology. | A 4–0 civilian vote is an immediate faction victory. A 3–1 split creates 6–4 alignment; 2–2 creates 5–5. These alignments proceed to a war-or-peace decision. |
| Finale | 3–6 min | Fight over the machinery, or negotiate and defend a Charter settlement through a crisis event. | The match ends in Ecology victory, Technology victory, or Gray Synthesis. |

Timing is a tuning target, not a fixed promise. The first playable should prioritize pace and clarity. If players spend too long discussing, use short, predictable council windows and let the town map continue to provide readable context.

## 5. Shared town map and MOBA layer

Build one compact map with three connected regions and a central hub. Keep sightlines, routes, and landmarks readable from the top-down camera.

| Region | Main purpose | Contestable play |
| --- | --- | --- |
| Greenhouse and fields | Food supply, blight control, ecological traces. | Ecology can stabilize crops; Tech can discreetly test irrigation or divert materials. |
| Salvage yard | Components, tool marks, and alternate travel routes. | Tech needs parts; Ecology can inventory, inspect, or secure them. |
| Pump and generator station | Water stability and the final machinery objective. | Both teams need access. Restoration, sabotage, inspection, and defense leave evidence. |
| Town square / Common Works | Council meetings, public interaction, peace facility, and Charter. | Players negotiate terms, contribute, challenge claims, or contest access. |

Use familiar MOBA concepts selectively: readable hero kits, cooldowns, map rotations, neutral resource sites, objective control, and team fights. Do not add lanes full of automated minions in the first build unless playtests show the map needs more constant pressure. The social deduction and town objectives should remain the focus.

Players should have reasons to move across the map, but avoid making travel so fast that surveillance is meaningless or so slow that players are isolated. Consider short routes, a few chokepoints, and one shared high-value site that regularly creates encounters.

## 6. Crisis, resources, and evidence

### Shared crisis

Use one crisis in the first build: a failing irrigation pump during a crop blight. Ecology actions can slow blight and protect soil. Technology actions can restore pump capacity and improve short-term access to water. Either faction can help the town in the immediate term, but each approach alone carries a cost. Joint work can reduce both the immediate shortage and long-term environmental damage.

The crisis must create pressure without forcing a single correct ending. Tune it so players can survive through different strategies, each with meaningful tradeoffs.

### Hidden discovery and personal choice

Once per match, place an old-world archive or failsafe at one of several possible town sites. Choose its location randomly at match start. Any player can discover it by investigating the site; the finder is therefore unpredictable, and either faction has an equal chance to uncover it. The discovery is not assigned to a faction, and it does not identify or switch the finder's team.

The secret contains a verified piece of information and a one-use control key that can alter the final crisis. The finder privately chooses based on their role:

- **If an Ecology or Technology operative finds it:** stay loyal and deliver the secret to their faction for a modest advantage, or become a whistleblower by revealing a catastrophic flaw in their own faction's extreme plan. Whistleblowing unlocks leverage for the Charter and changes the finder's personal objective to achieving Gray Synthesis; it does not switch their team.
- **If a civilian finds it:** entrust the key to the faction they support, granting that faction a modest advantage only if the civilian votes for it at Court, or reserve the key for the Common Works and earn a personal reward if Gray Synthesis is achieved. This gives a civilian finder a reason to support either side or preserve the peace option without pretending they have a faction to betray.

The finder makes this private choice immediately. Accessing the archive leaves a trace, and using the key creates an observable event, but neither automatically identifies the finder. The interface explains the personal stakes to the finder, including the peace reward, so the incentive to reject a possible 3–0 civilian sweep is deliberate. Other players can infer what happened from evidence, but the interface does not announce the finder or their choice.

For the first build, use one secret, two clear choices, and one modest effect for each. Avoid layered secret chains or a separate personal scoring system until playtests show the mechanic is understandable and fair.

### Resources

Keep the first build's resources simple: **scrap**, **water**, and **town stability**. Scrap enables repairs and covert upgrades. Water and town stability show the shared crisis cost. Do not add a large crafting inventory or persistent economy yet.

### Evidence

Actions create concrete, inspectable traces: missing components, altered soil, unusual power readings, damaged locks, or movement through restricted areas. Some clues are reliable; others are ambiguous until verified. Players can inspect a site, compare reports, or catch a player in an inconsistent account.

Do not use fabricated system messages as a main deception mechanic in the first build. Let deception come from player choices, selective disclosure, and plausible cover stories. Make the interface distinguish observed facts, verified evidence, and unverified claims.

## 7. Core systems

### Public work and covert actions

Every player has useful public tasks that support the town. Technology players can use some of these tasks as cover while pursuing secret restoration objectives. Ecology players can investigate, protect sites, and help with the crisis while tracking suspicious actions. Actions should consume time or expose the player to observation, so players must choose between doing useful work and advancing their agenda. The randomly placed archive is one additional point of interest, not a required objective; either faction can discover and use it.

### Shared civic abilities and faction abilities

All residents have the same baseline civic actions: move, inspect, carry, repair, call for help, and use a basic defensive shove. Public job kits add useful shared actions such as first aid, crop tending, or watch duty.

Each operative also has a faction ability. These unlock at Escalation by default. If the build allows an early use, it should create a readable witness clue or other cover-blowing risk. Civilians do not receive faction powers; their leverage comes from evidence, Court votes, and access to town tasks.

### Team fights and non-lethal control

Fighting is part of the MOBA foundation, especially in the finale. During open town, use short, recoverable clashes: interrupts, slows, displacement, temporary capture, or control of a site. Avoid permanent elimination; civilians and operatives must remain able to contribute to deduction, Court, and the endgame.

After Court, players know the alignment and can openly fight around clear objectives. Victory comes from controlling or disabling the generator, securing the beacon, or defending the peace facility—not chasing the last opponent indefinitely.

### Councils and accusations

At the first council, players can present evidence, challenge explanations, request an inspection, or restrict access. At Court, each civilian publicly selects Ecology or Technology in sequence, and the running count is visible. The fourth vote is the pivotal choice: if it completes a unanimous 4–0 result, the chosen faction wins immediately; otherwise it sets a 6–4 or 5–5 alignment. After any non-unanimous result, both aligned sides can choose to fight or pursue a ceasefire. The UI must show the rules and consequences before voting begins.

## 8. The peace path: Common Works and Charter

The **Common Works** is a visible shared facility that can support the pump and clinic under agreed limits. It gives both factions a practical way to cooperate without pretending their disagreement has disappeared.

Its construction uses three contribution tracks: ecological stabilization, engineering components, and labor or protection. Each faction controls a necessary action. Contributions are visible and interruptible, so cooperating reveals intent and creates vulnerability. The teams can begin work before the finale, giving players a reason to negotiate while the situation is still recoverable.

When players call a ceasefire at the facility, they negotiate the **Charter**: three operating terms that define the settlement.

- **Power output:** low or high.
- **Land access:** restricted or open.
- **Medical priority:** scheduled or automated.

Use a small number of preset combinations in the first build. Make the consequences visible on the map and in the match outcome. Ratification requires distinct commitments from both factions: Ecology stabilizes the land system and accepts a defined level of technology; Technology limits and locks the generator and accepts oversight. A crowd at the console cannot force agreement for the other team.

After ratification, the teams must survive a short crisis escalation. This is cooperative objective play: Ecology may protect vents or contain blight while Technology jump-starts the pump or stabilizes power. Players still have the option to betray the deal, but holding the ceasefire should require active and complementary work.

A peace attempt should be difficult because it requires trust, exposure, and compromise—not because its rules are hidden or its inputs are arbitrary. The archive may unlock one extra Charter option, but the Common Works must remain usable without it. A failed attempt consumes time or resources and changes the map state, but does not automatically award the match to one side.

## 9. Court outcomes and endgame

| Civilian vote | Alignment after Court | Result |
| --- | --- | --- |
| 4–0 for Ecology | 7 Ecology-aligned vs. 3 Technology | Immediate Ecology victory. The town gives the winning faction a decisive mandate; no additional fight or peace choice. |
| 4–0 for Technology | 7 Technology-aligned vs. 3 Ecology | Immediate Technology victory. The town gives the winning faction a decisive mandate; no additional fight or peace choice. |
| 3–1 split | 6–4 toward the three-vote side | No automatic win. Both sides choose between fighting over the generator or attempting the Charter. The 6-player side has a numbers advantage. |
| 2–2 split | 5–5 | No automatic win. Both sides choose between fighting over the generator or attempting the Charter. |

For any non-unanimous outcome, each aligned side chooses **confrontation** or **peace**. Peace proceeds only if both sides accept it; if either side chooses confrontation, the match moves to the objective fight. In confrontation, the larger side (if any) seeks control of the generator while the smaller side tries to stop activation and protect the town. In peace, both sides must complete and defend the Common Works under the Charter. The Court does not force either option. Players make the choice through a clear match action, not an inferred timer.

The final fight should feel like the culmination of the match: evidence, resource control, relationships, and the archive choice affect routes, defenses, and objective progress. Civilians who voted for a faction join its side during the finale and contribute through their public civic kit. The peace path should also use the same map, character kits, and real-time pressure, so it feels like another way to play the MOBA finale rather than a separate menu ending. The hidden discovery can shift leverage or reveal a new option, but none of the three endings should depend on it.

## 10. Initial playable kits

Start with five public civic kits assigned to two players each, then give the six operatives a faction-specific ability kit. Keep ability count low: one basic ability, one utility ability, and one finale ability. Civilians use civic abilities and have no secret faction kit. These are prototype roles; names and exact abilities can change after testing.

| Ecology operative kit | Team function | Technology operative kit | Team function |
| --- | --- | --- | --- |
| Tracker | Finds recent movement and verifies traces. | Runner | Moves parts quickly but leaves a detectable trail. |
| Grower | Stabilizes crops and creates defensive terrain. | Mechanic | Repairs devices and accelerates generator work. |
| Warden | Protects allies and holds chokepoints. | Saboteur | Disables a device or creates a temporary diversion. |

Example ability language: Root Snare slows enemies crossing prepared ground; Scent Trail reveals a recent disturbance; Shock Tool briefly interrupts a device; Exosuit Burst gives a fast, audible dash; Thorn Guard protects a crop plot or facility entrance. Abilities should be readable, temporary, and counterable. Avoid making any one kit mandatory for victory or peace.

## 11. Interface and feedback

- **HUD:** crisis clock, water and town stability, personal task, team objective, and cooldowns.
- **Map:** region landmarks, contested sites, and teammate status; keep operative identities hidden from civilians and opposing operatives. All ten players see the same public HUD layout, civic task labels, and character presentation.
- **Court display:** show civilian votes in order and the live tally, making the fourth civilian's pivotal choice legible. Do not show a civilian badge before the vote.
- **Evidence board:** fact, verification status, source, and time observed.
- **Secret discovery prompt:** shown only to the finder; explains the loyal and whistleblower choices, including the personal Gray Synthesis objective and the risk of leaving traces.
- **Council interface:** short timer, evidence presentation, challenge and inspection options, sequential civilian Court votes, and visible consequences.
- **Objective feedback:** clear progress and interruption messages for pump, generator, beacon, and Common Works.
- **Social cues:** consistent sound and visual signals for witnessed sabotage, verified evidence, Charter commitment, ceasefire breach, and objective completion.
- **Character readability:** abilities should communicate what happened without exposing hidden faction identity unless the action itself is strong evidence.

## 12. Initial build scope

### Include

- One 10-player online match with 3 Ecology operatives, 3 Technology operatives, and 4 civilians.
- Simple bot fill for private solo or small-group flow tests, using basic movement, civic task, and objective behaviors. Bots support flow and timing tests, not social deduction or negotiation.
- One compact town map with four named regions.
- Five shared public civic kits assigned to two residents each, plus six operative faction kits.
- One shared crisis, one resource set, and a limited list of public tasks.
- Hidden operative identities, evidence generation, inspection, one evidence council, and a four-voter Civilian Court.
- Shared civic abilities and faction abilities that unlock or expose the user during Escalation.
- One randomly located old-world secret, discoverable by any resident, with a private loyalty-or-whistleblower choice.
- Three complete endings: Ecology victory, Technology victory, and Gray Synthesis.
- Objective-based team combat and a cooperative peace holdout.

### Defer

- Multiple maps, large hero roster, ranked mode, matchmaking at scale, progression, cosmetics, seasons, global experiment dashboard, complex crafting, AI minions, and elaborate cinematic story branches.
- Voice moderation and public lobbies at scale; first tests can use private lobbies and simple pings/text.

## 13. Build sequence

| Milestone | Build and review |
| --- | --- |
| 1. Town graybox | Camera and movement, readable regions, simple collision, pump and Common Works interactions, plus simple bots that walk routes and attempt civic tasks. |
| 2. 10-player session | Private lobby, assignment of 3 Ecology, 3 Technology, and 4 civilians; faction partner knowledge; match clock, respawn, end-state flow, and bot fill for empty slots. |
| 3. MOBA action | Shared civic kits, six operative faction kits, cooldowns, objective control, short clashes, and clear combat feedback. |
| 4. Deduction loop | Public work, covert actions, evidence traces, inspections, first council, and accusation consequences. |
| 5. Crisis and objectives | Water/blight state, scrap, pump, salvage, generator, beacon, Common Works contribution tracks, and the one-use archive secret. |
| 6. Endgame routes | Ecology confrontation, Technology takeover, Charter ratification, and cooperative holdout. |
| 7. Court and bot pass | Implement sequential civilian voting, 4–0 immediate win, 6–4 / 5–5 endgames, and simple bot fill for solo flow tests. |
| 8. Human playtest pass | Run repeated private matches, measure clarity and pacing, then tune abilities, thresholds, and Court duration. Bots can test flow and objective timing but not believable deduction or negotiation. |

## 14. Initial acceptance criteria

- Ten player slots can start and finish a match without a moderator; bots can fill empty slots for solo flow tests.
- Each player understands the public crisis, their team's goal, and their immediate task after briefing.
- Civilians and opposing operatives cannot identify faction membership from public job title, team color, a civilian badge, or a basic civic ability alone.
- All ten players see the same public HUD and civic task labels; civilian status stays private until Court votes reveal it.
- All residents can plausibly perform the same public survival tasks and visit the same map regions.
- Operatives know their two faction partners; civilians begin unaffiliated and choose publicly at Court.
- Both teams have useful actions throughout the open-town phase and meaningful roles in the finale.
- Players can distinguish observed facts, verified evidence, and unverified claims.
- The town map creates repeated encounters and meaningful rotations without making investigation impossible.
- No player is permanently removed before the finale.
- The old-world secret can be discovered by any player; only the finder sees and makes the private choice.
- The loyal and whistleblower choices have clear, modest effects, leave fair evidence, and cannot decide the match alone.
- The three main endings remain reachable whether or not anyone finds the secret.
- Each of the three endings can be deliberately reached and is clearly communicated.
- Common Works requires contributions and commitments from both factions; one team cannot ratify alone.
- A failed peace attempt has a clear consequence and returns players to active objectives.

## 15. Playtest questions and measures

- Does the experience feel like a MOBA with deduction woven through it, or like a deduction game with combat pasted on?
- Can players move, fight, complete tasks, and notice suspicious behavior without overload?
- Is the Technology agenda hidden long enough to create investigation, while still leaving fair clues?
- Can Ecology make a consequential accusation using evidence rather than guesswork?
- Does Technology feel like a group with understandable reasons for restoring systems?
- Does each kit contribute in open-town play, confrontation, and peace objectives?
- Does peace feel like an exciting strategic choice rather than a less active ending?
- Which map locations create good encounters, and which let players avoid one another?
- Did the final fight depend on the match's earlier evidence and resource control?
- Did the fourth civilian's vote feel tense and consequential?
- Did the 4–0 automatic victory feel earned through the match's evidence and persuasion?
- Did a 6–4 alignment feel meaningfully different from 5–5 without making the smaller side helpless?
- Were the sequential votes understandable and resistant to confusion?
- Was the archive discovery fair and understandable when found?
- If a civilian found it, were the faction-support and Common Works options understandable and meaningful?
- Did bot fill let a solo tester evaluate map flow and objective timing without implying the bots test social deduction?
- Did the finder feel torn between faction loyalty and whistleblowing for peace?
- Could other players detect or negotiate around the choice without being told by the UI?

Track match length, objective completion, evidence inspections, accusation outcomes, fight duration, civilian vote split, 4–0 victory rate, archive discovery and choice rates, ceasefire attempts, Charter ratification, peace-holdout success, and player-reported clarity. Treat outcome rates as a measure of this ruleset and its incentives, not proof of a universal claim about human nature.

## 16. Key risks and design responses

| Risk | Early response |
| --- | --- |
| The game feels like two separate genres stitched together. | Use the same town objectives, character abilities, and real-time map pressure in deduction and finale play. |
| Hidden agendas become obvious too early. | Give everyone the same public HUD and town identity, overlap survival tasks across factions, and provide multiple explanations for early clues. |
| Social deduction gets lost in combat noise. | Keep early clashes short, non-lethal, and objective-focused; reserve full team fights for the finale. |
| MOBA combat overwhelms investigation. | Limit ability complexity, make evidence readable during action, and tune cooldowns to create observation windows. |
| Ecology has no reason to negotiate. | Make unilateral crisis solutions viable but costly; Common Works improves the settlement without being mandatory. |
| Peace becomes the obvious optimal choice. | Give war immediate tactical rewards and peace durable but conditional benefits; tune without making either path a trap. |
| Charter is decided by crowding the console. | Require separate faction commitments and explicit operating thresholds. |
| Failed ceasefire stalls the match. | Consume time/resources and shift objectives immediately back to active confrontation. |
| A player is removed and has nothing to do. | Avoid permanent elimination; use respawns, temporary capture, or delayed return with a visible cost. |
| The hidden discovery feels random or grants one player too much power. | Use several possible spawn sites, role-specific modest choices, clear trace evidence, and no ending that requires the secret. |
| Whistleblowing confuses faction identity or scoring. | Keep the player on their original faction roster; change their personal objective to Gray Synthesis without switching teams. |

## First build recommendation

Build a private 10-player prototype on one shared town map. Start with 3 Ecology operatives, 3 Technology operatives, and 4 unaffiliated civilians. Give each operative group limited partner knowledge; keep civilian identities neutral and faction operatives hidden. Use the same public civic jobs and abilities across all residents, with faction abilities unlocking at Escalation or exposing the user if used early. Add simple bot fill for solo tests of movement, tasks, and objective timing.

At Court, four civilians cast sequential votes with the tally visible. A unanimous 4–0 civilian mandate is an immediate win for the chosen faction. A 3–1 vote creates a 6–4 alignment; a 2–2 vote creates 5–5. Those non-unanimous outcomes lead to the faction choice between a full objective fight and a negotiated peace through the Common Works and Charter. Keep the fourth civilian's decision dramatic and informed by evidence gathered during play. Retain the archive as a whistleblower pivot that gives its finder a personal path toward Gray Synthesis, and keep bots focused on solo flow tests rather than simulated social deduction. The first success measure is whether the Court feels consequential, the vote outcomes are understood, and either war or peace remains a compelling choice after a non-unanimous vote. Start with basic bots in the graybox so solo testing can check movement, tasks, and objective timing; use human sessions to evaluate deception, persuasion, and peace negotiations.
