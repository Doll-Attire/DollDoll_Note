## ImageBlockData — 图片块数据
class_name ImageBlockData
extends BlockData

@export var image_path: String = ""   ## 相对路径 res://images/ 或 user://images/
@export var scale_factor: float = 1.0

func _init():
	block_type = BlockData.BlockType.IMAGE
	size = Vector2(200, 200)
