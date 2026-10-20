extends Node
## 런타임 합성 효과음 (autoload: Sfx).
##
## 아직 녹음된 사운드 에셋이 없으므로 AudioStreamGenerator 로 총성·타격·빗소리 등을
## 절차적으로 합성한다. 추후 실제 샘플(.wav/.ogg) 이 들어오면 play() 의 분기만
## 교체하면 된다. 모든 효과음은 사전에 PackedFloat32Array 로 렌더링해 캐시한다.

const SAMPLE_RATE := 22050.0
const POOL_SIZE := 10

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _rain_player: AudioStreamPlayer
var _rain_playback: AudioStreamGeneratorPlayback
var _rain_target_volume := -80.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2028
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_rain_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.5
	_rain_player.stream = gen
	_rain_player.volume_db = -80.0
	add_child(_rain_player)
	_rain_player.play()
	_rain_playback = _rain_player.get_stream_playback()


func _process(delta: float) -> void:
	_rain_player.volume_db = lerpf(_rain_player.volume_db, _rain_target_volume, delta * 2.0)
	if _rain_playback == null:
		return
	var frames := _rain_playback.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		# 저역 통과된 백색 잡음 → 빗소리
		var n := _rng.randf_range(-1.0, 1.0) * 0.35
		buf[i] = Vector2(n, n)
	_rain_playback.push_buffer(buf)


## 빗소리 볼륨 (dB). -80 이면 사실상 무음.
func set_rain(volume_db: float) -> void:
	_rain_target_volume = volume_db


## 등록된 효과음 이름으로 재생한다. 위치 기반 감쇠는 단순화해 볼륨만 조정한다.
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var data: PackedVector2Array = _get_or_render(name)
	if data.is_empty():
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE * pitch
	gen.buffer_length = maxf(0.1, data.size() / SAMPLE_RATE + 0.05)
	player.stop()
	player.stream = gen
	player.volume_db = volume_db
	player.play()
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		pb.push_buffer(data)


func _get_or_render(name: String) -> PackedVector2Array:
	if _cache.has(name):
		return _cache[name]
	var data := PackedVector2Array()
	match name:
		"gunshot":
			data = _render(0.35, func(t: float, i: int) -> float:
				var env := exp(-t * 18.0)
				var body := sin(t * 2.0 * PI * 90.0) * exp(-t * 30.0) * 0.8
				return (_rng.randf_range(-1.0, 1.0) * env + body) * 0.9)
		"gunshot_far":
			data = _render(0.5, func(t: float, i: int) -> float:
				return _rng.randf_range(-1.0, 1.0) * exp(-t * 9.0) * 0.4)
		"click":
			data = _render(0.06, func(t: float, i: int) -> float:
				return _rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5)
		"reload":
			data = _render(0.3, func(t: float, i: int) -> float:
				var a := exp(-fmod(t, 0.15) * 60.0)
				return _rng.randf_range(-1.0, 1.0) * a * 0.35)
		"punch":
			data = _render(0.18, func(t: float, i: int) -> float:
				return (sin(t * 2.0 * PI * 70.0) * exp(-t * 25.0) + _rng.randf_range(-0.3, 0.3) * exp(-t * 40.0)) * 0.8)
		"hit_flesh":
			data = _render(0.12, func(t: float, i: int) -> float:
				return _rng.randf_range(-1.0, 1.0) * exp(-t * 50.0) * 0.5)
		"impact":
			data = _render(0.08, func(t: float, i: int) -> float:
				return (_rng.randf_range(-1.0, 1.0) * exp(-t * 80.0) + sin(t * 2.0 * PI * 1800.0) * exp(-t * 60.0) * 0.3) * 0.4)
		"glass":
			data = _render(0.6, func(t: float, i: int) -> float:
				var tinkle := sin(t * 2.0 * PI * (2400.0 + 900.0 * sin(t * 37.0))) * exp(-t * 6.0)
				return (_rng.randf_range(-1.0, 1.0) * exp(-t * 12.0) * 0.6 + tinkle * 0.3))
		"power_down":
			data = _render(1.4, func(t: float, i: int) -> float:
				var f := 120.0 * (1.0 - t / 1.4) + 30.0
				return sin(t * 2.0 * PI * f) * exp(-t * 2.0) * 0.5)
		"buzz":
			data = _render(0.25, func(t: float, i: int) -> float:
				return sign(sin(t * 2.0 * PI * 60.0)) * 0.12 * exp(-t * 6.0))
		"pickup":
			data = _render(0.15, func(t: float, i: int) -> float:
				return sin(t * 2.0 * PI * (500.0 + t * 2400.0)) * exp(-t * 20.0) * 0.4)
		"door":
			data = _render(0.4, func(t: float, i: int) -> float:
				return (sin(t * 2.0 * PI * 55.0) * exp(-t * 10.0) + _rng.randf_range(-0.2, 0.2) * exp(-t * 20.0)) * 0.6)
		"dodge":
			data = _render(0.12, func(t: float, i: int) -> float:
				return _rng.randf_range(-1.0, 1.0) * exp(-t * 30.0) * 0.18)
		"ui":
			data = _render(0.08, func(t: float, i: int) -> float:
				return sin(t * 2.0 * PI * 880.0) * exp(-t * 40.0) * 0.3)
		"heartbeat":
			data = _render(0.5, func(t: float, i: int) -> float:
				var a := exp(-t * 14.0) + exp(-maxf(t - 0.22, 0.0) * 14.0) * float(t > 0.22)
				return sin(t * 2.0 * PI * 48.0) * a * 0.5)
		"car_engine":
			data = _render(1.2, func(t: float, i: int) -> float:
				return sign(sin(t * 2.0 * PI * (35.0 + 25.0 * t))) * 0.15 * minf(t * 3.0, 1.0))
		_:
			data = PackedVector2Array()
	_cache[name] = data
	return data


func _render(seconds: float, fn: Callable) -> PackedVector2Array:
	var count := int(seconds * SAMPLE_RATE)
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var v: float = clampf(fn.call(t, i), -1.0, 1.0)
		out[i] = Vector2(v, v)
	return out
