extends Node
## Procedural sound: every effect and the ambient music loop are synthesized
## into AudioStreamWAV buffers at startup. No audio files are shipped.

const RATE := 22050
var enabled := true
var sounds := {}
var players: Array = []
var music: AudioStreamPlayer
var _next := 0

func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -14.0
	add_child(music)
	sounds["click"] = _tone([880.0], 0.05, 0.25, "sq")
	sounds["plant"] = _tone([520.0, 780.0], 0.09, 0.3, "tri")
	sounds["harvest"] = _tone([660.0, 880.0, 1175.0], 0.07, 0.35, "tri")
	sounds["build"] = _noise_thud()
	sounds["error"] = _tone([200.0, 150.0], 0.09, 0.3, "sq")
	sounds["mission"] = _tone([523.0, 659.0, 784.0, 1046.0], 0.11, 0.35, "tri")
	sounds["alert"] = _tone([740.0, 520.0, 740.0, 520.0], 0.12, 0.3, "sq")
	sounds["rover"] = _tone([300.0, 360.0], 0.08, 0.25, "saw")
	sounds["rocket"] = _rumble(1.6)
	sounds["coin"] = _tone([988.0, 1319.0], 0.06, 0.3, "sq")
	sounds["research"] = _tone([440.0, 554.0, 659.0, 880.0], 0.08, 0.3, "sin")
	sounds["fest"] = _tone([523.0, 659.0, 784.0, 659.0, 784.0, 1046.0, 1319.0], 0.13, 0.35, "tri")

func play(name: String) -> void:
	if not enabled or not sounds.has(name):
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[name]
	p.play()

func start_music() -> void:
	if music.stream == null:
		music.stream = _ambient()
	if enabled and not music.playing:
		music.play()

func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		start_music()
	else:
		music.stop()

func _wav(data: PackedByteArray, loop_len: int = 0) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop_len > 0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = loop_len
	return w

func _osc(kind: String, ph: float) -> float:
	var f := fmod(ph, 1.0)
	match kind:
		"sq": return 1.0 if f < 0.5 else -1.0
		"tri": return 4.0 * absf(f - 0.5) - 1.0
		"saw": return 2.0 * f - 1.0
	return sin(ph * TAU)

func _tone(freqs: Array, step: float, vol: float, kind: String) -> AudioStreamWAV:
	var n := int(RATE * step * freqs.size() + RATE * 0.05)
	var d := PackedByteArray()
	d.resize(n * 2)
	var per := int(RATE * step)
	var ph := 0.0
	for i in n:
		var k := mini(i / per, freqs.size() - 1)
		var local := float(i - k * per) / per
		ph += float(freqs[k]) / RATE
		var env := clampf(1.0 - local, 0.0, 1.0) * clampf(local * 40.0, 0.0, 1.0)
		if i >= per * freqs.size():
			env = 0.0
		d.encode_s16(i * 2, int(_osc(kind, ph) * env * vol * 32000.0))
	return _wav(d)

func _noise_thud() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var d := PackedByteArray()
	d.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var lp := 0.0
	for i in n:
		var e := 1.0 - float(i) / n
		lp = lp * 0.85 + r.randf_range(-1.0, 1.0) * 0.15
		var s := lp * 2.0 + sin(i * TAU * 90.0 / RATE) * 0.5
		d.encode_s16(i * 2, int(clampf(s * e * e, -1.0, 1.0) * 26000.0))
	return _wav(d)

func _rumble(sec: float) -> AudioStreamWAV:
	var n := int(RATE * sec)
	var d := PackedByteArray()
	d.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var lp := 0.0
	for i in n:
		var x := float(i) / n
		var e := clampf(x * 6.0, 0.0, 1.0) * (1.0 - x)
		lp = lp * 0.93 + r.randf_range(-1.0, 1.0) * 0.07
		d.encode_s16(i * 2, int(clampf(lp * 4.0 * e, -1.0, 1.0) * 22000.0))
	return _wav(d)

func _ambient() -> AudioStreamWAV:
	# 4 slow pad chords plus a twinkling arpeggio, 16 s seamless loop.
	var rate := 8000
	var sec := 16.0
	var n := int(rate * sec)
	var d := PackedByteArray()
	d.resize(n * 2)
	var chords := [[220.0, 277.2, 329.6], [196.0, 246.9, 293.7], [174.6, 220.0, 261.6], [196.0, 246.9, 329.6]]
	var arp := [659.3, 784.0, 987.8, 784.0, 880.0, 659.3, 587.3, 784.0]
	for i in n:
		var tt := float(i) / rate
		var ci := int(tt / 4.0) % 4
		var cl := fmod(tt, 4.0) / 4.0
		var ce := sin(cl * PI)
		var s := 0.0
		for f in chords[ci]:
			s += sin(tt * TAU * float(f)) * 0.18 + sin(tt * TAU * float(f) * 2.003) * 0.04
		s *= 0.4 + 0.6 * ce
		var ai := int(tt * 2.0) % arp.size()
		var al := fmod(tt * 2.0, 1.0)
		s += sin(tt * TAU * float(arp[ai])) * 0.08 * exp(-al * 5.0)
		d.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 30000.0))
	var w := _wav(d, n)
	w.mix_rate = rate
	return w
