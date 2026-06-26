## ShapeBlock — 几何图形块
## 继承 BaseBlock，用 _draw 绘制矩形/椭圆/直线/箭头
## Godot 4.6 · GDScript 2.0 严格类型
class_name ShapeBlock
extends BaseBlock

# ── 图形块专属常量 ──
const SHAPE_MIN_SIZE: int = 30


# ═══════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════

func _block_ready() -> void:
	min_width = float(SHAPE_MIN_SIZE)
	min_height = float(SHAPE_MIN_SIZE)
	# Panel 默认有背景色，图形块要透明让 _draw 自绘图形可见
	var s := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", s)


func _block_setup() -> void:
	_redraw()


## 类型安全的 data 访问器
func _sd() -> ShapeBlockData:
	return data as ShapeBlockData


## 尺寸变化后重绘
func _on_self_resized() -> void:
	super._on_self_resized()
	_redraw()


## 选中/取消选中后重绘（选中时可能加边框提示）
func _on_select() -> void:
	_redraw()

func _on_deselect() -> void:
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
	var d: ShapeBlockData = _sd()
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var sw: float = d.stroke_width
	# 根据图形类型绘制
	match d.shape_type:
		ShapeBlockData.ShapeType.RECT:
			if d.fill_enabled:
				draw_rect(rect, d.fill_color, true)
			draw_rect(rect, d.stroke_color, false, sw, true)
		ShapeBlockData.ShapeType.ELLIPSE:
			# 填充和描边都用椭圆（多段近似），避免 draw_circle 画正圆导致"椭圆内切圆"
			if d.fill_enabled:
				_draw_ellipse_fill(rect.get_center(), rect.size * 0.5, d.fill_color)
			_draw_ellipse_outline(rect.get_center(), rect.size * 0.5, d.stroke_color, sw)
		ShapeBlockData.ShapeType.LINE:
			# 从左中到右中
			var p1: Vector2 = Vector2(0, rect.size.y * 0.5)
			var p2: Vector2 = Vector2(rect.size.x, rect.size.y * 0.5)
			draw_line(p1, p2, d.stroke_color, sw, true)
		ShapeBlockData.ShapeType.ARROW:
			# 直线 + 箭头头
			var p1: Vector2 = Vector2(0, rect.size.y * 0.5)
			var p2: Vector2 = Vector2(rect.size.x, rect.size.y * 0.5)
			draw_line(p1, p2, d.stroke_color, sw, true)
			# 箭头三角
			var head: float = minf(rect.size.x * 0.2, 20.0)
			var dir: Vector2 = (p2 - p1).normalized()
			var perp: Vector2 = dir.rotated(deg_to_rad(90))
			var tip: Vector2 = p2
			var base: Vector2 = p2 - dir * head
			var pts: PackedVector2Array = PackedVector2Array([
				tip,
				base + perp * head * 0.5,
				base - perp * head * 0.5
			])
			draw_colored_polygon(pts, d.stroke_color)


## 画椭圆描边（多段折线近似）
func _draw_ellipse_outline(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var segments: int = 48
	var prev: Vector2 = center + Vector2(radius.x, 0)
	for i in range(1, segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		var cur: Vector2 = center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		draw_line(prev, cur, color, width, true)
		prev = cur


## 画椭圆填充（三角扇近似）
func _draw_ellipse_fill(center: Vector2, radius: Vector2, color: Color) -> void:
	var segments: int = 48
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(center)
	for i in range(segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(pts, color)


# ═══════════════════════════════════════════
#  外部接口（供工具栏调整）
# ═══════════════════════════════════════════

func handle_stroke_color_change(color: Color) -> void:
	if data == null:
		return
	_sd().stroke_color = color
	_redraw()
	block_resized.emit(self)

func handle_fill_color_change(color: Color) -> void:
	if data == null:
		return
	_sd().fill_color = color
	_redraw()
	block_resized.emit(self)

func handle_stroke_width_change(w: float) -> void:
	if data == null:
		return
	_sd().stroke_width = clampf(w, 1.0, 20.0)
	_redraw()
	block_resized.emit(self)

func handle_fill_toggle(enabled: bool) -> void:
	if data == null:
		return
	_sd().fill_enabled = enabled
	_redraw()
	block_resized.emit(self)

func handle_shape_type_change(t: int) -> void:
	if data == null:
		return
	_sd().shape_type = t as ShapeBlockData.ShapeType
	_redraw()
	block_resized.emit(self)
