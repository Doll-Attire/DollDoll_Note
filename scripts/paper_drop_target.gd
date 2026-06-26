## PaperDropTarget — 挂载到 Paper 上
## 职责 1：接收贴纸拖拽，通过信号通知 main 在指定位置创建贴纸块
## 职责 2：绘制纸张底纹（横线/方格/点阵/活页孔），画在背景色之上、block 之下
class_name PaperDropTarget
extends Panel

signal sticker_dropped(abs_path: String, local_pos: Vector2)
signal emoji_sticker_dropped(text: String, local_pos: Vector2)

# ── 底纹配置（由 main.gd 在加载/切换时通过 apply_pattern 设置）──
var paper_pattern: int = 0          ## 0空白 1横线 2方格 3点阵 4活页孔
var pattern_color: Color = Color(0.72, 0.72, 0.72, 0.6)
var pattern_spacing: float = 28.0
# ── 吸附网格（由 main.gd 在设置开关时同步）──
var snap_grid_enabled: bool = false
var snap_grid_size: int = 24
# ── 纸张底图（用户上传的背景插画/人物，绘制在底纹之下）──
var bg_image_texture: Texture2D = null
var bg_image_opacity: float = 0.8
var bg_image_offset: Vector2 = Vector2.ZERO
var bg_image_scale: float = 1.0


func _can_drop_data(_at_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var t: Variant = (data as Dictionary).get("type", "")
	return t == "sticker" or t == "emoji_sticker"


func _drop_data(at_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var d: Dictionary = data as Dictionary
	var t: Variant = d.get("type", "")
	if t == "sticker" and d.has("path"):
		sticker_dropped.emit(String(d["path"]), at_pos)
	elif t == "emoji_sticker" and d.has("text"):
		emoji_sticker_dropped.emit(String(d["text"]), at_pos)


## 设置底纹并重绘（main.gd 切换底纹 / 加载笔记时调用）
func apply_pattern(p: int, col: Color, sp: float) -> void:
	paper_pattern = p
	pattern_color = col
	pattern_spacing = sp
	queue_redraw()


## 设置吸附网格开关与大小并重绘
func apply_snap_grid(enabled: bool, sz: int) -> void:
	snap_grid_enabled = enabled
	snap_grid_size = sz
	queue_redraw()


## 设置纸张底图并重绘（path 空=清除）
func apply_bg_image(path: String, opacity: float, offset: Vector2, scale: float) -> void:
	bg_image_opacity = opacity
	bg_image_offset = offset
	bg_image_scale = scale
	if path.is_empty():
		bg_image_texture = null
	else:
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			bg_image_texture = ImageTexture.create_from_image(img) if img != null else null
		else:
			bg_image_texture = null
	queue_redraw()


## 绘制纸张底纹 + 吸附网格参考线。本地坐标绘制，随 paper.scale 自动缩放
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	# 底图（最底层，在底纹之下；只画与纸张重合的部分，纸张大小改变自动适配）
	if bg_image_texture != null:
		var dest_rect: Rect2 = Rect2(bg_image_offset, bg_image_texture.get_size() * bg_image_scale)
		var paper_rect: Rect2 = Rect2(Vector2.ZERO, size)
		var overlap: Rect2 = dest_rect.intersection(paper_rect)
		if overlap.size.x > 0.0 and overlap.size.y > 0.0 and dest_rect.size.x > 0.0 and dest_rect.size.y > 0.0:
			var src_size: Vector2 = bg_image_texture.get_size()
			var rx: float = (overlap.position.x - dest_rect.position.x) / dest_rect.size.x
			var ry: float = (overlap.position.y - dest_rect.position.y) / dest_rect.size.y
			var rw: float = overlap.size.x / dest_rect.size.x
			var rh: float = overlap.size.y / dest_rect.size.y
			var src_rect: Rect2 = Rect2(Vector2(rx * src_size.x, ry * src_size.y), Vector2(rw * src_size.x, rh * src_size.y))
			draw_texture_rect_region(bg_image_texture, overlap, src_rect, Color(1.0, 1.0, 1.0, bg_image_opacity), false, true)
	# 底纹
	if paper_pattern != 0:
		var sp: float = maxf(pattern_spacing, 4.0)
		var col: Color = pattern_color
		match paper_pattern:
			1:  # 横线
				var y: float = sp
				while y < h:
					draw_line(Vector2(0.0, y), Vector2(w, y), col, 1.0)
					y += sp
			2:  # 方格
				var yg: float = sp
				while yg < h:
					draw_line(Vector2(0.0, yg), Vector2(w, yg), col, 1.0)
					yg += sp
				var xg: float = sp
				while xg < w:
					draw_line(Vector2(xg, 0.0), Vector2(xg, h), col, 1.0)
					xg += sp
			3:  # 点阵
				var yd: float = sp * 0.5
				while yd < h:
					var xd: float = sp * 0.5
					while xd < w:
						draw_circle(Vector2(xd, yd), 1.5, col)
						xd += sp
					yd += sp
			4:  # 活页孔（左侧一列）
				var margin_x: float = 36.0
				var yb: float = sp
				while yb < h:
					draw_arc(Vector2(margin_x, yb), 6.0, 0.0, TAU, 24, col, 1.5)
					yb += sp
	# 吸附网格参考线（开启吸附时显示，浅蓝区别于底纹）
	if snap_grid_enabled:
		var gc: Color = Color(0.45, 0.65, 1.0, 0.3)
		var gs: float = float(snap_grid_size)
		var sx: float = gs
		while sx < w:
			draw_line(Vector2(sx, 0.0), Vector2(sx, h), gc, 1.0)
			sx += gs
		var sy: float = gs
		while sy < h:
			draw_line(Vector2(0.0, sy), Vector2(w, sy), gc, 1.0)
			sy += gs
