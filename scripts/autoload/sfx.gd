extends Node
## All sound is synthesised at start-up (no audio files): little effects, a looping
## sea ambience and a hicaz-flavoured plucked tune. Jobs are spread over frames so
## the title screen never freezes while the samples are rendered.

const RATE := 16000
const BPM := 96.0
const SFX_NAMES: Array[String] = [
	"tick", "clink", "cash", "pip", "ping", "pour", "wash", "hiss", "bell", "whistle",
	"grumble", "fanfare", "lose", "gull", "horn", "meow", "click", "whoosh", "star",
]
const MIN_GAP := {
	"tick": 0.04, "clink": 0.04, "cash": 0.08, "pip": 0.1, "ping": 0.1, "pour": 0.1, "wash": 0.1,
	"hiss": 0.2, "bell": 0.2, "whistle": 0.5, "grumble": 0.3, "fanfare": 0.5, "lose": 0.5,
	"gull": 1.0, "horn": 2.0, "meow": 0.5, "click": 0.05, "whoosh": 0.2, "star": 0.15,
}
# hicaz on D: D Eb F# G A Bb C
const NOTE := {
	"D3": 146.83, "A3": 220.0, "D4": 293.66, "Eb4": 311.13, "F#4": 369.99, "G4": 392.0,
	"A4": 440.0, "Bb4": 466.16, "C5": 523.25, "D5": 587.33,
}
## [beat, length in beats, note]
const MELODY: Array = [
	[0.0, 1.0, "D4"], [1.0, 0.5, "F#4"], [1.5, 0.5, "G4"], [2.0, 1.0, "A4"], [3.0, 0.5, "Bb4"], [3.5, 0.5, "A4"],
	[4.0, 1.0, "G4"], [5.0, 0.5, "F#4"], [5.5, 0.5, "Eb4"], [6.0, 2.0, "D4"],
	[8.0, 1.0, "A4"], [9.0, 0.5, "C5"], [9.5, 0.5, "Bb4"], [10.0, 1.0, "A4"], [11.0, 0.5, "G4"], [11.5, 0.5, "F#4"],
	[12.0, 1.0, "G4"], [13.0, 1.0, "A4"], [14.0, 1.0, "Bb4"], [15.0, 1.0, "A4"],
	[16.0, 1.5, "D5"], [17.5, 0.5, "C5"], [18.0, 1.0, "Bb4"], [19.0, 1.0, "A4"],
	[20.0, 0.5, "G4"], [20.5, 0.5, "F#4"], [21.0, 1.0, "G4"], [22.0, 2.0, "A4"],
	[24.0, 1.0, "Bb4"], [25.0, 0.5, "A4"], [25.5, 0.5, "G4"], [26.0, 1.0, "F#4"], [27.0, 1.0, "Eb4"],
	[28.0, 2.0, "D4"],
]
const LOOP_BEATS := 32
const BARS := 8

var enabled := true
## Set while the simulation is fast-forwarded so nothing piles up.
var silent := false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_play: Dictionary = {}
var _jobs: Array[Callable] = []
var _music_buf := PackedFloat32Array()
var _music_player: AudioStreamPlayer
var _amb_player: AudioStreamPlayer
var _music_wanted := true
var _gull_timer := 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--force-audio"):
		enabled = false
		set_process(false)
		return
	_setup_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.BUS_SFX
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = Settings.BUS_MUSIC
	add_child(_music_player)
	_amb_player = AudioStreamPlayer.new()
	_amb_player.bus = Settings.BUS_SFX
	_amb_player.volume_db = -22.0
	add_child(_amb_player)
	for n in SFX_NAMES:
		_jobs.append(_job_sfx.bind(n))
	_jobs.append(_job_ambience)
	_music_buf.resize(int(LOOP_BEATS * 60.0 / BPM * RATE))
	for note in MELODY:
		_jobs.append(_job_melody_note.bind(note))
	for bar in BARS:
		_jobs.append(_job_bass_bar.bind(bar))
		_jobs.append(_job_drum_bar.bind(bar))
	_jobs.append(_job_finish_music)
	Settings.changed.connect(apply_volumes)
	apply_volumes()


func _exit_tree() -> void:
	# release the streams so nothing is still playing when the engine shuts down
	for p in _players:
		p.stop()
		p.stream = null
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _amb_player != null:
		_amb_player.stop()
		_amb_player.stream = null
	_streams.clear()


func _setup_buses() -> void:
	for bus_name in [Settings.BUS_MUSIC, Settings.BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	if not enabled:
		return
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, Settings.muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(Settings.BUS_MUSIC), linear_to_db(maxf(Settings.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(Settings.BUS_SFX), linear_to_db(maxf(Settings.sfx_volume, 0.0001)))


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		job.call()
		if Time.get_ticks_usec() - t0 > 7000:
			break
	if _music_wanted and _music_player.stream != null and not _music_player.playing:
		_music_player.play()
	_gull_timer -= delta
	if _gull_timer <= 0.0:
		_gull_timer = _rng.randf_range(6.0, 15.0)
		if not GameState.paused and _rng.randf() < 0.6:
			play("gull")


## Plays a named effect. Unknown or not-yet-rendered names are ignored.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or silent or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = MIN_GAP.get(sound, 0.04)
	if _last_play.has(sound) and now - float(_last_play[sound]) < gap:
		return
	_last_play[sound] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func set_music(on: bool) -> void:
	_music_wanted = on
	if not enabled or _music_player == null:
		return
	if not on:
		_music_player.stop()


func is_ready() -> bool:
	return _jobs.is_empty()


# ---- synthesis helpers -----------------------------------------------------

func _blank(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Adds a decaying tone. wave: 0 sine, 1 square, 2 triangle, 3 saw. slide is Hz over the duration.
func _tone(b: PackedFloat32Array, freq: float, dur: float, wave: int, vol: float, slide: float = 0.0, delay: float = 0.0) -> void:
	var n := int(dur * RATE)
	var s0 := int(delay * RATE)
	var phase := 0.0
	var attack := maxf(1.0, 0.012 * RATE)
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		phase += (freq + slide * t) / RATE
		var f := phase - floorf(phase)
		var v: float
		match wave:
			0:
				v = sin(TAU * phase)
			1:
				v = 1.0 if f < 0.5 else -1.0
			2:
				v = absf(f * 4.0 - 2.0) - 1.0
			_:
				v = f * 2.0 - 1.0
		var env := minf(i / attack, 1.0) * (1.0 - t) * (1.0 - t)
		b[idx] += v * env * vol


## Band-limited noise burst: low-pass at lo, high-pass at hi (each swept from *0 to *1).
func _noise(b: PackedFloat32Array, dur: float, vol: float, lp0: float, lp1: float, hp0: float, hp1: float, delay: float = 0.0) -> void:
	var n := int(dur * RATE)
	var s0 := int(delay * RATE)
	var lp := 0.0
	var hp := 0.0
	var attack := maxf(1.0, 0.02 * RATE)
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var a_lp := 1.0 - exp(-TAU * lerpf(lp0, lp1, t) / RATE)
		var a_hp := 1.0 - exp(-TAU * lerpf(hp0, hp1, t) / RATE)
		var w := _rng.randf() * 2.0 - 1.0
		lp += a_lp * (w - lp)
		hp += a_hp * (lp - hp)
		var env := minf(i / attack, 1.0) * (1.0 - t)
		b[idx] += (lp - hp) * env * vol * 2.0


func _to_wav(b: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


func _job_sfx(sound: String) -> void:
	_streams[sound] = _to_wav(_render(sound))


func _render(sound: String) -> PackedFloat32Array:
	var b: PackedFloat32Array
	match sound:
		"tick":
			b = _blank(0.08)
			_tone(b, 620.0, 0.05, 2, 0.35)
		"click":
			b = _blank(0.1)
			_tone(b, 900.0, 0.06, 2, 0.3)
			_tone(b, 1350.0, 0.05, 0, 0.18, 0.0, 0.015)
		"clink":
			b = _blank(0.3)
			_tone(b, 2700.0, 0.2, 2, 0.4)
			_tone(b, 3900.0, 0.12, 0, 0.22, 0.0, 0.02)
		"cash":
			b = _blank(0.55)
			_noise(b, 0.06, 0.25, 7000.0, 7000.0, 3500.0, 3500.0)
			_tone(b, 988.0, 0.14, 1, 0.16, 0.0, 0.02)
			_tone(b, 1319.0, 0.24, 1, 0.16, 0.0, 0.09)
			_tone(b, 1976.0, 0.32, 2, 0.2, 0.0, 0.16)
		"pip":
			b = _blank(0.25)
			_tone(b, 880.0, 0.12, 0, 0.3)
			_tone(b, 1175.0, 0.14, 0, 0.26, 0.0, 0.07)
		"ping":
			b = _blank(0.5)
			_tone(b, 1760.0, 0.38, 0, 0.35)
			_tone(b, 2217.0, 0.32, 0, 0.2, 0.0, 0.1)
		"pour":
			b = _blank(0.5)
			_noise(b, 0.38, 0.5, 1800.0, 2400.0, 700.0, 900.0)
			_tone(b, 1900.0, 0.08, 0, 0.12, 0.0, 0.28)
		"wash":
			b = _blank(0.65)
			_noise(b, 0.55, 0.45, 2600.0, 1400.0, 900.0, 600.0)
			_tone(b, 2400.0, 0.1, 2, 0.16, 0.0, 0.34)
		"hiss":
			b = _blank(0.7)
			_noise(b, 0.65, 0.5, 7500.0, 7500.0, 2500.0, 4500.0)
		"bell":
			b = _blank(1.2)
			_tone(b, 1568.0, 0.95, 0, 0.3)
			_tone(b, 2093.0, 0.85, 0, 0.2, 0.0, 0.02)
			_tone(b, 1568.0, 0.75, 0, 0.2, 0.0, 0.22)
			_tone(b, 2349.0, 0.65, 0, 0.14, 0.0, 0.24)
		"whistle":
			b = _blank(1.25)
			var phase := 0.0
			var n := int(1.1 * RATE)
			for i in n:
				var t := float(i) / RATE
				var f := 1250.0 + 300.0 * minf(t / 0.15, 1.0) - 50.0 * clampf((t - 0.15) / 0.85, 0.0, 1.0)
				f += 40.0 * sin(TAU * 9.0 * t)
				phase += f / RATE
				var env := minf(t / 0.08, 1.0) * (1.0 - clampf((t - 0.8) / 0.3, 0.0, 1.0))
				b[i] = sin(TAU * phase) * env * 0.25
		"grumble":
			b = _blank(0.7)
			_tone(b, 170.0, 0.55, 3, 0.34, -90.0)
			_tone(b, 120.0, 0.4, 3, 0.2, -30.0, 0.18)
			# crude low-pass: smooth the saw
			var prev := 0.0
			for i in b.size():
				prev += 0.18 * (b[i] - prev)
				b[i] = prev * 1.6
		"fanfare":
			b = _blank(1.4)
			var fs := [523.0, 659.0, 784.0, 1047.0]
			for i in fs.size():
				_tone(b, fs[i], 0.42, 2, 0.28, 0.0, i * 0.13)
			_tone(b, 1319.0, 0.75, 0, 0.22, 0.0, 0.55)
		"lose":
			b = _blank(1.0)
			var ls := [392.0, 349.0, 311.0, 262.0]
			for i in ls.size():
				_tone(b, ls[i], 0.42, 2, 0.28, 0.0, i * 0.18)
		"gull":
			b = _blank(1.0)
			_tone(b, 1500.0, 0.22, 3, 0.07, -800.0)
			_tone(b, 1100.0, 0.2, 3, 0.07, -200.0, 0.26)
			_tone(b, 1700.0, 0.3, 3, 0.06, -900.0, 0.52)
		"horn":
			b = _blank(1.6)
			_tone(b, 98.0, 1.4, 3, 0.2)
			_tone(b, 147.0, 1.4, 3, 0.14)
			var prev2 := 0.0
			for i in b.size():
				prev2 += 0.12 * (b[i] - prev2)
				b[i] = prev2 * 2.2
		"meow":
			b = _blank(0.5)
			_tone(b, 700.0, 0.35, 2, 0.28, 400.0)
			_tone(b, 1000.0, 0.2, 0, 0.12, -300.0, 0.05)
		"whoosh":
			b = _blank(0.3)
			_noise(b, 0.25, 0.3, 500.0, 3000.0, 150.0, 800.0)
		"star":
			b = _blank(0.5)
			_tone(b, 1046.0, 0.3, 2, 0.28)
			_tone(b, 1568.0, 0.4, 0, 0.18, 0.0, 0.05)
		_:
			b = _blank(0.05)
	return b


func _job_ambience() -> void:
	var secs := 4.0
	var b := _blank(secs)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += 0.04 * (w - lp)
		var swell := 0.55 + 0.45 * sin(TAU * t / secs)
		b[i] = lp * 2.4 * swell
	var wav := _to_wav(b, true)
	_amb_player.stream = wav
	_amb_player.play()


# ---- music -----------------------------------------------------------------

func _beat_to_index(beat: float) -> int:
	return int(beat * 60.0 / BPM * RATE)


## Plucked string: a few harmonics with a fast decay, wrapped around the loop end.
func _job_melody_note(note: Array) -> void:
	var f: float = NOTE[note[2]]
	var start := _beat_to_index(note[0])
	var dur := minf(float(note[1]) * 60.0 / BPM + 0.45, 1.6)
	var n := int(dur * RATE)
	var size := _music_buf.size()
	for i in n:
		var t := float(i) / RATE
		var decay := exp(-t * 3.2)
		var v := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.25 * sin(TAU * f * 3.0 * t) * exp(-t * 9.0)
		var attack := minf(t / 0.006, 1.0)
		var idx := (start + i) % size
		_music_buf[idx] += v * decay * attack * 0.2


func _job_bass_bar(bar: int) -> void:
	var size := _music_buf.size()
	for half in 2:
		var f: float = NOTE["D3"] if half == 0 else NOTE["A3"]
		var start := _beat_to_index(bar * 4.0 + half * 2.0)
		var n := int(1.4 * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := minf(t / 0.03, 1.0) * exp(-t * 2.2)
			_music_buf[(start + i) % size] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.16


func _job_drum_bar(bar: int) -> void:
	var size := _music_buf.size()
	# frame drum: low thump on 1 and 3, soft tick on the off-beats
	for hit in 4:
		var start := _beat_to_index(bar * 4.0 + hit)
		var thump := hit % 2 == 0
		var n := int((0.18 if thump else 0.07) * RATE)
		var lp := 0.0
		for i in n:
			var t := float(i) / RATE
			var env := exp(-t * (18.0 if thump else 45.0))
			var v: float
			if thump:
				v = sin(TAU * (95.0 - 40.0 * t) * t) * env * 0.3
			else:
				lp += 0.35 * ((_rng.randf() * 2.0 - 1.0) - lp)
				v = lp * env * 0.07
			_music_buf[(start + i) % size] += v


func _job_finish_music() -> void:
	var peak := 0.0
	for v in _music_buf:
		peak = maxf(peak, absf(v))
	if peak > 0.85:
		var k := 0.85 / peak
		for i in _music_buf.size():
			_music_buf[i] *= k
	_music_player.stream = _to_wav(_music_buf, true)
	_music_player.volume_db = -4.0
