## ImageBlock — 图片块
## 继承 BaseBlock，只实现图片加载、自动适配尺寸等特有逻辑
## Godot 4.6 · GDScript 2.0 严格类型
class_name ImageBlock
extends BaseBlock

# ── 图片块专属常量 ──
const IMG_MIN_SIZE: int = 40
const HANDLE_BASE: int = 16      ## 手柄基础尺寸
const HANDLE_MAX: int = 28       ## 手柄最大尺寸

@onready var image_texture: TextureRect = %ImageTexture


# ═══════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════

func _block_ready() -> void:
	min_width = float(IMG_MIN_SIZE)
	min_height = float(IMG_MIN_SIZE)


func _block_setup() -> void:
	_load_image()
	_update_handle_size()


## 尺寸变化后同步更新手柄大小（缩放时触发）
func _on_self_resized() -> void:
	super._on_self_resized()
	_update_handle_size()


## 类型安全的 data 访问器
func _id() -> ImageBlockData:
	return data as ImageBlockData


# ═══════════════════════════════════════════
#  图片加载
# ═══════════════════════════════════════════

func _load_image() -> void:
	if _id().image_path.is_empty():
		return

	var path: String = _id().image_path
	var texture: Texture2D = null

	# 优先用记录的路径（user:// 或绝对路径）
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			texture = ImageTexture.create_from_image(img)
	# 兼容旧版 res:// 路径
	elif FileAccess.file_exists("res://data/images/" + path.get_file()):
		var img := Image.load_from_file("res://data/images/" + path.get_file())
		if img:
			texture = ImageTexture.create_from_image(img)
	elif FileAccess.file_exists("user://data/images/" + path.get_file()):
		var img := Image.load_from_file("user://data/images/" + path.get_file())
		if img:
			texture = ImageTexture.create_from_image(img)

	if texture:
		image_texture.texture = texture
		# 首次加载时自动适配块尺寸到图片宽高比
		_auto_fit_to_texture(texture.get_size())
	else:
		image_texture.texture = null
		push_warning("ImageBlock: 图片加载失败 -> " + path)


## 加载图片后自动适配块的尺寸到图片宽高比和大小
func _auto_fit_to_texture(tex_size: Vector2) -> void:
	const MAX_W: float = 600.0
	const MAX_H: float = 400.0

	var new_w: float = tex_size.x
	var new_h: float = tex_size.y

	# 超出最大尺寸则按比例缩小
	if new_w > MAX_W or new_h > MAX_H:
		var scale_factor: float = minf(MAX_W / new_w, MAX_H / new_h)
		new_w = maxf(new_w * scale_factor, float(IMG_MIN_SIZE))
		new_h = maxf(new_h * scale_factor, float(IMG_MIN_SIZE))

	# 确保至少 MIN_SIZE
	new_w = maxf(new_w, float(IMG_MIN_SIZE))
	new_h = maxf(new_h, float(IMG_MIN_SIZE))

	size = Vector2(new_w, new_h)
	_id().size = size
	pivot_offset = size / 2.0
	_update_handle_size()


## 根据块尺寸自适应缩放手柄大小（大图手柄大，小图手柄小）
## 这样大图上手柄不会显得太小不好抓
func _update_handle_size() -> void:
	if resize_handle == null:
		return
	# 取块短边的 8%，限制在 [HANDLE_BASE, HANDLE_MAX] 之间
	var shorter: float = minf(size.x, size.y)
	var handle_size: float = clampf(shorter * 0.08, float(HANDLE_BASE), float(HANDLE_MAX))
	resize_handle.custom_minimum_size = Vector2i(int(handle_size), int(handle_size))
	# offset 始终让手柄贴在右下角
	resize_handle.offset_left = -handle_size
	resize_handle.offset_top = -handle_size
