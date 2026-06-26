## TextBlockData — 文本块数据
class_name TextBlockData
extends BlockData

@export var bbcode_content: String = ""
@export var bg_color: Color = Color("#FFF3E0")
@export var border_color: Color = Color("#E0C9A6")
@export var border_width: int = 2
@export var font_size: int = 22     ## 块内字体大小
@export var font_color: Color = Color.BLACK  ## 块内文字颜色

# ── 个性化扩展（批次3）──
@export var font_id: String = "default"   ## 字体标识：default/mono/serif/自定义路径键
@export var outline_size: int = 0         ## 文字描边宽度（0=无描边）
@export var outline_color: Color = Color.BLACK  ## 文字描边颜色
@export var corner_radius: int = 8        ## 块圆角半径
@export var bg_image_path: String = ""    ## 背景图路径（为未来 NinePatch 自绘文本框铺路）

# ── 框描边（外发光式，区别于内边框线 border）──
@export var box_glow_size: int = 0        ## 框外发光宽度（0=无）
@export var box_glow_color: Color = Color(0.3, 0.6, 1.0, 0.6)  ## 框外发光颜色

# ── 文本排版（批次4）──
@export var line_spacing: float = 1.2     ## 行间距倍数
@export var text_alignment: int = 0       ## 对齐: 0=左 1=居中 2=右
@export var use_markdown: bool = false    ## 是否按 Markdown 解析（转 BBCode）

func _init():
	block_type = BlockData.BlockType.TEXT
	size = Vector2(360, 180)
