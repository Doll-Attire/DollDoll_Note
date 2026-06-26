## EmojiStickerData — emoji/颜文字贴纸块数据
## 由 _place_emoji_sticker 创建，用 EmojiStickerBlock 渲染（字号随尺寸缩放）
class_name EmojiStickerData
extends BlockData

@export var emoji_text: String = ""

func _init():
	block_type = BlockData.BlockType.EMOJI
	size = Vector2(140, 140)
