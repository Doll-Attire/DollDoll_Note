## PageData — 页面数据容器
## 存储页面配置 + 所有块的数组
class_name PageData
extends Resource

## 纸张底纹样式
enum PaperPattern { BLANK, LINED, GRID, DOTTED, BINDER }

@export var blocks: Array[Resource] = []
@export var paper_bg_color: Color = Color.WHITE
@export var paper_width: int = 800
@export var paper_height: int = 1100
@export var note_title: String = "未命名笔记"
## 底纹样式（PaperPattern 枚举值）
@export var paper_pattern: int = PaperPattern.BLANK
@export var paper_pattern_color: Color = Color(0.72, 0.72, 0.72, 0.6)
@export var paper_pattern_spacing: float = 28.0
# ── 纸张底图（用户上传的背景插画/人物）──
@export var paper_bg_image: String = ""
@export var paper_bg_image_opacity: float = 0.8
@export var paper_bg_image_offset: Vector2 = Vector2.ZERO
@export var paper_bg_image_scale: float = 1.0
