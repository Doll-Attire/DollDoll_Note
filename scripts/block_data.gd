## BlockData — 所有块元素的基类
class_name BlockData
extends Resource

enum BlockType { TEXT, IMAGE, SHAPE, DRAW, EMOJI }

@export var block_type: BlockType
@export var position: Vector2 = Vector2(100, 100)
@export var size: Vector2 = Vector2(200, 120)
@export var z_index: int = 0
@export var rotation_degrees: float = 0.0
@export var opacity: float = 1.0
