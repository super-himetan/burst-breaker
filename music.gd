extends RefCounted
## Renders the background loop from code, like every other sound in the game.
## Notes wrap around the end of the buffer, so the loop has no seam.

const SAMPLE_RATE := 22050
const BPM := 112.0
const STEPS_PER_BAR := 16
const PEAK := 0.8
## Bar by bar: root note (MIDI) and whether the chord is minor.
const CHORDS: Array[Array] = [[45, true], [41, false], [48, false], [43, false], [45, true], [41, false], [43, false], [40, false]]
const ARP: Array[int] = [0, 2, 1, 2, 3, 2, 1, 2, 0, 2, 1, 3, 2, 3, 1, 2]
const BASS_STEPS: Array[int] = [0, 3, 6, 8, 11, 14]
## Sparse tune over the last four bars: [step, MIDI note].
const MELODY: Array[Array] = [
	[64, 76], [68, 79], [72, 81], [78, 79], [80, 77], [84, 76], [88, 72], [94, 74],
	[96, 74], [100, 76], [104, 79], [110, 76], [112, 75], [116, 76], [120, 71],
]


static func step_samples() -> int:
	return roundi(SAMPLE_RATE * 60.0 / BPM / 4.0)


## 16-bit mono PCM for one seamless loop, every layer mixed.
static func render_pcm() -> PackedByteArray:
	var layers := _render_layers()
	var mix := PackedFloat32Array()
	mix.resize(layers[0].size())
	for layer in layers:
		for i in layer.size():
			mix[i] += layer[i]
	return _to_pcm(mix, _loudness(mix))


## The loop split into three layers that play together and fade in separately:
## 0 the bass, beat and tune, 1 the arpeggio, 2 the hats that come in with intensity.
## They share one volume scale, so their sum never clips.
static func render_layers() -> Array[PackedByteArray]:
	var layers := _render_layers()
	var mix := PackedFloat32Array()
	mix.resize(layers[0].size())
	for layer in layers:
		for i in layer.size():
			mix[i] += layer[i]
	var loudest := _loudness(mix)
	var result: Array[PackedByteArray] = []
	for layer in layers:
		result.append(_to_pcm(layer, loudest))
	return result


static func _render_layers() -> Array[PackedFloat32Array]:
	var step := step_samples()
	var total := step * STEPS_PER_BAR * CHORDS.size()
	var base := PackedFloat32Array()
	base.resize(total)
	var arp := PackedFloat32Array()
	arp.resize(total)
	var hats := PackedFloat32Array()
	hats.resize(total)
	for bar in CHORDS.size():
		var root: int = CHORDS[bar][0]
		var third := 3 if CHORDS[bar][1] else 4
		var tones: Array[int] = [root + 12, root + 12 + third, root + 19, root + 24]
		for s in STEPS_PER_BAR:
			var at := (bar * STEPS_PER_BAR + s) * step
			_note(arp, at, step * 2, _hz(tones[ARP[s]] + 12), 0.1, 0.5)
			if BASS_STEPS.has(s):
				_note(base, at, step * 3, _hz(root), 0.34, 0.0)
			if s % 8 == 0:
				_thump(base, at, step * 2, 0.4)
			if s % 2 == 1:
				_hat(hats, at, step, 0.05 if s % 4 == 3 else 0.03, bar * STEPS_PER_BAR + s)
			if s % 4 == 2:
				_note(hats, at, step, _hz(tones[3] + 24), 0.05, 0.3)
	for entry: Array in MELODY:
		_note(base, int(entry[0]) * step, step * 5, _hz(int(entry[1])), 0.16, 0.0)
	return [base, arp, hats] as Array[PackedFloat32Array]


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Triangle voice with a fast attack and an exponential fall. `edge` mixes in a square for bite.
static func _note(mix: PackedFloat32Array, start: int, length: int, freq: float, volume: float, edge: float) -> void:
	var total := mix.size()
	var phase_step := freq / SAMPLE_RATE
	for i in length:
		var phase := fmod(i * phase_step, 1.0)
		var triangle := 4.0 * absf(phase - 0.5) - 1.0
		var square := 1.0 if phase < 0.5 else -1.0
		var envelope := minf(i / 80.0, 1.0) * pow(1.0 - float(i) / length, 2.0)
		mix[(start + i) % total] += lerpf(triangle, square, edge) * envelope * volume


static func _thump(mix: PackedFloat32Array, start: int, length: int, volume: float) -> void:
	var total := mix.size()
	var phase := 0.0
	for i in length:
		var k := float(i) / length
		phase += lerpf(130.0, 45.0, k) / SAMPLE_RATE
		mix[(start + i) % total] += sin(phase * TAU) * pow(1.0 - k, 2.0) * minf(i / 40.0, 1.0) * volume


static func _hat(mix: PackedFloat32Array, start: int, length: int, volume: float, seed_value: int) -> void:
	var total := mix.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var last := 0.0
	for i in length:
		var noise := rng.randf_range(-1.0, 1.0)
		mix[(start + i) % total] += (noise - last) * pow(1.0 - float(i) / length, 3.0) * volume
		last = noise


static func _loudness(mix: PackedFloat32Array) -> float:
	var loudest := 0.001
	for value in mix:
		loudest = maxf(loudest, absf(value))
	return loudest


static func _to_pcm(mix: PackedFloat32Array, loudest: float) -> PackedByteArray:
	var scale := PEAK / loudest
	var pcm := PackedByteArray()
	pcm.resize(mix.size() * 2)
	for i in mix.size():
		pcm.encode_s16(i * 2, int(mix[i] * scale * 32767.0))
	return pcm
