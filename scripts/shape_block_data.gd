## ShapeBlockData — 几何图形块数据
class_name ShapeBlockData
extends BlockData

enum ShapeType { RECT, ELLIPSE, LINE, ARROW }

@export var shape_type: ShapeType = ShapeType.RECT
@export var stroke_color: Color = Color(0.2, 0.2, 0.2, 1)
@export var fill_color: Color = Color(0.9, 0.9, 0.95, 0.6)
@export var stroke_width: float = 3.0
@export var fill_enabled: bool = true   ## 是否填充（线/箭头不填充）

func _init():
	block_type = BlockData.BlockType.SHAPE
	size = Vector2(200, 120)
