extends Node
## Placeholder audio: short synthesized one-shots, a speed-tracked engine rumble
## loop and a constant ambience drone. No continuous engine/turret/mining loops
## (source used procedural oscillators); the drone approximates that bed.
## WAVs are generated at call time and streamed through a round-robin pool.

const RATE: int = 22050

var _pool: Array = []
var _idx: int = 0
var _engine: AudioStreamPlayer
var _ambient: AudioStreamPlayer

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _noise_stream(0.9, 0.35, 5.0, true)
	_engine.volume_db = -26.0
	_engine.pitch_scale = 0.55
	add_child(_engine)
	_engine.play()
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _drone_stream(6.0)
	_ambient.volume_db = -22.0
	add_child(_ambient)
	_ambient.play()

func set_engine_speed(frac: float) -> void:
	_engine.pitch_scale = lerpf(0.5, 1.7, frac)
	_engine.volume_db = lerpf(-30.0, -16.0, frac)

func _play(stream: AudioStreamWAV, vol_db: float = 0.0) -> void:
	var p: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	p.stream = stream
	p.volume_db = vol_db
	p.play()

static func _partials(wave: String) -> Array:
	match wave:
		'saw':
			return [1.0, 0.5, 0.33, 0.25, 0.2, 0.17]
		'square':
			return [1.0, 0.33, 0.2, 0.14, 0.11, 0.09]
		'tri':
			return [1.0, 0.0, 0.11, 0.0, 0.04, 0.0]
		_:
			return [1.0]

func _osc_stream(dur: float, wave: String, f0: float, f1: float, gain: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	if n <= 0:
		return AudioStreamWAV.new()
	var data := PackedByteArray()
	data.resize(n * 2)
	var am := _partials(wave)
	var k := pow(f1 / f0, 1.0 / n)
	var f := f0
	var ph := 0.0
	var factor := 3.0 / maxf(decay, 0.01)
	var peak := 0.0
	for i in n:
		var s := 0.0
		for p in am.size():
			s += am[p] * sin(ph * (p + 1))
		s *= exp(-factor * float(i) / n) * gain
		peak = maxf(peak, absf(s))
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
		ph += TAU * f / RATE
		f *= k
	if peak < 0.01:
		peak = 0.01
	for i in n:
		var v := int(float(data.decode_s16(i * 2)) / peak * 32767.0) if peak > 1.0 else data.decode_s16(i * 2)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _noise_stream(dur: float, gain: float, decay: float, looped: bool = false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var brown := 0.0
	var factor := 3.0 / maxf(decay, 0.01)
	for i in n:
		brown = clampf(brown * 0.9 + (randf() - 0.5) * 0.35, -1.0, 1.0)
		var env := exp(-factor * float(i) / n)
		if looped:
			env = minf(1.0, float(i) / (n * 0.05)) * minf(1.0, float(n - i) / (n * 0.05))
		var s := brown * env * gain
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _mix(a: AudioStreamWAV, b: AudioStreamWAV, b_vol: float = 0.5) -> AudioStreamWAV:
	var n := maxi(a.data.size(), b.data.size())
	if n % 2:
		n += 1
	var data := PackedByteArray()
	data.resize(n)
	for i in range(0, n, 2):
		var sa := a.data.decode_s16(i) if i < a.data.size() else 0
		var sb := b.data.decode_s16(i) if i < b.data.size() else 0
		data.encode_s16(i, int(clampf((sa + sb * b_vol) / 1.0, -32767.0, 32767.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _drone_stream(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in n:
		var s := sin(ph1) * 0.5 + sin(ph2) * 0.35 + sin(ph2 * 1.5) * 0.15
		s *= 0.06
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
		ph1 += TAU * 55.0 / RATE
		ph2 += TAU * 82.7 / RATE
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func cannon_fire() -> void:
	_play(_mix(_osc_stream(0.16, 'saw', 105.0, 62.0, 0.42, 0.09), _noise_stream(0.10, 0.3, 0.05), 0.8), -7.0)

func turret_shot() -> void:
	_play(_mix(_osc_stream(0.06, 'square', 320.0, 210.0, 0.18, 0.04), _noise_stream(0.04, 0.1, 0.02), 0.6), -14.0)

func impact() -> void:
	_play(_mix(_osc_stream(0.07, 'square', 220.0, 70.0, 0.3, 0.05), _noise_stream(0.05, 0.2, 0.03), 0.5), -10.0)

func reload_start() -> void:
	_play(_osc_stream(0.05, 'tri', 150.0, 110.0, 0.2, 0.03), -12.0)

func reload_success(rel: float) -> void:
	_play(_osc_stream(0.14, 'sine', 420.0 + rel * 120.0, 890.0, 0.22, 0.3), -12.0)

func reload_fail(rel: float) -> void:
	_play(_mix(_osc_stream(0.2, 'saw', 130.0, 70.0, 0.25, 0.15), _osc_stream(0.22, 'square', 200.0, 92.0, 0.2, 0.2), 0.6), -10.0)

func node_depleted() -> void:
	_play(_osc_stream(0.14, 'square', 620.0, 180.0, 0.3, 0.1), -8.0)

func monolith_neutralized() -> void:
	_play(_mix(_noise_stream(0.9, 0.5, 0.18), _osc_stream(0.7, 'saw', 46.0, 30.0, 0.4, 0.14), 0.7), -4.0)

func panel_open() -> void:
	_play(_osc_stream(0.07, 'square', 660.0, 990.0, 0.12, 0.05), -16.0)

func panel_close() -> void:
	_play(_osc_stream(0.07, 'square', 990.0, 660.0, 0.12, 0.05), -16.0)

func ui_blip() -> void:
	_play(_osc_stream(0.03, 'sine', 1250.0, 1250.0, 0.1, 0.015), -18.0)

func ui_move() -> void:
	_play(_osc_stream(0.03, 'square', 220.0, 220.0, 0.1, 0.015), -18.0)

func unaffordable() -> void:
	_play(_osc_stream(0.08, 'square', 140.0, 140.0, 0.14, 0.06), -14.0)

func overheat() -> void:
	_play(_osc_stream(0.4, 'saw', 220.0, 90.0, 0.3, 0.3), -8.0)

func weapon_switch() -> void:
	_play(_osc_stream(0.05, 'square', 300.0, 200.0, 0.12, 0.04), -14.0)

func shard_impact() -> void:
	_play(_osc_stream(0.06, 'saw', 900.0, 300.0, 0.2, 0.04), -12.0)

func shockwave_slam() -> void:
	_play(_mix(_noise_stream(0.5, 0.5, 0.1), _osc_stream(0.5, 'saw', 55.0, 28.0, 0.4, 0.1), 0.7), -6.0)

func drift_skid() -> void:
	_play(_noise_stream(0.08, 0.14, 0.05), -16.0)

func hull_hit() -> void:
	_play(_mix(_osc_stream(0.18, 'saw', 180.0, 55.0, 0.35, 0.12), _noise_stream(0.12, 0.4, 0.05), 0.6), -8.0)