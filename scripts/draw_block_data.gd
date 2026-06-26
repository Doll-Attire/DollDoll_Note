## DrawBlockData — 手绘涂鸦块数据
class_name DrawBlockData
extends BlockData

## 笔触点序列（每个点: Vector2 局部坐标）
@export var strokes: Array = []  ## Array[PackedVector2Array]，每段笔触一个数组
## 每段笔触的颜色
@export var stroke_colors: Array[Color] = []
## 每段笔触的宽度
@export var stroke_widths: Array[float] = []
## 当前笔刷颜色
@export var brush_color: Color = Color(0.2, 0.2, 0.2, 1)
## 当前笔刷宽度
@export var brush_width: float = 3.0
## 平滑细分段数（0=折线，越大越平滑，上限约 24）
@export var brush_smooth: int = 8
## 笔锋：笔画粗细随速度/位置变化（书法感）
@export var brush_pen_tip: bool = false
## 画笔类型：0=实线, 1=马克笔(半透叠加), 2=铅笔(细+颗粒), 3=荧光笔(粗半透)
@export var brush_type: int = 0

func _init():
	block_type = BlockData.BlockType.DRAW
	size = Vector2(300, 200)
