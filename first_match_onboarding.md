# First-Match Onboarding

## Purpose

Help a new player understand their role, the first useful actions, the private evidence journal, and how to share evidence at First Council without pausing or restricting the match.

## Player flow

1. **Briefing:** The status bar identifies the player's faction or civilian role and a short role-appropriate objective. The hero lobby remains available.
2. **Open Town — movement:** The guide appears with WASD movement and directs the player toward a station. Moving at least two world units advances the guide.
3. **Station task:** The guide explains that E starts channeling and the player must stay nearby. Completing a player task advances the guide.
4. **Private clues:** The guide asks the player to open the journal with J and explains that evidence remains private until tabled. Opening the journal advances the guide.
5. **First Council:** The guide explains individual clue tabling, Table All, and the 1/2/3 civic-motion votes. Reaching First Council records the first-run guide as complete.

The guide is a small, non-blocking HUD panel. “Got it” hides the current tip until the next milestone; “Skip Guide” ends and remembers the guide. It does not pause the match or require any tutorial action to continue playing.

## Replay and persistence

- First-run completion is saved in `user://player_progress.cfg` under `[onboarding] first_match_guide_completed`.
- The guide starts automatically during the first Open Town only if it has not already been completed or skipped.
- “Replay First-Match Guide” in the H field manual starts an optional, manually advanced walkthrough and does not change saved completion.

## Implementation

- `scripts/FirstMatchGuide3D.gd` owns the guide UI, milestone progression, replay, and progress persistence.
- `scripts/Main3D.gd` starts the first-run guide, detects player movement and journal use, routes replay, and advances at First Council.
- `scripts/Resident3D.gd` emits a player task-completed signal for the guide.
- The field manual and settings controls are kept consistent with the active 3D controls: E channel, V inspect, R shove, F Hero ability, C operative ability, J journal.

## Verification

Run `test_first_match_guide.gd` for first-run progression, persistence, replay, and skip behavior. Run `run_all_tests.ps1` for the full regression suite.
