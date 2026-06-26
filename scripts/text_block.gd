## TextBlock — 文本块
## 继承 BaseBlock，只实现编辑/预览切换、字号、字体颜色、BBCode 渲染等文本特有逻辑
## Godot 4.6 · GDScript 2.0 严格类型
class_name TextBlock
extends BaseBlock

signal content_changed(data: TextBlockData)
## 打字时发出（参数=光标画布坐标），供 main 在 fx_layer 迸星
signal char_typed(canvas_pos: Vector2)

# ── 文本块专属常量 ──
const TEXT_MIN_WIDTH: int = 120
const TEXT_MIN_HEIGHT: int = 60

var _is_editing: bool = false
var _last_text_len: int = 0  ## 上次文本长度，用于判断是否为「输入字符」

## Tab 键唤起插入面板的信号（由 main 连接处理）
signal request_insert_panel()
## 热键插入信号（由 main 连接处理）
signal request_insert_hotkey(key_code: int)
## 颜文字浮层激活时的按键转发（数字选取/Tab切类/Esc关闭）
signal request_kaomoji_key(key_code: int)

## 插入面板激活状态（静态，所有 TextBlock 共享）
static var insert_panel_active: bool = false
## 颜文字浮层激活状态（静态，所有 TextBlock 共享）
static var kaomoji_panel_active: bool = false

@onready var text_edit: TextEdit = %TextEdit
@onready var rich_label: RichTextLabel = %RichLabel
@onready var live_preview: RichTextLabel = %LivePreview
@onready var edit_area: HBoxContainer = %EditArea


# ═══════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════

func _block_ready() -> void:
	min_width = float(TEXT_MIN_WIDTH)
	min_height = float(TEXT_MIN_HEIGHT)
	text_edit.text_changed.connect(_on_text_changed)
	# 拦截 TextEdit 的 Tab 键：避免被当缩进消费，改为唤起插入面板
	text_edit.gui_input.connect(_on_text_edit_gui_input)
	_switch_mode(false)


## 拦截 TextEdit 内部输入
## - Tab 键：唤起/关闭插入面板
## - 插入面板激活时：数字键/字母键/Esc 由 main 处理（热键插入）
func _on_text_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	# 颜文字浮层激活时，所有按键交给 main 处理（数字选取/Tab切分类/Esc关闭）
	if kaomoji_panel_active:
		request_kaomoji_key.emit(event.keycode)
		text_edit.accept_event()
		return
	# Tab 唤起插入面板
	if event.keycode == KEY_TAB:
		request_insert_panel.emit()
		text_edit.accept_event()
		return
	# 插入面板激活时，热键交给 main 处理
	if insert_panel_active:
		# Esc 关闭面板
		if event.keycode == KEY_ESCAPE:
			insert_panel_active = false
			request_insert_panel.emit()  # 复用关闭逻辑
			text_edit.accept_event()
			return
		# 数字键 1-9,0 和 Q W E R T 触发插入
		var hotkeys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T]
		if event.keycode in hotkeys:
			request_insert_hotkey.emit(event.keycode)
			text_edit.accept_event()


func _block_setup() -> void:
	text_edit.text = _td().bbcode_content
	_apply_font_theme()
	_update_style()
	_update_preview()


## 类型安全的 data 访问器
func _td() -> TextBlockData:
	return data as TextBlockData


# ═══════════════════════════════════════════
#  样式与主题
# ═══════════════════════════════════════════

## 应用字体大小、颜色、字体、描边、行间距主题
func _apply_font_theme() -> void:
	if not is_node_ready():
		await ready
	var theme := Theme.new()
	theme.set_font_size("font_size", "TextEdit", _td().font_size)
	theme.set_font_size("normal_font_size", "RichTextLabel", _td().font_size)
	# 同步 bold/italics/mono 字号，否则 [b][i][code] 会吃默认字号、不和正文一致
	theme.set_font_size("bold_font_size", "RichTextLabel", _td().font_size)
	theme.set_font_size("italics_font_size", "RichTextLabel", _td().font_size)
	theme.set_font_size("mono_font_size", "RichTextLabel", _td().font_size)
	theme.set_color("default_color", "RichTextLabel", _td().font_color)
	# 描边（outline）
	theme.set_constant("outline_size", "RichTextLabel", _td().outline_size)
	theme.set_constant("outline_size", "TextEdit", _td().outline_size)
	theme.set_color("outline_color", "RichTextLabel", _td().outline_color)
	theme.set_color("outline_color", "TextEdit", _td().outline_color)
	# 行间距
	theme.set_constant("line_separation", "RichTextLabel", int((_td().line_spacing - 1.0) * _td().font_size))
	theme.set_constant("line_separation", "TextEdit", int((_td().line_spacing - 1.0) * _td().font_size))
	# 字体：把所有变体(normal/bold/italics/bold_italics)都设成同一字体，
	# 否则 MD 的 [b][i] 标签会回退到默认字体，看起来"字体失效"
	var font: Font = _resolve_font(_td().font_id)
	if font != null:
		theme.set_font("font", "TextEdit", font)
		theme.set_font("normal_font", "RichTextLabel", font)
		theme.set_font("bold_font", "RichTextLabel", font)
		theme.set_font("italics_font", "RichTextLabel", font)
		theme.set_font("bold_italics_font", "RichTextLabel", font)
	text_edit.theme = theme
	rich_label.theme = theme
	live_preview.theme = theme


## 内置字体缓存（避免重复加载）
static var _font_cache: Dictionary = {}

## 根据 font_id 解析 Font 资源
## default = 引擎默认 | mono = Consolas等宽 | serif = 宋体衬线 | 其他 = user://data/fonts/ 下文件
func _resolve_font(font_id: String) -> Font:
	if font_id == "default" or font_id.is_empty():
		return null  # 用引擎默认
	# 缓存命中
	if _font_cache.has(font_id):
		return _font_cache[font_id] as Font
	var font: Font = null
	if font_id == "mono":
		# 等宽：Windows 用 Consolas，跨平台回退到 fallback
		font = _load_system_font("C:/Windows/Fonts/consola.ttf")
	elif font_id == "serif":
		# 衬线：Windows 用宋体
		font = _load_system_font("C:/Windows/Fonts/simsun.ttc")
	else:
		# 自定义字体文件
		var path: String = "user://data/fonts/" + font_id
		if FileAccess.file_exists(path):
			font = load(path) as Font
			if font == null:
				var fl := FontFile.new()
				fl.load_dynamic_font(path)
				font = fl
	if font != null:
		_font_cache[font_id] = font
	return font


## 从系统绝对路径加载字体（用 FontFile 动态加载）
func _load_system_font(abs_path: String) -> Font:
	if not FileAccess.file_exists(abs_path):
		return null
	var fl := FontFile.new()
	fl.load_dynamic_font(abs_path)
	return fl


## 构建文本框外观 StyleBox（背景色 + 内边框 + 圆角 + 框外描边）
## Panel 与悬浮预览共用，保证两者视觉一致
func _build_block_stylebox() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = _td().bg_color
	# 内边框线（原有 border）
	s.border_color = _td().border_color
	s.set_border_width_all(_td().border_width)
	s.set_corner_radius_all(_td().corner_radius)
	# 框外实色描边：用 expand_margin 向外扩展绘制区域，
	# border_width 画在扩展后的外圈，形成纯实色描边（非半透明发光）
	if _td().box_glow_size > 0:
		s.set_border_width_all(_td().border_width + _td().box_glow_size)
		# 描边色优先用 box_glow_color，但用 RGB 实色（强制不透明）
		var outline_c: Color = _td().box_glow_color
		outline_c.a = 1.0
		s.border_color = outline_c
		# 向外扩展，让描边画在块外侧
		var exp_m: float = float(_td().box_glow_size)
		s.expand_margin_left = exp_m
		s.expand_margin_right = exp_m
		s.expand_margin_top = exp_m
		s.expand_margin_bottom = exp_m
	return s


## 应用背景色 + 边框样式 + 圆角 + 框外实色描边
func _update_style() -> void:
	if not is_node_ready():
		await ready
	add_theme_stylebox_override("panel", _build_block_stylebox())
	# 编辑中时同步刷新悬浮预览的外观，保证预览与文本框始终一致
	if _is_editing and is_instance_valid(live_preview) and live_preview.visible:
		_update_live_preview_style()


## 刷新 BBCode 预览（若开启 Markdown 则先转 BBCode）
func _update_preview() -> void:
	rich_label.text = ""
	if _td().bbcode_content.strip_edges().is_empty():
		rich_label.text = "[i][color=#999999]双击编辑[/color][/i]"
		return
	var bb: String = MarkdownToBBCode.convert(_td().bbcode_content, _td().font_size) if _td().use_markdown else _td().bbcode_content
	# 过滤无法加载的 [img]，避免 RichLabel 报 Resource not found 刷屏
	rich_label.parse_bbcode(_sanitize_images(bb))


# ═══════════════════════════════════════════
#  编辑/预览模式切换
# ═══════════════════════════════════════════

func _switch_mode(editing: bool) -> void:
	_is_editing = editing
	text_edit.visible = editing
	rich_label.visible = not editing
	if editing:
		# 编辑模式：TextEdit 占满整个块（保持完整输入框尺寸）；
		# 实时预览悬浮在块右侧、与块同尺寸，不挤压输入框（见 _show_live_preview）。
		# EditArea 用 PASS、TextEdit 用 STOP 接收鼠标用于选文本 / 放光标；
		# 编辑态下 BaseBlock 对左键放行（见 base_block._gui_input），鼠标完全服务文本。
		edit_area.mouse_filter = Control.MOUSE_FILTER_PASS
		text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		text_edit.grab_focus()
		text_edit.select_all()
		_last_text_len = text_edit.text.length()
		_show_live_preview()
	else:
		# 预览模式：TextEdit 不抢鼠标，事件交给 Panel 处理拖拽 / 缩放 / 选中
		edit_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		live_preview.visible = false


func _on_text_changed() -> void:
	# 打字迸星：文本变长（输入字符）时，在光标画布位置冒一颗星
	var new_len: int = text_edit.text.length()
	if _is_editing and new_len > _last_text_len:
		var cdp := text_edit.get_caret_draw_pos()
		var caret_canvas: Vector2 = text_edit.get_global_transform() * Vector2(cdp.x, cdp.y)
		char_typed.emit(caret_canvas)
	_last_text_len = new_len
	_td().bbcode_content = text_edit.text
	_update_preview()
	if _is_editing:
		_refresh_live_preview()
	content_changed.emit(_td())


## 显示悬浮实时预览（编辑态）：块下方、与块同尺寸同外观，看到与文本框一致的最终渲染结果
func _show_live_preview() -> void:
	_update_live_preview_geom()
	_update_live_preview_style()
	live_preview.visible = true
	_refresh_live_preview()

## 预览位置 / 尺寸：悬浮在块下方 12px、大小与块一致
## 放下方是为避开选中块的属性浮层（inspector 贴在右上角）
## （LivePreview 是块子节点，自动跟随块缩放 / 移动 / 旋转）
func _update_live_preview_geom() -> void:
	if not is_instance_valid(live_preview):
		return
	live_preview.size = size
	live_preview.position = Vector2(0.0, size.y + 12.0)

## 预览外观：复刻文本框的背景 / 边框 / 圆角 / 描边，再加内边距
## （内边距模拟 RichLabel 在 Panel 内的 offset 8/8/8/22，文本位置才与真实文本框吻合）
func _update_live_preview_style() -> void:
	if not is_instance_valid(live_preview):
		return
	var s := _build_block_stylebox()
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 22
	live_preview.add_theme_stylebox_override("normal", s)


## 刷新悬浮实时预览的内容（编辑模式用）
func _refresh_live_preview() -> void:
	var bb: String = MarkdownToBBCode.convert(_td().bbcode_content, _td().font_size) if _td().use_markdown else _td().bbcode_content
	live_preview.parse_bbcode(_sanitize_images(bb))


## 过滤 BBCode 中无法加载的 [img] 标签，避免 RichLabel 报 Resource not found
func _sanitize_images(bbcode: String) -> String:
	var rgx := RegEx.new()
	rgx.compile("\\[img[^\\]]*\\](.*?)\\[/img\\]")
	var out := bbcode
	for m in rgx.search_all(bbcode):
		var path: String = (m.get_string(1) as String).strip_edges()
		if not _image_loadable(path):
			out = out.replace(m.get_string(0), "")
	return out


## 判断 [img] 路径是否可加载（res:// 资源 / 绝对路径文件）
func _image_loadable(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://"):
		return ResourceLoader.exists(path, "Texture2D")
	if path.begins_with("user://") or path.is_absolute_path():
		return FileAccess.file_exists(path)
	return ResourceLoader.exists("res://" + path, "Texture2D")


## 是否处于编辑模式（供 main.gd 判断键盘冲突用）
func is_editing() -> bool:
	return _is_editing

## 外部调用：直接进入编辑模式（选中态文本块按 Tab 进入编辑时调用）
## 进入编辑时同步确保选中态生效，避免"编辑了但没选中"的困惑
func enter_edit_mode() -> void:
	if not _is_editing:
		# 确保选中态：自动编辑场景下 select() 可能刚执行，
		# 这里强制再确认一次选中视觉
		if not _is_selected:
			select()
		_switch_mode(true)


# ═══════════════════════════════════════════
#  BaseBlock 钩子实现
# ═══════════════════════════════════════════

## 双击 → 切换编辑/预览模式
func _on_double_click(_mouse_pos: Vector2) -> bool:
	block_selected.emit(self)
	_switch_mode(not _is_editing)
	return true


## 取消选中时退出编辑模式
func _on_deselect() -> void:
	if _is_editing:
		_switch_mode(false)


## 编辑态下让位给文本编辑，不触发 Ctrl 旋转
func _is_editing_local() -> bool:
	return _is_editing


# ═══════════════════════════════════════════
#  外部调用：字号 / 字体颜色
# ═══════════════════════════════════════════

## 主场景将键盘 +/- 事件转过来
func handle_font_size_change(delta_size: int) -> void:
	if not _is_selected or data == null:
		return
	_td().font_size = clampi(_td().font_size + delta_size, 8, 72)
	_apply_font_theme()
	content_changed.emit(_td())


## 主场景传入颜色
func handle_font_color_change(color: Color) -> void:
	if not _is_selected or data == null:
		return
	_td().font_color = color
	_apply_font_theme()
	content_changed.emit(_td())


## 外部调用：设置描边宽度
func handle_outline_size_change(new_size: int) -> void:
	if not _is_selected or data == null:
		return
	_td().outline_size = clampi(new_size, 0, 20)
	_apply_font_theme()
	content_changed.emit(_td())


## 外部调用：设置描边颜色
func handle_outline_color_change(color: Color) -> void:
	if not _is_selected or data == null:
		return
	_td().outline_color = color
	_apply_font_theme()
	content_changed.emit(_td())


## 外部调用：设置块背景色
func handle_bg_color_change(color: Color) -> void:
	if not _is_selected or data == null:
		return
	_td().bg_color = color
	_update_style()
	content_changed.emit(_td())


## 主题换肤用：批量应用「文字色 / 块底色」，不要求选中（main.gd 主题预设调用）
func apply_colors(font_col: Color, bg_col: Color) -> void:
	if data == null:
		return
	_td().font_color = font_col
	_td().bg_color = bg_col
	_apply_font_theme()
	_update_style()
	content_changed.emit(_td())


## 外部调用：设置圆角
func handle_corner_radius_change(new_r: int) -> void:
	if not _is_selected or data == null:
		return
	_td().corner_radius = clampi(new_r, 0, 40)
	_update_style()
	content_changed.emit(_td())


## 外部调用：设置字体标识
func handle_font_id_change(new_id: String) -> void:
	if not _is_selected or data == null:
		return
	_td().font_id = new_id
	_apply_font_theme()
	content_changed.emit(_td())


## 外部调用：设置框外发光宽度
func handle_box_glow_size_change(new_size: int) -> void:
	if not _is_selected or data == null:
		return
	_td().box_glow_size = clampi(new_size, 0, 30)
	_update_style()
	content_changed.emit(_td())


## 外部调用：设置框外发光颜色
func handle_box_glow_color_change(color: Color) -> void:
	if not _is_selected or data == null:
		return
	_td().box_glow_color = color
	_update_style()
	content_changed.emit(_td())


## 外部调用：设置行间距倍数
func handle_line_spacing_change(new_spacing: float) -> void:
	if not _is_selected or data == null:
		return
	_td().line_spacing = clampf(new_spacing, 0.8, 3.0)
	_apply_font_theme()
	content_changed.emit(_td())


## 外部调用：设置文本对齐
func handle_text_alignment_change(align: int) -> void:
	if not _is_selected or data == null:
		return
	_td().text_alignment = clampi(align, 0, 2)
	_update_preview()
	content_changed.emit(_td())


## 外部调用：切换 Markdown 模式
func handle_markdown_toggle(enabled: bool) -> void:
	if not _is_selected or data == null:
		return
	_td().use_markdown = enabled
	_update_preview()
	content_changed.emit(_td())


## 外部调用：在光标位置插入语法包裹
## 无选区：插入 prefix+suffix，光标移到 prefix 之后（[center]光标在这[/center]）
## 有选区：用 prefix+选中文本+suffix 包裹，光标移到选中文本之后
func insert_at_cursor(prefix: String, suffix: String) -> void:
	if not _is_editing:
		return
	var sel: String = text_edit.get_selected_text()
	var caret_line: int = text_edit.get_caret_line()
	var caret_col: int = text_edit.get_caret_column()
	
	if sel.is_empty():
		# 无选区：插入 prefix+suffix，光标移到 prefix 之后
		# 例：插入 [center][/center]，光标停在 [center]|[/center]
		text_edit.insert_text_at_caret(prefix + suffix)
		text_edit.set_caret_line(caret_line)
		text_edit.set_caret_column(caret_col + prefix.length())
	else:
		# 有选区：包裹选中文本
		# insert_text_at_caret 会替换选区，插入 prefix+sel+suffix
		# 光标应停在 sel 之后（prefix 和 suffix 之间），即 caret_col + prefix.length() + sel.length()
		text_edit.insert_text_at_caret(prefix + sel + suffix)
		text_edit.set_caret_line(caret_line)
		text_edit.set_caret_column(caret_col + prefix.length() + sel.length())
	# 确保 TextEdit 保持焦点，光标可见
	text_edit.grab_focus()
	text_edit.editable = true
	_on_text_changed()


## 外部调用：把光标跳到文本末尾（Ctrl+Enter 快捷键）
func move_caret_to_end() -> void:
	if not _is_editing:
		return
	var line_count: int = text_edit.get_line_count()
	text_edit.set_caret_line(line_count - 1)
	var last_line: String = text_edit.get_line(line_count - 1)
	text_edit.set_caret_column(last_line.length())
	text_edit.grab_focus()


## 外部调用：让 TextEdit 重新获取焦点（插入面板关闭后调用）
func grab_text_focus() -> void:
	if _is_editing:
		text_edit.grab_focus()
