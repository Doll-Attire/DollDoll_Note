## EmojiStickerBlock — emoji/颜文字贴纸块
## 用 RichLabel 渲染 emoji，字号随块尺寸缩放（拖手柄 emoji 跟着变大），透明背景不裁剪
## 继承 BaseBlock 的拖拽/缩放/旋转/选中
class_name EmojiStickerBlock
extends BaseBlock

@onready var _label: RichTextLabel = %EmojiLabel
var _breathe_tween: Tween  ## 轻微呼吸缩放（作用于 _label，不动 block.scale，避免和拖拽/spawn 冲突）


func _block_ready() -> void:
	min_width = 40.0
	min_height = 40.0
	# 透明背景，emoji 直接显示
	var s := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", s)


func _block_setup() -> void:
	_label.bbcode_enabled = true
	# 垂直居中：emoji 彩色字形常比行高略高，顶对齐时顶部会被 RichLabel 裁掉一截
	# （旋转后触发重排才”恢复”的怪象即源于此）。居中后上下留白对称，不再贴边。
	# VerticalAlignment 枚举：0=顶 1=居中 2=底（用整数，与 text_alignment 惯例一致）
	_label.vertical_alignment = 1
	_label.text = "[center]" + _data().emoji_text + "[/center]"
	_apply_emoji_size()
	_start_breathe()


func _on_self_resized() -> void:
	super._on_self_resized()
	_apply_emoji_size()
	# 呼吸缩放以 _label 中心为轴，尺寸变化时重设轴心
	if _label != null:
		_label.pivot_offset = _label.size / 2.0


## 轻微呼吸缩放：scale 在 1.0 ↔ (1+amp) 循环，作用于 _label（内容层）
## 幅度 / 周期取自 BaseBlock 静态变量（由 main 设置同步）；amp=0 则关闭呼吸
func _start_breathe() -> void:
	if _breathe_tween:
		_breathe_tween.kill()
		_breathe_tween = null
	if _label != null:
		_label.pivot_offset = _label.size / 2.0
	# 幅度 0 = 关闭呼吸，归位即可
	if BaseBlock.breathe_amp <= 0.0:
		if _label != null:
			_label.modulate = Color(1.0, 1.0, 1.0)
		return
	var amp: float = BaseBlock.breathe_amp
	var period: float = maxf(BaseBlock.breathe_period, 0.2)
	# 用 modulate 亮度脉动而非 scale：RichTextLabel 在非整数 scale 下每帧重采样字形会"颤抖"，
	# 改 modulate 只叠加颜色（字形纹理不变），彻底消除颤抖。
	var bright: float = 1.0 + amp * 3.0
	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_property(_label, "modulate", Color(bright, bright, bright), period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(_label, "modulate", Color(1.0, 1.0, 1.0), period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 设置变更后重启呼吸（用新的幅度 / 速度）
func _apply_breathe() -> void:
	_start_breathe()


## 字号随块短边缩放：拖手柄改变尺寸时 emoji 视觉等比放大/缩小
func _apply_emoji_size() -> void:
	# 以高度为基准、系数略降（0.66），给 emoji 顶部/底部留出垂直余量避免被裁
	var fs: int = int(size.y * 0.66)
	_label.add_theme_font_size_override("normal_font_size", fs)
	# 字号变化后强制重排重绘，避免首帧用旧行高布局导致 emoji 顶部被裁
	_label.queue_redraw()


func _data() -> EmojiStickerData:
	return data as EmojiStickerData
