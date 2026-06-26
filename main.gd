## DollDollNote — 主脚本
## 管理所有组件：工具栏、纸张画布、贴纸面板、自动保存和导出
## Godot 4.6
extends Control

# ═══════════════════════════════════════════
#  节点引用
# ═══════════════════════════════════════════

@onready var toolbar: ColorRect = %Toolbar
@onready var open_btn: Button = %OpenBtn
@onready var new_btn: MenuButton = %NewBtn
@onready var markdown_btn: Button = %MarkdownBtn
@onready var note_list_btn: Button = %NoteListBtn
@onready var toolbar_divider: ColorRect = $ToolbarDivider
@onready var add_text_btn: Button = %AddTextBtn
@onready var add_image_btn: Button = %AddImageBtn
@onready var shape_btn: MenuButton = %ShapeBtn
@onready var doodle_btn: Button = %DoodleBtn
@onready var diary_btn: Button = %DiaryBtn
@onready var font_size_label: Label = %FontSizeLabel
@onready var font_color_btn: ColorPickerButton = %FontColorBtn
@onready var font_option_btn: OptionButton = %FontOptionBtn
@onready var outline_label: Label = %OutlineLabel
@onready var outline_spin: SpinBox = %OutlineSpin
@onready var outline_color_btn: ColorPickerButton = %OutlineColorBtn
@onready var block_bg_label: Label = %BlockBgLabel
@onready var block_bg_color_btn: ColorPickerButton = %BlockBgColorBtn
@onready var text_more_btn: Button = %TextMoreBtn
@onready var insert_btn: Button = %InsertBtn
@onready var emoji_btn: Button = %EmojiBtn
@onready var rotate_label: Label = %RotateLabel
@onready var rotate_left_btn: Button = %RotateLeftBtn
@onready var rotate_right_btn: Button = %RotateRightBtn
@onready var rotate_reset_btn: Button = %RotateResetBtn
@onready var bg_color_picker: ColorPickerButton = %BgColorPicker
@onready var canvas_size_btn: MenuButton = %CanvasSizeBtn
@onready var sticker_toggle: Button = %StickerToggle
@onready var export_json_btn: Button = %ExportJsonBtn
@onready var export_image_btn: Button = %ExportImageBtn
@onready var body: HBoxContainer = %Body
@onready var paper_scroll: Control = %PaperScroll
@onready var paper: PaperDropTarget = %Paper
@onready var sticker_panel: VBoxContainer = %StickerPanel
@onready var splitter: Control = %Splitter
@onready var open_sticker_dir: Button = %OpenStickerDir
@onready var refresh_stickers: Button = %RefreshStickers
@onready var sticker_to_emoji_btn: Button = %StickerToEmojiBtn
@onready var sticker_stamp_btn: Button = %StickerStampBtn
@onready var sticker_scroll: ScrollContainer = %StickerScroll
@onready var sticker_grid: GridContainer = %StickerGrid
@onready var settings_btn: MenuButton = %SettingsBtn
@onready var help_btn: Button = %HelpBtn
@onready var hint_label: Label = %HintLabel
@onready var sep_style: VSeparator = %Separator1
@onready var sep_rotate: VSeparator = %SeparatorR

# ── 文本进阶设置二级面板（动态构建）──
var _text_more_popup: PopupPanel
var _line_spacing_spin: SpinBox
var _box_glow_spin: SpinBox
var _box_glow_color_btn: ColorPickerButton
var _corner_radius_spin: SpinBox
var _markdown_check: CheckBox
## 快捷插入浮层（用 Control 而非 PopupPanel：
## Popup 会夺取 GUI 焦点上下文，导致 TextEdit 失焦、数字热键失效；
## Control 不改变焦点，TextEdit 保持焦点，Tab/数字键/Esc 正常路由）
var _insert_popup: Control
## 当前插入面板的热键映射: { key_code: [prefix, suffix] }
var _insert_hotkeys: Dictionary = {}
## 插入面板是否激活（Tab 唤起后为 true，插入后或关闭后为 false）
var _insert_panel_active: bool = false
## 颜文字浮层（Control，复用 insert panel 不抢焦点模式）
var _kaomoji_popup: Panel
var _kaomoji_active: bool = false
var _kaomoji_index: int = 0    ## 当前分类索引
var _kaomoji_cats: Array = []  ## 缓存 KaomojiData.get_categories()
var _kaomoji_hotkeys: Array = []  ## 当前分类的颜文字（按热键顺序）
## 颜文字热键序列（1-9,0 对应当前分类前 10 个颜文字）
const KAOMOJI_HOTKEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
## 选中属性浮层（z轴/透明度/删除）
var _inspector_popup: Panel
var _z_spin: SpinBox
var _opacity_spin: SpinBox
var _draw_color_btn: ColorPickerButton
var _draw_width_spin: SpinBox
var _draw_smooth_spin: SpinBox
var _draw_pen_tip_chk: CheckBox
var _draw_brush_opt: OptionButton
var _draw_tools_box: VBoxContainer

# ── 笔记列表面板（左侧，多日记切换）──
var _note_list_panel: Panel
var _note_list: VBoxContainer
var _note_splitter: Control
var _emoji_popup: Control
var _diary_popup: PopupPanel

var _current_selected_block: BaseBlock = null
# ── 多选状态 ──
var _selected_blocks: Array[BaseBlock] = []   ## 选中块集合（单选时 size=1）
var _box_selecting: bool = false              ## 正在框选
var _box_start: Vector2 = Vector2.ZERO        ## 框选起点（paper 局部坐标）
var _drag_last_pos: Vector2 = Vector2.ZERO    ## 批量移动同步用：拖拽块上次位置
var _selection_box: ColorRect                 ## 框选可视化矩形
var _current_page_data: PageData
var _autosave_timer: Timer
var _zoom: float = 1.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.15

# ── 用户设置（持久化到 settings.json）──
var _setting_ctrl_drag_rotate: bool = true ## Ctrl+拖拽旋转
var _setting_default_font_size: int = 22   ## 默认字号
var _setting_default_block_bg: Color = Color("#FFF3E0")  ## 默认块底色
var _setting_default_font_color: Color = Color.BLACK  ## 默认文字颜色
var _setting_default_opacity: float = 1.0  ## 默认块透明度（0.1~1.0）
var _setting_default_font_id: String = "default"  ## 默认字体
var _setting_default_alignment: int = 0   ## 默认对齐 0左1中2右
var _setting_snap_grid: bool = false   ## 移动时吸附网格

# ──「新建」菜单勾选状态（默认全保留：清内容、留纸张样式）──
var _new_keep_size: bool = true
var _new_keep_pattern: bool = true
var _new_keep_bg_image: bool = true
var _new_keep_bg_color: bool = true

# ── 特效开关（默认轨迹+点击开，环境特效按需开启）──
var _setting_fx_trail: bool = true
var _setting_fx_click: bool = true
var _setting_fx_meteor: bool = false
var _setting_fx_water: bool = false
var _setting_fx_petal: bool = false
var _setting_fx_rain: bool = false
var _setting_fx_snow: bool = false
var _setting_fx_firefly: bool = false
var _setting_fx_ripple: bool = false
var _setting_fx_vignette: bool = false   ## 画面氛围：暗角
var _setting_fx_scanlines: bool = false  ## 画面氛围：复古扫描线
var _setting_fx_grain: bool = false      ## 画面氛围：胶片颗粒
var _setting_fx_light_leak: bool = false ## 画面氛围：暖色漏光

# ── 贴纸呼吸（幅度 0 = 关闭）──
var _setting_breathe_amp: float = 0.04
var _setting_breathe_period: float = 1.3
var _setting_idle_float: bool = false  ## 闲置微浮动（块静止时轻微上下漂浮）
var _setting_inspector_docked: bool = false  ## 属性栏固定右侧（true=钉右侧，false=跟随浮窗）

# ── 全局 Ctrl 旋转状态（允许在控件外拖拽旋转选中块）──
var _global_rotating: bool = false
var _fx_layer: FXLayer
var _canvas_fx: ColorRect            ## 画面氛围叠加层（暗角/扫描线/颗粒/漏光）
var _canvas_fx_mat: ShaderMaterial ## 画面氛围 shader 材质
var _last_trail_pos: Vector2 = Vector2.ZERO  ## 鼠标星光轨迹节流：上次生成星的位置
var _last_ripple_pos: Vector2 = Vector2.ZERO  ## 鼠标涟漪节流：上次生成涟漪的位置
var _style_clipboard: Dictionary = {}  ## 复制样式剪贴板（存文本块样式字段）

# ── 撤销 / 重做（整页快照栈）──
var _undo_stack: Array = []
var _redo_stack: Array = []
const UNDO_LIMIT: int = 40
var _suspend_undo: bool = false  ## 恢复快照时暂停 push，避免循环

# ── Markdown 编辑器（全屏，左编辑右预览）──
const MD_SYNTAXES: Array = [
	["# H1", "# ", ""],
	["**B**", "**", "**"],
	["*I*", "*", "*"],
	["- 列表", "- ", ""],
	["> 引用", "> ", ""],
	["`代码`", "`", "`"],
]
var _md_panel: Control
var _md_toolbar: ColorRect
var _md_edit: TextEdit
var _md_preview: RichTextLabel
var _md_filename_edit: LineEdit
var _md_is_open: bool = false
var _md_last_len: int = 0  ## md 编辑器上次文本长度，用于打字迸星

# ── Markdown 显示设置（字号 / 字色 / 背景色 / 背景不透明度）──
var _setting_md_font_size: int = 18
var _setting_md_font_color: Color = Color(0.14, 0.14, 0.18)
var _setting_md_bg_color: Color = Color(1.0, 1.0, 1.0)
var _setting_md_bg_opacity: float = 0.0  ## 0=完全透明（透纸张纹理），1=不透明底色
var _setting_onboarding_done: bool = false  ## 是否已完成首次上手引导

# ── 中键拖拽平移状态 ──
var _middle_dragging: bool = false
var _middle_drag_last: Vector2 = Vector2.ZERO
var _last_hint_key: String = ""  ## 底部提示条去重：上次状态键，变化时才刷新文字
var _stamp_mode: bool = false    ## 印章模式：开启后点画布盖戳
var _stamp_emoji: String = "💮"  ## 当前印章图案

# 数据存到 user://（用户数据目录），确保导出后可读写
const DATA_DIR: String = "user://data/"
const STICKER_DIR: String = DATA_DIR + "stickers/"
const IMAGE_DIR: String = DATA_DIR + "images/"
const NOTE_DIR: String = DATA_DIR + "notes/"
const TEMPLATE_DIR: String = DATA_DIR + "templates/"
const SETTINGS_PATH: String = DATA_DIR + "settings.json"
const FONT_DIR: String = DATA_DIR + "fonts/"

# 内置字体选项: [显示名, font_id]
const FONT_PRESETS: Array = [
	["默认", "default"],
	["等宽", "mono"],
	["衬线", "serif"],
	["加载自定义…", "__custom__"],
]

# 画布预设: [名称, 宽, 高]
const CANVAS_PRESETS: Array = [
	["A4竖版", 800, 1100],
	["A4横版", 1100, 800],
	["方形", 900, 900],
	["宽屏", 1200, 800],
	["大号宽屏", 1600, 1000],
]

# 预加载场景
var _text_block_scene: PackedScene = preload("res://scenes/text_block.tscn")
var _image_block_scene: PackedScene = preload("res://scenes/image_block.tscn")
var _shape_block_scene: PackedScene = preload("res://scenes/shape_block.tscn")
var _draw_block_scene: PackedScene = preload("res://scenes/draw_block.tscn")
var _emoji_sticker_scene: PackedScene = preload("res://scenes/emoji_sticker_block.tscn")

# 形状预设: [名称, ShapeType 枚举值]
## 主题配色预设：[显示名, 纸色, 块底色, 文字色]
const THEME_PRESETS: Array = [
	["☁️ 原味", Color(1.0, 1.0, 1.0), Color(1.0, 0.953, 0.882), Color(0.0, 0.0, 0.0)],
	["🌸 马卡龙", Color(1.0, 0.941, 0.961), Color(1.0, 0.973, 0.984), Color(0.545, 0.353, 0.420)],
	["🫧 莫兰迪", Color(0.910, 0.894, 0.863), Color(0.949, 0.937, 0.914), Color(0.290, 0.290, 0.322)],
	["🍵 和纸", Color(0.961, 0.941, 0.882), Color(1.0, 0.996, 0.969), Color(0.227, 0.208, 0.188)],
	["📜 牛皮纸", Color(0.851, 0.773, 0.627), Color(0.961, 0.918, 0.816), Color(0.353, 0.262, 0.149)],
	["🌿 薄荷", Color(0.890, 0.941, 0.918), Color(0.957, 0.980, 0.965), Color(0.184, 0.365, 0.310)],
]

## 印章图案库
const STAMP_EMOJIS: Array = ["💮", "🌸", "🌟", "✨", "❤️", "💛", "✅", "🎀", "🍀", "⭐", "💖", "🎉"]

const CANVAS_FX_SHADER: Shader = preload("res://scripts/canvas_fx.gdshader")

const SHAPE_PRESETS: Array = [
	["矩形", 0],
	["椭圆", 1],
	["直线", 2],
	["箭头", 3],
]

# ═══════════════════════════════════════════
#  初始化
# ═══════════════════════════════════════════

func _ready():
	_load_settings()
	_apply_settings_to_blocks()
	_setup_paper_style()
	_setup_selection_box()
	_apply_ui_theme()
	_setup_autosave()
	_setup_canvas_menu()
	_setup_shape_menu()
	_setup_settings_menu()
	_setup_new_menu()
	_setup_fx_layer()
	_setup_canvas_fx()
	_setup_md_editor()
	_setup_md_toolbar()
	_setup_note_list()
	_setup_font_options()
	_setup_text_more_panel()
	_setup_insert_panel()
	_setup_kaomoji_panel()
	_setup_inspector()
	_setup_emoji_panel()
	_setup_diary_panel()
	_connect_signals()
	_load_or_new_page()
	_populate_stickers()
	_setup_drop()
	_update_font_ui()
	# 首次使用：延迟一帧弹上手卡（此时窗口与各面板均已就绪）
	if not _setting_onboarding_done:
		_show_onboarding.call_deferred()

func _setup_autosave():
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_autosave)
	add_child(_autosave_timer)

func _setup_paper_style():
	var s := StyleBoxFlat.new()
	s.bg_color = Color.WHITE
	s.shadow_size = 4
	s.shadow_color = Color(0, 0, 0, 0.08)
	paper.add_theme_stylebox_override("panel", s)

## 应用统一 UI 主题：按钮圆角、柔和配色、hover 效果
## 轻度精修，不破坏现有结构
func _apply_ui_theme() -> void:
	var theme := Theme.new()
	# 按钮默认样式
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(1, 1, 1, 0.9)
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 10
	btn_normal.content_margin_right = 10
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0, 0, 0, 0.08)
	theme.set_stylebox("normal", "Button", btn_normal)
	# hover
	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(1, 1, 1, 1)
	theme.set_stylebox("hover", "Button", btn_hover)
	# pressed
	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.82, 0.82, 0.85, 1)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	# 字体颜色
	theme.set_color("font_color", "Button", Color(0.25, 0.25, 0.28, 1))
	theme.set_color("font_hover_color", "Button", Color(0.15, 0.15, 0.18, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.2, 0.2, 0.23, 1))
	# 应用到工具栏内所有按钮
	toolbar.theme = theme
	# 贴纸面板也用
	sticker_panel.theme = theme

func _setup_canvas_menu():
	var popup := canvas_size_btn.get_popup()
	popup.clear()
	for p in CANVAS_PRESETS:
		popup.add_item(p[0])
	popup.add_separator()
	popup.add_item("自定义…")
	popup.add_separator()
	# 底纹子菜单（id 100..104 由子菜单发出，仍统一走 _on_canvas_preset_selected）
	var pm := PopupMenu.new()
	pm.name = "PatternMenu"
	pm.add_item("空白", 100)
	pm.add_item("横线", 101)
	pm.add_item("方格", 102)
	pm.add_item("点阵", 103)
	pm.add_item("活页孔", 104)
	pm.id_pressed.connect(_on_canvas_preset_selected)
	popup.add_child(pm)
	popup.add_submenu_item("📄 底纹…", "PatternMenu")
	popup.add_separator()
	popup.add_item("🖼 背景图…", 200)
	popup.id_pressed.connect(_on_canvas_preset_selected)

## 形状菜单
func _setup_shape_menu():
	var popup: PopupMenu = shape_btn.get_popup()
	popup.clear()
	for s in SHAPE_PRESETS:
		var sp: Array = s as Array
		popup.add_item(sp[0], sp[1])
	popup.id_pressed.connect(_on_shape_selected)

## 添加形状块 / 涂鸦块
func _on_shape_selected(type_id: int):
	if type_id == 100:
		# 涂鸦块
		var ddata := DrawBlockData.new()
		ddata.position = _get_spawn_position()
		var dblock: DrawBlock = _spawn_block(ddata) as DrawBlock
		_mark_dirty()
		_deselect_all()
		dblock.block_selected.emit(dblock)
		_update_font_ui()
		return
	# 普通形状块
	var data := ShapeBlockData.new()
	data.position = _get_spawn_position()
	data.shape_type = type_id as ShapeBlockData.ShapeType
	
	var block: ShapeBlock = _spawn_block(data) as ShapeBlock
	_mark_dirty()

	_deselect_all()
	block.block_selected.emit(block)
	_update_font_ui()

## 工具栏「✏️ 涂鸦」按钮：创建涂鸦块（复用 _on_shape_selected 的涂鸦分支）
func _on_add_doodle() -> void:
	_on_shape_selected(100)


# ── 设置菜单（下拉勾选列表）──
# 设置项 ID
const SETTING_ID_CTRL_ROTATE: int = 1
const SETTING_ID_DEFAULT_TEXT: int = 2
const SETTING_ID_SNAP_GRID: int = 3
const SETTING_ID_HELP: int = 4
const SETTING_ID_FX_TRAIL: int = 5
const SETTING_ID_FX_CLICK: int = 6
const SETTING_ID_FX_METEOR: int = 7
const SETTING_ID_FX_WATER: int = 8
const SETTING_ID_FX_PETAL: int = 9
const SETTING_ID_FX_RAIN: int = 11
const SETTING_ID_FX_SNOW: int = 12
const SETTING_ID_FX_FIREFLY: int = 13
const SETTING_ID_FX_RIPPLE: int = 14
const SETTING_ID_BREATHE: int = 10
const SETTING_ID_THEME: int = 15
const SETTING_ID_FLOAT: int = 16
const SETTING_ID_FX_VIGNETTE: int = 17
const SETTING_ID_FX_SCANLINES: int = 18
const SETTING_ID_FX_GRAIN: int = 19
const SETTING_ID_FX_LIGHT_LEAK: int = 20
const SETTING_ID_DOCK_INSPECTOR: int = 21
## 吸附网格大小（像素）
const GRID_SNAP_SIZE: int = 24

## 设置菜单勾选项文本前缀（✅/⬜）——某些主题下 PopupMenu 默认勾选图标渲染不出来，用文本前缀兜底
func _check_text(label: String, checked: bool) -> String:
	return ("✅ " if checked else "⬜ ") + label

## 加一个勾选项（文本带前缀 + 设 checked 状态）
func _add_check(popup: PopupMenu, label: String, id: int, checked: bool) -> void:
	popup.add_check_item(_check_text(label, checked), id)
	popup.set_item_checked(popup.get_item_index(id), checked)

## 切换勾选项状态（刷新 checked + 文本前缀）
func _refresh_check(popup: PopupMenu, idx: int, checked: bool) -> void:
	popup.set_item_checked(idx, checked)
	var text: String = popup.get_item_text(idx)
	var sp: int = text.find(" ")
	popup.set_item_text(idx, ("✅ " if checked else "⬜ ") + (text.substr(sp + 1) if sp >= 0 else text))


func _setup_settings_menu():
	var popup: PopupMenu = settings_btn.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	# 交互
	_add_check(popup, "Ctrl+拖拽旋转块", SETTING_ID_CTRL_ROTATE, _setting_ctrl_drag_rotate)
	_add_check(popup, "移动吸附网格", SETTING_ID_SNAP_GRID, _setting_snap_grid)
	_add_check(popup, "🎐 闲置微浮动", SETTING_ID_FLOAT, _setting_idle_float)
	_add_check(popup, "📐 属性栏固定右侧", SETTING_ID_DOCK_INSPECTOR, _setting_inspector_docked)
	popup.add_separator()
	_add_section_title(popup, "✦ 粒子")
	_add_check(popup, "✨ 鼠标星光轨迹", SETTING_ID_FX_TRAIL, _setting_fx_trail)
	_add_check(popup, "💫 点击迸发粒子", SETTING_ID_FX_CLICK, _setting_fx_click)
	_add_section_title(popup, "🌤 天气")
	_add_check(popup, "☄️ 流星雨", SETTING_ID_FX_METEOR, _setting_fx_meteor)
	_add_check(popup, "🌸 樱花飘落", SETTING_ID_FX_PETAL, _setting_fx_petal)
	_add_check(popup, "🌧 下雨", SETTING_ID_FX_RAIN, _setting_fx_rain)
	_add_check(popup, "❄️ 下雪", SETTING_ID_FX_SNOW, _setting_fx_snow)
	_add_check(popup, "✨ 萤火虫", SETTING_ID_FX_FIREFLY, _setting_fx_firefly)
	_add_section_title(popup, "💧 水面")
	_add_check(popup, "🌊 水面波纹", SETTING_ID_FX_WATER, _setting_fx_water)
	_add_check(popup, "🌊 涟漪（鼠标泛起）", SETTING_ID_FX_RIPPLE, _setting_fx_ripple)
	popup.add_separator()
	_add_section_title(popup, "🎬 画面氛围")
	_add_check(popup, "🌑 暗角", SETTING_ID_FX_VIGNETTE, _setting_fx_vignette)
	_add_check(popup, "📺 复古扫描线", SETTING_ID_FX_SCANLINES, _setting_fx_scanlines)
	_add_check(popup, "🎞 胶片颗粒", SETTING_ID_FX_GRAIN, _setting_fx_grain)
	_add_check(popup, "🌅 暖色漏光", SETTING_ID_FX_LIGHT_LEAK, _setting_fx_light_leak)
	popup.add_separator()
	popup.add_item("🎨 主题配色…", SETTING_ID_THEME)
	popup.add_item("🎈 贴纸呼吸设置…", SETTING_ID_BREATHE)
	popup.add_item("默认文本设置…", SETTING_ID_DEFAULT_TEXT)
	popup.add_item("❓ 帮助 / 快捷键", SETTING_ID_HELP)
	popup.id_pressed.connect(_on_setting_toggled)


## 设置菜单小节标题（disabled item，灰色不可点，仅作分组标签）
func _add_section_title(popup: PopupMenu, text: String) -> void:
	popup.add_item(text)
	popup.set_item_disabled(popup.get_item_count() - 1, true)

func _on_setting_toggled(id: int) -> void:
	var popup: PopupMenu = settings_btn.get_popup()
	var idx: int = popup.get_item_index(id)
	match id:
		SETTING_ID_CTRL_ROTATE:
			_setting_ctrl_drag_rotate = not _setting_ctrl_drag_rotate
			_refresh_check(popup, idx, _setting_ctrl_drag_rotate)
			_apply_settings_to_blocks()
			_save_settings()
		SETTING_ID_SNAP_GRID:
			_setting_snap_grid = not _setting_snap_grid
			_refresh_check(popup, idx, _setting_snap_grid)
			_apply_settings_to_blocks()
			_save_settings()
		SETTING_ID_FX_TRAIL:
			_setting_fx_trail = not _setting_fx_trail
			_refresh_check(popup, idx, _setting_fx_trail)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_CLICK:
			_setting_fx_click = not _setting_fx_click
			_refresh_check(popup, idx, _setting_fx_click)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_METEOR:
			_setting_fx_meteor = not _setting_fx_meteor
			_refresh_check(popup, idx, _setting_fx_meteor)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_WATER:
			_setting_fx_water = not _setting_fx_water
			_refresh_check(popup, idx, _setting_fx_water)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_PETAL:
			_setting_fx_petal = not _setting_fx_petal
			_refresh_check(popup, idx, _setting_fx_petal)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_RAIN:
			_setting_fx_rain = not _setting_fx_rain
			_refresh_check(popup, idx, _setting_fx_rain)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_SNOW:
			_setting_fx_snow = not _setting_fx_snow
			_refresh_check(popup, idx, _setting_fx_snow)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_FIREFLY:
			_setting_fx_firefly = not _setting_fx_firefly
			_refresh_check(popup, idx, _setting_fx_firefly)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_RIPPLE:
			_setting_fx_ripple = not _setting_fx_ripple
			_refresh_check(popup, idx, _setting_fx_ripple)
			_apply_fx_settings()
			_save_settings()
		SETTING_ID_FX_VIGNETTE:
			_setting_fx_vignette = not _setting_fx_vignette
			_refresh_check(popup, idx, _setting_fx_vignette)
			_apply_canvas_fx()
			_save_settings()
		SETTING_ID_FX_SCANLINES:
			_setting_fx_scanlines = not _setting_fx_scanlines
			_refresh_check(popup, idx, _setting_fx_scanlines)
			_apply_canvas_fx()
			_save_settings()
		SETTING_ID_FX_GRAIN:
			_setting_fx_grain = not _setting_fx_grain
			_refresh_check(popup, idx, _setting_fx_grain)
			_apply_canvas_fx()
			_save_settings()
		SETTING_ID_FX_LIGHT_LEAK:
			_setting_fx_light_leak = not _setting_fx_light_leak
			_refresh_check(popup, idx, _setting_fx_light_leak)
			_apply_canvas_fx()
			_save_settings()
		SETTING_ID_DOCK_INSPECTOR:
			_setting_inspector_docked = not _setting_inspector_docked
			_refresh_check(popup, idx, _setting_inspector_docked)
			_save_settings()
		SETTING_ID_BREATHE:
			_prompt_breathe_settings()
		SETTING_ID_THEME:
			_prompt_theme_select()
		SETTING_ID_FLOAT:
			_setting_idle_float = not _setting_idle_float
			_refresh_check(popup, idx, _setting_idle_float)
			_apply_settings_to_blocks()
			_save_settings()
		SETTING_ID_DEFAULT_TEXT:
			_prompt_default_text_settings()
		SETTING_ID_HELP:
			_show_help()

## 主题配色选择面板：列出预设色卡（纸色底 + 字色字），点击应用
func _prompt_theme_select() -> void:
	var popup := PopupPanel.new()
	popup.min_size = Vector2i(430, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "🎨 主题配色"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "点主题应用到纸张与新建块；勾选下方可同时换掉现有文本块（Ctrl+Z 可撤销）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	var chk := CheckBox.new()
	chk.text = "同时应用到现有文本块"
	chk.button_pressed = true
	vbox.add_child(chk)
	for preset in THEME_PRESETS:
		var p: Array = preset as Array
		var paper_c: Color = p[1]
		var font_c: Color = p[3]
		var btn := Button.new()
		btn.text = p[0]
		btn.custom_minimum_size = Vector2i(124, 58)
		btn.add_theme_font_size_override("font_size", 14)
		var sn := StyleBoxFlat.new()
		sn.bg_color = paper_c
		sn.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", sn)
		var sh := (sn.duplicate() as StyleBoxFlat)
		sh.border_color = Color(0.3, 0.6, 1.0, 0.9)
		sh.border_width_left = 2
		sh.border_width_right = 2
		sh.border_width_top = 2
		sh.border_width_bottom = 2
		btn.add_theme_stylebox_override("hover", sh)
		var sp := (sn.duplicate() as StyleBoxFlat)
		sp.bg_color = paper_c.darkened(0.06)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_color_override("font_color", font_c)
		btn.add_theme_color_override("font_hover_color", font_c)
		btn.add_theme_color_override("font_pressed_color", font_c)
		btn.pressed.connect(_apply_theme.bind(p, chk, popup))
		grid.add_child(btn)
	add_child(popup)
	popup.popup_centered()


## 应用一套主题：纸色 + 新建默认 +（可选）现有文本块；应用后关闭面板
func _apply_theme(preset: Array, chk: CheckBox, popup: PopupPanel) -> void:
	var paper_col: Color = preset[1]
	var block_col: Color = preset[2]
	var font_col: Color = preset[3]
	_push_undo()
	# 纸色（设 picker 触发 _on_bg_color_changed → 改纸 + mark_dirty）
	bg_color_picker.color = paper_col
	# 新建块默认
	_setting_default_block_bg = block_col
	_setting_default_font_color = font_col
	_save_settings()
	# 现有文本块
	if chk != null and chk.button_pressed:
		for child in paper.get_children():
			if child is TextBlock and is_instance_valid(child):
				(child as TextBlock).apply_colors(font_col, block_col)
	_update_font_ui()
	_mark_dirty()
	if popup != null:
		popup.hide()


## 把设置同步到 BaseBlock 静态变量等处
func _apply_settings_to_blocks() -> void:
	BaseBlock.ctrl_drag_rotate_enabled = _setting_ctrl_drag_rotate
	BaseBlock.snap_to_grid_enabled = _setting_snap_grid
	BaseBlock.snap_grid_size = GRID_SNAP_SIZE
	BaseBlock.idle_float_enabled = _setting_idle_float
	paper.apply_snap_grid(_setting_snap_grid, GRID_SNAP_SIZE)
	_apply_breathe_to_blocks()


## 把特效开关同步到 FXLayer
func _apply_fx_settings() -> void:
	if _fx_layer == null or not is_instance_valid(_fx_layer):
		return
	_fx_layer.trail_enabled = _setting_fx_trail
	_fx_layer.click_enabled = _setting_fx_click
	_fx_layer.meteor_enabled = _setting_fx_meteor
	_fx_layer.water_enabled = _setting_fx_water
	_fx_layer.petal_enabled = _setting_fx_petal
	_fx_layer.rain_enabled = _setting_fx_rain
	_fx_layer.snow_enabled = _setting_fx_snow
	_fx_layer.firefly_enabled = _setting_fx_firefly
	_fx_layer.ripple_enabled = _setting_fx_ripple
	_apply_canvas_fx()


## 创建特效层并加到画布滚动区（铺满、置顶、不挡操作）
func _setup_fx_layer() -> void:
	_fx_layer = FXLayer.new()
	paper_scroll.add_child(_fx_layer)
	_apply_fx_settings()


## 画面氛围叠加层（ColorRect + ShaderMaterial）：暗角/扫描线/颗粒/漏光
func _setup_canvas_fx() -> void:
	_canvas_fx = ColorRect.new()
	_canvas_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_fx.z_index = 200
	var mat := ShaderMaterial.new()
	mat.shader = CANVAS_FX_SHADER
	_canvas_fx.material = mat
	_canvas_fx_mat = mat
	paper_scroll.add_child(_canvas_fx)
	_apply_canvas_fx()


## 把画面氛围开关同步到 shader uniform（开 = 固定强度，关 = 0）
func _apply_canvas_fx() -> void:
	if _canvas_fx_mat == null:
		return
	_canvas_fx_mat.set_shader_parameter("vignette", 0.85 if _setting_fx_vignette else 0.0)
	_canvas_fx_mat.set_shader_parameter("scanlines", 0.6 if _setting_fx_scanlines else 0.0)
	_canvas_fx_mat.set_shader_parameter("grain", 0.55 if _setting_fx_grain else 0.0)
	_canvas_fx_mat.set_shader_parameter("light_leak", 0.8 if _setting_fx_light_leak else 0.0)


## 构建 Markdown 编辑器：全屏覆盖、半透明背景（透出画布特效）、左编辑右预览
## 构建 Markdown 编辑器：直接铺在纸张上（继承纸张大小 / 纹理 / 底图），左右分栏
## 工具栏另建 _md_toolbar 在顶部替换主工具栏（见 _setup_md_toolbar）
func _setup_md_editor() -> void:
	_md_panel = Control.new()
	_md_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_md_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 不加任何背景遮罩：纸张的底色 / 纹理 / 底图直接作为书写背景
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 8)
	# 左：md 源码编辑（透明背景，透出纸张纹理 / 底图）
	_md_edit = TextEdit.new()
	_md_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_md_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_md_edit.add_theme_font_size_override("font_size", 18)
	var empty := StyleBoxEmpty.new()
	_md_edit.add_theme_stylebox_override("normal", empty)
	_md_edit.add_theme_stylebox_override("focus", empty)
	_md_edit.add_theme_stylebox_override("read_only", empty)
	_md_edit.text_changed.connect(_on_md_text_changed)
	split.add_child(_md_edit)
	# 右：实时预览（透明背景）
	_md_preview = RichTextLabel.new()
	_md_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_md_preview.bbcode_enabled = true
	_md_preview.add_theme_font_size_override("normal_font_size", 18)
	_md_preview.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	split.add_child(_md_preview)
	_md_panel.add_child(split)
	_md_panel.visible = false
	paper.add_child(_md_panel)  # 长在纸张上，跟随纸张缩放 / 平移
	_apply_md_style()


## MD 专用工具栏（顶部，与主工具栏同位置同样式；MD 模式时替换主工具栏）
func _setup_md_toolbar() -> void:
	_md_toolbar = ColorRect.new()
	_md_toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_md_toolbar.color = Color(0.88, 0.88, 0.91, 1.0)
	_md_toolbar.visible = false
	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 12
	inner.offset_right = -12
	inner.offset_top = 12
	inner.offset_bottom = -12
	inner.add_theme_constant_override("separation", 6)
	var btn_back := _md_tool_button("← 返回日记")
	btn_back.pressed.connect(_close_md_editor)
	inner.add_child(btn_back)
	inner.add_child(_md_sep(12))
	var btn_open := _md_tool_button("📂 打开")
	btn_open.pressed.connect(_on_md_open)
	inner.add_child(btn_open)
	var btn_save := _md_tool_button("💾 保存")
	btn_save.pressed.connect(_on_md_save)
	inner.add_child(btn_save)
	_md_filename_edit = LineEdit.new()
	_md_filename_edit.placeholder_text = "文件名（保存到笔记目录）"
	_md_filename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_md_filename_edit.custom_minimum_size = Vector2i(200, 0)
	inner.add_child(_md_filename_edit)
	inner.add_child(_md_sep(10))
	for syn in MD_SYNTAXES:
		var b := _md_tool_button(syn[0])
		b.pressed.connect(_md_wrap.bind(syn[1], syn[2]))
		inner.add_child(b)
	inner.add_child(_md_sep(10))
	var btn_insert := _md_tool_button("📤 插入画布")
	btn_insert.pressed.connect(_on_md_insert_canvas)
	inner.add_child(btn_insert)
	var btn_settings := _md_tool_button("⚙ 显示")
	btn_settings.pressed.connect(_prompt_md_settings)
	inner.add_child(btn_settings)
	_md_toolbar.add_child(inner)
	add_child(_md_toolbar)


## 应用 md 编辑器 / 预览的字号 / 字色 / 背景样式
func _apply_md_style() -> void:
	if _md_edit == null or _md_preview == null:
		return
	_md_edit.add_theme_font_size_override("font_size", _setting_md_font_size)
	_md_edit.add_theme_color_override("font_color", _setting_md_font_color)
	_md_edit.add_theme_color_override("font_readonly_color", _setting_md_font_color)
	# 醒目光标：块状 + 蓝色（CaretType: CARET_LINE=0, CARET_BLOCK=1），透明背景上也能看清输入位置
	_md_edit.caret_type = 1
	_md_edit.add_theme_color_override("caret_color", Color(0.16, 0.5, 0.87))
	# 背景：不透明度 0 = 透明（StyleBoxEmpty，透纸张纹理）；>0 = 半透明底色
	var sb: StyleBox
	if _setting_md_bg_opacity <= 0.001:
		sb = StyleBoxEmpty.new()
	else:
		var s := StyleBoxFlat.new()
		var c: Color = _setting_md_bg_color
		c.a = _setting_md_bg_opacity
		s.bg_color = c
		sb = s
	_md_edit.add_theme_stylebox_override("normal", sb)
	_md_edit.add_theme_stylebox_override("focus", sb)
	_md_preview.add_theme_font_size_override("normal_font_size", _setting_md_font_size)
	_md_preview.add_theme_font_size_override("bold_font_size", _setting_md_font_size)
	_md_preview.add_theme_font_size_override("italics_font_size", _setting_md_font_size)
	_md_preview.add_theme_font_size_override("mono_font_size", _setting_md_font_size)
	_md_preview.add_theme_color_override("default_color", _setting_md_font_color)
	_md_preview.add_theme_stylebox_override("normal", sb)


## md 显示设置对话框（字号 / 文字色 / 背景色 / 背景不透明度）
func _prompt_md_settings() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Markdown 显示设置"
	dialog.min_size = Vector2i(380, 240)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	# 字号
	var row_size := HBoxContainer.new()
	var lbl_size := Label.new()
	lbl_size.text = "字号:"
	lbl_size.custom_minimum_size = Vector2i(70, 0)
	var size_slider := HSlider.new()
	size_slider.min_value = 10.0
	size_slider.max_value = 36.0
	size_slider.step = 1.0
	size_slider.value = float(_setting_md_font_size)
	size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var size_val := Label.new()
	size_val.custom_minimum_size = Vector2i(40, 0)
	size_val.text = str(_setting_md_font_size)
	size_slider.value_changed.connect(func(v: float): size_val.text = str(int(v)))
	row_size.add_child(lbl_size)
	row_size.add_child(size_slider)
	row_size.add_child(size_val)
	vbox.add_child(row_size)
	# 文字色
	var row_fc := HBoxContainer.new()
	var lbl_fc := Label.new()
	lbl_fc.text = "文字色:"
	lbl_fc.custom_minimum_size = Vector2i(70, 0)
	var fc_btn := ColorPickerButton.new()
	fc_btn.color = _setting_md_font_color
	fc_btn.edit_alpha = false
	fc_btn.custom_minimum_size = Vector2i(80, 0)
	row_fc.add_child(lbl_fc)
	row_fc.add_child(fc_btn)
	vbox.add_child(row_fc)
	# 背景色
	var row_bg := HBoxContainer.new()
	var lbl_bg := Label.new()
	lbl_bg.text = "背景色:"
	lbl_bg.custom_minimum_size = Vector2i(70, 0)
	var bg_btn := ColorPickerButton.new()
	bg_btn.color = _setting_md_bg_color
	bg_btn.edit_alpha = false
	bg_btn.custom_minimum_size = Vector2i(80, 0)
	row_bg.add_child(lbl_bg)
	row_bg.add_child(bg_btn)
	vbox.add_child(row_bg)
	# 背景不透明度
	var row_op := HBoxContainer.new()
	var lbl_op := Label.new()
	lbl_op.text = "背景:"
	lbl_op.custom_minimum_size = Vector2i(70, 0)
	var op_slider := HSlider.new()
	op_slider.min_value = 0.0
	op_slider.max_value = 1.0
	op_slider.step = 0.05
	op_slider.value = _setting_md_bg_opacity
	op_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var op_val := Label.new()
	op_val.custom_minimum_size = Vector2i(40, 0)
	op_val.text = "%d%%" % int(_setting_md_bg_opacity * 100.0)
	op_slider.value_changed.connect(func(v: float): op_val.text = "%d%%" % int(v * 100.0))
	row_op.add_child(lbl_op)
	row_op.add_child(op_slider)
	row_op.add_child(op_val)
	vbox.add_child(row_op)
	var hint := Label.new()
	hint.text = "背景 0% = 完全透明（透出纸张纹理）；调高更清晰"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)
	margin.add_child(vbox)
	dialog.add_child(margin)
	dialog.confirmed.connect(func():
		_setting_md_font_size = int(size_slider.value)
		_setting_md_font_color = fc_btn.color
		_setting_md_bg_color = bg_btn.color
		_setting_md_bg_opacity = op_slider.value
		_apply_md_style()
		_save_settings()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _md_tool_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size.y = 32
	return b


func _md_sep(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2i(w, 0)
	return c


## 打开 Markdown 模式：有画布块时弹对话框（保存并清空 / 直接清空 / 取消）
func _open_md_editor() -> void:
	if _has_blocks_on_paper():
		_prompt_md_switch_dialog()
		return
	_do_open_md_editor()


func _has_blocks_on_paper() -> bool:
	for child in paper.get_children():
		if child is BaseBlock:
			return true
	return false


## 切换前对话框：保存当前笔记 / 直接清空 / 取消
func _prompt_md_switch_dialog() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "切换到 Markdown 模式"
	dlg.dialog_text = "画布上有日记内容，切换到 Markdown 模式会清空画布。请选择："
	dlg.ok_button_text = "直接清空"
	dlg.add_button("保存笔记并清空", false, "save_clear")
	dlg.add_cancel_button("取消")
	dlg.confirmed.connect(func():
		_do_open_md_editor()
		dlg.queue_free()
	)
	dlg.custom_action.connect(func(action):
		if action == "save_clear":
			_autosave()
			_do_open_md_editor()
			dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


## 实际进入 MD 模式：清空画布块 + 显示 md 编辑器 + 替换工具栏
func _do_open_md_editor() -> void:
	# 清空画布块（md 独占纸张；_md_panel 不是 BaseBlock，不受影响）
	for child in paper.get_children():
		if child is BaseBlock:
			child.queue_free()
	_current_page_data.blocks.clear()
	_md_is_open = true
	_md_panel.visible = true
	_md_last_len = _md_edit.text.length()
	toolbar.visible = false
	toolbar_divider.visible = false
	_md_toolbar.visible = true
	_md_edit.grab_focus()
	_on_md_text_changed()


## 关闭 Markdown 模式：恢复主工具栏（画布块已清空，不恢复）
func _close_md_editor() -> void:
	_md_is_open = false
	_md_panel.visible = false
	toolbar.visible = true
	toolbar_divider.visible = true
	_md_toolbar.visible = false


## 实时预览：md → BBCode → 过滤无效图片 → 渲染；顺带打字迸星
func _on_md_text_changed() -> void:
	# 打字迸星（md 编辑器复用 fx_layer）
	var new_len: int = _md_edit.text.length()
	if new_len > _md_last_len and _fx_layer != null and is_instance_valid(_fx_layer):
		var cdp := _md_edit.get_caret_draw_pos()
		var caret_canvas: Vector2 = _md_edit.get_global_transform() * Vector2(cdp.x, cdp.y)
		_fx_layer.spawn_at_canvas(caret_canvas)
	_md_last_len = new_len
	var bb: String = MarkdownToBBCode.convert(_md_edit.text, _setting_md_font_size)
	_md_preview.parse_bbcode(_sanitize_images_bb(bb))


## 过滤 BBCode 中无法加载的 [img]（与 TextBlock 同逻辑，避免刷屏报错）
func _sanitize_images_bb(bbcode: String) -> String:
	var rgx := RegEx.new()
	rgx.compile("\\[img[^\\]]*\\](.*?)\\[/img\\]")
	var out := bbcode
	for m in rgx.search_all(bbcode):
		var path: String = (m.get_string(1) as String).strip_edges()
		if not _bb_image_loadable(path):
			out = out.replace(m.get_string(0), "")
	return out


func _bb_image_loadable(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://"):
		return ResourceLoader.exists(path, "Texture2D")
	if path.begins_with("user://") or path.is_absolute_path():
		return FileAccess.file_exists(path)
	return ResourceLoader.exists("res://" + path, "Texture2D")


## 保存到笔记目录 NOTE_DIR/{文件名}.md
func _on_md_save() -> void:
	var fname: String = _md_filename_edit.text.strip_edges()
	if fname.is_empty():
		fname = "md_" + _generate_title()
	if not fname.ends_with(".md"):
		fname += ".md"
	var abs_path: String = ProjectSettings.globalize_path(NOTE_DIR + fname)
	var dir: String = abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_warning("MD 保存失败: ", abs_path)
		return
	f.store_string(_md_edit.text)
	f.close()
	_md_filename_edit.text = fname


## 打开 .md 文件（FileDialog）
func _on_md_open() -> void:
	var dialog := FileDialog.new()
	dialog.title = "打开 Markdown"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.md", "Markdown 文件")
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.size = Vector2i(700, 450)
	dialog.file_selected.connect(_md_open_file)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _md_open_file(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	_md_edit.text = f.get_as_text()
	f.close()
	_md_filename_edit.text = path.get_file()
	_on_md_text_changed()


## 把当前 md 内容作为一个 markdown 文本块插入画布（视口中心）
func _on_md_insert_canvas() -> void:
	_push_undo()
	var data := TextBlockData.new()
	data.bbcode_content = _md_edit.text
	data.use_markdown = true
	data.size = Vector2(420.0, 320.0)
	var zoom: float = paper.scale.x if paper.scale.x != 0.0 else 1.0
	var center: Vector2 = (paper_scroll.size * 0.5 - paper.position) / zoom
	data.position = center - data.size * 0.5
	data.bg_color = _setting_default_block_bg
	data.font_color = _setting_default_font_color
	data.opacity = _setting_default_opacity
	_spawn_block(data)
	_mark_dirty()
	_close_md_editor()


## md 语法包裹：有选中 → prefix+选+suffix；无选中 → 插入 prefix+suffix 并把光标放中间
func _md_wrap(prefix: String, suffix: String) -> void:
	var sel: String = _md_edit.get_selected_text()
	if not sel.is_empty():
		var col: int = _md_edit.get_caret_column()
		_md_edit.insert_text_at_caret(prefix + sel + suffix)
		_md_edit.set_caret_column(col + prefix.length() + sel.length() + suffix.length())
	else:
		_md_edit.insert_text_at_caret(prefix + suffix)
		_md_edit.set_caret_column(_md_edit.get_caret_column() - suffix.length())
	_md_edit.grab_focus()


## 把呼吸幅度 / 周期同步到 BaseBlock 静态变量，并重启所有 emoji 贴纸的呼吸
func _apply_breathe_to_blocks() -> void:
	BaseBlock.breathe_amp = _setting_breathe_amp
	BaseBlock.breathe_period = _setting_breathe_period
	for child in paper.get_children():
		if child is EmojiStickerBlock:
			(child as EmojiStickerBlock)._apply_breathe()


## 贴纸呼吸设置对话框（幅度 + 速度两个滑块，实时预览数值）
func _prompt_breathe_settings() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "贴纸呼吸设置"
	dialog.min_size = Vector2i(340, 170)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	# 幅度
	var row_amp := HBoxContainer.new()
	var lbl_amp := Label.new()
	lbl_amp.text = "幅度:"
	lbl_amp.custom_minimum_size = Vector2i(50, 0)
	var amp_slider := HSlider.new()
	amp_slider.min_value = 0.0
	amp_slider.max_value = 0.10
	amp_slider.step = 0.01
	amp_slider.value = _setting_breathe_amp
	amp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amp_val := Label.new()
	amp_val.custom_minimum_size = Vector2i(42, 0)
	amp_val.text = "%d%%" % int(_setting_breathe_amp * 100.0)
	amp_slider.value_changed.connect(func(v: float): amp_val.text = "%d%%" % int(v * 100.0))
	row_amp.add_child(lbl_amp)
	row_amp.add_child(amp_slider)
	row_amp.add_child(amp_val)
	vbox.add_child(row_amp)
	# 速度（周期秒，越小越快）
	var row_spd := HBoxContainer.new()
	var lbl_spd := Label.new()
	lbl_spd.text = "速度:"
	lbl_spd.custom_minimum_size = Vector2i(50, 0)
	var spd_slider := HSlider.new()
	spd_slider.min_value = 0.5
	spd_slider.max_value = 3.0
	spd_slider.step = 0.1
	spd_slider.value = _setting_breathe_period
	spd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spd_val := Label.new()
	spd_val.custom_minimum_size = Vector2i(42, 0)
	spd_val.text = "%.1fs" % _setting_breathe_period
	spd_slider.value_changed.connect(func(v: float): spd_val.text = "%.1fs" % v)
	row_spd.add_child(lbl_spd)
	row_spd.add_child(spd_slider)
	row_spd.add_child(spd_val)
	vbox.add_child(row_spd)
	var hint := Label.new()
	hint.text = "幅度拉到 0% 即关闭呼吸；速度数值越小摆得越快"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)
	margin.add_child(vbox)
	dialog.add_child(margin)
	dialog.confirmed.connect(func():
		_setting_breathe_amp = amp_slider.value
		_setting_breathe_period = spd_slider.value
		_apply_breathe_to_blocks()
		_save_settings()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


## 帮助 / 快捷键面板
func _show_help() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "❓ 帮助 / 快捷键"
	dlg.ok_button_text = "知道了"
	dlg.min_size = Vector2i(580, 600)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	dlg.add_child(scroll)
	vbox.add_child(_help_card("⌨️ 快捷键 · 选中块时", [
		"Del  删除选中（多选全删）",
		"Ctrl + D  复制 ·  Ctrl + Z 撤销 ·  Ctrl + Y（或 Ctrl+Shift+Z）重做",
		"+ / -  调层级 ·  Ctrl + + / -  调字号（文本块）",
		"[ / ]  透明度 ·  Ctrl + [ / ]  旋转 ±15°",
		"Tab  选中文本块进入编辑",
		"Ctrl + Enter  编辑时光标跳到末尾",
		"Ctrl + ;  颜文字菜单（数字键选取）",
		"Esc  取消选中 / 关颜文字 ·  F1  打开本帮助",
	], Color(0.3, 0.6, 1.0)))
	vbox.add_child(_help_card("🖱️ 鼠标手势", [
		"双击空白  新建文本块 ·  双击文本块  进入/退出编辑",
		"右键块  上下文菜单（复制/置顶/置底/旋转/删除）",
		"涂鸦块  右键拖动画线 / 右键单击弹菜单",
		"空白拖拽  框选多块 ·  Ctrl + 点击  多选切换 ·  Alt + 点击  原地复制",
		"Ctrl + 左键拖块  旋转（5° 吸附，按 Shift 自由）",
		"Ctrl + 滚轮  缩放画布（以鼠标为中心）·  中键拖拽  平移",
	], Color(0.95, 0.55, 0.4)))
	vbox.add_child(_help_card("✍️ 文本语法（BBCode / Markdown）", [
		"[b]粗[/b]  [i]斜[/i]  [u]下划线[/u]  [s]删除线[/s]",
		"[font_size=32]字号[/font_size]  [color=#FF6600]颜色[/color]",
		"[center]居中[/center]  [right]右对齐[/right]",
		"开 Markdown 模式：## 标题 · **粗** · *斜* · - 列表 · > 引用",
	], Color(0.45, 0.7, 0.4)))
	vbox.add_child(_help_card("✨ 功能导览", [
		"✨ 新建：下拉勾选要保留的纸张样式（大小/底纹/底图/底色）",
		"📅 日记助手：时间戳 / 天气 / 心情 / 模板 / 运势 / 随机 emoji",
		"📝 MD：全屏 Markdown 编辑器，可一键插回画布",
		"画布菜单：尺寸 / 底纹 / 背景图（透明度+位置可调）",
		"自定义模板：把当前排版另存为模板复用，面板右键删除",
		"选中块旁的属性浮层：层级 / 透明度 / 绘图工具 / 删除",
	], Color(0.7, 0.5, 0.85)))
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


## 帮助面板的一个卡片：彩色左边框 + 圆角浅底，标题 + 条目
func _help_card(title: String, items: Array, accent: Color = Color(0.3, 0.6, 1.0)) -> PanelContainer:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.55)
	s.set_corner_radius_all(10)
	s.border_width_left = 4
	s.border_color = accent
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", accent.darkened(0.12))
	col.add_child(t)
	for it in items:
		var l := Label.new()
		l.text = "· " + (it as String)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.3, 0.3, 0.34))
		col.add_child(l)
	return panel


## 首次上手卡：3 步快速认识 DollDollNote（仅首次打开弹一次）
func _show_onboarding() -> void:
	if _setting_onboarding_done:
		return
	var dlg := AcceptDialog.new()
	dlg.title = "👋 欢迎使用 DollDollNote"
	dlg.ok_button_text = "开始记手账 ✨"
	dlg.min_size = Vector2i(600, 480)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	dlg.add_child(vbox)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 16)
	var hi := Label.new()
	hi.text = "30 秒上手，记住这三件事就够了 👇"
	hi.add_theme_font_size_override("font_size", 18)
	hi.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(hi)
	vbox.add_child(_onboarding_step("🖊️", "双击纸张空白处", "在该位置新建一个文本块，双击块即可编辑文字"))
	vbox.add_child(_onboarding_step("✋", "拖拽 · 缩放 · 旋转", "按住块拖动、拖边缘缩放、Ctrl + 左键拖拽旋转"))
	vbox.add_child(_onboarding_step("🧭", "右键菜单 & ❓ 帮助", "右键块打开菜单；随时按 ❓ 按钮或 F1 查看全部快捷键"))
	var tip := Label.new()
	tip.text = "💡 底部状态条会随你的操作实时提示可用快捷键，不用死记～"
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	vbox.add_child(tip)
	dlg.confirmed.connect(_on_onboarding_closed)
	dlg.canceled.connect(_on_onboarding_closed)
	add_child(dlg)
	dlg.popup_centered()


## 关闭上手卡：标记已完成并持久化
func _on_onboarding_closed() -> void:
	_setting_onboarding_done = true
	_save_settings()


## 上手卡的一步：大 emoji + 标题 + 说明
func _onboarding_step(icon: String, title: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 30)
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", Color(0.2, 0.2, 0.24))
	col.add_child(t)
	var d := Label.new()
	d.text = desc
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	col.add_child(d)
	row.add_child(col)
	return row


## 底部提示条：状态键变化时才刷新文字（避免每帧重设）
func _update_hint_if_changed() -> void:
	if hint_label == null or not is_instance_valid(hint_label):
		return
	var key: String = _hint_key()
	if key == _last_hint_key:
		return
	_last_hint_key = key
	hint_label.text = _hint_text_for(key)


## 当前提示状态键：编辑 / 多选 / 文本块 / 其他块 / 框选 / 空
func _hint_key() -> String:
	if _stamp_mode:
		return "stamp"
	if _box_selecting:
		return "boxing"
	var b: BaseBlock = _current_selected_block
	if b == null or not is_instance_valid(b):
		return "empty"
	if b is TextBlock and (b as TextBlock).is_editing():
		return "editing"
	if _selected_blocks.size() > 1:
		return "multi"
	if b is TextBlock:
		return "text"
	return "block"


## 各状态对应的提示文字
func _hint_text_for(key: String) -> String:
	match key:
		"stamp":
			return "💮 印章模式 · 点击画布盖戳（" + _stamp_emoji + "）· Esc 取消"
		"empty":
			return "💡 双击空白新建文本 · 拖拽移动 · Ctrl+滚轮缩放 · 中键平移 · 右键更多 · ❓ / F1 帮助"
		"boxing":
			return "▢ 框选中… 松开选中范围内的块 · Esc 取消"
		"text":
			return "✏️ 文本块 · Del 删除 · Ctrl+D 复制 · +/- 层级 · [/] 透明 · Ctrl+[/] 旋转 · 双击进入编辑"
		"editing":
			return "📝 编辑中 · Tab 插入语法 · Ctrl+; 颜文字 · Ctrl+Enter 跳末尾 · Esc 退出编辑"
		"multi":
			return "🔗 已选中 %d 块 · Del 全删 · 拖动一起移动 · Ctrl+D 复制 · Esc 取消" % _selected_blocks.size()
		"block":
			return "✦ 已选中块 · Del 删除 · Ctrl+D 复制 · +/- 层级 · [/] 透明 · Ctrl+[/] 旋转 · Ctrl+左键拖拽也可旋转"
	return ""


## 帮助面板的一个小节（标题 + 条目）
func _help_section(title: String, items: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color(0.2, 0.4, 0.8))
	section.add_child(t)
	for it in items:
		var l := Label.new()
		l.text = "  " + (it as String)
		l.add_theme_font_size_override("font_size", 12)
		section.add_child(l)
	return section


## 初始化字体下拉选项
func _setup_font_options() -> void:
	font_option_btn.clear()
	for preset in FONT_PRESETS:
		var p: Array = preset as Array
		font_option_btn.add_item(p[0])

## 构建文本进阶设置二级面板（PopupPanel）
## 含：行间距、框发光宽度、框发光颜色、圆角
func _setup_text_more_panel() -> void:
	_text_more_popup = PopupPanel.new()
	_text_more_popup.title = "文本进阶设置"
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# 行间距
	var row1 := HBoxContainer.new()
	var lbl1 := Label.new()
	lbl1.text = "行间距:"
	lbl1.custom_minimum_size = Vector2i(70, 0)
	_line_spacing_spin = SpinBox.new()
	_line_spacing_spin.min_value = 0.8
	_line_spacing_spin.max_value = 3.0
	_line_spacing_spin.step = 0.1
	_line_spacing_spin.value = 1.2
	_line_spacing_spin.suffix = " x"
	row1.add_child(lbl1)
	row1.add_child(_line_spacing_spin)
	vbox.add_child(row1)
	
	# 框描边宽度
	var row2 := HBoxContainer.new()
	var lbl2 := Label.new()
	lbl2.text = "框描边:"
	lbl2.custom_minimum_size = Vector2i(70, 0)
	_box_glow_spin = SpinBox.new()
	_box_glow_spin.min_value = 0
	_box_glow_spin.max_value = 30
	_box_glow_spin.value = 0
	_box_glow_spin.suffix = " px"
	_box_glow_color_btn = ColorPickerButton.new()
	_box_glow_color_btn.custom_minimum_size = Vector2i(28, 28)
	_box_glow_color_btn.color = Color(0.2, 0.2, 0.2, 1)  ## 实色描边默认深灰
	_box_glow_color_btn.edit_alpha = true
	row2.add_child(lbl2)
	row2.add_child(_box_glow_spin)
	row2.add_child(_box_glow_color_btn)
	vbox.add_child(row2)
	
	# 圆角
	var row3 := HBoxContainer.new()
	var lbl3 := Label.new()
	lbl3.text = "圆角:"
	lbl3.custom_minimum_size = Vector2i(70, 0)
	_corner_radius_spin = SpinBox.new()
	_corner_radius_spin.min_value = 0
	_corner_radius_spin.max_value = 40
	_corner_radius_spin.value = 8
	_corner_radius_spin.suffix = " px"
	row3.add_child(lbl3)
	row3.add_child(_corner_radius_spin)
	vbox.add_child(row3)
	
	# Markdown 开关
	var row4 := HBoxContainer.new()
	var lbl4 := Label.new()
	lbl4.text = "Markdown:"
	lbl4.custom_minimum_size = Vector2i(70, 0)
	_markdown_check = CheckBox.new()
	_markdown_check.text = "按 MD 语法渲染"
	row4.add_child(lbl4)
	row4.add_child(_markdown_check)
	vbox.add_child(row4)
	
	margin.add_child(vbox)
	_text_more_popup.add_child(margin)
	add_child(_text_more_popup)

## 构建 BBCode/Markdown 快捷插入面板
## 根据当前文本块是否开启 MD 显示不同语法按钮
func _setup_insert_panel() -> void:
	_insert_popup = Control.new()
	# PASS：浮层空白区不拦截鼠标，点击穿透到下方（如纸张）；
	# 面板内按钮自身 STOP，仍可正常点击
	_insert_popup.mouse_filter = Control.MOUSE_FILTER_PASS
	_insert_popup.visible = false
	# 不可见时清理激活态（保险；正常由 _hide_insert_panel 处理）
	_insert_popup.visibility_changed.connect(func():
		if not _insert_popup.visible:
			_insert_panel_active = false
			TextBlock.insert_panel_active = false
	)
	add_child(_insert_popup)

## 热键序列：1-9, 0, 然后用 Q W E R T 补充
const INSERT_HOTKEYS: Array = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
	KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T,
]
## 热键显示字符
const INSERT_HOTKEY_LABELS: Array = [
	"1", "2", "3", "4", "5",
	"6", "7", "8", "9", "0",
	"Q", "W", "E", "R", "T",
]

## 弹出快捷插入面板，根据 MD 模式显示对应语法按钮
func _refresh_insert_panel() -> void:
	# 清空旧内容和热键映射
	for c in _insert_popup.get_children():
		c.queue_free()
	_insert_hotkeys.clear()
	
	var is_md: bool = false
	if _current_selected_block is TextBlock:
		is_md = (_current_selected_block as TextBlock).data.use_markdown
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	# 语法快捷项: [显示名, 插入前缀, 插入后缀]
	var items: Array = []
	if is_md:
		items = [
			["粗体", "**", "**"],
			["斜体", "*", "*"],
			["删除", "~~", "~~"],
			["代码", "`", "`"],
			["标题1", "# ", ""],
			["标题2", "## ", ""],
			["标题3", "### ", ""],
			["引用", "> ", ""],
			["列表", "- ", ""],
			["分隔线", "\n---\n", ""],
			["链接", "[", "](url)"],
			["图片", "![](", ")"],
		]
	else:
		items = [
			["粗体", "[b]", "[/b]"],
			["斜体", "[i]", "[/i]"],
			["删除", "[s]", "[/s]"],
			["下划", "[u]", "[/u]"],
			["居中", "[center]", "[/center]"],
			["右对齐", "[right]", "[/right]"],
			["标题", "[font_size=32]", "[/font_size]"],
			["颜色", "[color=#FF0000]", "[/color]"],
			["缩进", "[indent]", "[/indent]"],
			["代码", "[code]", "[/code]"],
			["链接", "[url=]", "[/url]"],
			["图片", "[img]", "[/img]"],
		]
	
	# 给每项分配热键，按钮显示"热键 功能名"
	for i in range(items.size()):
		var it: Array = items[i] as Array
		var hotkey_idx: int = i
		if hotkey_idx >= INSERT_HOTKEYS.size():
			break  # 超过热键数量的项不分配
		var key_code: int = int(INSERT_HOTKEYS[hotkey_idx])
		var key_label: String = INSERT_HOTKEY_LABELS[hotkey_idx] as String
		# 存热键映射
		_insert_hotkeys[key_code] = [it[1], it[2]]
		# 创建按钮，显示热键+功能名
		var btn := Button.new()
		btn.text = "[%s] %s" % [key_label, it[0]]
		btn.custom_minimum_size = Vector2i(110, 30)
		# 关闭键盘焦点：防止 Tab 焦点导航误入按钮，确保按键始终由 TextEdit 处理
		btn.focus_mode = Control.FOCUS_NONE
		var prefix: String = it[1]
		var suffix: String = it[2]
		btn.pressed.connect(func():
			_insert_syntax(prefix, suffix)
		)
		grid.add_child(btn)
	
	# 底部提示
	var hint := Label.new()
	hint.text = "Tab 关闭 | 数字键快速插入 | Esc 退出"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var vbox := VBoxContainer.new()
	vbox.add_child(grid)
	vbox.add_child(hint)
	margin.add_child(vbox)
	_insert_popup.add_child(margin)

## 生成插入按钮的回调闭包（保留兼容）
func _make_insert_func(prefix: String, suffix: String) -> Callable:
	return func():
		_insert_syntax(prefix, suffix)

## 把语法插入到当前编辑中文本块的光标位置
func _insert_syntax(prefix: String, suffix: String) -> void:
	if not (_current_selected_block is TextBlock):
		return
	var tb: TextBlock = _current_selected_block as TextBlock
	if not tb.is_editing():
		return
	tb.insert_at_cursor(prefix, suffix)

## 构建 Emoji 面板（分类标签页 + 网格）
func _setup_emoji_panel() -> void:
	_emoji_popup = Control.new()
	_emoji_popup.mouse_filter = Control.MOUSE_FILTER_PASS
	_emoji_popup.visible = false
	add_child(_emoji_popup)


## 从 Emoji 面板一键跳转到图片贴纸库（关闭 emoji 浮层，展开贴纸侧栏）
func _open_sticker_from_emoji() -> void:
	_emoji_popup.visible = false
	sticker_toggle.button_pressed = true

## 刷新并弹出 Emoji 面板
func _refresh_emoji_panel() -> void:
	for c in _emoji_popup.get_children():
		c.queue_free()

	# 背景面板（白底圆角阴影）
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.98)
	sb.set_corner_radius_all(10)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.15)
	bg.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# 用 TabContainer 分类
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2i(360, 260)
	
	var categories: Array = EmojiData.get_categories()
	for cat in categories:
		var c: Array = cat as Array
		var cat_name: String = c[0] as String
		var emojis: Array = c[1] as Array
		var scroll := ScrollContainer.new()
		scroll.name = cat_name
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		for emoji in emojis:
			var e: String = emoji as String
			var btn := EmojiButton.new()
			btn.text = e
			btn.emoji_text = e
			btn.custom_minimum_size = Vector2i(32, 32)
			btn.add_theme_font_size_override("font_size", 18)
			btn.flat = true
			btn.pressed.connect(func():
				_insert_emoji(e)
			)
			grid.add_child(btn)
		scroll.add_child(grid)
		tabs.add_child(scroll)
	
	# 顶部条：标题 + 跳转到图片贴纸库
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var etitle := Label.new()
	etitle.text = "😊 Emoji 表情"
	etitle.add_theme_font_size_override("font_size", 15)
	etitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(etitle)
	var to_sticker := Button.new()
	to_sticker.text = "📎 贴纸库"
	to_sticker.add_theme_font_size_override("font_size", 12)
	to_sticker.tooltip_text = "打开图片贴纸库"
	to_sticker.pressed.connect(_open_sticker_from_emoji)
	header.add_child(to_sticker)
	vbox.add_child(header)
	vbox.add_child(tabs)
	margin.add_child(vbox)
	bg.add_child(margin)
	_emoji_popup.add_child(bg)

## 插入 emoji 到当前文本块
func _insert_emoji(e: String) -> void:
	if not (_current_selected_block is TextBlock):
		return
	var tb: TextBlock = _current_selected_block as TextBlock
	if not tb.is_editing():
		return
	tb.insert_at_cursor(e, "")

# ═══════════════════════════════════════════
#  日记助手面板（天气/心情/时间戳/模板）
# ═══════════════════════════════════════════

## 天气选项
const WEATHER_OPTIONS: Array = ["☀️ 晴", "⛅ 多云", "☁️ 阴", "🌧️ 雨", "⛈️ 雷雨", "❄️ 雪", "🌫️ 雾", "🌪️ 台风"]
## 心情选项
const MOOD_OPTIONS: Array = ["😄 开心", "😊 满足", "😌 平静", "😔 低落", "😢 难过", "😤 烦躁", "😰 焦虑", "😴 疲惫", "🤩 兴奋", "🥰 幸福"]
## 趣味玩法：随机撒花用 emoji 池
const PLAY_EMOJIS: Array = ["✨", "🌟", "💫", "⭐", "🎉", "🎊", "🎈", "🌸", "🌺", "🍀", "🌈", "☀️", "🌙", "❤️", "💛", "💚", "💙", "💜", "🧡", "💝", "💖"]
## 趣味玩法：今日运势签 [运势, emoji, 运势语]
const FORTUNES: Array = [
	["大吉", "🌟", "万事顺遂，好运连连！"],
	["中吉", "✨", "稳步前进，小有收获。"],
	["小吉", "🍀", "平平安安，知足常乐。"],
	["吉", "😊", "保持微笑，好事将近。"],
	["末吉", "🌈", "稍加耐心，柳暗花明。"],
]
## 模板预设: [名称, 块定义数组]
## 块定义字段见 _make_text_data / _make_shape_data / _make_image_data。
## content 支持 {date} {md_date} {weekday} {year} {month} {day} {time} 占位符（自动替换为当天）。
const DIARY_TEMPLATES: Array = [
	["每日心情", [
		{"type": "text", "pos": [60, 60], "size": [680, 90], "content": "[font_size=34][b]{date}[/b][/font_size]", "bg": "#FFF3E0", "corner_radius": 16, "box_glow_size": 4, "box_glow_color": "#E0C9A6", "font_size": 34},
		{"type": "text", "pos": [60, 170], "size": [330, 50], "content": "天气：☀️晴   心情：😄开心", "bg": "#E8F5E9", "corner_radius": 12, "font_size": 20},
		{"type": "text", "pos": [410, 170], "size": [330, 50], "content": "[b]心情指数：[/b]⭐⭐⭐⭐⭐", "bg": "#E8F5E9", "corner_radius": 12, "font_size": 18},
		{"type": "text", "pos": [60, 240], "size": [680, 320], "content": "[b]今天发生了什么：[/b]\n\n\n\n[b]感悟：[/b]\n", "bg": "#FFFFFF", "corner_radius": 12, "border": "#E0C9A6", "border_width": 1, "font_size": 20},
		{"type": "shape", "pos": [60, 580], "size": [680, 4], "shape": 2, "stroke": "#E0C9A6", "width": 2.0},
	]],
	["暖色手账", [
		{"type": "text", "pos": [60, 60], "size": [680, 80], "content": "[center][font_size=30][b]{date}[/b][/font_size][/center]", "bg": "#FCE4EC", "corner_radius": 18, "box_glow_size": 5, "box_glow_color": "#F8BBD0", "font_size": 30},
		{"type": "text", "pos": [60, 160], "size": [330, 200], "content": "[b]📝 待办[/b]\n• \n• \n• ", "bg": "#FFF9C4", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [410, 160], "size": [330, 200], "content": "[b]💖 感恩[/b]\n• \n• ", "bg": "#E1F5FE", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 380], "size": [680, 220], "content": "[b]✨ 今日记录[/b]\n\n\n", "bg": "#FFFFFF", "corner_radius": 12, "border": "#FFCDD2", "border_width": 2, "font_size": 18},
	]],
	["周计划", [
		{"type": "text", "pos": [60, 60], "size": [680, 70], "content": "[font_size=28][b]本周计划[/b][/font_size]", "bg": "#E3F2FD", "corner_radius": 14, "box_glow_size": 4, "box_glow_color": "#90CAF9", "font_size": 28},
		{"type": "text", "pos": [60, 150], "size": [680, 40], "content": "[b]🎯 目标：[/b]", "bg": "#FFFFFF", "font_size": 18},
		{"type": "text", "pos": [60, 200], "size": [680, 40], "content": "周一：", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 245], "size": [680, 40], "content": "周二：", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 290], "size": [680, 40], "content": "周三：", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 335], "size": [680, 40], "content": "周四：", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 380], "size": [680, 40], "content": "周五：", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 425], "size": [680, 40], "content": "周末：", "bg": "#F3E5F5", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 480], "size": [680, 120], "content": "[b]📝 复盘：[/b]\n", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
	]],
	["读书笔记", [
		{"type": "image", "pos": [60, 60], "size": [160, 220], "image_path": ""},
		{"type": "text", "pos": [240, 60], "size": [440, 75], "content": "[font_size=28][b]《书名》[/b][/font_size]", "bg": "#FFF3E0", "corner_radius": 14, "box_glow_size": 4, "box_glow_color": "#FFCC80", "font_size": 28},
		{"type": "text", "pos": [240, 150], "size": [440, 45], "content": "[b]作者：[/b]      [b]日期：[/b]{md_date}", "bg": "#FFFFFF", "font_size": 18},
		{"type": "text", "pos": [240, 210], "size": [440, 70], "content": "[b]⭐ 评分：[/b]⭐⭐⭐⭐⭐", "bg": "#FFFFFF", "font_size": 18},
		{"type": "text", "pos": [60, 300], "size": [680, 130], "content": "[b]📌 摘录：[/b]\n", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 450], "size": [680, 200], "content": "[b]💭 感悟：[/b]\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
	]],
	["月度复盘", [
		{"type": "text", "pos": [60, 60], "size": [680, 80], "content": "[center][font_size=30][b]{year}年{month}月 复盘[/b][/font_size][/center]", "bg": "#F3E5F5", "corner_radius": 16, "box_glow_size": 5, "box_glow_color": "#CE93D8", "font_size": 30},
		{"type": "text", "pos": [60, 160], "size": [330, 160], "content": "[b]✅ 完成的事[/b]\n• \n• \n• ", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [410, 160], "size": [330, 160], "content": "[b]❌ 遗憾的事[/b]\n• \n• ", "bg": "#FFEBEE", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 340], "size": [680, 160], "content": "[b]📊 本月数据[/b]\n运动：   阅读：   睡眠：", "bg": "#E3F2FD", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 520], "size": [680, 140], "content": "[b]🎯 下月目标：[/b]\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
	]],
	["空白手账", [
		{"type": "text", "pos": [120, 80], "size": [560, 70], "content": "[center][font_size=26][b]{date}[/b][/font_size][/center]", "bg": "#FFFFFF", "corner_radius": 14, "box_glow_size": 3, "box_glow_color": "#E0C9A6", "font_size": 26},
	]],
	["今日打卡", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "✨", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 70], "content": "[font_size=30][b]今日打卡 {md_date}[/b][/font_size]", "bg": "#FFF3E0", "corner_radius": 14, "font_size": 30},
		{"type": "text", "pos": [60, 150], "size": [680, 280], "content": "[b]✅ 打卡清单[/b]\n\n• ☐ 早起\n• ☐ 运动 30 分钟\n• ☐ 阅读\n• ☐ 喝水 8 杯\n• ☐ 早睡", "bg": "#E8F5E9", "corner_radius": 12, "font_size": 20},
		{"type": "shape", "pos": [60, 450], "size": [680, 4], "shape": 2, "stroke": "#E0C9A6", "width": 2.0},
		{"type": "text", "pos": [60, 470], "size": [680, 120], "content": "[b]🌙 复盘：[/b]\n", "bg": "#FFFDE7", "corner_radius": 12, "font_size": 18},
	]],
	["感恩日记", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "💛", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 70], "content": "[font_size=28][b]感恩日记[/b][/font_size]", "bg": "#FFF9C4", "corner_radius": 14, "font_size": 28},
		{"type": "text", "pos": [60, 150], "size": [220, 150], "content": "[b]感恩 ①[/b]\n", "bg": "#FFF3E0", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [290, 150], "size": [220, 150], "content": "[b]感恩 ②[/b]\n", "bg": "#E1F5FE", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [520, 150], "size": [220, 150], "content": "[b]感恩 ③[/b]\n", "bg": "#F3E5F5", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 320], "size": [680, 160], "content": "[b]✨ 今日小确幸：[/b]\n", "bg": "#FFFFFF", "corner_radius": 12, "border": "#FFCDD2", "border_width": 2, "font_size": 18},
	]],
	["心情追踪", [
		{"type": "text", "pos": [60, 50], "size": [680, 60], "content": "[center][font_size=26][b]心情追踪 {date}[/b][/font_size][/center]", "bg": "#E3F2FD", "corner_radius": 14, "font_size": 26},
		{"type": "text", "pos": [80, 140], "size": [120, 120], "content": "😭", "font_size": 72, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [320, 140], "size": [120, 120], "content": "😐", "font_size": 72, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [560, 140], "size": [120, 120], "content": "😊", "font_size": 72, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [60, 270], "size": [200, 30], "content": "[center]低落[/center]", "font_size": 16, "text_alignment": 1},
		{"type": "text", "pos": [300, 270], "size": [200, 30], "content": "[center]平静[/center]", "font_size": 16, "text_alignment": 1},
		{"type": "text", "pos": [540, 270], "size": [200, 30], "content": "[center]开心[/center]", "font_size": 16, "text_alignment": 1},
		{"type": "text", "pos": [60, 320], "size": [680, 180], "content": "[b]📝 今日心情记录：[/b]\n", "bg": "#FFFDE7", "corner_radius": 12, "font_size": 18},
	]],
	["旅行手账", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "📍", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 70], "content": "[font_size=28][b]旅行手账[/b][/font_size]", "bg": "#E1F5FE", "corner_radius": 14, "font_size": 28},
		{"type": "text", "pos": [60, 140], "size": [680, 40], "content": "[b]日期：[/b]{md_date}    [b]地点：[/b]", "bg": "#FFFFFF", "font_size": 18},
		{"type": "image", "pos": [60, 200], "size": [320, 220], "image_path": ""},
		{"type": "text", "pos": [400, 200], "size": [340, 220], "content": "[b]🎒 今日见闻：[/b]\n\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 440], "size": [680, 150], "content": "[b]💭 心情感悟：[/b]\n", "bg": "#F3E5F5", "corner_radius": 10, "font_size": 18},
	]],
	["日程表", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "⏰", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]今日日程[/b][/font_size]  {md_date}", "bg": "#E3F2FD", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 140], "size": [680, 48], "content": "09:00    晨练 / 早餐", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 195], "size": [680, 48], "content": "12:00    午餐 + 休息", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 250], "size": [680, 48], "content": "14:00    深度工作", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 305], "size": [680, 48], "content": "18:00    晚餐", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 360], "size": [680, 48], "content": "20:00    阅读 / 复盘", "bg": "#FFFDE7", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 420], "size": [680, 100], "content": "[b]📝 备注：[/b]\n", "bg": "#F3E5F5", "corner_radius": 10, "font_size": 18},
	]],
	["会议记录", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "💼", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]会议记录[/b][/font_size]", "bg": "#E8EAF6", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 130], "size": [680, 70], "content": "[b]主题：[/b]\n[b]时间：[/b]{md_date}    [b]参会：[/b]", "bg": "#FFFFFF", "corner_radius": 8, "font_size": 18},
		{"type": "text", "pos": [60, 210], "size": [680, 160], "content": "[b]📋 议题：[/b]\n• \n• ", "bg": "#FFF3E0", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 380], "size": [680, 120], "content": "[b]✅ 结论与待办：[/b]\n• ", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
	]],
	["习惯追踪", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "🎯", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]习惯追踪[/b][/font_size]", "bg": "#FCE4EC", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 130], "size": [680, 35], "content": "[b]习惯          一  二  三  四  五  六  日[/b]", "bg": "#E3F2FD", "corner_radius": 6, "font_size": 16},
		{"type": "text", "pos": [60, 170], "size": [680, 35], "content": "💧 喝水       ☐  ☐  ☐  ☐  ☐  ☐  ☐", "font_size": 16},
		{"type": "text", "pos": [60, 210], "size": [680, 35], "content": "🏃 运动       ☐  ☐  ☐  ☐  ☐  ☐  ☐", "font_size": 16},
		{"type": "text", "pos": [60, 250], "size": [680, 35], "content": "📖 阅读       ☐  ☐  ☐  ☐  ☐  ☐  ☐", "font_size": 16},
		{"type": "text", "pos": [60, 290], "size": [680, 35], "content": "😴 早睡       ☐  ☐  ☐  ☐  ☐  ☐  ☐", "font_size": 16},
		{"type": "text", "pos": [60, 340], "size": [680, 120], "content": "[b]📊 本周复盘：[/b]\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
	]],
	["学习计划", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "📚", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]学习计划[/b][/font_size]  {md_date}", "bg": "#E8EAF6", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 140], "size": [220, 50], "content": "09:00  数学", "bg": "#FFF3E0", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [290, 140], "size": [220, 50], "content": "10:30  英语", "bg": "#FFF3E0", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [520, 140], "size": [220, 50], "content": "14:00  物理", "bg": "#FFF3E0", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 200], "size": [680, 50], "content": "16:00  编程实践", "bg": "#FFF3E0", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 260], "size": [680, 180], "content": "[b]📝 今日任务[/b]\n• \n• \n• \n• ", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 450], "size": [680, 120], "content": "[b]💡 学习总结：[/b]\n", "bg": "#F3E5F5", "corner_radius": 10, "font_size": 18},
	]],
	["健身打卡", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "💪", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]健身打卡[/b][/font_size]", "bg": "#E1F5FE", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 140], "size": [680, 35], "content": "[b]项目            组数   次数    备注[/b]", "bg": "#E3F2FD", "corner_radius": 6, "font_size": 16},
		{"type": "text", "pos": [60, 180], "size": [680, 35], "content": "🏃 跑步          1      5km    晨跑", "font_size": 16},
		{"type": "text", "pos": [60, 220], "size": [680, 35], "content": "🏋️ 力量训练      4      12      胸+三头", "font_size": 16},
		{"type": "text", "pos": [60, 260], "size": [680, 35], "content": "🧘 拉伸          1      15min   放松", "font_size": 16},
		{"type": "text", "pos": [60, 300], "size": [680, 35], "content": "🚴 动感单车      1      30min   有氧", "font_size": 16},
		{"type": "text", "pos": [60, 350], "size": [680, 200], "content": "[b]🔥 今日训练感受：[/b]\n\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
	]],
	["今日菜谱", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "🍳", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]今日菜谱[/b][/font_size]", "bg": "#FFF9C4", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 130], "size": [680, 40], "content": "[b]菜名：[/b]                [b]用时：[/b]", "bg": "#FFFFFF", "corner_radius": 6, "font_size": 18},
		{"type": "text", "pos": [60, 180], "size": [680, 140], "content": "[b]🥗 食材：[/b]\n• \n• \n• ", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 18},
		{"type": "text", "pos": [60, 330], "size": [680, 240], "content": "[b]👩‍🍳 步骤：[/b]\n1. \n2. \n3. \n4. ", "bg": "#FFF3E0", "corner_radius": 10, "font_size": 18},
	]],
	["项目看板", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "📋", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]项目看板[/b][/font_size]", "bg": "#E8EAF6", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 140], "size": [220, 340], "content": "[b]📌 待办[/b]\n\n• \n• \n• \n• ", "bg": "#FFEBEE", "corner_radius": 10, "font_size": 16},
		{"type": "text", "pos": [290, 140], "size": [220, 340], "content": "[b]🔨 进行中[/b]\n\n• \n• \n• ", "bg": "#FFF9C4", "corner_radius": 10, "font_size": 16},
		{"type": "text", "pos": [520, 140], "size": [220, 340], "content": "[b]✅ 已完成[/b]\n\n• \n• ", "bg": "#E8F5E9", "corner_radius": 10, "font_size": 16},
	]],
	["读书清单", [
		{"type": "text", "pos": [60, 40], "size": [90, 90], "content": "📖", "font_size": 64, "bg": "#00000000", "border_width": 0, "text_alignment": 1},
		{"type": "text", "pos": [160, 50], "size": [500, 60], "content": "[font_size=26][b]读书清单[/b][/font_size]", "bg": "#F3E5F5", "corner_radius": 12, "font_size": 26},
		{"type": "text", "pos": [60, 140], "size": [680, 35], "content": "[b]书名               进度      评分[/b]", "bg": "#E3F2FD", "corner_radius": 6, "font_size": 16},
		{"type": "text", "pos": [60, 180], "size": [680, 35], "content": "《书名一》         50%       ⭐⭐⭐⭐", "font_size": 16},
		{"type": "text", "pos": [60, 220], "size": [680, 35], "content": "《书名二》         100%      ⭐⭐⭐⭐⭐", "font_size": 16},
		{"type": "text", "pos": [60, 260], "size": [680, 35], "content": "《书名三》         待读       —", "font_size": 16},
		{"type": "text", "pos": [60, 300], "size": [680, 35], "content": "《书名四》         待读       —", "font_size": 16},
		{"type": "text", "pos": [60, 350], "size": [680, 220], "content": "[b]✍️ 读书心得：[/b]\n\n", "bg": "#FFFDE7", "corner_radius": 10, "font_size": 18},
	]],
]

## 构建日记面板
func _setup_diary_panel() -> void:
	_diary_popup = PopupPanel.new()
	_diary_popup.title = "日记助手"
	add_child(_diary_popup)

## 刷新并弹出日记面板
func _refresh_diary_panel() -> void:
	for c in _diary_popup.get_children():
		c.queue_free()
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# ── 时间戳 ──
	var time_section := Label.new()
	time_section.text = "⏰ 时间戳"
	time_section.add_theme_font_size_override("font_size", 13)
	time_section.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(time_section)
	
	var time_row := HBoxContainer.new()
	var now_btn := Button.new()
	now_btn.text = "📅 插入当前日期时间"
	now_btn.custom_minimum_size = Vector2i(180, 30)
	now_btn.pressed.connect(func():
		_insert_text_to_block(_format_datetime())
		_diary_popup.hide()
	)
	time_row.add_child(now_btn)
	
	var date_btn := Button.new()
	date_btn.text = "📆 仅日期"
	date_btn.custom_minimum_size = Vector2i(100, 30)
	date_btn.pressed.connect(func():
		_insert_text_to_block(_format_date())
		_diary_popup.hide()
	)
	time_row.add_child(date_btn)
	vbox.add_child(time_row)
	
	# ── 天气 ──
	var weather_label := Label.new()
	weather_label.text = "🌤️ 天气"
	weather_label.add_theme_font_size_override("font_size", 13)
	weather_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(weather_label)
	
	var weather_grid := GridContainer.new()
	weather_grid.columns = 4
	weather_grid.add_theme_constant_override("h_separation", 4)
	weather_grid.add_theme_constant_override("v_separation", 4)
	for w in WEATHER_OPTIONS:
		var ws: String = w as String
		var btn := Button.new()
		btn.text = ws
		btn.custom_minimum_size = Vector2i(80, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			_insert_text_to_block(ws)
			_diary_popup.hide()
		)
		weather_grid.add_child(btn)
	vbox.add_child(weather_grid)
	
	# ── 心情 ──
	var mood_label := Label.new()
	mood_label.text = "💭 心情"
	mood_label.add_theme_font_size_override("font_size", 13)
	mood_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(mood_label)
	
	var mood_grid := GridContainer.new()
	mood_grid.columns = 5
	mood_grid.add_theme_constant_override("h_separation", 4)
	mood_grid.add_theme_constant_override("v_separation", 4)
	for m in MOOD_OPTIONS:
		var ms: String = m as String
		var btn := Button.new()
		btn.text = ms
		btn.custom_minimum_size = Vector2i(72, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			_insert_text_to_block(ms)
			_diary_popup.hide()
		)
		mood_grid.add_child(btn)
	vbox.add_child(mood_grid)

	# ── 趣味玩法 ──
	var play_label := Label.new()
	play_label.text = "🎲 趣味"
	play_label.add_theme_font_size_override("font_size", 13)
	play_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(play_label)
	var play_row := HBoxContainer.new()
	var scatter_btn := Button.new()
	scatter_btn.text = "✨ 随机撒 emoji"
	scatter_btn.add_theme_font_size_override("font_size", 12)
	scatter_btn.pressed.connect(_scatter_random_emoji)
	play_row.add_child(scatter_btn)
	var fortune_btn := Button.new()
	fortune_btn.text = "🧧 抽今日运势"
	fortune_btn.add_theme_font_size_override("font_size", 12)
	fortune_btn.pressed.connect(_draw_fortune)
	play_row.add_child(fortune_btn)
	vbox.add_child(play_row)
	
	# ── 模板 ──
	var tmpl_label := Label.new()
	tmpl_label.text = "📝 模板"
	tmpl_label.add_theme_font_size_override("font_size", 13)
	tmpl_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(tmpl_label)

	# 把当前画布排版另存为自定义模板
	var save_btn := Button.new()
	save_btn.text = "💾 把当前排版存为模板"
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(_prompt_save_as_template)
	vbox.add_child(save_btn)

	# 预设模板
	var preset_label := Label.new()
	preset_label.text = "预设"
	preset_label.add_theme_font_size_override("font_size", 12)
	preset_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(preset_label)

	var tmpl_grid := GridContainer.new()
	tmpl_grid.columns = 3
	tmpl_grid.add_theme_constant_override("h_separation", 4)
	tmpl_grid.add_theme_constant_override("v_separation", 4)
	for t in DIARY_TEMPLATES:
		var tp: Array = t as Array
		var tname: String = tp[0] as String
		var tblocks: Array = tp[1] as Array
		var btn := Button.new()
		btn.text = tname
		btn.custom_minimum_size = Vector2i(90, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			_create_template_blocks(tblocks)
			_diary_popup.hide()
		)
		tmpl_grid.add_child(btn)
	vbox.add_child(tmpl_grid)

	# 自定义模板（从 user://data/templates/ 加载）
	var custom_tmpls: Array = _load_custom_templates()
	if not custom_tmpls.is_empty():
		var custom_label := Label.new()
		custom_label.text = "我的模板"
		custom_label.add_theme_font_size_override("font_size", 12)
		custom_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(custom_label)
		var custom_grid := GridContainer.new()
		custom_grid.columns = 3
		custom_grid.add_theme_constant_override("h_separation", 4)
		custom_grid.add_theme_constant_override("v_separation", 4)
		for ct in custom_tmpls:
			var ct_arr: Array = ct as Array
			var cname: String = ct_arr[0] as String
			var cblocks: Array = ct_arr[1] as Array
			var cbtn := Button.new()
			cbtn.text = cname
			cbtn.custom_minimum_size = Vector2i(90, 32)
			cbtn.add_theme_font_size_override("font_size", 12)
			cbtn.tooltip_text = "左键套用 · 右键删除"
			cbtn.pressed.connect(func():
				_apply_custom_template(cblocks)
				_diary_popup.hide()
			)
			# 右键删除
			cbtn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and not ev.pressed:
					_confirm_delete_template(cname)
			)
			custom_grid.add_child(cbtn)
		vbox.add_child(custom_grid)
	
	margin.add_child(vbox)
	_diary_popup.add_child(margin)

## 弹出对话框输入模板名，把当前画布排版存为自定义模板
func _prompt_save_as_template() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "另存为模板"
	dlg.ok_button_text = "保存"
	var dlg_vbox := VBoxContainer.new()
	var hint := Label.new()
	hint.text = "模板名称："
	dlg_vbox.add_child(hint)
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "如：我的日记模板"
	line_edit.text = "我的模板"
	dlg_vbox.add_child(line_edit)
	dlg.add_child(dlg_vbox)
	add_child(dlg)
	dlg.confirmed.connect(func():
		var name_str: String = line_edit.text.strip_edges()
		if name_str.is_empty():
			name_str = "未命名模板"
		_save_current_as_template(name_str)
		_refresh_diary_panel()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(320, 120))
	line_edit.grab_focus()
	line_edit.select_all()


## 把当前画布的所有块快照存为模板（user://data/templates/{name}.tres）
## 复用 PageData 容器，深拷贝 blocks 避免与当前页共享 Resource
func _save_current_as_template(tmpl_name: String) -> void:
	_sync_block_data()
	var tmpl := PageData.new()
	tmpl.note_title = tmpl_name
	for b in _current_page_data.blocks:
		tmpl.blocks.append((b as BlockData).duplicate(true))
	var abs_dir: String = ProjectSettings.globalize_path(TEMPLATE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var path: String = TEMPLATE_DIR + tmpl_name + ".tres"
	var result: int = ResourceSaver.save(tmpl, path)
	if result == OK:
		print("模板已保存: ", path)
	else:
		push_warning("模板保存失败: 错误码 ", result)


## 扫描 user://data/templates/，返回 [[名称, blocks数组], ...]
func _load_custom_templates() -> Array:
	var out: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(TEMPLATE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return out
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var loaded = ResourceLoader.load(TEMPLATE_DIR + fname)
			if loaded is PageData:
				var pd: PageData = loaded as PageData
				out.append([pd.note_title, pd.blocks])
		fname = dir.get_next()
	dir.list_dir_end()
	return out


## 套用自定义模板：深拷贝 blocks 后挂到当前画布（避免多实例共享同一 Resource）
func _apply_custom_template(blocks: Array) -> void:
	_deselect_all()
	for block_data in blocks:
		var dup: BlockData = (block_data as BlockData).duplicate(true)
		_spawn_block(dup)
	_mark_dirty()


## 右键删除自定义模板的确认弹窗
func _confirm_delete_template(tmpl_name: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "删除模板"
	dlg.dialog_text = "确定删除模板「%s」？" % tmpl_name
	add_child(dlg)
	dlg.confirmed.connect(func():
		_delete_custom_template(tmpl_name)
		_refresh_diary_panel()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(320, 100))


## 删除自定义模板文件
func _delete_custom_template(tmpl_name: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(TEMPLATE_DIR + tmpl_name + ".tres")
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
		print("模板已删除: ", tmpl_name)


## 格式化当前日期时间 "2026年6月24日 周三 15:30"
func _format_datetime() -> String:
	var dt = Time.get_datetime_dict_from_system()
	var weekdays = ["周日","周一","周二","周三","周四","周五","周六"]
	var wday: String = weekdays[dt.weekday] if dt.weekday < 7 else ""
	return "%04d年%d月%d日 %s %02d:%02d" % [dt.year, dt.month, dt.day, wday, dt.hour, dt.minute]

## 格式化当前日期 "2026-06-24"
func _format_date() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

## 插入文本到当前编辑中的文本块
func _insert_text_to_block(text: String) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		if tb.is_editing():
			tb.insert_at_cursor(text, "")
			return
	# 没有编辑中的文本块，新建一个
	_create_text_block_with_content(text)

## 用指定内容新建文本块（单块，供天气/心情/时间戳用）
func _create_text_block_with_content(content: String) -> void:
	var data := TextBlockData.new()
	data.position = _get_spawn_position()
	data.bbcode_content = content
	data.font_size = _setting_default_font_size
	data.font_id = _setting_default_font_id
	data.bg_color = _setting_default_block_bg
	# 根据内容自适应尺寸（时间戳/天气/心情等单行内容不再用默认大框）
	data.size = _estimate_text_size(content, data.font_size)
	
	var block: TextBlock = _text_block_scene.instantiate()
	paper.add_child(block)
	block.setup(data)
	_connect_block_signals(block)
	_current_page_data.blocks.append(data)
	_mark_dirty()
	
	_deselect_all()
	block.block_selected.emit(block)
	_update_font_ui()


## 根据文本内容估算块尺寸（去除 BBCode 标签后按字符数/行数估）
func _estimate_text_size(content: String, font_size: int) -> Vector2:
	var plain: String = _strip_bbcode(content)
	var lines: Array = plain.split("\n")
	var max_len: int = 1
	for line in lines:
		max_len = maxi(max_len, (line as String).length())
	var w: float = float(max_len) * float(font_size) * 0.75 + 28.0
	var h: float = float(lines.size()) * float(font_size) * 1.5 + 16.0
	return Vector2(clampf(w, 80.0, 700.0), clampf(h, 40.0, 600.0))


## 去除 BBCode/Markdown 标签，用于尺寸估算
func _strip_bbcode(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	return re.sub(s, "", true)


## 趣味玩法：在画布随机位置撒若干个随机大小的 emoji 贴纸
func _scatter_random_emoji() -> void:
	_deselect_all()
	var pw: float = maxf(paper.size.x, 600.0)
	var ph: float = maxf(paper.size.y, 600.0)
	var count: int = 8
	for i in range(count):
		var emoji: String = (PLAY_EMOJIS[randi() % PLAY_EMOJIS.size()] as String)
		var sz: float = randf_range(60.0, 140.0)
		var pos: Vector2 = Vector2(randf_range(60.0, pw - sz - 20.0), randf_range(60.0, ph - sz - 20.0))
		var data := EmojiStickerData.new()
		data.position = pos
		data.emoji_text = emoji
		data.size = Vector2(sz, sz)
		_spawn_block(data)
	_mark_dirty()


## 趣味玩法：抽取今日运势（随机运势签文本块）
func _draw_fortune() -> void:
	var f: Array = (FORTUNES[randi() % FORTUNES.size()] as Array)
	var luck: String = f[0] as String
	var emoji: String = f[1] as String
	var msg: String = f[2] as String
	var content: String = "[font_size=42][b]" + luck + "[/b][/font_size]\n[font_size=60]" + emoji + "[/font_size]\n[font_size=18]" + msg + "[/font_size]\n[font_size=13]{date}[/font_size]"
	var data := TextBlockData.new()
	data.position = _get_spawn_position()
	data.bbcode_content = _resolve_template_vars(content)
	data.font_size = 20
	data.bg_color = Color("#FFF9C4")
	data.border_color = Color("#FFD54F")
	data.border_width = 2
	data.corner_radius = 16
	data.box_glow_size = 4
	data.box_glow_color = Color("#FFD54F")
	data.text_alignment = 1
	data.size = Vector2(280, 280)
	_spawn_block(data)
	_mark_dirty()


## 根据模板定义数组创建多个预设好的块（文本+图形+图片）
## 模板 def 字段见 _make_text_data / _make_shape_data / _make_image_data 注释
func _create_template_blocks(block_defs: Array) -> void:
	_deselect_all()
	var created: Array[BaseBlock] = []
	for def in block_defs:
		var d: Dictionary = def as Dictionary
		var btype: String = d.get("type", "text") as String
		var pos: Vector2 = _vec2_from_def(d, "pos", Vector2(60, 60))
		var bsize: Vector2 = _vec2_from_def(d, "size", Vector2(300, 200))
		var data: BlockData = null
		if btype == "text":
			data = _make_text_data(d, pos, bsize)
		elif btype == "shape":
			data = _make_shape_data(d, pos, bsize)
		elif btype == "image":
			data = _make_image_data(d, pos, bsize)
		if data == null:
			continue
		if d.has("rotation"):
			data.rotation_degrees = float(d["rotation"])
		var block: BaseBlock = _spawn_block(data)
		if block != null:
			created.append(block)
	# 默认全选刚创建的块，便于整组移动（避免与其他控件叠在一起）
	if created.size() > 1:
		for b in created:
			b.select()
			_selected_blocks.append(b)
		_current_selected_block = created[0]
	elif created.size() == 1:
		created[0].block_selected.emit(created[0])
	_mark_dirty()


## 通用：用 block_data 实例化块并挂到当前画布（setup/连接/入页/脏标记）
## 模板、装饰、程序化新建共用，避免重复 instantiate→add→setup→connect→append
func _spawn_block(data: BlockData, play_anim: bool = true) -> BaseBlock:
	var block: BaseBlock = null
	if data is TextBlockData:
		block = _text_block_scene.instantiate()
	elif data is ImageBlockData:
		block = _image_block_scene.instantiate()
	elif data is ShapeBlockData:
		block = _shape_block_scene.instantiate()
	elif data is DrawBlockData:
		block = _draw_block_scene.instantiate()
	elif data is EmojiStickerData:
		block = _emoji_sticker_scene.instantiate()
	else:
		push_warning("_spawn_block: 未知块类型")
		return null
	paper.add_child(block)
	block.setup(data)
	_connect_block_signals(block)
	_current_page_data.blocks.append(data)
	# 统一 Q 弹弹出动画（新建块用；撤销恢复时跳过，避免重建时全部弹出）
	if play_anim:
		block._play_spawn_anim()
	return block


## 模板文本占位符替换：{date} {md_date} {weekday} {year} {month} {day} {time}
## 用当前系统时间填充，避免模板里写死日期（修「每日心情」日期不变 bug）
func _resolve_template_vars(content: String) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var weekdays: Array = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
	var wday: String = weekdays[dt.weekday] if dt.weekday < 7 else ""
	var date_str: String = "%04d年%d月%d日 %s" % [dt.year, dt.month, dt.day, wday]
	var md_date: String = "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
	var time_str: String = "%02d:%02d" % [dt.hour, dt.minute]
	var resolved: String = content
	resolved = resolved.replace("{date}", date_str)
	resolved = resolved.replace("{md_date}", md_date)
	resolved = resolved.replace("{weekday}", wday)
	resolved = resolved.replace("{year}", str(dt.year))
	resolved = resolved.replace("{month}", str(dt.month))
	resolved = resolved.replace("{day}", str(dt.day))
	resolved = resolved.replace("{time}", time_str)
	return resolved


## 从模板 def 取 Vector2（key 对应 [x, y] 数组），缺失/非法返回 fallback
func _vec2_from_def(d: Dictionary, key: String, fallback: Vector2) -> Vector2:
	if not d.has(key):
		return fallback
	var arr: Array = d[key] as Array
	if arr.size() < 2:
		return fallback
	return Vector2(float(arr[0]), float(arr[1]))


## 从模板 def 取 Color（支持 "#RRGGBB" 字符串或 Color 值）
func _color_from_def(d: Dictionary, key: String, fallback: Color) -> Color:
	if not d.has(key):
		return fallback
	var v: Variant = d[key]
	if v is Color:
		return v as Color
	return Color(String(v))


## 构造文本块 data（支持全部 TextBlockData 样式字段 + 占位符替换）
func _make_text_data(d: Dictionary, pos: Vector2, bsize: Vector2) -> TextBlockData:
	var data := TextBlockData.new()
	data.position = pos
	data.size = bsize
	data.bbcode_content = _resolve_template_vars(d.get("content", "") as String)
	data.font_size = int(d.get("font_size", _setting_default_font_size))
	data.font_id = String(d.get("font_id", _setting_default_font_id))
	data.bg_color = _color_from_def(d, "bg", _setting_default_block_bg)
	data.font_color = _color_from_def(d, "font_color", data.font_color)
	data.border_color = _color_from_def(d, "border", data.border_color)
	data.border_width = int(d.get("border_width", data.border_width))
	data.corner_radius = int(d.get("corner_radius", data.corner_radius))
	data.outline_size = int(d.get("outline_size", data.outline_size))
	data.outline_color = _color_from_def(d, "outline_color", data.outline_color)
	data.box_glow_size = int(d.get("box_glow_size", data.box_glow_size))
	data.box_glow_color = _color_from_def(d, "box_glow_color", data.box_glow_color)
	data.line_spacing = float(d.get("line_spacing", data.line_spacing))
	data.text_alignment = int(d.get("text_alignment", data.text_alignment))
	data.use_markdown = bool(d.get("use_markdown", data.use_markdown))
	return data


## 构造图形块 data。fill 给颜色字符串即填充，否则仅描边
func _make_shape_data(d: Dictionary, pos: Vector2, bsize: Vector2) -> ShapeBlockData:
	var data := ShapeBlockData.new()
	data.position = pos
	data.size = bsize
	data.shape_type = int(d.get("shape", 0)) as ShapeBlockData.ShapeType
	data.stroke_color = _color_from_def(d, "stroke", data.stroke_color)
	data.stroke_width = float(d.get("width", data.stroke_width))
	if d.has("fill"):
		data.fill_enabled = true
		data.fill_color = _color_from_def(d, "fill", data.fill_color)
	else:
		data.fill_enabled = bool(d.get("fill_enabled", false))
	return data


## 构造图片块 data（模板里的图片占位/封面）
func _make_image_data(d: Dictionary, pos: Vector2, bsize: Vector2) -> ImageBlockData:
	var data := ImageBlockData.new()
	data.position = pos
	data.size = bsize
	data.image_path = String(d.get("image_path", ""))
	return data

## 从 user://data/settings.json 加载设置（真 JSON，非 Resource）
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		if d.has("ctrl_drag_rotate"):
			_setting_ctrl_drag_rotate = bool(d["ctrl_drag_rotate"])
		if d.has("default_font_size"):
			_setting_default_font_size = int(d["default_font_size"])
		if d.has("default_block_bg"):
			_setting_default_block_bg = Color(d["default_block_bg"])
		if d.has("default_font_color"):
			_setting_default_font_color = Color(d["default_font_color"])
		if d.has("default_opacity"):
			_setting_default_opacity = float(d["default_opacity"])
		if d.has("default_font_id"):
			_setting_default_font_id = String(d["default_font_id"])
		if d.has("default_alignment"):
			_setting_default_alignment = int(d["default_alignment"])
		if d.has("snap_grid"):
			_setting_snap_grid = bool(d["snap_grid"])
		if d.has("fx_trail"):
			_setting_fx_trail = bool(d["fx_trail"])
		if d.has("fx_click"):
			_setting_fx_click = bool(d["fx_click"])
		if d.has("fx_meteor"):
			_setting_fx_meteor = bool(d["fx_meteor"])
		if d.has("fx_water"):
			_setting_fx_water = bool(d["fx_water"])
		if d.has("fx_petal"):
			_setting_fx_petal = bool(d["fx_petal"])
		if d.has("fx_rain"):
			_setting_fx_rain = bool(d["fx_rain"])
		if d.has("fx_snow"):
			_setting_fx_snow = bool(d["fx_snow"])
		if d.has("fx_firefly"):
			_setting_fx_firefly = bool(d["fx_firefly"])
		if d.has("fx_ripple"):
			_setting_fx_ripple = bool(d["fx_ripple"])
		if d.has("fx_vignette"):
			_setting_fx_vignette = bool(d["fx_vignette"])
		if d.has("fx_scanlines"):
			_setting_fx_scanlines = bool(d["fx_scanlines"])
		if d.has("fx_grain"):
			_setting_fx_grain = bool(d["fx_grain"])
		if d.has("fx_light_leak"):
			_setting_fx_light_leak = bool(d["fx_light_leak"])
		if d.has("breathe_amp"):
			_setting_breathe_amp = float(d["breathe_amp"])
		if d.has("breathe_period"):
			_setting_breathe_period = float(d["breathe_period"])
		if d.has("idle_float"):
			_setting_idle_float = bool(d["idle_float"])
		if d.has("inspector_docked"):
			_setting_inspector_docked = bool(d["inspector_docked"])
		if d.has("md_font_size"):
			_setting_md_font_size = int(d["md_font_size"])
		if d.has("md_font_color"):
			_setting_md_font_color = Color(d["md_font_color"])
		if d.has("md_bg_color"):
			_setting_md_bg_color = Color(d["md_bg_color"])
		if d.has("md_bg_opacity"):
			_setting_md_bg_opacity = float(d["md_bg_opacity"])
		if d.has("onboarding_done"):
			_setting_onboarding_done = bool(d["onboarding_done"])

## 保存设置到 user://data/settings.json
func _save_settings() -> void:
	var d: Dictionary = {
		"ctrl_drag_rotate": _setting_ctrl_drag_rotate,
		"default_font_size": _setting_default_font_size,
		"default_block_bg": _setting_default_block_bg.to_html(false),
		"default_font_color": _setting_default_font_color.to_html(false),
		"default_opacity": _setting_default_opacity,
		"default_font_id": _setting_default_font_id,
		"default_alignment": _setting_default_alignment,
		"snap_grid": _setting_snap_grid,
		"fx_trail": _setting_fx_trail,
		"fx_click": _setting_fx_click,
		"fx_meteor": _setting_fx_meteor,
		"fx_water": _setting_fx_water,
		"fx_petal": _setting_fx_petal,
		"fx_rain": _setting_fx_rain,
		"fx_snow": _setting_fx_snow,
		"fx_firefly": _setting_fx_firefly,
		"fx_ripple": _setting_fx_ripple,
		"fx_vignette": _setting_fx_vignette,
		"fx_scanlines": _setting_fx_scanlines,
		"fx_grain": _setting_fx_grain,
		"fx_light_leak": _setting_fx_light_leak,
		"breathe_amp": _setting_breathe_amp,
		"breathe_period": _setting_breathe_period,
		"idle_float": _setting_idle_float,
		"inspector_docked": _setting_inspector_docked,
		"md_font_size": _setting_md_font_size,
		"md_font_color": _setting_md_font_color.to_html(false),
		"md_bg_color": _setting_md_bg_color.to_html(false),
		"md_bg_opacity": _setting_md_bg_opacity,
		"onboarding_done": _setting_onboarding_done,
	}
	var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("设置保存失败")
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()

## 默认文本设置对话框
func _prompt_default_text_settings() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "默认文本框设置"
	dialog.min_size = Vector2i(320, 200)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	# 字体选择
	var row_font := HBoxContainer.new()
	var lbl_font := Label.new()
	lbl_font.text = "字体:"
	lbl_font.custom_minimum_size = Vector2i(60, 0)
	var font_opt := OptionButton.new()
	for preset in FONT_PRESETS:
		var p: Array = preset as Array
		font_opt.add_item(p[0])
	# 选中当前默认字体
	for i in FONT_PRESETS.size():
		if (FONT_PRESETS[i] as Array)[1] == _setting_default_font_id:
			font_opt.select(i)
			break
	row_font.add_child(lbl_font)
	row_font.add_child(font_opt)
	vbox.add_child(row_font)
	
	# 字号
	var row_size := HBoxContainer.new()
	var lbl_size := Label.new()
	lbl_size.text = "字号:"
	lbl_size.custom_minimum_size = Vector2i(60, 0)
	var size_spin := SpinBox.new()
	size_spin.min_value = 8
	size_spin.max_value = 72
	size_spin.value = float(_setting_default_font_size)
	row_size.add_child(lbl_size)
	row_size.add_child(size_spin)
	vbox.add_child(row_size)
	
	# 对齐
	var row_align := HBoxContainer.new()
	var lbl_align := Label.new()
	lbl_align.text = "对齐:"
	lbl_align.custom_minimum_size = Vector2i(60, 0)
	var align_opt := OptionButton.new()
	align_opt.add_item("左对齐", 0)
	align_opt.add_item("居中", 1)
	align_opt.add_item("右对齐", 2)
	align_opt.select(_setting_default_alignment)
	row_align.add_child(lbl_align)
	row_align.add_child(align_opt)
	vbox.add_child(row_align)

	# 块底色
	var row_bg := HBoxContainer.new()
	var lbl_bg := Label.new()
	lbl_bg.text = "块底色:"
	lbl_bg.custom_minimum_size = Vector2i(60, 0)
	var bg_cbtn := ColorPickerButton.new()
	bg_cbtn.color = _setting_default_block_bg
	bg_cbtn.edit_alpha = false
	row_bg.add_child(lbl_bg)
	row_bg.add_child(bg_cbtn)
	vbox.add_child(row_bg)

	# 文字颜色
	var row_fc := HBoxContainer.new()
	var lbl_fc := Label.new()
	lbl_fc.text = "文字色:"
	lbl_fc.custom_minimum_size = Vector2i(60, 0)
	var fc_cbtn := ColorPickerButton.new()
	fc_cbtn.color = _setting_default_font_color
	fc_cbtn.edit_alpha = false
	row_fc.add_child(lbl_fc)
	row_fc.add_child(fc_cbtn)
	vbox.add_child(row_fc)

	# 透明度
	var row_op := HBoxContainer.new()
	var lbl_op := Label.new()
	lbl_op.text = "透明度:"
	lbl_op.custom_minimum_size = Vector2i(60, 0)
	var op_spin := SpinBox.new()
	op_spin.min_value = 10
	op_spin.max_value = 100
	op_spin.step = 5
	op_spin.value = _setting_default_opacity * 100.0
	op_spin.suffix = "%"
	row_op.add_child(lbl_op)
	row_op.add_child(op_spin)
	vbox.add_child(row_op)
	
	margin.add_child(vbox)
	dialog.add_child(margin)
	
	dialog.confirmed.connect(func():
		var idx: int = font_opt.selected
		if idx < FONT_PRESETS.size():
			_setting_default_font_id = (FONT_PRESETS[idx] as Array)[1]
		_setting_default_font_size = int(size_spin.value)
		_setting_default_alignment = align_opt.selected
		_setting_default_block_bg = bg_cbtn.color
		_setting_default_font_color = fc_cbtn.color
		_setting_default_opacity = op_spin.value / 100.0
		_save_settings()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	add_child(dialog)
	dialog.popup_centered()

func _connect_signals():
	add_text_btn.pressed.connect(_on_add_text)
	add_image_btn.pressed.connect(_on_add_image)
	doodle_btn.pressed.connect(_on_add_doodle)
	open_btn.pressed.connect(_on_open_file)
	markdown_btn.pressed.connect(_open_md_editor)
	note_list_btn.toggled.connect(_on_note_list_toggle)
	font_color_btn.color_changed.connect(_on_font_color_changed)
	font_option_btn.item_selected.connect(_on_font_option_selected)
	outline_spin.value_changed.connect(_on_outline_size_changed)
	outline_color_btn.color_changed.connect(_on_outline_color_changed)
	block_bg_color_btn.color_changed.connect(_on_block_bg_color_changed)
	text_more_btn.pressed.connect(_on_text_more_pressed)
	insert_btn.pressed.connect(_on_insert_pressed)
	emoji_btn.pressed.connect(_on_emoji_pressed)
	diary_btn.pressed.connect(_on_diary_pressed)
	_line_spacing_spin.value_changed.connect(_on_line_spacing_changed)
	_box_glow_spin.value_changed.connect(_on_box_glow_size_changed)
	_box_glow_color_btn.color_changed.connect(_on_box_glow_color_changed)
	_corner_radius_spin.value_changed.connect(_on_corner_radius_changed)
	_markdown_check.toggled.connect(_on_markdown_toggled)
	rotate_left_btn.pressed.connect(func(): _rotate_selected_block(-15.0))
	rotate_right_btn.pressed.connect(func(): _rotate_selected_block(15.0))
	rotate_reset_btn.pressed.connect(_on_rotate_reset)
	bg_color_picker.color_changed.connect(_on_bg_color_changed)
	sticker_toggle.toggled.connect(_on_sticker_toggle)
	open_sticker_dir.pressed.connect(_on_open_sticker_dir)
	export_json_btn.pressed.connect(_on_export_json)
	export_image_btn.pressed.connect(_on_export_image)
	refresh_stickers.pressed.connect(_populate_stickers)
	sticker_to_emoji_btn.pressed.connect(_on_emoji_pressed)
	sticker_stamp_btn.pressed.connect(_prompt_stamp_select)
	help_btn.pressed.connect(_show_help)
	
	paper.gui_input.connect(_on_paper_clicked)
	splitter.gui_input.connect(_on_splitter_drag)
	# 贴纸拖拽放置：paper 上的 PaperDropTarget 信号
	(paper as PaperDropTarget).sticker_dropped.connect(_on_sticker_dropped)
	(paper as PaperDropTarget).emoji_sticker_dropped.connect(_on_emoji_sticker_dropped)

func _process(_delta: float) -> void:
	# 属性浮层跟随选中块（画布移动/缩放时保持贴附）
	if _inspector_popup != null and _inspector_popup.visible \
	   and _current_selected_block != null and is_instance_valid(_current_selected_block):
		var vp := Vector2(get_viewport_rect().size)
		if _setting_inspector_docked:
			_inspector_popup.position = Vector2(vp.x - _inspector_popup.size.x - 8.0, 64.0)
		else:
			var br: Rect2 = _current_selected_block.get_global_rect()
			var anchor_global := Vector2(br.end.x + 6.0, br.position.y)
			var local_pos: Vector2 = get_global_transform().affine_inverse() * anchor_global
			local_pos.x = clampf(local_pos.x, 4.0, vp.x - _inspector_popup.size.x - 4.0)
			local_pos.y = clampf(local_pos.y, 4.0, vp.y - _inspector_popup.size.y - 4.0)
			_inspector_popup.position = local_pos
	# 底部提示条：按当前状态（选中/编辑/框选）刷新快捷键提示
	_update_hint_if_changed()


func _input(event: InputEvent):
	# F1：打开帮助 / 快捷键面板（约定俗成的帮助键）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_show_help()
		get_viewport().set_input_as_handled()
		return
	# ── 印章模式：左键点画布盖戳，Esc 退出（优先级高，放在最前）──
	if _stamp_mode:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_exit_stamp_mode()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if paper_scroll.get_global_rect().has_point(get_global_mouse_position()):
				_stamp_emoji_at(_stamp_emoji, paper.get_local_mouse_position())
				get_viewport().set_input_as_handled()
			return
	# ── Esc：按优先级关闭最上层浮层（统一交互——任何二级窗口都可 Esc 关）──
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _md_is_open:
			_close_md_editor()
		elif _kaomoji_popup != null and _kaomoji_popup.visible:
			_hide_kaomoji_panel()
		elif _emoji_popup != null and _emoji_popup.visible:
			_emoji_popup.visible = false
		elif _insert_popup != null and _insert_popup.visible:
			_hide_insert_panel()
		elif _text_more_popup != null and _text_more_popup.visible:
			_text_more_popup.hide()
		elif _diary_popup != null and _diary_popup.visible:
			_diary_popup.hide()
		elif sticker_panel.visible:
			sticker_toggle.button_pressed = false
		elif _note_list_panel != null and _note_list_panel.visible:
			note_list_btn.button_pressed = false
		elif not _selected_blocks.is_empty():
			_deselect_all()
		else:
			return  # 无浮层/选中：Esc 放行（不消费）
		get_viewport().set_input_as_handled()
		return
	# ── 特效：鼠标星光轨迹 + 点击迸发（仅叠加视觉，不消费事件）──
	if _fx_layer != null and is_instance_valid(_fx_layer):
		if event is InputEventMouseMotion:
			var mp: Vector2 = paper_scroll.get_local_mouse_position()
			if _fx_layer.trail_enabled and mp.distance_to(_last_trail_pos) > 6.0:
				_fx_layer.spawn_trail(mp)
				_last_trail_pos = mp
			if _fx_layer.ripple_enabled and mp.distance_to(_last_ripple_pos) > 28.0:
				_fx_layer.spawn_ripple(mp)
				_last_ripple_pos = mp
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed and _fx_layer.click_enabled:
			if paper_scroll.get_global_rect().has_point(get_global_mouse_position()):
				_fx_layer.spawn_burst(paper_scroll.get_local_mouse_position())
	# ── 撤销 / 重做（文本编辑中让位给 TextEdit 自带撤销）──
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed \
	   and (event.keycode == KEY_Z or event.keycode == KEY_Y):
		var in_text_edit: bool = (_current_selected_block is TextBlock \
			and is_instance_valid(_current_selected_block) \
			and (_current_selected_block as TextBlock).is_editing()) \
			or _md_is_open
		if not in_text_edit:
			if event.keycode == KEY_Y or event.shift_pressed:
				_redo()
			else:
				_undo()
			get_viewport().set_input_as_handled()
			return
	# ── Ctrl+; 唤起/关闭颜文字浮层 ──
	if event is InputEventKey and event.pressed and not event.echo \
	   and event.keycode == KEY_SEMICOLON and event.ctrl_pressed:
		if _kaomoji_active:
			_hide_kaomoji_panel()
		else:
			_show_kaomoji_panel()
		get_viewport().set_input_as_handled()
		return
	# ── 颜文字浮层激活时（非编辑态）拦截键盘选取 ──
	# 编辑态由 TextBlock._on_text_edit_gui_input 转发，不走这里
	if _kaomoji_active and event is InputEventKey and event.pressed and not event.echo:
		var editing_kk: bool = _current_selected_block is TextBlock and \
							   (_current_selected_block as TextBlock).is_editing()
		if not editing_kk:
			_on_request_kaomoji_key(event.keycode)
			get_viewport().set_input_as_handled()
			return
	# （多选/各浮层的 Esc 已并入上方统一优先级处理）
	# ── 全局 Ctrl+拖拽旋转：选中块后，在任意位置（含控件外）Ctrl+左键拖拽即可旋转 ──
	if _setting_ctrl_drag_rotate and _current_selected_block != null \
	   and is_instance_valid(_current_selected_block):
		var block: BaseBlock = _current_selected_block
		# 编辑态的文本块不让全局旋转（避免和文本编辑冲突）
		var editing: bool = block is TextBlock and (block as TextBlock).is_editing()
		if not editing:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed and event.ctrl_pressed:
					# 鼠标落在块上时不拦截——让块做 Ctrl 多选 toggle
					if _mouse_on_any_block():
						return
					_global_rotating = true
					block.start_global_rotate(get_global_mouse_position())
					get_viewport().set_input_as_handled()
					return
				elif not event.pressed and _global_rotating:
					block.stop_rotate()
					_global_rotating = false
					get_viewport().set_input_as_handled()
					return
			elif event is InputEventMouseMotion and _global_rotating:
				# 直接复用 BaseBlock 的旋转逻辑
				block._do_rotate_drag(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
	
	# ── 中键拖拽平移页面 ──
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_middle_dragging = true
			_middle_drag_last = get_global_mouse_position()
			get_viewport().set_input_as_handled()
			return
		elif _middle_dragging:
			_middle_dragging = false
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion and _middle_dragging:
		var cur: Vector2 = get_global_mouse_position()
		var delta: Vector2 = cur - _middle_drag_last
		paper.position += delta
		_middle_drag_last = cur
		get_viewport().set_input_as_handled()
		return
	
	# 键盘快捷键 —— 编辑文本块时禁用全局快捷键，避免冲突
	# （否则编辑时按 Delete 删字符会同时删整个块，按 +/- 会改字号）
	var block_editing := _current_selected_block is TextBlock and \
						 (_current_selected_block as TextBlock).is_editing()
	
	if event is InputEventKey and event.pressed and not event.echo and not block_editing:
		match event.keycode:
			KEY_DELETE:
				_delete_selected_block()
			KEY_D:
				if event.ctrl_pressed:
					_duplicate_selected()
			KEY_G:
				if event.ctrl_pressed and event.shift_pressed:
					_select_group()
				elif event.ctrl_pressed:
					_group_selected()
			KEY_TAB:
				# 选中（预览态）文本块时按 Tab 进入编辑；编辑态 Tab 由 TextEdit 拦截唤起插入浮层
				if _current_selected_block is TextBlock:
					(_current_selected_block as TextBlock).enter_edit_mode()
			KEY_EQUAL, KEY_KP_ADD:
				if event.ctrl_pressed:
					_selected_text_block_font(2)
				else:
					_adjust_selected_z_index(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				if event.ctrl_pressed:
					_selected_text_block_font(-2)
				else:
					_adjust_selected_z_index(-1)
			KEY_BRACKETRIGHT:
				if event.ctrl_pressed:
					_rotate_selected_block(15.0)
				else:
					_adjust_selected_opacity(0.1)
			KEY_BRACKETLEFT:
				if event.ctrl_pressed:
					_rotate_selected_block(-15.0)
				else:
					_adjust_selected_opacity(-0.1)
	
	# ── 编辑态专属快捷键 ──
	# 注意：Tab/数字键/Esc 的插入面板逻辑已移至 TextBlock._on_text_edit_gui_input
	# （在 TextEdit 的 gui_input 阶段拦截，避免被 TextEdit 消费）
	if event is InputEventKey and event.pressed and not event.echo and block_editing:
		# Ctrl+Enter：光标跳到文本末尾
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			(_current_selected_block as TextBlock).move_caret_to_end()
			get_viewport().set_input_as_handled()
			return
	
	# ── 缩放/滚动处理 ──
	# Paper 在 PaperScroll (Control, clip_contents=true) 内，
	# paper.position 和 paper.scale 全由我们手动控制，不受 Container 干扰。
	
	if event is InputEventMouseButton and event.ctrl_pressed:
		# Ctrl+滚轮：以鼠标位置为中心缩放（PS 式：鼠标下的内容点不动）
		var step := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = -ZOOM_STEP
		else:
			return
		
		var old_zoom := _zoom
		_zoom = clampf(_zoom + step, ZOOM_MIN, ZOOM_MAX)
		if _zoom == old_zoom:
			return  # 已到极限，无需调整
		
		# 锚点 = 鼠标在 PaperScroll 内的局部坐标
		var anchor: Vector2 = paper_scroll.get_local_mouse_position()
		# 锚点对应的 Paper 局部坐标（缩放前）
		var local: Vector2 = (anchor - paper.position) / old_zoom
		
		paper.scale = Vector2(_zoom, _zoom)
		# 新位置 = 锚点 - 局部坐标 × 新缩放（保持锚点下的内容点不动）
		paper.position = anchor - local * _zoom
		
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		# 普通滚轮：直接改 paper.position（实现"滚动"）
		var scroll_delta := Vector2.ZERO
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_delta.y = 80.0   # 向上滚 → Paper 下移 → 看上面内容
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_delta.y = -80.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			scroll_delta.x = 80.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			scroll_delta.x = -80.0
		else:
			return
		
		# 限制不滚出纸张范围（横向纵向独立判断）
		var paper_visual: Vector2 = paper.size * _zoom
		var clip_size: Vector2 = paper_scroll.size
		
		# 纵向
		if paper_visual.y > clip_size.y:
			var min_y: float = -(paper_visual.y - clip_size.y)
			var max_y: float = 0.0
			paper.position.y = clampf(paper.position.y + scroll_delta.y, min_y, max_y)
		# 横向
		if paper_visual.x > clip_size.x:
			var min_x: float = -(paper_visual.x - clip_size.x)
			var max_x: float = 0.0
			paper.position.x = clampf(paper.position.x + scroll_delta.x, min_x, max_x)
		get_viewport().set_input_as_handled()

func _setup_drop():
	get_window().files_dropped.connect(_on_files_dropped)

func _load_or_new_page():
	# 尝试加载最近的笔记；失败则建新页
	var loaded: bool = _try_load_latest_note()
	if not loaded:
		_new_page()
		_apply_paper_style_from_data()

## 扫描 NOTE_DIR 找修改时间最新的 .json，加载之
func _try_load_latest_note() -> bool:
	var abs_note_dir: String = ProjectSettings.globalize_path(NOTE_DIR)
	if not DirAccess.dir_exists_absolute(abs_note_dir):
		return false
	
	var dir := DirAccess.open(abs_note_dir)
	if dir == null:
		return false
	
	var latest_path: String = ""
	var latest_mtime: int = -1
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json") or fname.ends_with(".res") or fname.ends_with(".tres"):
			var full_path: String = abs_note_dir + "/" + fname
			var mtime: int = FileAccess.get_modified_time(full_path)
			if mtime > latest_mtime:
				latest_mtime = mtime
				latest_path = NOTE_DIR + fname
		fname = dir.get_next()
	dir.list_dir_end()
	
	if latest_path.is_empty():
		return false
	
	print("尝试加载最近笔记: ", latest_path)
	var page_data: PageData = ResourceLoader.load(latest_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if page_data == null or not (page_data is PageData):
		push_warning("笔记加载失败，可能是格式不兼容: " + latest_path)
		return false
	
	_current_page_data = page_data
	_apply_paper_style_from_data()
	# 恢复画布尺寸
	paper.custom_minimum_size = Vector2i(
		_current_page_data.paper_width,
		_current_page_data.paper_height
	)
	# 重建所有块
	for block_data in _current_page_data.blocks:
		_instantiate_block(block_data)
	print("笔记加载成功: %d 个块" % _current_page_data.blocks.size())
	return true

## 根据 block_data 实例化对应类型的块
func _instantiate_block(block_data: BlockData) -> void:
	var block: BaseBlock = null
	if block_data is TextBlockData:
		block = _text_block_scene.instantiate()
	elif block_data is ImageBlockData:
		block = _image_block_scene.instantiate()
	elif block_data is ShapeBlockData:
		block = _shape_block_scene.instantiate()
	elif block_data is DrawBlockData:
		block = _draw_block_scene.instantiate()
	elif block_data is EmojiStickerData:
		block = _emoji_sticker_scene.instantiate()
	else:
		push_warning("未知块类型，跳过")
		return
	paper.add_child(block)
	block.setup(block_data)
	_connect_block_signals(block)

## 从 _current_page_data 恢复纸张背景样式
func _apply_paper_style_from_data():
	var s := StyleBoxFlat.new()
	s.bg_color = _current_page_data.paper_bg_color
	s.shadow_size = 4
	s.shadow_color = Color(0, 0, 0, 0.08)
	paper.add_theme_stylebox_override("panel", s)
	# 同步背景色选择器
	bg_color_picker.color = _current_page_data.paper_bg_color
	# 应用纸张底纹（PaperDropTarget._draw 据此绘制）
	paper.apply_pattern(
		_current_page_data.paper_pattern,
		_current_page_data.paper_pattern_color,
		_current_page_data.paper_pattern_spacing
	)
	# 应用纸张底图
	paper.apply_bg_image(
		_current_page_data.paper_bg_image,
		_current_page_data.paper_bg_image_opacity,
		_current_page_data.paper_bg_image_offset,
		_current_page_data.paper_bg_image_scale
	)


## 切换纸张底纹（idx 为 PageData.PaperPattern 枚举值 0..4）
func _on_pattern_selected(idx: int) -> void:
	_current_page_data.paper_pattern = idx
	paper.apply_pattern(
		idx,
		_current_page_data.paper_pattern_color,
		_current_page_data.paper_pattern_spacing
	)
	_mark_dirty()


## 把底图状态字典应用到画布（实时预览）
func _apply_bg_image_from_state(st: Dictionary) -> void:
	var p: String = String(st["path"])
	var op: float = float(st["op"])
	var off: Vector2 = Vector2(float(st["ox"]), float(st["oy"]))
	var sc: float = float(st["sc"])
	_current_page_data.paper_bg_image = p
	_current_page_data.paper_bg_image_opacity = op
	_current_page_data.paper_bg_image_offset = off
	_current_page_data.paper_bg_image_scale = sc
	paper.apply_bg_image(p, op, off, sc)
	_mark_dirty()


## 纸张背景图设置对话框（选图 + 透明度/位置/缩放，实时预览）
func _prompt_bg_image_settings() -> void:
	var st: Dictionary = {
		"path": _current_page_data.paper_bg_image,
		"op": _current_page_data.paper_bg_image_opacity,
		"ox": _current_page_data.paper_bg_image_offset.x,
		"oy": _current_page_data.paper_bg_image_offset.y,
		"sc": _current_page_data.paper_bg_image_scale,
	}
	var dlg := AcceptDialog.new()
	dlg.title = "纸张背景图"
	dlg.ok_button_text = "完成"
	dlg.min_size = Vector2i(400, 300)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var pick_btn := Button.new()
	pick_btn.text = "📁 选择图片…" if String(st["path"]).is_empty() else ("📂 " + String(st["path"]).get_file())
	var clear_btn := Button.new()
	clear_btn.text = "🗑 清除背景图"
	var op_s := HSlider.new()
	op_s.min_value = 0.0
	op_s.max_value = 1.0
	op_s.step = 0.05
	op_s.value = float(st["op"])
	var ox_s := HSlider.new()
	ox_s.min_value = -800.0
	ox_s.max_value = 800.0
	ox_s.step = 5.0
	ox_s.value = float(st["ox"])
	var oy_s := HSlider.new()
	oy_s.min_value = -800.0
	oy_s.max_value = 800.0
	oy_s.step = 5.0
	oy_s.value = float(st["oy"])
	var sc_s := HSlider.new()
	sc_s.min_value = 0.1
	sc_s.max_value = 3.0
	sc_s.step = 0.05
	sc_s.value = float(st["sc"])

	op_s.value_changed.connect(func(v: float):
		st["op"] = v
		_apply_bg_image_from_state(st)
	)
	ox_s.value_changed.connect(func(v: float):
		st["ox"] = v
		_apply_bg_image_from_state(st)
	)
	oy_s.value_changed.connect(func(v: float):
		st["oy"] = v
		_apply_bg_image_from_state(st)
	)
	sc_s.value_changed.connect(func(v: float):
		st["sc"] = v
		_apply_bg_image_from_state(st)
	)
	pick_btn.pressed.connect(_pick_bg_image_file.bind(st, pick_btn))
	clear_btn.pressed.connect(func():
		st["path"] = ""
		pick_btn.text = "📁 选择图片…"
		_apply_bg_image_from_state(st)
	)

	vbox.add_child(pick_btn)
	vbox.add_child(clear_btn)
	vbox.add_child(_slider_row("透明度", op_s))
	vbox.add_child(_slider_row("位置 X", ox_s))
	vbox.add_child(_slider_row("位置 Y", oy_s))
	vbox.add_child(_slider_row("缩放", sc_s))
	margin.add_child(vbox)
	dlg.add_child(margin)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


## 弹出文件选择器挑背景图，选中后复制到 user:// 并实时预览
func _pick_bg_image_file(st: Dictionary, pick_btn: Button) -> void:
	var fd := FileDialog.new()
	fd.title = "选择背景图"
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.add_filter("*.png", "PNG")
	fd.add_filter("*.jpg", "JPG")
	fd.add_filter("*.jpeg", "JPEG")
	fd.add_filter("*.webp", "WebP")
	add_child(fd)
	fd.file_selected.connect(func(p: String):
		var dest_path: String = _copy_bg_image_to_user(p)
		st["path"] = dest_path
		pick_btn.text = "📂 " + dest_path.get_file()
		_apply_bg_image_from_state(st)
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered(Vector2i(600, 400))


## 滑块行：Label + HSlider
func _slider_row(label_text: String, slider: HSlider) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2i(56, 0)
	row.add_child(l)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2i(220, 20)
	row.add_child(slider)
	return row


## 复制底图到 user://data/images/，返回 user:// 相对路径
func _copy_bg_image_to_user(src: String) -> String:
	var abs_dir: String = ProjectSettings.globalize_path(IMAGE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var src_abs: String = ProjectSettings.globalize_path(src)
	var dest_abs: String = abs_dir + src.get_file()
	if not FileAccess.file_exists(dest_abs):
		DirAccess.copy_absolute(src_abs, dest_abs)
	return IMAGE_DIR + src.get_file()


# ═══════════════════════════════════════════
#  新建笔记（下拉勾选要保留的纸张样式）
# ═══════════════════════════════════════════

const NEW_ID_KEEP_SIZE: int = 1
const NEW_ID_KEEP_PATTERN: int = 2
const NEW_ID_KEEP_BG_IMAGE: int = 3
const NEW_ID_KEEP_BG_COLOR: int = 4
const NEW_ID_CREATE: int = 100

func _setup_new_menu() -> void:
	var popup: PopupMenu = new_btn.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	popup.add_check_item("保留纸张大小", NEW_ID_KEEP_SIZE)
	popup.add_check_item("保留纸张底纹", NEW_ID_KEEP_PATTERN)
	popup.add_check_item("保留纸张底图", NEW_ID_KEEP_BG_IMAGE)
	popup.add_check_item("保留纸张底色", NEW_ID_KEEP_BG_COLOR)
	popup.add_separator()
	popup.add_item("✨ 新建（按以上勾选保留）", NEW_ID_CREATE)
	_sync_new_menu_checks(popup)
	if not popup.id_pressed.is_connected(_on_new_menu):
		popup.id_pressed.connect(_on_new_menu)

func _sync_new_menu_checks(popup: PopupMenu) -> void:
	popup.set_item_checked(popup.get_item_index(NEW_ID_KEEP_SIZE), _new_keep_size)
	popup.set_item_checked(popup.get_item_index(NEW_ID_KEEP_PATTERN), _new_keep_pattern)
	popup.set_item_checked(popup.get_item_index(NEW_ID_KEEP_BG_IMAGE), _new_keep_bg_image)
	popup.set_item_checked(popup.get_item_index(NEW_ID_KEEP_BG_COLOR), _new_keep_bg_color)

func _on_new_menu(id: int) -> void:
	var popup: PopupMenu = new_btn.get_popup()
	match id:
		NEW_ID_KEEP_SIZE:
			_new_keep_size = not _new_keep_size
			popup.set_item_checked(popup.get_item_index(id), _new_keep_size)
		NEW_ID_KEEP_PATTERN:
			_new_keep_pattern = not _new_keep_pattern
			popup.set_item_checked(popup.get_item_index(id), _new_keep_pattern)
		NEW_ID_KEEP_BG_IMAGE:
			_new_keep_bg_image = not _new_keep_bg_image
			popup.set_item_checked(popup.get_item_index(id), _new_keep_bg_image)
		NEW_ID_KEEP_BG_COLOR:
			_new_keep_bg_color = not _new_keep_bg_color
			popup.set_item_checked(popup.get_item_index(id), _new_keep_bg_color)
		NEW_ID_CREATE:
			_do_new_page()

## 新建一页：先把当前页存盘，清空所有块，按勾选继承纸张样式
func _do_new_page() -> void:
	_push_undo()
	# 1) 先把当前页立即存盘（避免切页后丢失未保存改动）
	_autosave()
	# 2) 记录旧纸张样式（PageData 是 Resource，块节点释放不影响它）
	var old: PageData = _current_page_data
	# 3) 清空选中态与所有块（无动画快速清）
	_deselect_all()
	for child in paper.get_children():
		if child is BaseBlock:
			child.queue_free()
	# 4) 新建页面数据，按勾选继承旧纸张样式
	_current_page_data = PageData.new()
	_current_page_data.note_title = _generate_title()
	if old != null:
		if _new_keep_size:
			_current_page_data.paper_width = old.paper_width
			_current_page_data.paper_height = old.paper_height
		if _new_keep_pattern:
			_current_page_data.paper_pattern = old.paper_pattern
			_current_page_data.paper_pattern_color = old.paper_pattern_color
			_current_page_data.paper_pattern_spacing = old.paper_pattern_spacing
		if _new_keep_bg_image:
			_current_page_data.paper_bg_image = old.paper_bg_image
			_current_page_data.paper_bg_image_opacity = old.paper_bg_image_opacity
			_current_page_data.paper_bg_image_offset = old.paper_bg_image_offset
			_current_page_data.paper_bg_image_scale = old.paper_bg_image_scale
		if _new_keep_bg_color:
			_current_page_data.paper_bg_color = old.paper_bg_color
	# 5) 应用纸张尺寸 + 全部样式 + 重置视图到原点
	paper.custom_minimum_size = Vector2i(_current_page_data.paper_width, _current_page_data.paper_height)
	paper.position = Vector2.ZERO
	_zoom = 1.0
	paper.scale = Vector2.ONE
	_apply_paper_style_from_data()
	_mark_dirty()

func _new_page():
	_current_page_data = PageData.new()
	_current_page_data.note_title = _generate_title()
	# 默认画布尺寸与 PageData 默认值一致
	paper.custom_minimum_size = Vector2i(
		_current_page_data.paper_width,
		_current_page_data.paper_height
	)

func _generate_title() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "笔记_%04d%02d%02d_%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func _mark_dirty():
	_autosave_timer.start(2.0)


## 存当前页面深拷贝快照到撤销栈（操作前调用），并清空重做栈
func _push_undo() -> void:
	if _suspend_undo:
		return
	_sync_block_data()
	var snap: PageData = _current_page_data.duplicate(true)
	_undo_stack.append(snap)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _undo() -> void:
	if _undo_stack.is_empty():
		return
	_sync_block_data()
	_redo_stack.append(_current_page_data.duplicate(true))
	_apply_page_snapshot(_undo_stack.pop_back() as PageData)


func _redo() -> void:
	if _redo_stack.is_empty():
		return
	_sync_block_data()
	_undo_stack.append(_current_page_data.duplicate(true))
	_apply_page_snapshot(_redo_stack.pop_back() as PageData)


## 把快照恢复到场景：清块重建（无动画）+ 重应用纸张样式
func _apply_page_snapshot(snap: PageData) -> void:
	_suspend_undo = true
	_deselect_all()
	for child in paper.get_children():
		if child is BaseBlock:
			child.queue_free()
	# 快照里的块数据先取出，清空 blocks 后逐个 spawn（spawn 会重新 append）
	var saved_blocks: Array = snap.blocks.duplicate()
	_current_page_data = snap
	_current_page_data.blocks.clear()
	for bd in saved_blocks:
		_spawn_block(bd as BlockData, false)
	paper.custom_minimum_size = Vector2i(snap.paper_width, snap.paper_height)
	_apply_paper_style_from_data()
	_suspend_undo = false
	_mark_dirty()

# ═══════════════════════════════════════════
#  画布尺寸
# ═══════════════════════════════════════════

func _on_canvas_preset_selected(id: int):
	# 背景图设置（id 200）
	if id == 200:
		_prompt_bg_image_settings()
		return
	# 底纹选项（id 100+，见 _setup_canvas_menu）
	if id >= 100:
		_on_pattern_selected(id - 100)
		return
	if id < len(CANVAS_PRESETS):
		var p: Array = CANVAS_PRESETS[id]
		_set_canvas_size(p[1], p[2])
	else:
		# 自定义：弹出对话框输入宽高
		_prompt_custom_canvas_size()

## 自定义画布尺寸对话框
## 用 ConfirmationDialog（有确认/取消两按钮），内容用 MarginContainer 包裹确保布局
func _prompt_custom_canvas_size() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "自定义画布尺寸"
	dialog.min_size = Vector2i(320, 140)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var row1 := HBoxContainer.new()
	var label1 := Label.new()
	label1.text = "宽度:"
	label1.custom_minimum_size = Vector2i(50, 0)
	var w_spin := SpinBox.new()
	w_spin.min_value = 100
	w_spin.max_value = 5000
	w_spin.value = float(_current_page_data.paper_width)
	w_spin.suffix = " px"
	row1.add_child(label1)
	row1.add_child(w_spin)
	
	var row2 := HBoxContainer.new()
	var label2 := Label.new()
	label2.text = "高度:"
	label2.custom_minimum_size = Vector2i(50, 0)
	var h_spin := SpinBox.new()
	h_spin.min_value = 100
	h_spin.max_value = 5000
	h_spin.value = float(_current_page_data.paper_height)
	h_spin.suffix = " px"
	row2.add_child(label2)
	row2.add_child(h_spin)
	
	vbox.add_child(row1)
	vbox.add_child(row2)
	margin.add_child(vbox)
	dialog.add_child(margin)
	
	# confirmed = 点"确认"按钮
	dialog.confirmed.connect(func():
		var w: int = int(w_spin.value)
		var h: int = int(h_spin.value)
		print("自定义画布尺寸: %d x %d" % [w, h])
		_set_canvas_size(w, h)
		dialog.queue_free()
	)
	# canceled = 点"取消"或关窗
	dialog.canceled.connect(func(): dialog.queue_free())
	
	add_child(dialog)
	dialog.popup_centered()

func _set_canvas_size(w: int, h: int):
	_current_page_data.paper_width = w
	_current_page_data.paper_height = h
	paper.custom_minimum_size = Vector2i(w, h)
	_mark_dirty()

# ═══════════════════════════════════════════
#  贴纸文件夹
# ═══════════════════════════════════════════

func _on_open_sticker_dir():
	var dir_path: String = ProjectSettings.globalize_path(STICKER_DIR)
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	OS.shell_open(dir_path)

# ═══════════════════════════════════════════
#  添加块
# ═══════════════════════════════════════════

func _on_add_text():
	var data := TextBlockData.new()
	data.position = _get_spawn_position()
	# 应用默认设置
	data.font_size = _setting_default_font_size
	data.font_id = _setting_default_font_id
	data.bg_color = _setting_default_block_bg
	data.font_color = _setting_default_font_color
	data.opacity = _setting_default_opacity
	# 对齐用 BBCode 标签包裹默认内容
	match _setting_default_alignment:
		0: data.bbcode_content = "新文本"
		1: data.bbcode_content = "[center]新文本[/center]"
		2: data.bbcode_content = "[right]新文本[/right]"
	data.text_alignment = _setting_default_alignment
	
	var block: TextBlock = _spawn_block(data) as TextBlock
	_mark_dirty()

	_deselect_all()
	# 通过 emit 信号走 main 的选中逻辑，确保 _current_selected_block 被正确赋值
	# （直接调 block.select() 不会触发 _on_block_selected，导致 _current_selected_block 为 null）
	block.block_selected.emit(block)
	_update_font_ui()
	# 新建后保持预览态（可拖拽定位），双击进入编辑

func _on_add_image():
	var dialog := FileDialog.new()
	dialog.title = "选择图片"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "支持的图片")
	dialog.add_filter("*.png", "PNG")
	dialog.add_filter("*.jpg, *.jpeg", "JPEG")
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(_on_image_selected)
	add_child(dialog)
	dialog.popup_centered()

func _on_image_selected(path: String):
	var data := ImageBlockData.new()
	data.position = _get_spawn_position()
	
	_copy_image_to_user(path, data)
	
	var block: ImageBlock = _spawn_block(data) as ImageBlock
	_mark_dirty()

	_deselect_all()
	block.select()

func _on_files_dropped(files: PackedStringArray):
	for file_path in files:
		var ext = file_path.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp", "gif"]:
			var data := ImageBlockData.new()
			data.position = _get_spawn_position()
			_copy_image_to_user(file_path, data)
			
			var block: ImageBlock = _image_block_scene.instantiate()
			paper.add_child(block)
			block.setup(data)
			_connect_block_signals(block)
			_current_page_data.blocks.append(data)
			_mark_dirty()

func _copy_image_to_user(src_path: String, data: ImageBlockData):
	var dir_path: String = IMAGE_DIR
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var ts: float = Time.get_unix_time_from_system()
	var ext: String = src_path.get_extension()
	var file_name: String = "img_%s_%s.%s" % [
		ts,
		src_path.get_file().get_basename().md5_text().left(8),
		ext
	]
	# copy_absolute 需要 OS 绝对路径；data 存 user:// 路径以便跨平台加载
	var dest_abs: String = abs_dir + file_name
	DirAccess.copy_absolute(src_path, dest_abs)
	data.image_path = dir_path + file_name

func _get_spawn_position() -> Vector2:
	# 基于纸上现有块数量计算生成位置，删除后位置可复用
	var count := 0
	for child in paper.get_children():
		if child is BaseBlock:
			count += 1
	return Vector2(
		60 + (count % 5) * 80,
		60 + (count % 4) * 80
	)

func _connect_block_signals(block: BaseBlock):
	block.block_selected.connect(_on_block_selected)
	block.block_moved.connect(_on_block_moved)
	block.block_resized.connect(_on_block_changed)
	block.request_context_menu.connect(_on_block_context_menu)
	block.interaction_started.connect(_push_undo)
	if block is TextBlock:
		(block as TextBlock).content_changed.connect(_on_block_content_changed)
		(block as TextBlock).char_typed.connect(_on_char_typed)
		(block as TextBlock).request_insert_panel.connect(_on_request_insert_panel)
		(block as TextBlock).request_insert_hotkey.connect(_on_request_insert_hotkey)
		(block as TextBlock).request_kaomoji_key.connect(_on_request_kaomoji_key)

func _random_pastel() -> Color:
	var hues: Array[float] = [0.05, 0.12, 0.55, 0.60, 0.80, 0.95]
	var h: float = hues[randi() % hues.size()]
	return Color.from_hsv(h, 0.2, 0.97)

# ═══════════════════════════════════════════
#  块选择 & 交互
# ═══════════════════════════════════════════

## 鼠标是否落在任何块上（用于区分 Ctrl 多选 toggle vs 控件外 Ctrl 旋转）
func _mouse_on_any_block() -> bool:
	var mp: Vector2 = get_global_mouse_position()
	for child in paper.get_children():
		if child is BaseBlock:
			if (child as BaseBlock).get_global_rect().has_point(mp):
				return true
	return false


func _on_block_selected(block: BaseBlock):
	# Alt + 点击 = 复制该块（偏移 20,20）并选中新块
	if Input.is_key_pressed(KEY_ALT):
		_duplicate_block_into_selection(block)
		return
	# Ctrl + 点击 = Windows 式多选 toggle（加入 / 剔除）
	if Input.is_key_pressed(KEY_CTRL):
		if _selected_blocks.has(block):
			_selected_blocks.erase(block)
			block.deselect()
			if _selected_blocks.is_empty():
				_current_selected_block = null
				_hide_inspector()
			else:
				_current_selected_block = _selected_blocks[0]
				_refresh_inspector()
		else:
			_selected_blocks.append(block)
			block.select()
			_current_selected_block = block
			_show_inspector()
		_update_font_ui()
		return
	# 多选态下拖拽其中一块：不清空集合，记录起点供批量同步
	if _selected_blocks.size() > 1 and _selected_blocks.has(block):
		_drag_last_pos = block.position
		_current_selected_block = block
		_refresh_inspector()
		return
	_deselect_all()
	_current_selected_block = block
	_selected_blocks = [block]
	block.select()
	_update_font_ui()
	_show_inspector()


## Alt+点击复制单个块：原地偏移 20,20，选中新块
func _duplicate_block_into_selection(src: BaseBlock) -> void:
	if not is_instance_valid(src):
		return
	_push_undo()
	var nd: BlockData = (src.collect_data() as BlockData).duplicate(true)
	nd.position += Vector2(20.0, 20.0)
	var nb: BaseBlock = _spawn_block(nd)
	if nb == null:
		return
	_deselect_all()
	_current_selected_block = nb
	_selected_blocks = [nb]
	nb.select()
	_show_inspector()
	_update_font_ui()
	_mark_dirty()

func _deselect_all():
	# 取消选中时顺手收起插入/颜文字/属性浮层
	if _insert_popup != null and _insert_popup.visible:
		_hide_insert_panel()
	if _kaomoji_popup != null and _kaomoji_popup.visible:
		_hide_kaomoji_panel()
	_hide_inspector()
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.deselect()
	_selected_blocks.clear()
	_current_selected_block = null
	_update_font_ui()

func _on_paper_clicked(event: InputEvent):
	# 双击空白：在该位置新建文本块（block 双击已被自身拦截，这里只处理空白）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
	   and event.pressed and event.double_click and not event.ctrl_pressed:
		_create_text_at(paper.get_local_mouse_position())
		return
	# 左键按下（非 Ctrl、非双击）：开始框选
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.double_click and not event.ctrl_pressed:
			_box_start = paper.get_local_mouse_position()
			_box_selecting = true
		elif not event.pressed and _box_selecting:
			_box_selecting = false
			_finish_box_select()
		return
	# 拖拽中实时更新选择框
	if event is InputEventMouseMotion and _box_selecting:
		_update_selection_box()


## 在指定 paper 坐标新建文本块（双击空白处用，自动进入编辑）
func _create_text_at(paper_pos: Vector2) -> void:
	_push_undo()
	var data := TextBlockData.new()
	data.position = paper_pos
	data.font_size = _setting_default_font_size
	data.font_id = _setting_default_font_id
	data.bg_color = _setting_default_block_bg
	data.font_color = _setting_default_font_color
	data.opacity = _setting_default_opacity
	data.text_alignment = _setting_default_alignment
	data.size = Vector2(240, 90)
	var block: TextBlock = _spawn_block(data) as TextBlock
	_mark_dirty()
	_deselect_all()
	block.block_selected.emit(block)
	_update_font_ui()
	# 双击进入编辑


## 创建框选可视化矩形（paper 子节点，置底）
func _setup_selection_box() -> void:
	_selection_box = ColorRect.new()
	_selection_box.color = Color(0.3, 0.6, 1.0, 0.15)
	_selection_box.z_index = -10
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	paper.add_child(_selection_box)


## 拖拽中更新选择框位置/尺寸
func _update_selection_box() -> void:
	var cur: Vector2 = paper.get_local_mouse_position()
	var rect: Rect2 = Rect2(
		Vector2(minf(_box_start.x, cur.x), minf(_box_start.y, cur.y)),
		Vector2(absf(cur.x - _box_start.x), absf(cur.y - _box_start.y)))
	_selection_box.position = rect.position
	_selection_box.size = rect.size
	# 拖拽距离过小（与 _finish_box_select 的单击阈值一致）时不显示蓝框，
	# 避免单击空白时蓝框一闪而过
	_selection_box.visible = rect.size.x >= 5.0 or rect.size.y >= 5.0


## 释放：选中与框选矩形相交的块（paper 局部 AABB，忽略旋转）
func _finish_box_select() -> void:
	_selection_box.visible = false
	var cur: Vector2 = paper.get_local_mouse_position()
	var box_rect: Rect2 = Rect2(
		Vector2(minf(_box_start.x, cur.x), minf(_box_start.y, cur.y)),
		Vector2(absf(cur.x - _box_start.x), absf(cur.y - _box_start.y)))
	# 矩形过小视为单击 → 取消选中
	if box_rect.size.x < 5.0 and box_rect.size.y < 5.0:
		_deselect_all()
		return
	_deselect_all()
	for child in paper.get_children():
		if child is BaseBlock:
			var b: BaseBlock = child as BaseBlock
			var block_rect: Rect2 = Rect2(b.position, b.size)
			if box_rect.intersects(block_rect, true):
				_selected_blocks.append(b)
				b.select()
	if not _selected_blocks.is_empty():
		_current_selected_block = _selected_blocks[0]
		_show_inspector()
	_update_font_ui()
## 贴纸面板分割条拖拽
var _splitter_dragging: bool = false
func _on_splitter_drag(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_splitter_dragging = true
		else:
			_splitter_dragging = false
		return
	
	if event is InputEventMouseMotion and _splitter_dragging:
		var new_w = sticker_panel.size.x - event.relative.x
		new_w = clampi(new_w, 20, 800)
		sticker_panel.custom_minimum_size.x = new_w

func _on_block_moved(block: BaseBlock):
	_mark_dirty()
	# 多选批量移动：拖拽块带动其他选中块同步位移
	if _selected_blocks.size() > 1 and _selected_blocks.has(block):
		var delta: Vector2 = block.position - _drag_last_pos
		if delta != Vector2.ZERO:
			for b in _selected_blocks:
				if b != block and is_instance_valid(b):
					b.position += delta
					b.data.position = b.position
		_drag_last_pos = block.position

func _on_block_changed(_block: BaseBlock):
	_mark_dirty()

func _on_block_content_changed(_data: TextBlockData):
	_mark_dirty()


## 打字迸星：在光标画布位置生成一颗小星
func _on_char_typed(canvas_pos: Vector2) -> void:
	if _fx_layer != null and is_instance_valid(_fx_layer):
		_fx_layer.spawn_at_canvas(canvas_pos)

func _delete_selected_block():
	if _selected_blocks.is_empty():
		return
	_push_undo()
	var to_del: Array[BaseBlock] = _selected_blocks.duplicate()
	_deselect_all()  # 清选中态 + 收起 inspector
	for b in to_del:
		if is_instance_valid(b):
			var data: BlockData = b.collect_data()
			_current_page_data.blocks.erase(data)
			b._play_delete_anim()  # Q 弹消失，动画结束自动 queue_free
	_mark_dirty()


## 右键上下文菜单的项 ID
const CTX_COPY: int = 1
const CTX_DELETE: int = 2
const CTX_FRONT: int = 3
const CTX_BACK: int = 4
const CTX_ROTATE_L: int = 5
const CTX_ROTATE_R: int = 6
const CTX_COPY_STYLE: int = 7
const CTX_PASTE_STYLE: int = 8
const CTX_GROUP: int = 9       ## 编组
const CTX_UNGROUP: int = 10    ## 解散组
const CTX_SELECT_GROUP: int = 11 ## 选全组

## 块右键 → 弹出上下文菜单（复制/置顶置底/旋转/删除）
func _on_block_context_menu(block: BaseBlock) -> void:
	if not _selected_blocks.has(block):
		block.block_selected.emit(block)
	var menu := PopupMenu.new()
	menu.add_item("复制  Ctrl+D", CTX_COPY)
	menu.add_item("📋 复制样式", CTX_COPY_STYLE)
	menu.add_item("📥 粘贴样式", CTX_PASTE_STYLE)
	menu.add_item("置顶", CTX_FRONT)
	menu.add_item("置底", CTX_BACK)
	menu.add_separator()
	menu.add_item("↺ 左旋 90°", CTX_ROTATE_L)
	menu.add_item("↻ 右旋 90°", CTX_ROTATE_R)
	menu.add_separator()
	if _selected_blocks.size() >= 2:
		menu.add_item("🔗 编组  Ctrl+G", CTX_GROUP)
	if _current_selected_block != null and is_instance_valid(_current_selected_block) and not _current_selected_block.data.group_id.is_empty():
		menu.add_item("🎯 选全组  Ctrl+Shift+G", CTX_SELECT_GROUP)
		menu.add_item("✂️ 解散组", CTX_UNGROUP)
	menu.add_separator()
	menu.add_item("删除  Del", CTX_DELETE)
	menu.id_pressed.connect(_on_context_action)
	menu.close_requested.connect(menu.queue_free)
	add_child(menu)
	var gp: Vector2 = get_global_mouse_position()
	menu.position = Vector2i(int(gp.x), int(gp.y))
	menu.popup()


## 上下文菜单动作分发
func _on_context_action(id: int) -> void:
	match id:
		CTX_COPY:
			_duplicate_selected()
		CTX_DELETE:
			_delete_selected_block()
		CTX_FRONT:
			_bring_to_front()
		CTX_BACK:
			_send_to_back()
		CTX_ROTATE_L:
			_rotate_selected_block(-90.0)
		CTX_ROTATE_R:
			_rotate_selected_block(90.0)
		CTX_COPY_STYLE:
			_copy_style()
		CTX_PASTE_STYLE:
			_paste_style()
		CTX_GROUP:
			_group_selected()
		CTX_UNGROUP:
			_ungroup_selected()
		CTX_SELECT_GROUP:
			_select_group()


## 编组：把当前选中的多个块归入一个新组（同 group_id），并刷新组色边框
func _group_selected() -> void:
	if _selected_blocks.size() < 2:
		return
	_push_undo()
	var gid: String = "grp_" + str(randi())
	for b in _selected_blocks:
		if is_instance_valid(b):
			(b as BaseBlock).data.group_id = gid
	_refresh_selection_colors()
	_mark_dirty()


## 解散组：清空选中块的 group_id
func _ungroup_selected() -> void:
	if _selected_blocks.is_empty():
		return
	_push_undo()
	for b in _selected_blocks:
		if is_instance_valid(b):
			(b as BaseBlock).data.group_id = ""
	_refresh_selection_colors()
	_mark_dirty()


## 选全组：选中当前块所在组的所有块
func _select_group() -> void:
	if _current_selected_block == null or not is_instance_valid(_current_selected_block):
		return
	var gid: String = _current_selected_block.data.group_id
	if gid.is_empty():
		return
	_deselect_all()
	for child in paper.get_children():
		if child is BaseBlock and is_instance_valid(child):
			var cb: BaseBlock = child as BaseBlock
			if cb.data.group_id == gid:
				_selected_blocks.append(cb)
				cb.select()
	if not _selected_blocks.is_empty():
		_current_selected_block = _selected_blocks[0]
		_show_inspector()
		_update_font_ui()


## 刷新当前选中块的边框颜色（编组/解散后调，让组色立即生效）
func _refresh_selection_colors() -> void:
	for b in _selected_blocks:
		if is_instance_valid(b) and (b as BaseBlock)._is_selected:
			(b as BaseBlock).select()


## 复制选中块的样式（仅文本块；存样式字段，不含内容/位置/尺寸）
func _copy_style() -> void:
	if not (_current_selected_block is TextBlock):
		return
	var d: TextBlockData = (_current_selected_block as TextBlock).data as TextBlockData
	_style_clipboard = {
		"font_size": d.font_size,
		"font_color": d.font_color,
		"font_id": d.font_id,
		"outline_size": d.outline_size,
		"outline_color": d.outline_color,
		"bg_color": d.bg_color,
		"border_color": d.border_color,
		"border_width": d.border_width,
		"corner_radius": d.corner_radius,
		"box_glow_size": d.box_glow_size,
		"box_glow_color": d.box_glow_color,
		"line_spacing": d.line_spacing,
		"text_alignment": d.text_alignment,
		"use_markdown": d.use_markdown,
	}


## 粘贴样式到所有选中的文本块（跳过非文本块；剪贴板空则忽略）
func _paste_style() -> void:
	if _style_clipboard.is_empty():
		return
	_push_undo()
	var applied: bool = false
	for b in _selected_blocks:
		if b is TextBlock:
			var d: TextBlockData = (b as TextBlock).data as TextBlockData
			for k in _style_clipboard:
				d.set(k, _style_clipboard[k])
			(b as TextBlock)._apply_font_theme()
			(b as TextBlock)._update_style()
			(b as TextBlock)._update_preview()
			applied = true
	if applied:
		_update_font_ui()
		_mark_dirty()


## 复制所有选中块（偏移 30,30 放置，并选中新块）
func _duplicate_selected() -> void:
	if _selected_blocks.is_empty():
		return
	_push_undo()
	var to_dup: Array[BaseBlock] = _selected_blocks.duplicate()
	_deselect_all()
	for b in to_dup:
		if not is_instance_valid(b):
			continue
		var nd: BlockData = (b.collect_data() as BlockData).duplicate(true)
		nd.position += Vector2(30.0, 30.0)
		var nb: BaseBlock = _spawn_block(nd)
		if nb != null:
			nb.select()
			_selected_blocks.append(nb)
	if not _selected_blocks.is_empty():
		_current_selected_block = _selected_blocks[0]
		_show_inspector()
	_mark_dirty()


## 置顶选中块（z 轴设为 100）
func _bring_to_front() -> void:
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.data.z_index = 100
			b.z_index = 100
	_refresh_inspector()
	_mark_dirty()


## 置底选中块（z 轴设为 -100）
func _send_to_back() -> void:
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.data.z_index = -100
			b.z_index = -100
	_refresh_inspector()
	_mark_dirty()


## Ctrl+[ / ] 旋转选中块
func _rotate_selected_block(degrees: float):
	if not _current_selected_block or not is_instance_valid(_current_selected_block):
		return
	var data: BlockData = _current_selected_block.collect_data()
	data.rotation_degrees = fmod(data.rotation_degrees + degrees, 360.0)
	if data.rotation_degrees < 0:
		data.rotation_degrees += 360.0
	_current_selected_block.rotation = deg_to_rad(data.rotation_degrees)
	_mark_dirty()

## 旋转归零
func _on_rotate_reset():
	if not _current_selected_block or not is_instance_valid(_current_selected_block):
		return
	var data: BlockData = _current_selected_block.collect_data()
	data.rotation_degrees = 0.0
	_current_selected_block.rotation = 0.0
	_mark_dirty()

# ═══════════════════════════════════════════
#  字号 / 字体颜色 UI
# ═══════════════════════════════════════════

func _update_font_ui():
	var show: bool = _current_selected_block is TextBlock
	font_size_label.visible = show
	font_color_btn.visible = show
	font_option_btn.visible = show
	outline_label.visible = show
	outline_spin.visible = show
	outline_color_btn.visible = show
	block_bg_label.visible = show
	block_bg_color_btn.visible = show
	text_more_btn.visible = show
	insert_btn.visible = show
	# 样式组前导分隔符：仅在选中文本块时显示（避免未选中时堆叠竖线）
	sep_style.visible = show
	# emoji_btn 常驻工具栏（不随文本块选中状态变化）

	if show:
		var tb: TextBlock = _current_selected_block as TextBlock
		font_size_label.text = "字号: %d" % tb.data.font_size
		font_color_btn.color = tb.data.font_color
		outline_spin.value = tb.data.outline_size
		outline_color_btn.color = tb.data.outline_color
		block_bg_color_btn.color = tb.data.bg_color
		# 字体下拉同步当前值
		_sync_font_option(tb.data.font_id)
	
	# 旋转按钮对两种块都显示
	var has_block: bool = _current_selected_block != null and is_instance_valid(_current_selected_block)
	rotate_label.visible = has_block
	rotate_left_btn.visible = has_block
	rotate_right_btn.visible = has_block
	rotate_reset_btn.visible = has_block
	# 旋转组前导分隔符：仅在有选中块时显示
	sep_rotate.visible = has_block

## 同步字体下拉框选中项到当前 font_id
func _sync_font_option(font_id: String) -> void:
	for i in FONT_PRESETS.size():
		var p: Array = FONT_PRESETS[i] as Array
		if p[1] == font_id:
			font_option_btn.select(i)
			return
	# 自定义字体：若不在预设里，显示文件名
	if not font_id.is_empty() and font_id != "default":
		# 检查是否已作为动态项添加
		for i in font_option_btn.item_count:
			if font_option_btn.get_item_metadata(i) == font_id:
				font_option_btn.select(i)
				return
		# 未添加则追加
		font_option_btn.add_item(font_id.get_file())
		font_option_btn.set_item_metadata(font_option_btn.item_count - 1, font_id)
		font_option_btn.select(font_option_btn.item_count - 1)
	else:
		font_option_btn.select(0)

func _selected_text_block_font(delta: int):
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_font_size_change(delta)
		_update_font_ui()
		_mark_dirty()

func _on_font_color_changed(color: Color):
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_font_color_change(color)
		_update_font_ui()
		_mark_dirty()

## 字体下拉选择
func _on_font_option_selected(idx: int) -> void:
	if not (_current_selected_block is TextBlock):
		return
	var tb: TextBlock = _current_selected_block as TextBlock
	if idx < FONT_PRESETS.size():
		var p: Array = FONT_PRESETS[idx] as Array
		var fid: String = p[1]
		if fid == "__custom__":
			# 弹文件对话框选 .ttf/.otf
			_prompt_custom_font()
			return
		tb.handle_font_id_change(fid)
	else:
		# 动态添加的自定义字体项
		var fid: String = font_option_btn.get_item_metadata(idx)
		if fid != null:
			tb.handle_font_id_change(fid)
	_update_font_ui()
	_mark_dirty()

## 弹对话框选择自定义字体文件
func _prompt_custom_font() -> void:
	var dialog := FileDialog.new()
	dialog.title = "选择字体文件"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.ttf, *.otf", "TrueType/OpenType 字体")
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(_on_custom_font_selected)
	add_child(dialog)
	dialog.popup_centered()

func _on_custom_font_selected(path: String) -> void:
	if not (_current_selected_block is TextBlock):
		return
	# 复制到 user://data/fonts/
	var abs_dir: String = ProjectSettings.globalize_path(FONT_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var fname: String = path.get_file()
	var dest_abs: String = abs_dir + fname
	if not FileAccess.file_exists(dest_abs):
		DirAccess.copy_absolute(path, dest_abs)
	var tb: TextBlock = _current_selected_block as TextBlock
	tb.handle_font_id_change(fname)
	_update_font_ui()
	_mark_dirty()

## 描边宽度变化
func _on_outline_size_changed(value: float) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_outline_size_change(int(value))
		_mark_dirty()

## 描边颜色变化
func _on_outline_color_changed(color: Color) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_outline_color_change(color)
		_mark_dirty()

## 块背景色变化
func _on_block_bg_color_changed(color: Color) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_bg_color_change(color)
		_mark_dirty()

## 弹出文本进阶设置二级面板
func _on_text_more_pressed() -> void:
	if not (_current_selected_block is TextBlock):
		return
	var tb: TextBlock = _current_selected_block as TextBlock
	# 同步当前值到面板控件
	_line_spacing_spin.value = tb.data.line_spacing
	_box_glow_spin.value = tb.data.box_glow_size
	_box_glow_color_btn.color = tb.data.box_glow_color
	_corner_radius_spin.value = tb.data.corner_radius
	_markdown_check.set_pressed_no_signal(tb.data.use_markdown)
	# 弹出在按钮下方
	var btn_rect: Rect2 = text_more_btn.get_global_rect()
	_text_more_popup.size = Vector2i(280, 200)
	_text_more_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.end.y + 4))
	_text_more_popup.popup()

## 弹出快捷插入面板
func _on_insert_pressed() -> void:
	if not (_current_selected_block is TextBlock):
		return
	if not (_current_selected_block as TextBlock).is_editing():
		return
	_show_insert_panel()

## 由 TextBlock 的 Tab 键触发的插入面板唤起
func _on_request_insert_panel() -> void:
	if _insert_panel_active:
		# 已激活则关闭
		_hide_insert_panel()
	else:
		_show_insert_panel()

## 显示插入浮层（Control 不抢焦点，TextEdit 保持键盘焦点，热键正常工作）
func _show_insert_panel() -> void:
	_refresh_insert_panel()
	_insert_popup.visible = true
	# 同步浮层尺寸到内容所需最小尺寸（margin 的 combined minimum）
	var content_min := Vector2.ZERO
	for c in _insert_popup.get_children():
		var m: Vector2 = (c as Control).get_combined_minimum_size()
		content_min.x = maxf(content_min.x, m.x)
		content_min.y = maxf(content_min.y, m.y)
	# 保底尺寸，避免布局未就绪时过窄
	content_min.x = maxf(content_min.x, 360.0)
	content_min.y = maxf(content_min.y, 120.0)
	_insert_popup.size = content_min
	# 定位到插入按钮下方：全局坐标转 main 局部坐标
	var btn_rect: Rect2 = insert_btn.get_global_rect()
	var anchor_global := Vector2(btn_rect.position.x, btn_rect.end.y + 4.0)
	_insert_popup.position = get_global_transform().affine_inverse() * anchor_global
	_insert_panel_active = true
	TextBlock.insert_panel_active = true

## 隐藏插入面板，焦点回文本编辑
func _hide_insert_panel() -> void:
	_insert_popup.hide()
	_insert_panel_active = false
	TextBlock.insert_panel_active = false
	if _current_selected_block is TextBlock:
		(_current_selected_block as TextBlock).grab_text_focus()

## 热键插入回调（由 TextBlock 的数字键触发）
func _on_request_insert_hotkey(key_code: int) -> void:
	if _insert_hotkeys.has(key_code):
		var entry: Array = _insert_hotkeys[key_code] as Array
		_insert_syntax(entry[0], entry[1])
	_hide_insert_panel()


## 构建颜文字浮层（Control，不抢焦点，仿 insert panel）
func _setup_kaomoji_panel() -> void:
	_kaomoji_popup = Panel.new()
	_kaomoji_popup.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.98)
	sb.set_corner_radius_all(10)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.15)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_kaomoji_popup.add_theme_stylebox_override("panel", sb)
	_kaomoji_popup.visibility_changed.connect(func():
		if not _kaomoji_popup.visible:
			_kaomoji_active = false
			TextBlock.kaomoji_panel_active = false
	)
	add_child(_kaomoji_popup)


## 构建选中属性浮层（z轴/透明度/删除）
func _setup_inspector() -> void:
	_inspector_popup = Panel.new()
	_inspector_popup.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97)
	sb.set_corner_radius_all(8)
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_inspector_popup.add_theme_stylebox_override("panel", sb)
	_inspector_popup.custom_minimum_size = Vector2i(180, 0)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)

	var title := _insp_label("属性")
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var row_z := HBoxContainer.new()
	row_z.add_child(_insp_label("z轴"))
	_z_spin = SpinBox.new()
	_z_spin.min_value = -100
	_z_spin.max_value = 100
	_z_spin.value_changed.connect(func(v: float): _apply_z_index(int(v)))
	_style_inspector_spin(_z_spin)
	row_z.add_child(_z_spin)
	vbox.add_child(row_z)

	var row_o := HBoxContainer.new()
	row_o.add_child(_insp_label("透明"))
	_opacity_spin = SpinBox.new()
	_opacity_spin.min_value = 0.1
	_opacity_spin.max_value = 1.0
	_opacity_spin.step = 0.1
	_opacity_spin.value_changed.connect(func(v: float): _apply_opacity(v))
	_style_inspector_spin(_opacity_spin)
	row_o.add_child(_opacity_spin)
	vbox.add_child(row_o)

	# ── 涂鸦专属（包在一个 VBox 里，整体显隐）──
	_draw_tools_box = VBoxContainer.new()
	_draw_tools_box.add_theme_constant_override("separation", 4)
	_draw_tools_box.visible = false
	var dt := _insp_label("涂鸦")
	dt.add_theme_font_size_override("font_size", 13)
	_draw_tools_box.add_child(dt)
	# 画笔类型
	var row_bt := HBoxContainer.new()
	row_bt.add_child(_insp_label("画笔"))
	_draw_brush_opt = OptionButton.new()
	_draw_brush_opt.add_item("实线", 0)
	_draw_brush_opt.add_item("马克笔", 1)
	_draw_brush_opt.add_item("铅笔", 2)
	_draw_brush_opt.add_item("荧光笔", 3)
	_draw_brush_opt.item_selected.connect(_on_draw_brush_type_selected)
	_draw_brush_opt.add_theme_color_override("font_color", _INSP_TEXT)
	_draw_brush_opt.add_theme_color_override("font_hover_color", _INSP_TEXT)
	row_bt.add_child(_draw_brush_opt)
	_draw_tools_box.add_child(row_bt)
	var row_dc := HBoxContainer.new()
	row_dc.add_child(_insp_label("笔色"))
	_draw_color_btn = ColorPickerButton.new()
	_draw_color_btn.edit_alpha = false
	_draw_color_btn.color = Color(0.2, 0.2, 0.2)
	_draw_color_btn.custom_minimum_size = Vector2i(60, 0)
	_draw_color_btn.color_changed.connect(_on_draw_color_changed)
	row_dc.add_child(_draw_color_btn)
	_draw_tools_box.add_child(row_dc)
	var row_dw := HBoxContainer.new()
	row_dw.add_child(_insp_label("粗细"))
	_draw_width_spin = SpinBox.new()
	_draw_width_spin.min_value = 1.0
	_draw_width_spin.max_value = 30.0
	_draw_width_spin.value = 3.0
	_draw_width_spin.value_changed.connect(_on_draw_width_changed)
	_style_inspector_spin(_draw_width_spin)
	row_dw.add_child(_draw_width_spin)
	_draw_tools_box.add_child(row_dw)
	# 平滑段数（0=折线，越大越平滑，可极端到 24）
	var row_ds := HBoxContainer.new()
	row_ds.add_child(_insp_label("平滑"))
	_draw_smooth_spin = SpinBox.new()
	_draw_smooth_spin.min_value = 0.0
	_draw_smooth_spin.max_value = 24.0
	_draw_smooth_spin.value = 8.0
	_draw_smooth_spin.suffix = " 段"
	_draw_smooth_spin.value_changed.connect(_on_draw_smooth_changed)
	_style_inspector_spin(_draw_smooth_spin)
	row_ds.add_child(_draw_smooth_spin)
	_draw_tools_box.add_child(row_ds)
	# 笔锋开关（书法感：粗细随速度/位置变化）
	var row_dp := HBoxContainer.new()
	row_dp.add_child(_insp_label("笔锋"))
	_draw_pen_tip_chk = CheckBox.new()
	_draw_pen_tip_chk.text = "开启"
	_draw_pen_tip_chk.add_theme_color_override("font_color", _INSP_TEXT)
	_draw_pen_tip_chk.add_theme_color_override("font_hover_color", _INSP_TEXT)
	_draw_pen_tip_chk.toggled.connect(_on_draw_pen_tip_toggled)
	row_dp.add_child(_draw_pen_tip_chk)
	_draw_tools_box.add_child(row_dp)
	_draw_tools_box.add_child(_insp_button("撤销一笔", _on_draw_erase))
	_draw_tools_box.add_child(_insp_button("清空涂鸦", _on_draw_clear))
	vbox.add_child(_draw_tools_box)

	vbox.add_child(_insp_button("删除 (Del)", _delete_selected_block))

	_inspector_popup.add_child(vbox)
	add_child(_inspector_popup)


## inspector 文字色（白底用深色）
const _INSP_TEXT: Color = Color(0.22, 0.22, 0.26)


## inspector 用 Label（统一深色文字）
func _insp_label(text: String, w: int = 44) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2i(w, 0)
	l.add_theme_color_override("font_color", _INSP_TEXT)
	return l


## inspector 用 Button（统一深色文字）
func _insp_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", _INSP_TEXT)
	b.add_theme_color_override("font_hover_color", _INSP_TEXT)
	b.add_theme_color_override("font_pressed_color", _INSP_TEXT)
	b.pressed.connect(callback)
	return b


## SpinBox 在白底上数字也要深色
func _style_inspector_spin(s: SpinBox) -> void:
	var le: LineEdit = s.get_line_edit()
	if le != null:
		le.add_theme_color_override("font_color", _INSP_TEXT)


## 显示属性浮层，贴当前选中块右上角
func _show_inspector() -> void:
	if _current_selected_block == null or not is_instance_valid(_current_selected_block):
		_hide_inspector()
		return
	_refresh_inspector()
	_inspector_popup.size = Vector2(180.0, 150.0)
	var vp := get_viewport_rect().size
	if _setting_inspector_docked:
		_inspector_popup.position = Vector2(vp.x - 190.0, 64.0)
	else:
		var br2: Rect2 = _current_selected_block.get_global_rect()
		var anchor2 := Vector2(br2.end.x + 6.0, br2.position.y)
		var lp2: Vector2 = get_global_transform().affine_inverse() * anchor2
		lp2.x = clampf(lp2.x, 4.0, vp.x - 190.0)
		lp2.y = clampf(lp2.y, 4.0, vp.y - 130.0)
		_inspector_popup.position = lp2
	_inspector_popup.visible = true


## 隐藏属性浮层
func _hide_inspector() -> void:
	if _inspector_popup != null:
		_inspector_popup.visible = false


## 刷新属性浮层的 z轴/透明度值
func _refresh_inspector() -> void:
	if _inspector_popup == null or _current_selected_block == null \
	   or not is_instance_valid(_current_selected_block):
		return
	_z_spin.value = float(_current_selected_block.data.z_index)
	_opacity_spin.value = _current_selected_block.modulate.a
	# 涂鸦工具：仅涂鸦块显示，同步笔色 / 粗细
	var is_draw: bool = _current_selected_block is DrawBlock
	_draw_tools_box.visible = is_draw
	if is_draw:
		var dd: DrawBlockData = (_current_selected_block as DrawBlock).data as DrawBlockData
		_draw_color_btn.color = dd.brush_color
		_draw_width_spin.value = dd.brush_width
		_draw_smooth_spin.value = dd.brush_smooth
		_draw_pen_tip_chk.set_pressed_no_signal(dd.brush_pen_tip)
		_draw_brush_opt.select(dd.brush_type)


## 应用 z 轴到所有选中块（SpinBox/快捷键共用）
func _apply_z_index(z: int) -> void:
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.data.z_index = clampi(z, -100, 100)
			b.z_index = b.data.z_index
	_mark_dirty()


## 应用透明度到所有选中块
func _apply_opacity(op: float) -> void:
	var o: float = clampf(op, 0.1, 1.0)
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.data.opacity = o
			b.modulate.a = o
	_mark_dirty()


## 涂鸦笔色变更（应用到所有选中的涂鸦块，影响下一笔）
func _on_draw_color_changed(c: Color) -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).handle_brush_color_change(c)
	_mark_dirty()


## 涂鸦粗细变更
func _on_draw_width_changed(w: float) -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).handle_brush_width_change(w)
	_mark_dirty()


## 撤销涂鸦最近一笔
func _on_draw_erase() -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).erase_last_stroke()
	_mark_dirty()


## 清空涂鸦
func _on_draw_clear() -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).clear_strokes()
	_mark_dirty()


## 涂鸦平滑段数变更（0=折线，越大越平滑）
func _on_draw_smooth_changed(v: float) -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).handle_brush_smooth_change(int(v))
	_mark_dirty()


## 涂鸦笔锋开关
func _on_draw_pen_tip_toggled(on: bool) -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).handle_brush_pen_tip_change(on)
	_mark_dirty()


## 涂鸦画笔类型变更（0 实线 / 1 马克笔 / 2 铅笔 / 3 荧光笔）
func _on_draw_brush_type_selected(idx: int) -> void:
	for b in _selected_blocks:
		if b is DrawBlock:
			(b as DrawBlock).handle_brush_type_change(idx)
	_mark_dirty()


## 快捷键：z 轴 ±1
func _adjust_selected_z_index(delta: int) -> void:
	for b in _selected_blocks:
		if is_instance_valid(b):
			b.data.z_index = clampi(b.data.z_index + delta, -100, 100)
			b.z_index = b.data.z_index
	_refresh_inspector()
	_mark_dirty()


## 快捷键：透明度 ±0.1
func _adjust_selected_opacity(delta: float) -> void:
	for b in _selected_blocks:
		if is_instance_valid(b):
			var o: float = clampf(b.modulate.a + delta, 0.1, 1.0)
			b.data.opacity = o
			b.modulate.a = o
	_refresh_inspector()
	_mark_dirty()


## 显示颜文字浮层（Ctrl+; 唤起）
func _show_kaomoji_panel() -> void:
	if _kaomoji_cats.is_empty():
		_kaomoji_cats = KaomojiData.get_categories()
	_kaomoji_index = 0
	_refresh_kaomoji_panel()
	_kaomoji_popup.visible = true
	# 同步浮层尺寸到内容所需最小尺寸
	var content_min := Vector2.ZERO
	for c in _kaomoji_popup.get_children():
		var m: Vector2 = (c as Control).get_combined_minimum_size()
		content_min.x = maxf(content_min.x, m.x)
		content_min.y = maxf(content_min.y, m.y)
	content_min.x = maxf(content_min.x, 340.0)
	_kaomoji_popup.size = content_min
	# 定位：优先贴当前编辑的文本框下方，否则中央偏上
	var vp_size: Vector2 = get_viewport_rect().size
	var anchor_global := Vector2((vp_size.x - content_min.x) * 0.5, 80.0)
	if _current_selected_block is TextBlock and (_current_selected_block as TextBlock).is_editing():
		var tb_rect: Rect2 = (_current_selected_block as TextBlock).get_global_rect()
		anchor_global = Vector2(tb_rect.position.x, tb_rect.end.y + 6.0)
	# 全局坐标转 main 局部坐标 + 边界夹紧
	var local_pos: Vector2 = get_global_transform().affine_inverse() * anchor_global
	local_pos.x = clampf(local_pos.x, 4.0, vp_size.x - content_min.x - 4.0)
	local_pos.y = clampf(local_pos.y, 4.0, vp_size.y - 120.0)
	_kaomoji_popup.position = local_pos
	_kaomoji_active = true
	TextBlock.kaomoji_panel_active = true


## 隐藏颜文字浮层，焦点回文本编辑
func _hide_kaomoji_panel() -> void:
	_kaomoji_popup.visible = false
	_kaomoji_active = false
	TextBlock.kaomoji_panel_active = false
	if _current_selected_block is TextBlock:
		(_current_selected_block as TextBlock).grab_text_focus()


## 刷新颜文字浮层内容（当前分类的颜文字网格）
func _refresh_kaomoji_panel() -> void:
	for c in _kaomoji_popup.get_children():
		c.queue_free()
	if _kaomoji_cats.is_empty():
		_kaomoji_cats = KaomojiData.get_categories()
	var cat: Array = _kaomoji_cats[_kaomoji_index] as Array
	var cat_name: String = cat[0] as String
	var items: Array = cat[1] as Array
	_kaomoji_hotkeys = items

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# 分类标签（含操作提示）
	var title := Label.new()
	title.text = "%s   (%d/%d)  ·  Tab 切换分类 · 数字键选取 · Esc 关闭" % [cat_name, _kaomoji_index + 1, _kaomoji_cats.size()]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	vbox.add_child(title)

	# 颜文字网格：每格 = 数字键标签 + EmojiButton（点击插入文本，拖拽放置贴纸）
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in range(items.size()):
		var k: String = items[i] as String
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var num_label := Label.new()
		num_label.text = str((i + 1) % 10)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 11)
		num_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		cell.add_child(num_label)
		var btn := EmojiButton.new()
		btn.text = k
		btn.emoji_text = k
		btn.custom_minimum_size = Vector2i(60, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.flat = true
		btn.tooltip_text = "点击插入 · 拖拽放置贴纸 · 快捷键 " + str((i + 1) % 10)
		btn.pressed.connect(func():
			_insert_text_to_block(k)
			_hide_kaomoji_panel()
		)
		cell.add_child(btn)
		grid.add_child(cell)
	vbox.add_child(grid)

	margin.add_child(vbox)
	_kaomoji_popup.add_child(margin)


## 颜文字键盘选取回调（编辑态由 TextBlock 转发，非编辑态由 _input 直接触发）
func _on_request_kaomoji_key(key_code: int) -> void:
	if key_code == KEY_ESCAPE:
		_hide_kaomoji_panel()
		return
	if key_code == KEY_TAB:
		var n_cats: int = _kaomoji_cats.size()
		if n_cats <= 0:
			return
		if Input.is_key_pressed(KEY_SHIFT):
			_kaomoji_index = (_kaomoji_index - 1 + n_cats) % n_cats
		else:
			_kaomoji_index = (_kaomoji_index + 1) % n_cats
		_refresh_kaomoji_panel()
		return
	# 数字键 1-9,0 选取当前分类对应颜文字
	var idx: int = KAOMOJI_HOTKEYS.find(key_code)
	if idx >= 0 and idx < _kaomoji_hotkeys.size():
		_insert_text_to_block(_kaomoji_hotkeys[idx] as String)
		_hide_kaomoji_panel()


## Emoji 面板常驻：切换显示（不要求编辑中，emoji 可拖拽放置贴纸）
func _on_emoji_pressed() -> void:
	if _emoji_popup.visible:
		_emoji_popup.visible = false
		return
	_refresh_emoji_panel()
	_emoji_popup.size = Vector2i(400, 380)
	var vp := get_viewport_rect().size
	_emoji_popup.position = Vector2i(int(vp.x - 420), 60)
	_emoji_popup.visible = true

## 弹出日记助手面板
func _on_diary_pressed() -> void:
	_refresh_diary_panel()
	var btn_rect: Rect2 = diary_btn.get_global_rect()
	_diary_popup.size = Vector2i(380, 0)  # 高度自适应
	_diary_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.end.y + 4))
	_diary_popup.popup()

func _on_line_spacing_changed(value: float) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_line_spacing_change(value)
		_mark_dirty()

func _on_box_glow_size_changed(value: float) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_box_glow_size_change(int(value))
		_mark_dirty()

func _on_box_glow_color_changed(color: Color) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_box_glow_color_change(color)
		_mark_dirty()

func _on_corner_radius_changed(value: float) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_corner_radius_change(int(value))
		_mark_dirty()

func _on_markdown_toggled(enabled: bool) -> void:
	if _current_selected_block is TextBlock:
		var tb: TextBlock = _current_selected_block as TextBlock
		tb.handle_markdown_toggle(enabled)
		_mark_dirty()

# ═══════════════════════════════════════════
#  背景色
# ═══════════════════════════════════════════

func _on_bg_color_changed(color: Color):
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.shadow_size = 4
	s.shadow_color = Color(0, 0, 0, 0.08)
	paper.add_theme_stylebox_override("panel", s)
	_current_page_data.paper_bg_color = color
	_mark_dirty()

# ═══════════════════════════════════════════
#  打开文件
# ═══════════════════════════════════════════

## 打开已保存的 .tres 笔记文件
func _on_open_file():
	var dialog := FileDialog.new()
	dialog.title = "打开笔记"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.tres", "DollDollNote 笔记文件")
	dialog.access = FileDialog.ACCESS_FILESYSTEM  # 允许打开任意位置（含导出的）
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(_on_file_opened)
	add_child(dialog)
	dialog.popup_centered()

## 文件选中后加载
func _on_file_opened(path: String) -> void:
	# 转成 user:// 或 res:// 友好路径；若在外部则 ResourceLoader 也能用绝对路径
	var load_path: String = path
	var page_data: PageData = ResourceLoader.load(load_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if page_data == null or not (page_data is PageData):
		push_warning("打开失败，文件不是有效的笔记: " + path)
		return
	
	# 清空当前 paper
	_deselect_all()
	for child in paper.get_children():
		if child is BaseBlock:
			child.queue_free()
	# 等待 queue_free 生效（下一帧）—— 这里直接同步清理数组
	_current_page_data.blocks.clear()
	
	_current_page_data = page_data
	_apply_paper_style_from_data()
	paper.custom_minimum_size = Vector2i(
		_current_page_data.paper_width,
		_current_page_data.paper_height
	)
	# 重建所有块
	for block_data in _current_page_data.blocks:
		_instantiate_block(block_data)
	print("打开笔记成功: %d 个块" % _current_page_data.blocks.size())
	_mark_dirty()


# ═══════════════════════════════════════════
#  笔记列表面板（左侧侧栏，多日记切换）
# ═══════════════════════════════════════════

## 构建笔记列表面板（动态加到 Body 最左侧）
func _setup_note_list() -> void:
	_note_list_panel = Panel.new()
	_note_list_panel.custom_minimum_size = Vector2i(220, 0)
	_note_list_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.94, 0.91, 1.0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_note_list_panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	# Header
	var header := HBoxContainer.new()
	var ttl := Label.new()
	ttl.text = "📓 笔记"
	ttl.add_theme_font_size_override("font_size", 16)
	ttl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh := Button.new()
	refresh.text = "⟳"
	refresh.tooltip_text = "刷新列表"
	refresh.pressed.connect(_refresh_note_list)
	header.add_child(ttl)
	header.add_child(hspacer)
	header.add_child(refresh)
	vbox.add_child(header)
	# 列表（可滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_list = VBoxContainer.new()
	_note_list.size_flags_horizontal = Control.SIZE_FILL
	_note_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_note_list)
	vbox.add_child(scroll)
	_note_list_panel.add_child(vbox)
	# 分隔条
	_note_splitter = Control.new()
	_note_splitter.custom_minimum_size = Vector2i(4, 0)
	_note_splitter.visible = false
	# 插到 Body 最左侧（PaperScroll 之前）
	body.add_child(_note_splitter)
	body.move_child(_note_splitter, 0)
	body.add_child(_note_list_panel)
	body.move_child(_note_list_panel, 0)
	_refresh_note_list()


## 扫描 NOTE_DIR，按修改时间降序填充笔记列表
func _refresh_note_list() -> void:
	if _note_list == null:
		return
	for c in _note_list.get_children():
		c.queue_free()
	var abs_dir: String = ProjectSettings.globalize_path(NOTE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	var notes: Array = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") or fname.ends_with(".res"):
			var full_path: String = abs_dir + "/" + fname
			var mt: int = FileAccess.get_modified_time(full_path)
			notes.append([NOTE_DIR + fname, fname.get_basename(), mt])
		fname = dir.get_next()
	dir.list_dir_end()
	notes.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	for n in notes:
		_add_note_item(String(n[0]), String(n[1]), int(n[2]))


## 添加单个笔记项（标题 + 当前高亮 + 点击加载）
func _add_note_item(path: String, title: String, mtime: int) -> void:
	var btn := Button.new()
	btn.text = title
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.alignment = 0  # HorizontalAlignment.LEFT（标题左对齐）
	btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	btn.add_theme_color_override("font_hover_color", Color(0.15, 0.4, 0.8))
	btn.tooltip_text = "修改于: " + Time.get_datetime_string_from_unix_time(mtime, false).replace("T", " ")
	btn.pressed.connect(_load_note_by_path.bind(path))
	# 当前笔记高亮
	if _current_page_data != null and _current_page_data.note_title == title:
		btn.modulate = Color(0.55, 0.75, 1.0)
	_note_list.add_child(btn)


## 点击笔记项 → 加载该笔记（复用 _on_file_opened）
func _load_note_by_path(path: String) -> void:
	_on_file_opened(path)
	_refresh_note_list()


## 工具栏「📓 笔记」开关侧栏
func _on_note_list_toggle(on: bool) -> void:
	_note_list_panel.visible = on
	_note_splitter.visible = on
	if on:
		_refresh_note_list()

# ═══════════════════════════════════════════
#  贴纸面板
# ═══════════════════════════════════════════

func _on_sticker_toggle(toggled_on: bool):
	sticker_panel.visible = toggled_on
	splitter.visible = toggled_on

## 贴纸图片合法扩展名
const STICKER_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp"]

## 程序化装饰预设：[id, 显示名]。全部用 ShapeBlock 生成，零外部素材，矢量统一
const DECORATIONS: Array = [
	["washi_red", "胶带·红"],
	["washi_blue", "胶带·蓝"],
	["washi_green", "胶带·绿"],
	["sticky_yellow", "便利贴"],
	["sticky_pink", "便利贴·粉"],
	["arrow", "➜ 箭头"],
	["divider", "— 分隔线"],
	["dot", "● 圆点"],
	["highlight", "▭ 高亮框"],
]

## 内置装饰 PNG 目录（随项目分发；编辑器/自用阶段 res:// 可全局化读取，导出后需走 import 资源）
const DECORATION_DIR: String = "res://assets/decorations/"


## 放置程序化装饰（ShapeBlock 预设样式），复用 _spawn_block 挂载
func _place_decoration(deco_id: String) -> void:
	var data: ShapeBlockData = _make_decoration_data(deco_id, _get_spawn_position())
	if data == null:
		return
	_spawn_block(data)
	_mark_dirty()


## 根据装饰 id 构造预设样式的 ShapeBlockData
func _make_decoration_data(deco_id: String, pos: Vector2) -> ShapeBlockData:
	var data := ShapeBlockData.new()
	data.position = pos
	data.shape_type = ShapeBlockData.ShapeType.RECT
	data.fill_enabled = true
	match deco_id:
		"washi_red":
			data.size = Vector2(150, 26)
			data.fill_color = Color(0.95, 0.42, 0.42, 0.6)
			data.rotation_degrees = -4.0
		"washi_blue":
			data.size = Vector2(150, 26)
			data.fill_color = Color(0.42, 0.62, 0.95, 0.6)
			data.rotation_degrees = 3.0
		"washi_green":
			data.size = Vector2(150, 26)
			data.fill_color = Color(0.5, 0.85, 0.55, 0.6)
			data.rotation_degrees = -2.0
		"sticky_yellow":
			data.size = Vector2(150, 150)
			data.fill_color = Color(1.0, 0.96, 0.55, 1.0)
			data.rotation_degrees = -3.0
		"sticky_pink":
			data.size = Vector2(150, 150)
			data.fill_color = Color(1.0, 0.75, 0.82, 1.0)
			data.rotation_degrees = 4.0
		"arrow":
			data.size = Vector2(170, 24)
			data.shape_type = ShapeBlockData.ShapeType.ARROW
			data.fill_enabled = false
			data.stroke_color = Color(0.25, 0.25, 0.28, 1.0)
			data.stroke_width = 3.0
		"divider":
			data.size = Vector2(320, 6)
			data.shape_type = ShapeBlockData.ShapeType.LINE
			data.fill_enabled = false
			data.stroke_color = Color(0.6, 0.55, 0.5, 1.0)
			data.stroke_width = 2.0
		"dot":
			data.size = Vector2(18, 18)
			data.shape_type = ShapeBlockData.ShapeType.ELLIPSE
			data.fill_color = Color(0.95, 0.5, 0.5, 1.0)
		"highlight":
			data.size = Vector2(220, 50)
			data.fill_enabled = false
			data.stroke_color = Color(0.95, 0.75, 0.2, 1.0)
			data.stroke_width = 4.0
		_:
			return null
	return data


## 在贴纸网格顶部注入「🎨 装饰」分组（程序化按钮，点击放置）
func _add_decoration_group() -> void:
	var section := Label.new()
	section.text = "🎨 装饰"
	section.add_theme_font_size_override("font_size", 13)
	section.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	sticker_grid.add_child(section)
	for d in DECORATIONS:
		var da: Array = d as Array
		var did: String = da[0] as String
		var dname: String = da[1] as String
		var btn := Button.new()
		btn.text = dname
		btn.custom_minimum_size = Vector2i(64, 36)
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "点击放置到画布"
		btn.pressed.connect(_place_decoration.bind(did))
		sticker_grid.add_child(btn)


func _populate_stickers():
	for child in sticker_grid.get_children():
		child.queue_free()

	# 1) 顶部注入程序化装饰分组（零素材，始终可用）
	_add_decoration_group()

	# 2) 用户贴纸库 user://data/stickers/（绝对路径扫描，避开 res:// 虚拟文件系统问题）
	var abs_sticker: String = ProjectSettings.globalize_path(STICKER_DIR)
	if not DirAccess.dir_exists_absolute(abs_sticker):
		DirAccess.make_dir_recursive_absolute(abs_sticker)
		abs_sticker = ""  # 新建目录，本次不扫
	var groups: Dictionary = {}
	if abs_sticker != "":
		_scan_stickers_recursive(abs_sticker, "", groups)

	if groups.is_empty() and abs_sticker != "":
		var hint := Label.new()
		hint.text = "（贴纸库为空，点 📂 添加贴纸到文件夹）"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sticker_grid.add_child(hint)

	# 3) 内置装饰 PNG res://assets/decorations/（若存在）
	var abs_decor: String = ProjectSettings.globalize_path(DECORATION_DIR)
	if DirAccess.dir_exists_absolute(abs_decor):
		var decor_groups: Dictionary = {}
		_scan_stickers_recursive(abs_decor, "", decor_groups)
		for k in decor_groups:
			groups["内置贴纸/" + String(k)] = decor_groups[k]
	
	var total: int = 0
	# 排序：根目录优先，然后按文件夹名
	var sorted_keys: Array = groups.keys()
	sorted_keys.sort()
	
	for folder_key in sorted_keys:
		var paths: Array = groups[folder_key]
		if paths.is_empty():
			continue
		# 如果不是根目录，加一个分组标签
		if folder_key != "":
			var section := Label.new()
			section.text = "📁 " + folder_key
			section.add_theme_font_size_override("font_size", 13)
			section.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
			sticker_grid.add_child(section)
		for p in paths:
			_add_sticker_thumb(p as String, folder_key)
			total += 1
	print("贴纸扫描完成: 发现 %d 个，%d 个分组" % [total, groups.size()])

## 递归扫描贴纸目录，按相对文件夹路径分组
func _scan_stickers_recursive(abs_base: String, rel_folder: String, out_groups: Dictionary) -> void:
	var dir := DirAccess.open(abs_base + "/" + rel_folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname == "." or fname == ".." or fname.begins_with("."):
			fname = dir.get_next()
			continue
		var rel_path: String = rel_folder + "/" + fname if rel_folder != "" else fname
		if dir.current_is_dir():
			# 递归子文件夹
			_scan_stickers_recursive(abs_base, rel_path, out_groups)
		else:
			var ext: String = fname.get_extension().to_lower()
			if ext in STICKER_EXTS:
				var group_key: String = rel_folder  # 空字符串表示根目录
				if not out_groups.has(group_key):
					out_groups[group_key] = []
				(out_groups[group_key] as Array).append(abs_base + "/" + rel_path)
		fname = dir.get_next()
	dir.list_dir_end()

## 贴纸缩略图按钮。点击时把贴纸复制到 user://data/stickers_used/ 存相对路径
func _add_sticker_thumb(abs_path: String, _folder: String):
	var btn := StickerButton.new()
	btn.sticker_path = abs_path
	btn.custom_minimum_size = Vector2i(64, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.tooltip_text = abs_path.get_file() + "（可拖拽到画布）"
	
	var img := Image.load_from_file(abs_path)
	if img == null:
		return
	# 将大图缩成缩略图，避免纹理尺寸撑爆 GridContainer
	var thumb_size: int = 64
	img.resize(thumb_size, thumb_size, Image.INTERPOLATE_LANCZOS)
	btn.texture_normal = ImageTexture.create_from_image(img)
	# 点击放置（放到画布中央）。用 pressed 而非 button_down：
	# 一旦用户发起拖拽（_get_drag_data 触发），Godot 会抑制 pressed，
	# 避免「拖拽放置一个 + 按下又放置一个」的双贴纸 bug。
	btn.pressed.connect(func():
		_place_sticker_at(abs_path, Vector2(120, 120))
	)
	sticker_grid.add_child(btn)

## 在 paper 的指定位置放置贴纸（拖拽释放或点击都调用）
func _place_sticker_at(abs_path: String, paper_pos: Vector2) -> void:
	var used_path: String = _copy_sticker_to_user(abs_path)
	var data := ImageBlockData.new()
	# paper_pos 是 paper 局部坐标，需考虑 zoom 换算
	data.position = paper_pos / _zoom if _zoom != 0 else paper_pos
	data.image_path = used_path
	
	_spawn_block(data)
	_mark_dirty()

## 贴纸拖拽放置回调：在鼠标释放位置创建贴纸块
func _on_sticker_dropped(abs_path: String, local_pos: Vector2) -> void:
	_place_sticker_at(abs_path, local_pos)


## 放置 emoji/颜文字为可缩放贴纸块（复用 TextBlock：大字号 + 透明 + 居中）
func _place_emoji_sticker(text: String, paper_pos: Vector2) -> void:
	var data := EmojiStickerData.new()
	# paper_pos 是 paper 局部坐标，需考虑 zoom 换算
	data.position = paper_pos / _zoom if _zoom != 0 else paper_pos
	data.emoji_text = text
	data.size = Vector2(140, 140)
	_spawn_block(data)
	_mark_dirty()


## 印章选择面板：列出预设印章 emoji，选一个进入印章模式
func _prompt_stamp_select() -> void:
	if _stamp_mode:
		_exit_stamp_mode()
		return
	var popup := PopupPanel.new()
	popup.min_size = Vector2i(340, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "💮 选一个印章，然后点画布盖戳"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)
	for e in STAMP_EMOJIS:
		var emoji: String = e
		var btn := Button.new()
		btn.text = emoji
		btn.custom_minimum_size = Vector2i(46, 46)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_enter_stamp_mode.bind(emoji, popup))
		grid.add_child(btn)
	add_child(popup)
	popup.popup_centered()


## 进入印章模式（记录 emoji，关闭选择面板，刷新底部提示）
func _enter_stamp_mode(emoji: String, popup: PopupPanel) -> void:
	_stamp_emoji = emoji
	_stamp_mode = true
	if popup != null:
		popup.hide()
	_last_hint_key = ""
	_update_hint_if_changed()


## 退出印章模式
func _exit_stamp_mode() -> void:
	_stamp_mode = false
	_last_hint_key = ""
	_update_hint_if_changed()


## 在画布指定位置盖戳：创建 emoji 贴纸 + 盖戳动画 + 墨点迸溅
func _stamp_emoji_at(text: String, paper_pos: Vector2) -> void:
	_push_undo()
	var data := EmojiStickerData.new()
	data.size = Vector2(140, 140)
	# paper_pos 已是 paper 内部坐标（get_local_mouse_position 已扣除 zoom），中心对齐鼠标
	data.position = paper_pos - data.size * 0.5
	data.emoji_text = text
	var block: EmojiStickerBlock = _spawn_block(data, false) as EmojiStickerBlock
	if block == null:
		return
	block._play_stamp_anim()
	if _fx_layer != null and is_instance_valid(_fx_layer):
		_fx_layer.spawn_burst(paper_scroll.get_local_mouse_position())
	_mark_dirty()


## emoji/颜文字贴纸拖拽放置回调
func _on_emoji_sticker_dropped(text: String, local_pos: Vector2) -> void:
	_place_emoji_sticker(text, local_pos)

## 把贴纸复制到 user://data/stickers_used/，返回 user:// 相对路径
func _copy_sticker_to_user(src_abs_path: String) -> String:
	var used_dir: String = DATA_DIR + "stickers_used/"
	var abs_used_dir: String = ProjectSettings.globalize_path(used_dir)
	if not DirAccess.dir_exists_absolute(abs_used_dir):
		DirAccess.make_dir_recursive_absolute(abs_used_dir)
	var src_file: String = src_abs_path.get_file()
	var dest_abs: String = abs_used_dir + src_file
	# 若已存在同名文件，直接复用（避免重复复制）
	if not FileAccess.file_exists(dest_abs):
		DirAccess.copy_absolute(src_abs_path, dest_abs)
	return used_dir + src_file

# ═══════════════════════════════════════════
#  自动保存
# ═══════════════════════════════════════════

func _autosave():
	_sync_block_data()
	
	var save_dir: String = NOTE_DIR
	var abs_save: String = ProjectSettings.globalize_path(save_dir)
	if not DirAccess.dir_exists_absolute(abs_save):
		DirAccess.make_dir_recursive_absolute(abs_save)
	
	# 注意：ResourceSaver 只认 .tres(文本)/.res(二进制)，不认 .json
	# 用 .json 会返回 ERR_FILE_UNRECOGNIZED(15) 导致保存失败
	var file_name: String = _current_page_data.note_title + ".tres"
	var path: String = save_dir + file_name
	
	var result: int = ResourceSaver.save(_current_page_data, path)
	if result == OK:
		print("自动保存成功: ", path)
	else:
		push_warning("自动保存失败: 错误码 ", result)
	# 侧栏可见时刷新（标题/时间可能变化）
	if _note_list_panel != null and _note_list_panel.visible:
		_refresh_note_list()

func _sync_block_data():
	_current_page_data.blocks.clear()
	for child in paper.get_children():
		if child is BaseBlock:
			_current_page_data.blocks.append(child.collect_data())

# ═══════════════════════════════════════════
#  导出
# ═══════════════════════════════════════════

func _on_export_json():
	_sync_block_data()
	
	var dialog := FileDialog.new()
	dialog.title = "导出笔记"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	# ResourceSaver 用 .tres(文本) 存 Godot Resource，.json 不被识别
	dialog.add_filter("*.tres", "DollDollNote 笔记文件")
	dialog.file_selected.connect(func(path: String):
		if not path.ends_with(".tres"):
			path += ".tres"
		var result: int = ResourceSaver.save(_current_page_data, path)
		if result == OK:
			print("导出成功: ", path)
		else:
			push_warning("导出失败: 错误码 ", result)
	)
	dialog.size = Vector2i(800, 500)
	add_child(dialog)
	dialog.popup_centered()

func _on_export_image():
	# get_global_rect() 已包含 scale 变换，直接用它裁切
	var paper_rect := paper.get_global_rect()
	var main_vp := get_viewport()
	await RenderingServer.frame_post_draw
	var full_img := main_vp.get_texture().get_image()
	var cropped := full_img.get_region(paper_rect)
	
	var dialog := FileDialog.new()
	dialog.title = "导出为图片"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.add_filter("*.png", "PNG 图片")
	dialog.file_selected.connect(func(path: String):
		cropped.save_png(path)
		print("导出图片成功: ", path)
	)
	dialog.size = Vector2i(800, 500)
	add_child(dialog)
	dialog.popup_centered()
