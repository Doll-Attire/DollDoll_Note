## DrawBlock — 手绘涂鸦块
## 继承 BaseBlock，鼠标在块内拖拽记录笔触，用 _draw 渲染
## Godot 4.6 · GDScript 2.0 严格类型
class_name DrawBlock
extends BaseBlock

# ── 涂鸦块专属常量 ──
const DRAW_MIN_SIZE: int = 50

# ── 绘制状态 ──
var _is_drawing: bool = false
var _current_stroke: PackedVector2Array = PackedVector2Array()


# ═══════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════

func _block_ready() -> void:
	min_width = float(DRAW_MIN_SIZE)
	min_height = float(DRAW_MIN_SIZE)
	# 透明背景，让笔触可见
	var s := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", s)
	# 涂鸦块需要接收鼠标事件来画图
	mouse_filter = Control.MOUSE_FILTER_STOP


func _block_setup() -> void:
	_redraw()


## 类型安全的 data 访问器
func _dd() -> DrawBlockData:
	return data as DrawBlockData


func _on_self_resized() -> void:
	super._on_self_resized()
	_redraw()


# ═══════════════════════════════════════════
#  绘制
# ═══════════════════════════════════════════

func _redraw() -> void:
	if not is_node_ready():
		return
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var d: DrawBlockData = _dd()
	# 绘制所有已完成的笔触
	for i in range(d.strokes.size()):
		var pts: PackedVector2Array = d.strokes[i] as PackedVector2Array
		var col: Color = d.stroke_colors[i] if i < d.stroke_colors.size() else d.brush_color
		var w: float = d.stroke_widths[i] if i < d.stroke_widths.size() else d.brush_width
		_draw_stroke(pts, col, w)
	# 绘制当前正在画的笔触
	if not _current_stroke.is_empty():
		_draw_stroke(_current_stroke, d.brush_color, d.brush_width)


## 绘制一段笔触：brush_type 调 color/width，brush_smooth 平滑，brush_pen_tip 笔锋
func _draw_stroke(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() == 1:
		draw_circle(pts[0], width * 0.5, color)
		return
	if pts.size() < 2:
		return
	# 画笔类型 → 实际 color / width
	var bt: int = _dd().brush_type if data != null else 0
	var dc: Color = color
	var dw: float = width
	match bt:
		1:  # 马克笔：半透叠加
			dc = Color(color.r, color.g, color.b, color.a * 0.55)
			dw = width * 1.2
		2:  # 铅笔：细
			dw = maxf(0.8, width * 0.65)
		3:  # 荧光笔：粗 + 半透
			dc = Color(color.r, color.g, color.b, color.a * 0.3)
			dw = width * 2.5
	var seg: int = _dd().brush_smooth if data != null else 8
	# seg <= 0：折线（不平滑）
	if seg <= 0:
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], dc, dw, true)
		draw_circle(pts[0], dw * 0.5, dc)
		draw_circle(pts[pts.size() - 1], dw * 0.5, dc)
		return
	var smooth := _smooth_catmull(pts, seg)
	if smooth.size() < 2:
		return
	if data != null and _dd().brush_pen_tip:
		# 笔锋：逐段变宽。梭形（起止细、中间粗）× 速度因子（快→细、慢→粗）
		var n: int = smooth.size()
		for i in range(n - 1):
			var t: float = float(i) / float(n - 1)
			var shape: float = 0.45 + 0.55 * sin(t * PI)
			var d: float = smooth[i].distance_to(smooth[i + 1])
			var speed: float = clampf(remap(d, 2.0, 14.0, 1.25, 0.55), 0.55, 1.25)
			var w: float = maxf(0.5, dw * shape * speed)
			draw_line(smooth[i], smooth[i + 1], dc, w, true)
			draw_circle(smooth[i], w * 0.5, dc)
		draw_circle(smooth[n - 1], dw * 0.5, dc)
	else:
		draw_polyline(smooth, dc, dw, true)
		draw_circle(pts[0], dw * 0.5, dc)
		draw_circle(pts[pts.size() - 1], dw * 0.5, dc)
	# 铅笔颗粒（确定性纹理，基于点 index，不闪烁）
	if bt == 2:
		for i in range(0, smooth.size(), 2):
			var ang: float = fmod(float(i) * 2.3, TAU)
			var off: Vector2 = Vector2(cos(ang), sin(ang)) * dw * 0.5
			draw_circle(smooth[i] + off, dw * 0.3, Color(dc.r, dc.g, dc.b, dc.a * 0.3))


## Catmull-Rom 样条插值：在相邻点间生成平滑曲线点（曲线经过所有原点）
func _smooth_catmull(pts: PackedVector2Array, seg: int) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(n - 1):
		var p0: Vector2 = pts[max(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[min(n - 1, i + 2)]
		for s in range(1, seg + 1):
			var t: float = float(s) / float(seg)
			var t2: float = t * t
			var t3: float = t2 * t
			var pt: Vector2 = 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out.append(pt)
	out.append(pts[n - 1])
	return out


# ═══════════════════════════════════════════
#  鼠标交互（左键走 BaseBlock 原有逻辑，右键画图）
# ═══════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if data == null:
		return
	var d: DrawBlockData = _dd()
	var mouse_pos := get_local_mouse_position()
	
	# ── 右键：拖动画图，右键单击（未移动）弹上下文菜单 ──
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			block_selected.emit(self)
			_is_drawing = true
			_current_stroke = PackedVector2Array()
			_current_stroke.append(mouse_pos)
			get_viewport().set_input_as_handled()
			return
		else:
			if _is_drawing:
				# 整段没移动（仅按下那一个点）→ 视为右键单击：弹上下文菜单，不落笔
				if _current_stroke.size() <= 1:
					_current_stroke = PackedVector2Array()
					_is_drawing = false
					request_context_menu.emit(self)
					get_viewport().set_input_as_handled()
					return
				_finish_stroke()
			_is_drawing = false
			return
	
	# ── 右键拖拽画图 ──
	if event is InputEventMouseMotion and _is_drawing:
		_current_stroke.append(mouse_pos)
		_redraw()
		get_viewport().set_input_as_handled()
		return
	
	# ── 左键：交给 BaseBlock 处理（拖动/缩放/Ctrl旋转） ──
	super._gui_input(event)


## 完成当前笔触，存入数据
func _finish_stroke() -> void:
	if _current_stroke.size() < 1:
		_current_stroke = PackedVector2Array()
		return
	var d: DrawBlockData = _dd()
	d.strokes.append(_current_stroke.duplicate())
	d.stroke_colors.append(d.brush_color)
	d.stroke_widths.append(d.brush_width)
	_current_stroke = PackedVector2Array()
	_redraw()
	block_resized.emit(self)  # 触发脏标记


# ═══════════════════════════════════════════
#  外部接口（供工具栏调整）
# ═══════════════════════════════════════════

func handle_brush_color_change(color: Color) -> void:
	if data == null:
		return
	_dd().brush_color = color

func handle_brush_width_change(w: float) -> void:
	if data == null:
		return
	_dd().brush_width = clampf(w, 1.0, 30.0)


## 设置平滑段数（0=折线，越大越平滑）
func handle_brush_smooth_change(seg: int) -> void:
	if data == null:
		return
	_dd().brush_smooth = clampi(seg, 0, 24)
	_redraw()


## 开关笔锋
func handle_brush_pen_tip_change(on: bool) -> void:
	if data == null:
		return
	_dd().brush_pen_tip = on
	_redraw()


## 设置画笔类型（0 实线 / 1 马克笔 / 2 铅笔 / 3 荧光笔）
func handle_brush_type_change(t: int) -> void:
	if data == null:
		return
	_dd().brush_type = clampi(t, 0, 3)
	_redraw()

## 清空所有笔触
func clear_strokes() -> void:
	if data == null:
		return
	var d: DrawBlockData = _dd()
	d.strokes.clear()
	d.stroke_colors.clear()
	d.stroke_widths.clear()
	_redraw()
	block_resized.emit(self)


## 撤销最近一笔
func erase_last_stroke() -> void:
	if data == null:
		return
	var d: DrawBlockData = _dd()
	if d.strokes.is_empty():
		return
	d.strokes.pop_back()
	d.stroke_colors.pop_back()
	d.stroke_widths.pop_back()
	_redraw()
	block_resized.emit(self)
