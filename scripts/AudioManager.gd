extends Node

# ==============================================================================
# The Gray Synthesis - Procedural Audio & Atmospheric Soundscape Manager
# ==============================================================================
# Comprehensive, fully self-contained audio engine for the 3D isometric experience.
# Features:
# 1. 100% Procedurally Synthesized AudioStreamWAV sound effects (zero external files).
# 2. Distinct Sector-Specific Footstep Soundscapes:
#    - Town Square: Crisp stone/slate click & acoustic tap
#    - Pump Station: Resonant industrial steel grating & metallic ring
#    - Greenhouse: Muffled dark loam/dirt thud & soft scatter
#    - Salvage Yard: Crunching slag & rust gravel grit
# 3. Task & Interaction Audio Feedback:
#    - Channeling start pulse, active tick, and triumphant completion chime
#    - Jammed error buzz, alcove inspection drone, and archive unseal chime
# 4. Tactical Abilities & Combat Stems:
#    - Heavy civic shove impact thud
#    - Speed burst whoosh, mulch mist hiss, root snare snap, thorn shield chime, electric sparks
# 5. Ceremonial & Match Phase Stingers:
#    - Town Briefing, Escalation siren, Court wooden gavel strike, live vote ballot chimes
#    - High-stakes Finale klaxon, victory fanfare arpeggio, and defeat sting
# 6. Dynamic Seamless Ambient Sector Loops:
#    - 4 continuous looping ambient soundscapes cross-faded smoothly by player location
# 7. Spatial 3D Audio (AudioStreamPlayer3D) + 2D Master Channels
# ==============================================================================

const SAMPLE_RATE := 22050

# Volume Settings (0.0 to 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 0.75
var music_volume: float = 0.8
var is_muted: bool = false
var _pre_mute_master: float = 1.0

# Sound Library: sound_name -> AudioStreamWAV
var sfx_library: Dictionary = {}

# Ambient Loop Library: sector_id -> AudioStreamWAV
var ambient_library: Dictionary = {}

# Audio Players
var _sfx_players_2d: Array[AudioStreamPlayer] = []
var _sfx_players_3d: Array[AudioStreamPlayer3D] = []
var _ambient_players: Dictionary = {} # sector_id -> AudioStreamPlayer
var _active_ambient_sector: String = "town_square"
var _target_ambient_sector: String = "town_square"
var _fade_speed: float = 2.5

# Footstep cadence tracking per entity
var _last_footstep_time: Dictionary = {}

func _init() -> void:
	_synthesize_all_audio()
	_setup_audio_channels()

func _ready() -> void:
	if _sfx_players_2d.is_empty():
		_setup_audio_channels()
	start_ambient()

# ------------------------------------------------------------------------------
# 1. Procedural Synthesis Pipeline
# ------------------------------------------------------------------------------
func _synthesize_all_audio() -> void:
	# Footsteps
	sfx_library["footstep_stone"] = _synth_footstep_stone()
	sfx_library["footstep_metal"] = _synth_footstep_metal()
	sfx_library["footstep_dirt"] = _synth_footstep_dirt()
	sfx_library["footstep_gravel"] = _synth_footstep_gravel()

	# Interactions & Tasks
	sfx_library["channel_start"] = _synth_channel_start()
	sfx_library["channel_tick"] = _synth_channel_tick()
	sfx_library["task_complete"] = _synth_task_complete()
	sfx_library["task_jammed"] = _synth_task_jammed()
	sfx_library["alcove_inspect"] = _synth_alcove_inspect()
	sfx_library["archive_unseal"] = _synth_archive_unseal()

	# Tactical Actions & Abilities
	sfx_library["shove_impact"] = _synth_shove_impact()
	sfx_library["speed_burst"] = _synth_speed_burst()
	sfx_library["zone_mist"] = _synth_zone_mist()
	sfx_library["zone_roots"] = _synth_zone_roots()
	sfx_library["zone_shield"] = _synth_zone_shield()
	sfx_library["zone_sparks"] = _synth_zone_sparks()

	# Match Phase Stingers & Ceremonies
	sfx_library["phase_escalation"] = _synth_phase_escalation()
	sfx_library["phase_court"] = _synth_phase_court()
	sfx_library["court_vote"] = _synth_court_vote()
	sfx_library["phase_finale"] = _synth_phase_finale()
	sfx_library["victory_fanfare"] = _synth_victory_fanfare()
	sfx_library["defeat_sting"] = _synth_defeat_sting()

	# Audio Mixer Preview & Atmosphere Cues
	sfx_library["test_tone"] = _synth_test_tone()
	sfx_library["covert_hunch"] = _synth_covert_hunch()
	sfx_library["ui_click"] = _synth_ui_click()

	# Ambient Continuous Loops
	ambient_library["town_square"] = _synth_ambient_town_square()
	ambient_library["pump_station"] = _synth_ambient_pump_station()
	ambient_library["greenhouse"] = _synth_ambient_greenhouse()
	ambient_library["salvage_yard"] = _synth_ambient_salvage_yard()

func _create_wav(samples: int, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples
	return wav

# --- A. Footsteps ---
func _synth_footstep_stone() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.08) # 80ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 65.0)
		# Crisp transient click + dual stone resonance (1350Hz + 820Hz)
		var click := (randf() * 2.0 - 1.0) * exp(-t * 220.0) * 0.45
		var res := (sin(TAU * 1350.0 * t) * 0.5 + sin(TAU * 820.0 * t) * 0.5) * env * 0.55
		var sample := clampf((click + res) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 30000.0))

	wav.data = bytes
	return wav

func _synth_footstep_metal() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.12) # 120ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 38.0)
		var click := (randf() * 2.0 - 1.0) * exp(-t * 180.0) * 0.35
		# Steel grating resonant harmonics (1120Hz + 1780Hz + 2450Hz)
		var res := (sin(TAU * 1120.0 * t) * 0.45 + sin(TAU * 1780.0 * t) * 0.35 + sin(TAU * 2450.0 * t) * 0.20) * env * 0.65
		var sample := clampf((click + res) * 0.95, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 30000.0))

	wav.data = bytes
	return wav

func _synth_footstep_dirt() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.09) # 90ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 52.0)
		# Low muffled thud (145Hz down to 80Hz) + soft noise scatter
		var freq := lerpf(145.0, 75.0, t * 11.0)
		var thud := sin(TAU * freq * t) * env * 0.75
		var scatter := (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.25
		var sample := clampf((thud + scatter) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 30000.0))

	wav.data = bytes
	return wav

func _synth_footstep_gravel() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.11) # 110ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 45.0)
		# Dual crunch grains staggered
		var g1 := (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.5
		var t2 := maxf(0.0, t - 0.02)
		var g2 := (randf() * 2.0 - 1.0) * exp(-t2 * 65.0) * 0.4
		var grit_body := sin(TAU * 420.0 * t) * env * 0.25
		var sample := clampf((g1 + g2 + grit_body) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 30000.0))

	wav.data = bytes
	return wav

# --- B. Task & Interaction Sounds ---
func _synth_channel_start() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.18) # 180ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * (float(i) / float(count)))
		var freq := lerpf(220.0, 440.0, t / 0.18)
		var sample := sin(TAU * freq * t) * env * 0.8
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_channel_tick() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.04) # 40ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 80.0)
		var sample := sin(TAU * 580.0 * t) * env * 0.5
		bytes.encode_s16(i * 2, int(sample * 24000.0))

	wav.data = bytes
	return wav

func _synth_task_complete() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.35) # 350ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 9.0)
		# Triumphant bright dual chime (E5: 659.2Hz + B5: 987.7Hz + sparkle E6: 1318.5Hz)
		var tone := sin(TAU * 659.2 * t) * 0.45 + sin(TAU * 987.7 * t) * 0.35 + sin(TAU * 1318.5 * t) * 0.20
		var sample := clampf(tone * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_task_jammed() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.22) # 220ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 12.0)
		var freq := lerpf(180.0, 80.0, t / 0.22)
		# Harsh square/saw buzz
		var buzz := 1.0 if (fmod(t * freq, 1.0) > 0.5) else -1.0
		var sample := buzz * env * 0.65
		bytes.encode_s16(i * 2, int(sample * 26000.0))

	wav.data = bytes
	return wav

func _synth_alcove_inspect() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.32) # 320ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * minf(1.0, t / 0.15)) * exp(-t * 6.5)
		# Mysterious subterranean resonant drone (D3: 146.8Hz + A3: 220Hz + F#3: 185Hz)
		var chord := sin(TAU * 146.8 * t) * 0.45 + sin(TAU * 220.0 * t) * 0.35 + sin(TAU * 185.0 * t) * 0.20
		var sample := clampf(chord * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_archive_unseal() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.65) # 650ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 4.5)
		var bass := sin(TAU * 110.0 * t) * 0.4 * exp(-t * 6.0)
		var chime := sin(TAU * 880.0 * t) * 0.3 + sin(TAU * 1320.0 * t) * 0.2 + sin(TAU * 1760.0 * t) * 0.15
		var sample := clampf((bass + chime * env) * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

# --- C. Tactical Combat & Abilities ---
func _synth_shove_impact() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.16) # 160ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 30.0)
		var freq := lerpf(175.0, 40.0, t / 0.16)
		var punch := sin(TAU * freq * t) * env * 0.75
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.35
		var sample := clampf((punch + noise) * 0.95, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 31000.0))

	wav.data = bytes
	return wav

func _synth_speed_burst() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.25) # 250ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * (float(i) / float(count)))
		var freq := lerpf(350.0, 950.0, t / 0.25)
		var whoosh := (randf() * 2.0 - 1.0) * 0.4 + sin(TAU * freq * t) * 0.6
		var sample := clampf(whoosh * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_zone_mist() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.35) # 350ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * minf(1.0, t / 0.08)) * exp(-t * 6.0)
		var hiss := (randf() * 2.0 - 1.0) * env * 0.75
		bytes.encode_s16(i * 2, int(hiss * 25000.0))

	wav.data = bytes
	return wav

func _synth_zone_roots() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.28) # 280ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 14.0)
		# 3 wood cracks at 0ms, 40ms, 90ms
		var crack1 := exp(-t * 80.0) * sin(TAU * 620.0 * t)
		var t2 := maxf(0.0, t - 0.04)
		var crack2 := exp(-t2 * 90.0) * sin(TAU * 480.0 * t2)
		var t3 := maxf(0.0, t - 0.09)
		var crack3 := exp(-t3 * 85.0) * sin(TAU * 750.0 * t3)
		var sample := clampf((crack1 * 0.4 + crack2 * 0.35 + crack3 * 0.35) * env * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 29000.0))

	wav.data = bytes
	return wav

func _synth_zone_shield() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.30) # 300ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 10.0)
		# Crystalline chime (G5: 784Hz + D6: 1175Hz + G6: 1568Hz)
		var ring := sin(TAU * 784.0 * t) * 0.5 + sin(TAU * 1175.0 * t) * 0.35 + sin(TAU * 1568.0 * t) * 0.20
		var sample := clampf(ring * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_zone_sparks() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.25) # 250ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 12.0)
		var buzz := 1.0 if (fmod(t * 320.0, 1.0) > 0.4) else -1.0
		var crackle := (randf() * 2.0 - 1.0) if (randf() > 0.4) else 0.0
		var sample := clampf((buzz * 0.4 + crackle * 0.6) * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

# --- D. Ceremonies & Match Phase Stingers ---
func _synth_phase_escalation() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.70) # 700ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * minf(1.0, t / 0.1)) * exp(-t * 2.8)
		# Rising warning klaxon (440Hz -> 660Hz)
		var freq := 440.0 + sin(TAU * 2.5 * t) * 180.0
		var tone := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.25
		var sample := clampf(tone * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_phase_court() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.65) # 650ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Heavy wooden gavel strike + hollow wood resonance + ceremonial bell
		var gavel := exp(-t * 35.0) * (sin(TAU * 115.0 * t) * 0.6 + sin(TAU * 285.0 * t) * 0.35)
		var bell := exp(-t * 6.5) * (sin(TAU * 587.3 * t) * 0.35 + sin(TAU * 880.0 * t) * 0.20)
		var sample := clampf((gavel + bell) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 29000.0))

	wav.data = bytes
	return wav

func _synth_court_vote() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.24) # 240ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 15.0)
		var click := (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.4
		var chime := sin(TAU * 659.2 * t) * env * 0.6
		var sample := clampf((click + chime) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_phase_finale() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.75) # 750ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Urgent three-burst alarm ping
		var p_t := fmod(t, 0.22)
		var p_env := exp(-p_t * 22.0)
		var alarm := sin(TAU * 880.0 * p_t) * p_env * 0.8
		var sample := clampf(alarm, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_victory_fanfare() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.85) # 850ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Ascending triad arpeggio (C4: 261Hz, E4: 329Hz, G4: 392Hz, C5: 523Hz)
		var chord := 0.0
		if t < 0.15:
			chord = sin(TAU * 261.6 * t) * exp(-(t) * 8.0)
		elif t < 0.30:
			var t1 := t - 0.15
			chord = sin(TAU * 329.6 * t1) * exp(-(t1) * 8.0)
		elif t < 0.45:
			var t2 := t - 0.30
			chord = sin(TAU * 392.0 * t2) * exp(-(t2) * 8.0)
		else:
			var t3 := t - 0.45
			var sustain := exp(-t3 * 3.5)
			chord = (sin(TAU * 523.25 * t3) * 0.5 + sin(TAU * 659.25 * t3) * 0.3 + sin(TAU * 783.99 * t3) * 0.2) * sustain
		var sample := clampf(chord * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_defeat_sting() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.85) # 850ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Somber minor descent (G3: 196Hz -> Eb3: 155.5Hz -> C3: 130.8Hz)
		var chord := 0.0
		if t < 0.22:
			chord = sin(TAU * 196.0 * t) * exp(-(t) * 6.0)
		elif t < 0.44:
			var t1 := t - 0.22
			chord = sin(TAU * 155.56 * t1) * exp(-(t1) * 6.0)
		else:
			var t2 := t - 0.44
			var sustain := exp(-t2 * 4.0)
			chord = (sin(TAU * 130.81 * t2) * 0.6 + sin(TAU * 196.0 * t2) * 0.3) * sustain
		var sample := clampf(chord * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

# --- E. Audio Preview & Atmosphere Stems ---
func _synth_test_tone() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.42) # 420ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Dual melodic chime (C5: 523.25Hz -> E5: 659.25Hz)
		var freq := 523.25 if t < 0.18 else 659.25
		var t_note := t if t < 0.18 else (t - 0.18)
		var env := exp(-t_note * 9.0) * minf(1.0, t_note * 80.0)
		var harmonic := sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 2.0 * t) * 0.20
		var sample := clampf(harmonic * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_covert_hunch() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.28) # 280ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * minf(1.0, t / 0.08)) * exp(-t * 9.5)
		# Tense sub-bass heartbeat pulse (95Hz down to 62Hz)
		var freq := lerpf(95.0, 62.0, t / 0.28)
		var sub := sin(TAU * freq * t) * 0.85 + (randf() * 0.15 - 0.075) * exp(-t * 22.0)
		var sample := clampf(sub * env * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 28000.0))

	wav.data = bytes
	return wav

func _synth_ui_click() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.04) # 40ms
	var wav := _create_wav(count)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 110.0)
		var click := sin(TAU * 1650.0 * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.4
		var sample := clampf(click * env * 0.8, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 26000.0))

	wav.data = bytes
	return wav

# --- F. Ambient Seamless Loops (1.5s loop duration) ---
func _synth_ambient_town_square() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 1.5)
	var wav := _create_wav(count, true)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Open plaza breeze: filtered brown noise + soft harmonic oscillation
		var breeze := (sin(TAU * 0.66 * t) * 0.3 + 0.7) * (randf() * 0.4 - 0.2)
		var sub := sin(TAU * 65.0 * t) * 0.12
		var sample := clampf((breeze + sub) * 0.6, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 20000.0))

	wav.data = bytes
	return wav

func _synth_ambient_pump_station() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 1.5)
	var wav := _create_wav(count, true)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Industrial machine hum: 60Hz fundamental + 120Hz + hydraulic pulse
		var m60 := sin(TAU * 60.0 * t) * 0.45
		var m120 := sin(TAU * 120.0 * t) * 0.25
		var hydro := sin(TAU * 1.33 * t) * 0.2 * (randf() * 0.3 - 0.15)
		var sample := clampf((m60 + m120 + hydro) * 0.65, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 22000.0))

	wav.data = bytes
	return wav

func _synth_ambient_greenhouse() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 1.5)
	var wav := _create_wav(count, true)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Bio-hum: gentle warm chord (220Hz + 330Hz) + soft rustle
		var bio := (sin(TAU * 220.0 * t) * 0.25 + sin(TAU * 330.0 * t) * 0.15) * 0.6
		var rustle := (randf() * 0.2 - 0.1) * (sin(TAU * 0.8 * t) * 0.4 + 0.6)
		var sample := clampf((bio + rustle) * 0.55, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 20000.0))

	wav.data = bytes
	return wav

func _synth_ambient_salvage_yard() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 1.5)
	var wav := _create_wav(count, true)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Scrap yard wind & metallic resonance (85Hz + shimmering high metallic tones)
		var rumble := sin(TAU * 85.0 * t) * 0.3
		var shimmer := sin(TAU * 1420.0 * t) * 0.1 * sin(TAU * 2.0 * t)
		var wind := (randf() * 0.3 - 0.15) * 0.5
		var sample := clampf((rumble + shimmer + wind) * 0.6, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 21000.0))

	wav.data = bytes
	return wav

# ------------------------------------------------------------------------------
# 2. Audio Channel Setup & Management
# ------------------------------------------------------------------------------
func _setup_audio_channels() -> void:
	if not _sfx_players_2d.is_empty():
		return
	# 2D SFX Players pool (8 reusable voices)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "SFX2D_%d" % i
		player.bus = "Master"
		add_child(player)
		_sfx_players_2d.append(player)

	# 3D Positional SFX Players pool (12 reusable spatial voices)
	for i in range(12):
		var p3d := AudioStreamPlayer3D.new()
		p3d.name = "SFX3D_%d" % i
		p3d.max_distance = 35.0
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3d.bus = "Master"
		add_child(p3d)
		_sfx_players_3d.append(p3d)

	# Ambient Sector Looper Players (4 cross-fading sector voices)
	for sec_id in ambient_library.keys():
		var amb_player := AudioStreamPlayer.new()
		amb_player.name = "Ambient_" + sec_id
		amb_player.stream = ambient_library[sec_id]
		amb_player.bus = "Master"
		amb_player.volume_db = -80.0 # start silent
		add_child(amb_player)
		_ambient_players[sec_id] = amb_player

func start_ambient() -> void:
	for sec_id in _ambient_players.keys():
		var player: AudioStreamPlayer = _ambient_players[sec_id]
		if player.is_inside_tree() and not player.playing:
			player.play()

# ------------------------------------------------------------------------------
# 3. Audio Mixer & Volume Control APIs
# ------------------------------------------------------------------------------
func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	if master_volume > 0.001:
		is_muted = false
	_apply_volumes()

func get_master_volume() -> float:
	return master_volume

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()

func get_sfx_volume() -> float:
	return sfx_volume

func set_ambient_volume(val: float) -> void:
	ambient_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()

func get_ambient_volume() -> float:
	return ambient_volume

func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()

func get_music_volume() -> float:
	return music_volume

func toggle_mute() -> bool:
	if is_muted:
		is_muted = false
		master_volume = _pre_mute_master if _pre_mute_master > 0.05 else 1.0
	else:
		is_muted = true
		_pre_mute_master = master_volume if master_volume > 0.05 else 1.0
		master_volume = 0.0
	_apply_volumes()
	return is_muted

func set_muted(mute: bool) -> void:
	if is_muted == mute:
		return
	toggle_mute()

func is_muted_active() -> bool:
	return is_muted

func reset_to_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	ambient_volume = 0.75
	music_volume = 0.8
	is_muted = false
	_pre_mute_master = 1.0
	_apply_volumes()

func _apply_volumes() -> void:
	for sec_id in _ambient_players.keys():
		var player: AudioStreamPlayer = _ambient_players[sec_id]
		var is_target: bool = (sec_id == _target_ambient_sector)
		var eff_vol: float = (ambient_volume * master_volume) if not is_muted else 0.0
		var target_vol_db: float = (linear_to_db(clampf(eff_vol, 0.0001, 1.0)) - 4.0) if is_target else -80.0
		player.volume_db = target_vol_db

# ------------------------------------------------------------------------------
# 4. Audio Playback APIs
# ------------------------------------------------------------------------------
func play_sfx(sound_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0, is_music: bool = false) -> AudioStreamPlayer:
	if not sfx_library.has(sound_name):
		return null
	var player: AudioStreamPlayer = _get_available_2d_player()
	if player == null:
		return null
	player.stream = sfx_library[sound_name]
	player.pitch_scale = clampf(pitch_scale, 0.4, 2.5)
	player.volume_db = _calc_music_volume_db(volume_offset_db) if is_music else _calc_sfx_volume_db(volume_offset_db)
	if player.is_inside_tree():
		player.play()
	return player

func play_sfx_3d(sound_name: String, pos: Vector3, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> AudioStreamPlayer3D:
	if not sfx_library.has(sound_name):
		return null
	var p3d: AudioStreamPlayer3D = _get_available_3d_player()
	if p3d == null:
		return null
	p3d.stream = sfx_library[sound_name]
	if p3d.is_inside_tree():
		p3d.global_position = pos
	else:
		p3d.position = pos
	p3d.pitch_scale = clampf(pitch_scale, 0.4, 2.5)
	p3d.volume_db = _calc_sfx_volume_db(volume_offset_db)
	if p3d.is_inside_tree():
		p3d.play()
	return p3d

func play_footstep(sector_id: String, pos: Vector3, is_sprint: bool = false, entity_id: int = 1, custom_time: float = -1.0) -> void:
	var now: float = custom_time if custom_time >= 0.0 else (float(Time.get_ticks_msec()) * 0.001)
	var min_interval := 0.24 if is_sprint else 0.36
	if _last_footstep_time.has(entity_id):
		if now - float(_last_footstep_time[entity_id]) < min_interval:
			return
	_last_footstep_time[entity_id] = now

	var sound_key := "footstep_stone"
	match sector_id:
		"pump_station":
			sound_key = "footstep_metal"
		"greenhouse":
			sound_key = "footstep_dirt"
		"salvage_yard":
			sound_key = "footstep_gravel"
		_:
			sound_key = "footstep_stone"

	var pitch := randf_range(0.92, 1.08)
	if is_sprint:
		pitch *= 1.12
	play_sfx_3d(sound_key, pos, pitch, -2.0)

func set_ambient_sector(sector_id: String) -> void:
	if ambient_library.has(sector_id):
		_target_ambient_sector = sector_id

func update_ambient_crossfade(delta: float) -> void:
	for sec_id in _ambient_players.keys():
		var player: AudioStreamPlayer = _ambient_players[sec_id]
		var is_target: bool = (sec_id == _target_ambient_sector)
		var eff_vol: float = (ambient_volume * master_volume) if not is_muted else 0.0
		var target_vol_db: float = (linear_to_db(clampf(eff_vol, 0.0001, 1.0)) - 4.0) if is_target else -80.0
		player.volume_db = lerpf(player.volume_db, target_vol_db, clampf(delta * _fade_speed, 0.0, 1.0))

func play_phase_stinger(phase_name: String) -> void:
	match phase_name:
		"escalation":
			play_sfx("phase_escalation", 1.0, 1.0, true)
		"court":
			play_sfx("phase_court", 1.0, 2.0, true)
		"court_vote":
			play_sfx("court_vote", 1.0, 0.5, true)
		"finale":
			play_sfx("phase_finale", 1.0, 1.5, true)
		"victory":
			play_sfx("victory_fanfare", 1.0, 2.0, true)
		"defeat":
			play_sfx("defeat_sting", 1.0, 2.0, true)

func _calc_sfx_volume_db(offset_db: float) -> float:
	if is_muted or master_volume <= 0.0001 or sfx_volume <= 0.0001:
		return -80.0
	var vol_linear := clampf(sfx_volume * master_volume, 0.0001, 1.0)
	return linear_to_db(vol_linear) + offset_db

func _calc_music_volume_db(offset_db: float) -> float:
	if is_muted or master_volume <= 0.0001 or music_volume <= 0.0001:
		return -80.0
	var vol_linear := clampf(music_volume * master_volume, 0.0001, 1.0)
	return linear_to_db(vol_linear) + offset_db

func _get_available_2d_player() -> AudioStreamPlayer:
	for p in _sfx_players_2d:
		if not p.playing:
			return p
	return _sfx_players_2d[0] if _sfx_players_2d.size() > 0 else null

func _get_available_3d_player() -> AudioStreamPlayer3D:
	for p in _sfx_players_3d:
		if not p.playing:
			return p
	return _sfx_players_3d[0] if _sfx_players_3d.size() > 0 else null
