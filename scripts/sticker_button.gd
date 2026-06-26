## StickerButton — 贴纸缩略图按钮，支持拖拽
## 继承 TextureButton，实现 _get_drag_data 提供拖拽数据
## 拖拽时显示缩略图预览，释放到 paper 上在该位置创建贴纸块
class_name StickerButton
extends TextureButton

## 贴纸文件绝对路径（由 main._add_sticker_thumb 设置）
var sticker_path: String = ""


func _get_drag_data(_at_pos: Vector2) -> Variant:
	if sticker_path.is_empty():
		return null
	# 拖拽预览：用自身纹理做个小预览
	var preview := TextureRect.new()
	preview.texture = texture_normal
	preview.custom_minimum_size = Vector2i(48, 48)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	# 返回拖拽数据：标记为贴纸 + 路径
	return {
		"type": "sticker",
		"path": sticker_path,
	}
