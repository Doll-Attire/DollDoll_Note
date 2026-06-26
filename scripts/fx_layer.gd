## FXLayer — 特效层
## 统一承载所有粒子 / 环境特效：
##   鼠标星光轨迹、点击烟花、打字迸星、流星雨、水面波纹、樱花飘落、雨、雪、萤火虫
## 挂在 PaperScroll 下、铺满、mouse_filter=IGNORE（不挡操作）、z_index 置顶
## 粒子用手写对象池（数组 + _draw），比 GPUParticles 轻量可控、好调参
## Godot 4.6 · GDScript 2.0 严格类型
class_name FXLayer
extends Control

# ── 开关（由 main.gd 在设置变更时同步）──
var trail_enabled: bool = true
var click_enabled: bool = true
var meteor_enabled: bool = false
var water_enabled: bool = false
var petal_enabled: bool = false
var rain_enabled: bool = false
var snow_enabled: bool = false
var firefly_enabled: bool = false
var ripple_enabled: bool = false

# ── 粒子池 ──
var _particles: Array = []
const MAX_PARTICLES: int = 900

# ── 时间累加（_process 加 delta；不能用 Time，会破坏 resume）──
var _time: float = 0.0
# ── 环境特效节奏 ──
var _meteor_timer: float = 0.0
var _meteor_next: float = 0.8
var _petal_timer: float = 0.0
var _rain_timer: float = 0.0
var _snow_timer: float = 0.0
var _firefly_timer: float = 0.0

# ── 配色 ──
const STAR_COLORS: Array = [
	Color(1.0, 0.93, 0.65),   # 暖金
	Color(1.0, 1.0, 0.9),     # 白
	Color(1.0, 0.82, 0.5),    # 深金
	Color(1.0, 0.6, 0.75),    # 粉
	Color(0.7, 0.9, 1.0),     # 蓝
]
const PETAL_COLOR: Color = Color(1.0, 0.72, 0.84, 0.95)
const METEOR_COLOR: Color = Color(1.0, 0.95, 0.82, 1.0)
const WATER_COLOR: Color = Color(0.5, 0.76, 1.0, 0.32)
const WATER_HIGHLIGHT: Color = Color(0.78, 0.92, 1.0, 0.55)
const RAIN_COLOR: Color = Color(0.62, 0.78, 1.0, 0.55)
const SNOW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.92)
const FIREFLY_COLOR: Color = Color(1.0, 0.92, 0.45)
const RIPPLE_COLOR: Color = Color(0.75, 0.88, 1.0, 0.85)

# 粒子 kind
const KIND_STAR: int = 0
const KIND_METEOR: int = 1
const KIND_PETAL: int = 2
const KIND_RAIN: int = 3
const KIND_SNOW: int = 4
const KIND_FIREFLY: int = 5
const KIND_RIPPLE: int = 6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100


func _process(delta: float) -> void:
	_time += delta
	_update_particles(delta)
	_update_ambient(delta)
	queue_redraw()


# ═══════════════════════════════════════════
#  外部触发（main 调）
# ═══════════════════════════════════════════

## 鼠标移动留星（上浮淡出 + 闪烁）
func spawn_trail(local_pos: Vector2) -> void:
	if not trail_enabled or _particles.size() >= MAX_PARTICLES:
		return
	_particles.append(_make_star(local_pos,
		Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -8.0)),
		randf_range(0.6, 1.0), randf_range(2.5, 5.0)))


## 点击迸发 → 烟花：双层环形 + 多色 + 中心闪光
func spawn_burst(local_pos: Vector2) -> void:
	if not click_enabled:
		return
	var c1: Color = STAR_COLORS[randi() % STAR_COLORS.size()]
	var c2: Color = STAR_COLORS[randi() % STAR_COLORS.size()]
	var base_ang: float = randf() * TAU
	# 外环：快、大
	var n1: int = 14
	for i in n1:
		var ang: float = base_ang + (float(i) / float(n1)) * TAU
		var spd: float = randf_range(130.0, 210.0)
		_particles.append(_make_particle(local_pos, Vector2(cos(ang), sin(ang)) * spd,
			randf_range(0.7, 1.0), randf_range(3.5, 5.5), c1 if i % 2 == 0 else c2, KIND_STAR))
	# 内环：慢、小
	var n2: int = 8
	for i in n2:
		var ang: float = base_ang + (float(i) / float(n2)) * TAU + 0.3
		var spd: float = randf_range(45.0, 85.0)
		_particles.append(_make_particle(local_pos, Vector2(cos(ang), sin(ang)) * spd,
			randf_range(0.5, 0.8), randf_range(2.0, 3.5), c1, KIND_STAR))
	# 中心闪光
	_particles.append(_make_star(local_pos, Vector2.ZERO, 0.5, 10.0))


## 打字迸星：传入画布坐标（TextEdit 光标全局位），转成本层局部后留星
func spawn_at_canvas(canvas_pos: Vector2) -> void:
	if not trail_enabled or _particles.size() >= MAX_PARTICLES:
		return
	var local: Vector2 = get_global_transform().affine_inverse() * canvas_pos
	_particles.append(_make_star(local,
		Vector2(randf_range(-12.0, 12.0), randf_range(-30.0, -10.0)),
		randf_range(0.6, 1.0), randf_range(2.5, 4.5)))


## 鼠标涟漪：在指定位置生成一个向外扩散的圆环（水面泛涟漪感）
func spawn_ripple(local_pos: Vector2) -> void:
	if not ripple_enabled or _particles.size() >= MAX_PARTICLES:
		return
	_particles.append({
		"pos": local_pos,
		"vel": Vector2.ZERO,
		"life": 1.1,
		"max_life": 1.1,
		"size": 3.0,
		"color": RIPPLE_COLOR,
		"rot": 0.0,
		"rot_vel": 0.0,
		"kind": KIND_RIPPLE,
		"sway_phase": 0.0,
	})


# ═══════════════════════════════════════════
#  粒子构造
# ═══════════════════════════════════════════

func _make_particle(pos: Vector2, vel: Vector2, max_life: float, sz: float, col: Color, kind: int) -> Dictionary:
	return {
		"pos": pos,
		"vel": vel,
		"life": max_life,
		"max_life": max_life,
		"size": sz,
		"color": col,
		"rot": randf() * TAU,
		"rot_vel": randf_range(-3.0, 3.0),
		"kind": kind,
		"sway_phase": randf() * TAU,
	}


func _make_star(pos: Vector2, vel: Vector2, max_life: float, sz: float) -> Dictionary:
	return _make_particle(pos, vel, max_life, sz,
		STAR_COLORS[randi() % STAR_COLORS.size()], KIND_STAR)


# ═══════════════════════════════════════════
#  环境特效生成
# ═══════════════════════════════════════════

func _update_ambient(delta: float) -> void:
	if meteor_enabled:
		_meteor_timer += delta
		if _meteor_timer >= _meteor_next:
			_meteor_timer = 0.0
			_meteor_next = randf_range(0.5, 1.3)
			_spawn_meteor()
			if randf() < 0.45:
				_spawn_meteor()
	if petal_enabled:
		_petal_timer += delta
		if _petal_timer >= 0.06:
			_petal_timer = 0.0
			_spawn_petal()
	if rain_enabled:
		_rain_timer += delta
		if _rain_timer >= 0.02:  # 密集阵雨
			_rain_timer = 0.0
			_spawn_rain()
			if randf() < 0.6:
				_spawn_rain()
	if snow_enabled:
		_snow_timer += delta
		if _snow_timer >= 0.1:
			_snow_timer = 0.0
			_spawn_snow()
	if firefly_enabled:
		_firefly_timer += delta
		if _firefly_timer >= 0.45:  # 慢补，维持约 20 只
			_firefly_timer = 0.0
			_spawn_firefly()


func _spawn_meteor() -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	var vel := Vector2(randf_range(300.0, 520.0), randf_range(160.0, 280.0))
	_particles.append(_make_particle(
		Vector2(randf_range(-size.x * 0.3, size.x), -30.0),
		vel, 1.8, randf_range(4.0, 7.0), METEOR_COLOR, KIND_METEOR))
	# 修正拖尾朝向
	_particles[_particles.size() - 1]["rot"] = vel.angle()


func _spawn_petal() -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append(_make_particle(
		Vector2(randf() * size.x, -12.0),
		Vector2(randf_range(-12.0, 12.0), randf_range(28.0, 60.0)),
		randf_range(7.0, 10.0), randf_range(5.0, 9.0), PETAL_COLOR, KIND_PETAL))


func _spawn_rain() -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append(_make_particle(
		Vector2(randf_range(-50.0, size.x), -10.0),
		Vector2(randf_range(-25.0, -10.0), randf_range(620.0, 820.0)),
		2.0, randf_range(10.0, 18.0), RAIN_COLOR, KIND_RAIN))


func _spawn_snow() -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append(_make_particle(
		Vector2(randf() * size.x, -10.0),
		Vector2(randf_range(-15.0, 15.0), randf_range(40.0, 85.0)),
		randf_range(6.0, 9.0), randf_range(2.0, 4.0), SNOW_COLOR, KIND_SNOW))


func _spawn_firefly() -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append(_make_particle(
		Vector2(randf() * size.x, randf() * size.y),
		Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0)),
		randf_range(7.0, 11.0), randf_range(2.0, 3.5), FIREFLY_COLOR, KIND_FIREFLY))


# ═══════════════════════════════════════════
#  更新
# ═══════════════════════════════════════════

func _update_particles(delta: float) -> void:
	var i: int = 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.pop_at(i)
			continue
		var kind: int = int(p["kind"])
		var pos: Vector2 = p["pos"]
		# 落地 / 出屏的粒子直接清除（雨雪花瓣）
		if (kind == KIND_RAIN or kind == KIND_SNOW or kind == KIND_PETAL) and pos.y > size.y + 30.0:
			_particles.pop_at(i)
			continue
		var vel: Vector2 = p["vel"]
		if kind == KIND_PETAL or kind == KIND_SNOW:
			var amp: float = 26.0 if kind == KIND_PETAL else 18.0
			var sway: float = sin(float(p["sway_phase"]) + _time * 2.0) * amp
			p["pos"] = pos + Vector2(sway * delta, vel.y * delta)
		elif kind == KIND_FIREFLY:
			var ph: float = float(p["sway_phase"]) + _time
			p["pos"] = pos + Vector2((vel.x + sin(ph * 1.3) * 16.0) * delta,
									 (vel.y + cos(ph) * 16.0) * delta)
		elif kind == KIND_RIPPLE:
			# 涟漪：半径向外扩散，位置不变
			p["size"] = float(p["size"]) + 55.0 * delta
		else:
			# STAR / METEOR / RAIN：直线运动；STAR 加阻力（烟花绽放 / 轨迹上浮减速）
			p["pos"] = pos + vel * delta
			if kind == KIND_STAR:
				p["vel"] = vel * (1.0 - delta * 0.85)
		p["rot"] = float(p["rot"]) + float(p["rot_vel"]) * delta
		i += 1


# ═══════════════════════════════════════════
#  渲染
# ═══════════════════════════════════════════

func _draw() -> void:
	for p in _particles:
		var life_ratio: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var kind: int = int(p["kind"])
		var col: Color = p["color"]
		var pos: Vector2 = p["pos"]
		var sz: float = float(p["size"])
		match kind:
			KIND_METEOR:
				var vel: Vector2 = p["vel"]
				var tail: Vector2 = pos - vel.normalized() * 110.0
				col.a = life_ratio * 0.95
				draw_line(pos, tail, col, sz * 0.9, true)
				draw_circle(pos, sz, col)
			KIND_PETAL:
				col.a = life_ratio * 0.95
				_petal(pos, sz, float(p["rot"]), col)
			KIND_RAIN:
				col.a = life_ratio * 0.7
				draw_line(pos, pos + Vector2(-2.0, sz), col, 1.5, true)
			KIND_SNOW:
				col.a = life_ratio
				draw_circle(pos, sz, col)
			KIND_FIREFLY:
				# 闪烁（sin）+ 光晕
				var blink: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 4.0 + float(p["sway_phase"]) * 3.0))
				var glow: Color = col
				glow.a = life_ratio * blink * 0.3
				draw_circle(pos, sz * 3.0, glow)
				var core: Color = col
				core.a = life_ratio * blink
				draw_circle(pos, sz, core)
			KIND_RIPPLE:
				# 涟漪：空心圆环，半径随生命扩散、alpha 淡出
				col.a = life_ratio * 0.6
				draw_arc(pos, sz, 0.0, TAU, 28, col, 1.5, true)
			_:
				# KIND_STAR：闪烁 + 淡出
				var twinkle: float = 0.7 + 0.3 * sin(_time * 8.0 + float(p["rot"]) * 5.0)
				col.a = life_ratio * twinkle
				_star(pos, sz, sz * 0.4, float(p["rot"]), col)
	if water_enabled:
		_draw_water()


## 4 角星（8 顶点交替内外径）
func _star(pos: Vector2, outer: float, inner: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a: float = rot + float(i) * (TAU / 8.0)
		var r: float = outer if i % 2 == 0 else inner
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


## 花瓣形（近似 4 瓣）
func _petal(pos: Vector2, sz: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a: float = rot + float(i) * (TAU / 8.0)
		var r: float = sz if i % 2 == 0 else sz * 0.5
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


## 底部水面（约占下方 28%）：双频波纹填充 + 表面高光线
func _draw_water() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var water_top: float = h * 0.72
	var steps: int = 60
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, h))
	pts.append(Vector2(0.0, _wave_y(0.0, water_top)))
	for i in range(steps + 1):
		var x: float = w * float(i) / float(steps)
		pts.append(Vector2(x, _wave_y(x, water_top)))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, WATER_COLOR)
	var prev: Vector2 = Vector2(0.0, _wave_y(0.0, water_top))
	for i in range(1, steps + 1):
		var x: float = w * float(i) / float(steps)
		var cur: Vector2 = Vector2(x, _wave_y(x, water_top))
		draw_line(prev, cur, WATER_HIGHLIGHT, 2.0, true)
		prev = cur


## 水面波形 y（双频叠加，随 x 推进 + 时间起伏）
func _wave_y(x: float, base: float) -> float:
	var nx: float = x * 0.06
	return base + sin(_time * 1.6 + nx) * 7.0 + sin(_time * 0.9 + nx * 0.4) * 4.0
