extends "res://game_base.gd"
## Sound effects generated from code, and the layered background music.


func _apply_sound() -> void:
	var volume_db := _volume_db(save.sfx_volume)
	for player in players:
		player.volume_db = volume_db
	_apply_music()

func _apply_music() -> void:
	for player in music_players:
		if player.stream != null:
			player.stream_paused = save.music_volume <= 0

## The base layer always plays; the others fade in with the game and with its intensity.
func _mix_music(delta: float) -> void:
	if music_players.is_empty() or music_players[0].stream == null:
		return
	var in_game := screen == Menus.Screen.GAME and not paused
	var intensity := clampf(heat * 1.4 + fever_glow + (0.6 if in_game and sim.boss_block != null else 0.0), 0.0, 1.0)
	var targets := [1.0, 1.0 if in_game else 0.35, intensity if in_game else 0.0]
	var base_db := MUSIC_VOLUME_DB + _volume_db(save.music_volume)
	for i in music_players.size():
		var current := db_to_linear(music_players[i].volume_db - base_db)
		var next := move_toward(current, float(targets[i]), delta * 1.5)
		music_players[i].volume_db = base_db + linear_to_db(maxf(next, 0.0001))
		music_players[i].pitch_scale = WORLD_PITCH.get(sim.world if in_game else "wall", 1.0)

## Starts the layers together once the background render has finished.
func _poll_music() -> void:
	if music_task < 0 or not WorkerThreadPool.is_task_completed(music_task):
		return
	WorkerThreadPool.wait_for_task_completion(music_task)
	music_task = -1
	for i in music_layers.size():
		var stream := _wav(music_layers[i])
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = music_layers[i].size() / 2
		music_players[i].stream = stream
		music_players[i].volume_db = MUSIC_VOLUME_DB + _volume_db(save.music_volume) + (0.0 if i == 0 else -60.0)
	for player in music_players:
		player.play()
	_apply_music()

## Starts the loop once the background render has finished.
func _exit_tree() -> void:
	if music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(music_task)

func _build_audio() -> void:
	sounds = {
		"hit": _tone(880.0, 0.06, 0.28, "triangle"),
		"pop": _tone(520.0, 0.09, 0.4, "triangle", -3000.0),
		"boom": _noise(0.3, 0.75),
		"coin": _tone(1320.0, 0.07, 0.22, "sine", 2500.0),
		"fire": _tone(300.0, 0.1, 0.3, "triangle", 1800.0),
		"pick": _tone(660.0, 0.12, 0.35, "sine", 1600.0),
		"win": _tone(660.0, 0.35, 0.45, "triangle", 1200.0),
		"lose": _tone(300.0, 0.5, 0.45, "triangle", -380.0),
		"charge": _tone(120.0, BURST_WINDUP, 0.5, "triangle", 900.0, true),
		"blast": _noise(1.1, 0.95),
	}
	for i in 14:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for i in 3:
		var layer := AudioStreamPlayer.new()
		layer.volume_db = MUSIC_VOLUME_DB
		add_child(layer)
		music_players.append(layer)

func _play(id: String, pitch: float) -> void:
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = sounds[id]
	player.pitch_scale = pitch
	player.play()

func _tone(freq: float, duration: float, volume: float, wave: String, sweep := 0.0, swell := false) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var k := float(i) / SAMPLE_RATE
		phase += (freq + sweep * k) / SAMPLE_RATE
		# A triangle wave is rounder than a square, and sits better with the softer look.
		var value := sin(phase * TAU) if wave == "sine" else 1.0 - 4.0 * absf(fmod(phase, 1.0) - 0.5)
		var progress := float(i) / count
		var envelope := progress if swell else 1.0 - progress
		data.encode_s16(i * 2, int(value * volume * envelope * 32767.0))
	return _wav(data)

func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var held := 0.0
	for i in count:
		# Holding each sample longer over time drops the pitch, like a real blast.
		if i % (1 + i / 800) == 0:
			held = randf_range(-1.0, 1.0)
		var env := pow(1.0 - float(i) / count, 2.0)
		data.encode_s16(i * 2, int(held * volume * env * 32767.0))
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
