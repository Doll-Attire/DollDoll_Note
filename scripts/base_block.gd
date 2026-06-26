## BaseBlock — 所有块元素的基类
## 承载选中态、拖拽移动、边缘缩放、边界夹紧等公共交互逻辑
## 子类（TextBlock / ImageBlock）只需重写 _block_setup / _block_ready / _on_select 等钩子
## Godot 4.6 · GDScript 2.0 严格类型
class_name BaseBlock
extends Panel

signal block_selected(block: BaseBlock)
signal block_moved(block: BaseBlock)
signal block_resized(block: BaseBlock)
signal request_context_menu(block: BaseBlock)
## 拖拽 / 缩放 / 旋转真正开始时发出（供 main 存撤销快照）
signal interaction_started()

# ── 边缘判定位标志 ──
const EDGE_NONE: int = 0
const EDGE_LEFT: int = 1
const EDGE_RIGHT: int = 2
const EDGE_TOP: int = 4
const EDGE_BOTTOM: int = 8

# ── 缩放判定区宽度（基础值，实际会根据块尺寸自适应） ──
const RESIZE_MARGIN_BASE: int = 20

# ── 拖拽触发阈值（全局像素）：按下后移动超过此距离才算拖拽 ──
# 避免单击选中 / 编辑态点光标时因微小抖动误触发整块拖动
const DRAG_THRESHOLD: float = 4.0

# ── 数据与状态 ──
var data: BlockData
var _is_selected: bool = false
var _select_tween: Tween  ## 选中边框呼吸动画
var _scale_tween: Tween  ## spawn/拖动/删除 scale 动画（互斥，新动画 kill 旧）
# ── 拖拽倾斜（果冻感：拖动时朝运动方向倾斜，松开弹回）──
var _last_drag_global: Vector2 = Vector2.ZERO
var _drag_tilt: float = 0.0
var _tilt_tween: Tween
var _float_phase: float = 0.0   ## 闲置浮动初相（随机，避免整齐划一）
var _float_time: float = 0.0    ## 闲置浮动累计时间
var _dragging: bool = false
var _drag_armed: bool = false        ## 已按下待拖：移动超 DRAG_THRESHOLD 才升为 _dragging
var _rotating: bool = false          ## Ctrl+拖拽旋转中
var _rotate_start_angle: float = 0.0 ## 旋转开始时鼠标相对块中心的角度
var _rotate_start_deg: float = 0.0   ## 旋转开始时块的旋转角度
var _resize_edge: int = EDGE_NONE
var _drag_offset: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_mouse_origin: Vector2 = Vector2.ZERO
## 拖拽起点：按下时的全局鼠标位置（视口坐标，不受本块 rotation 影响）
var _drag_mouse_origin: Vector2 = Vector2.ZERO
## 拖拽起点：按下时块在 paper 坐标系下的 position
var _drag_start_pos: Vector2 = Vector2.ZERO

# ── 全局开关（由 main.gd 在设置变更时同步）──
## 为 true 时按住 Ctrl + 左键拖拽 = 旋转块。默认开启。
static var ctrl_drag_rotate_enabled: bool = true
## 为 true 时拖拽块吸附到网格（snap_grid_size 像素）
static var snap_to_grid_enabled: bool = false
static var snap_grid_size: int = 24
## 贴纸呼吸幅度（scale 增量，0 = 关闭呼吸）
static var breathe_amp: float = 0.04
## 贴纸呼吸周期（秒，越小越快）
static var breathe_period: float = 1.3
## 闲置微浮动（仅空闲块：position 叠加 sin 偏移，不改 data，纯视觉不存盘）
static var idle_float_enabled: bool = false
static var idle_float_amp: float = 6.0
static var idle_float_period: float = 3.5

# ── 子类可覆盖的最小尺寸 ──
var min_width: float = 80.0
var min_height: float = 40.0

@onready var resize_handle: Panel = %ResizeHandle
@onready var selection_border: Panel = %SelectionBorder


# ═══════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════

func _ready() -> void:
	resized.connect(_on_self_resized)
	_block_ready()


## 子类钩子：_ready 中的特有初始化
func _block_ready() -> void:
	pass


## 通用 setup：应用位置/尺寸/旋转，然后调用子类 _block_setup 做特有加载
func setup(block_data: BlockData) -> void:
	data = block_data
	position = data.position
	size = data.size
	pivot_offset = size / 2.0
	rotation = deg_to_rad(data.rotation_degrees)
	z_index = data.z_index
	modulate.a = data.opacity
	_block_setup()
	deselect()
	_float_phase = randf() * TAU


## 子类钩子：setup 中的特有加载（如读取图片、应用主题）
func _block_setup() -> void:
	pass


func _on_self_resized() -> void:
	pivot_offset = size / 2.0

## 闲置微浮动：仅完全空闲（非拖拽/缩放/旋转/选中/编辑）时给 position 叠加轻微 sin 偏移
## 不改 data.position（纯视觉不存盘）；选中或编辑中暂停，避免干扰操作与输入
func _process(delta: float) -> void:
	if data == null or not idle_float_enabled:
		return
	if not _is_idle_for_float():
		return
	_float_time += delta
	var off: float = sin(_float_time / idle_float_period * TAU + _float_phase) * idle_float_amp
	position = data.position + Vector2(0.0, off)

## 是否处于可闲置浮动的状态（排除一切交互 / 选中 / 编辑）
func _is_idle_for_float() -> bool:
	if _dragging or _rotating or _resize_edge != EDGE_NONE:
		return false
	if _is_selected or _is_editing_local():
		return false
	return true


# ═══════════════════════════════════════════
#  选中状态
# ═══════════════════════════════════════════

func select() -> void:
	_is_selected = true
	selection_border.visible = true
	resize_handle.visible = true
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = Color(0.3, 0.6, 1.0, 1.0)
	s.set_border_width_all(4)
	s.set_corner_radius_all(8)
	selection_border.add_theme_stylebox_override("panel", s)
	# 选中边框呼吸动画：增亮脉动（蓝→亮蓝，醒目）
	if _select_tween:
		_select_tween.kill()
	selection_border.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_select_tween = create_tween().set_loops()
	_select_tween.tween_property(selection_border, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tween.tween_property(selection_border, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_on_select()


func deselect() -> void:
	_is_selected = false
	_dragging = false
	_drag_armed = false
	_resize_edge = EDGE_NONE
	if _select_tween:
		_select_tween.kill()
		_select_tween = null
	selection_border.modulate = Color(1, 1, 1, 1)
	selection_border.visible = false
	resize_handle.visible = false
	_on_deselect()


# ═══════════════════════════════════════════
#  Q 弹动画（spawn / 删除 / 拖动抬起，统一视觉逻辑）
# ═══════════════════════════════════════════

## spawn 弹出：scale 0.65→1.0 ELASTIC + 淡入（Q 弹落地，时长偏长更从容）
func _play_spawn_anim() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.65, 0.65)
	modulate.a = 0.0
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_scale_tween.tween_property(self, "modulate:a", data.opacity, 0.25)


## 印章盖戳动画：从大歪着砸下 → 落地压扁 → Q弹回正（盖章的「啪」+回弹手感）
func _play_stamp_anim() -> void:
	pivot_offset = size / 2.0
	if _scale_tween:
		_scale_tween.kill()
	# 初始：大 + 略歪 + 透明（悬在空中）
	scale = Vector2(1.8, 1.8)
	modulate.a = 0.0
	rotation = deg_to_rad(data.rotation_degrees + 14.0)
	_scale_tween = create_tween()
	# 阶段 1：加速砸下，落地瞬间压扁（宽矮）+ 快速淡入 ——「啪」
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.12) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_scale_tween.tween_property(self, "modulate:a", data.opacity, 0.07)
	# 阶段 2：压扁后 Q弹回正（ELASTIC 过冲）+ 旋转抖着回正
	_scale_tween.chain().set_parallel(true)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_scale_tween.tween_property(self, "rotation", deg_to_rad(data.rotation_degrees), 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


## 删除：scale→0.2 + 淡出（Q 弹消失），结束后 queue_free
func _play_delete_anim() -> void:
	pivot_offset = size / 2.0
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_parallel(true)
	_scale_tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.32) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "modulate:a", 0.0, 0.32)
	_scale_tween.chain().tween_callback(queue_free)


## 拖动抬起：scale 1.0↔1.03（抓起放大 / 放下回弹）
func _play_drag_anim(up: bool) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	var target: Vector2 = Vector2(1.03, 1.03) if up else Vector2.ONE
	_scale_tween.tween_property(self, "scale", target, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## 子类钩子：选中时额外操作
func _on_select() -> void:
	pass


## 子类钩子：取消选中时额外操作（如退出编辑模式）
func _on_deselect() -> void:
	pass


# ═══════════════════════════════════════════
#  边缘判定与光标
# ═══════════════════════════════════════════

## 当前实际缩放判定宽度（自适应：大块用大值，小块缩小避免全是边缘）
## 取块短边的 20%，上限 RESIZE_MARGIN_BASE，下限 10
func _current_resize_margin() -> float:
	var shorter: float = minf(size.x, size.y)
	return clampf(shorter * 0.2, 10.0, float(RESIZE_MARGIN_BASE))

## 判断鼠标在哪个边缘（位标志组合）
func _get_edge(mouse_pos: Vector2) -> int:
	# 编辑态下不做边缘缩放判定：让位给文本光标定位/选词，
	# 避免在文本框外缘点击放置光标时误触发缩放（缩放改走右下角手柄）
	if _is_editing_local():
		return EDGE_NONE
	var m: float = _current_resize_margin()
	var e := EDGE_NONE
	if mouse_pos.x <= m:
		e |= EDGE_LEFT
	elif mouse_pos.x >= size.x - m:
		e |= EDGE_RIGHT
	if mouse_pos.y <= m:
		e |= EDGE_TOP
	elif mouse_pos.y >= size.y - m:
		e |= EDGE_BOTTOM
	return e


## 根据边缘位标志返回对应的鼠标光标形状
func _cursor_for_edge(edge: int) -> int:
	if edge == EDGE_NONE:
		return Control.CURSOR_ARROW
	var h := edge & (EDGE_LEFT | EDGE_RIGHT)
	var v := edge & (EDGE_TOP | EDGE_BOTTOM)
	if h and v:
		var left_top := (edge & EDGE_LEFT and edge & EDGE_TOP) or \
						(edge & EDGE_RIGHT and edge & EDGE_BOTTOM)
		return Control.CURSOR_FDIAGSIZE if left_top else Control.CURSOR_BDIAGSIZE
	if h:
		return Control.CURSOR_HSIZE
	return Control.CURSOR_VSIZE


# ═══════════════════════════════════════════
#  边界夹紧
# ═══════════════════════════════════════════

## 拖拽/缩放后调用，确保块基本在纸张可视范围内
func _clamp_inside_paper() -> void:
	var parent: Control = get_parent()
	if parent == null:
		return
	var parent_size := parent.size
	if parent_size.x <= 0 or parent_size.y <= 0:
		return
	# 留出缩放判定宽度给缩放手柄，避免手柄溢出可视区
	var margin := _current_resize_margin()
	position.x = clampf(position.x, -margin, parent_size.x - size.x + margin)
	position.y = clampf(position.y, -margin, parent_size.y - size.y + margin)
	data.position = position


# ═══════════════════════════════════════════
#  鼠标交互
# ═══════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	var mouse_pos := get_local_mouse_position()

	# 右键：请求上下文菜单（DrawBlock 自行 override：右键拖动画图、右键单击仍弹菜单）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		request_context_menu.emit(self)
		get_viewport().set_input_as_handled()
		return
	# ── 鼠标按下/释放 ──
	if event is InputEventMouseButton and \
	   event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 编辑态：左键完全交给文本控件（选文本 / 放光标），不拖拽 / 缩放块
			# （用户在编辑文本时不会想拖动输入框；退出编辑靠点外部 / Esc）
			if _is_editing_local():
				return
			# 双击交给子类钩子处理（如 TextBlock 进入编辑模式）
			if event.double_click:
				if _on_double_click(mouse_pos):
					get_viewport().set_input_as_handled()
					return
			block_selected.emit(self)
			# Alt + 点击：交给 main 复制块（本块不进入拖拽）
			if event.alt_pressed:
				return
			# 块上不再 Ctrl 旋转——旋转统一走「控件外 Ctrl + 拖拽」全局手势。
			# Ctrl + 点击由 main 做 Windows 式多选 toggle（加入 / 剔除）。
			# 若本块被剔除（_is_selected 已被 main 置 false）则不进入拖拽；
			# 加入则可像普通块一样拖动整组选中块。
			if event.ctrl_pressed and not _is_selected:
				return
			_drag_offset = mouse_pos
			_resize_edge = _get_edge(mouse_pos)
			if _resize_edge == EDGE_NONE:
				# 不立即进入拖拽：先 arm，移动超 DRAG_THRESHOLD 才真正拖
				# （避免单击 / 编辑态点光标时微小抖动误触发整块拖动）
				_drag_armed = true
				# 记录拖拽起点（全局鼠标 + 当前 position），后续用绝对差定位
				_drag_mouse_origin = get_global_mouse_position()
				_last_drag_global = _drag_mouse_origin
				_drag_start_pos = data.position
			else:
				interaction_started.emit()
				_resize_start_size = size
				_resize_start_pos = position
				_resize_mouse_origin = get_global_mouse_position()
			return
		else:
			var was_dragging: bool = _dragging
			_dragging = false
			_drag_armed = false
			_resize_edge = EDGE_NONE
			_rotating = false
			# 仅在真正拖拽过时才回弹（单击没动过 scale/rotation，不必播放）
			if was_dragging:
				_play_drag_anim(false)
				# 拖拽倾斜弹回（ELASTIC 回到 data.rotation_degrees）
				if _tilt_tween:
					_tilt_tween.kill()
				_drag_tilt = 0.0
				_tilt_tween = create_tween()
				_tilt_tween.tween_property(self, "rotation", deg_to_rad(data.rotation_degrees), 0.4) \
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			return

	# ── 鼠标移动 ──
	if event is InputEventMouseMotion:
		# 旋转优先级最高
		if _rotating:
			_do_rotate_drag(get_global_mouse_position())
			return
		if _resize_edge != EDGE_NONE:
			_do_resize(get_global_mouse_position())
			_clamp_inside_paper()
			return
		# armed → dragging：移动超过阈值才真正拖（单击 / 选文本不被误判为拖）
		if _drag_armed and not _dragging:
			if (get_global_mouse_position() - _drag_mouse_origin).length() > DRAG_THRESHOLD:
				_drag_armed = false
				_dragging = true
				interaction_started.emit()
				if _tilt_tween:
					_tilt_tween.kill()
				_play_drag_anim(true)
		if _dragging:
			# 用全局鼠标位置差换算到 paper 坐标，避免 event.relative 被
			# 接收控件自身的旋转变换所旋转——那是旋转后拖拽方向错乱的根因。
			var paper: Control = get_parent()
			if paper == null:
				return
			var zoom: float = paper.scale.x if paper.scale.x != 0 else 1.0
			var cur_global: Vector2 = get_global_mouse_position()
			var delta_global: Vector2 = cur_global - _drag_mouse_origin
			var delta_paper: Vector2 = delta_global / zoom
			position = _drag_start_pos + delta_paper
			if snap_to_grid_enabled:
				position = position.snapped(Vector2(float(snap_grid_size), float(snap_grid_size)))
			data.position = position
			_clamp_inside_paper()
			# 拖拽倾斜：水平速度 → 朝运动方向倾斜（果冻感），松开弹回
			var vel: Vector2 = cur_global - _last_drag_global
			_last_drag_global = cur_global
			_drag_tilt = clampf(vel.x * 0.35, -10.0, 10.0)
			rotation = deg_to_rad(data.rotation_degrees + _drag_tilt)
			block_moved.emit(self)
			return
		# 悬停时更新光标样式
		mouse_default_cursor_shape = _cursor_for_edge(_get_edge(mouse_pos))


## 子类可覆盖：是否正处于自身编辑态（编辑态下 Ctrl 旋转让位给文本编辑）
func _is_editing_local() -> bool:
	return false


## Ctrl+拖拽旋转：以块中心为轴，鼠标角度变化即旋转角度
func _do_rotate_drag(global_mouse: Vector2) -> void:
	var center_global: Vector2 = global_position + size * 0.5
	var cur_angle: float = global_mouse.angle_to_point(center_global)
	var delta_deg: float = rad_to_deg(cur_angle - _rotate_start_angle)
	# 吸附：不按 shift 时每 5° 吸附，按 shift 自由
	var new_deg: float = _rotate_start_deg + delta_deg
	if not Input.is_key_pressed(KEY_SHIFT):
		new_deg = roundf(new_deg / 5.0) * 5.0
	# 归一化到 [0, 360)
	new_deg = fmod(new_deg, 360.0)
	if new_deg < 0:
		new_deg += 360.0
	data.rotation_degrees = new_deg
	rotation = deg_to_rad(new_deg)
	block_resized.emit(self)  # 复用 resized 信号触发脏标记


## 开始全局旋转（供 main.gd 在控件外按 Ctrl 拖拽时调用）
func start_global_rotate(mouse_global: Vector2) -> void:
	_rotating = true
	interaction_started.emit()
	var center_global: Vector2 = global_position + size * 0.5
	_rotate_start_angle = mouse_global.angle_to_point(center_global)
	_rotate_start_deg = data.rotation_degrees


## 结束旋转
func stop_rotate() -> void:
	_rotating = false


## 子类钩子：双击处理。返回 true 表示已消费事件（如进入编辑模式）
func _on_double_click(_mouse_pos: Vector2) -> bool:
	return false


# ═══════════════════════════════════════════
#  缩放（核心修复：处理 zoom 和 rotation）
# ═══════════════════════════════════════════

## 拖拽边缘缩放。关键修正：
## 1. 全局鼠标 delta 除以 paper.scale，换算到 paper 局部空间
##    （否则 zoom≠1 时缩放过冲，缩小方向尤其明显——"拉不动"的元凶）
## 2. 若块有旋转，再把 delta 旋转 -rotation，换算到块自身局部坐标系
##    （否则旋转 45° 后拉右边，方向对不上）
func _do_resize(global_mouse: Vector2) -> void:
	var paper: Control = get_parent()
	if paper == null:
		return
	var zoom: float = paper.scale.x if paper.scale.x != 0 else 1.0

	var delta_global: Vector2 = global_mouse - _resize_mouse_origin
	# 全局像素差 → paper 局部坐标差
	var delta_local: Vector2 = delta_global / zoom
	# 若块旋转过，转到块自身坐标系（边缘方向才对得上）
	if rotation != 0.0:
		delta_local = delta_local.rotated(-rotation)

	var new_pos := _resize_start_pos
	var new_size := _resize_start_size

	if _resize_edge & EDGE_LEFT:
		new_pos.x = _resize_start_pos.x + delta_local.x
		new_size.x = _resize_start_size.x - delta_local.x
		if new_size.x < min_width:
			new_pos.x = _resize_start_pos.x + _resize_start_size.x - min_width
			new_size.x = min_width
	elif _resize_edge & EDGE_RIGHT:
		new_size.x = _resize_start_size.x + delta_local.x
		new_size.x = maxf(new_size.x, min_width)

	if _resize_edge & EDGE_TOP:
		new_pos.y = _resize_start_pos.y + delta_local.y
		new_size.y = _resize_start_size.y - delta_local.y
		if new_size.y < min_height:
			new_pos.y = _resize_start_pos.y + _resize_start_size.y - min_height
			new_size.y = min_height
	elif _resize_edge & EDGE_BOTTOM:
		new_size.y = _resize_start_size.y + delta_local.y
		new_size.y = maxf(new_size.y, min_height)

	position = new_pos
	size = new_size
	data.position = new_pos
	data.size = new_size
	block_resized.emit(self)


# ═══════════════════════════════════════════
#  数据收集
# ═══════════════════════════════════════════

## 外部调用：返回当前块的数据（用于保存）
func collect_data() -> BlockData:
	return data
