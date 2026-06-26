## EmojiButton — emoji/颜文字按钮，支持拖拽放置为贴纸
## 继承 Button：pressed（点击）由 main 连接为「插入文本光标」；
## _get_drag_data（拖拽）返回 emoji_sticker 数据，释放到 paper 放置为可缩放贴纸块
class_name EmojiButton
extends Button

## 按钮代表的表情文本（emoji 或颜文字）
var emoji_text: String = ""


func _get_drag_data(_at_pos: Vector2) -> Variant:
	if emoji_text.is_empty():
		return null
	# 拖拽预览：用 Label 显示表情（大字号），跟随鼠标
	var preview := Label.new()
	preview.text = emoji_text
	preview.add_theme_font_size_override("font_size", 36)
	set_drag_preview(preview)
	# 返回拖拽数据：标记为 emoji 贴纸 + 文本
	return {
		"type": "emoji_sticker",
		"text": emoji_text,
	}
