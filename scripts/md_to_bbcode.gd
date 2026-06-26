## MarkdownToBBCode — 简易 Markdown 转 BBCode 转换器
## 支持常见 MD 语法子集，转换后供 RichTextLabel.parse_bbcode 使用
## Godot 4.6 · GDScript 2.0 严格类型
class_name MarkdownToBBCode

## 把 Markdown 文本转为 BBCode
## 支持的语法：
##   #/##/### 标题     → [font_size=N]大字[/font_size]
##   **bold**          → [b]bold[/b]
##   *italic*          → [i]italic[/i]
##   ~~strike~~        → [s]strike[/s]
##   `code`            → [code]code[/code]
##   > quote           → [indent]quote[/indent]
##   - / * 列表项      → • 项
##   [text](url)       → [url=url]text[/url]
##   ![alt](path)      → [img]path[/img]
##   ---               → 水平分隔线（用一排字符模拟）
static func convert(md: String, base_size: int = 16) -> String:
	var lines: PackedStringArray = md.split("\n")
	var out: PackedStringArray = []
	var in_list: bool = false
	# 标题字号 = 基准字号 × 倍数，保证标题永远比正文大（不受正文字号调整影响）
	var h1: int = int(float(base_size) * 1.5)
	var h2: int = int(float(base_size) * 1.3)
	var h3: int = int(float(base_size) * 1.15)
	for raw_line in lines:
		var line: String = raw_line
		# 标题
		if line.begins_with("### "):
			_close_list(out, in_list)
			in_list = false
			out.append("[font_size=%d][b]%s[/b][/font_size]" % [h3, _inline(line.substr(4))])
			continue
		if line.begins_with("## "):
			_close_list(out, in_list)
			in_list = false
			out.append("[font_size=%d][b]%s[/b][/font_size]" % [h2, _inline(line.substr(3))])
			continue
		if line.begins_with("# "):
			_close_list(out, in_list)
			in_list = false
			out.append("[font_size=%d][b]%s[/b][/font_size]" % [h1, _inline(line.substr(2))])
			continue
		# 水平分隔线
		if line.strip_edges() == "---" or line.strip_edges() == "***":
			_close_list(out, in_list)
			in_list = false
			out.append("[color=#cccccc]────────────[/color]")
			continue
		# 引用
		if line.begins_with("> "):
			_close_list(out, in_list)
			in_list = false
			out.append("[indent][color=#666666]" + _inline(line.substr(2)) + "[/color][/indent]")
			continue
		# 列表项
		if line.begins_with("- ") or line.begins_with("* "):
			if not in_list:
				in_list = true
			out.append("• " + _inline(line.substr(2)))
			continue
		# 空行 → 关闭列表
		if line.strip_edges().is_empty():
			_close_list(out, in_list)
			in_list = false
			out.append("")
			continue
		# 普通段落
		_close_list(out, in_list)
		in_list = false
		out.append(_inline(line))
	return "\n".join(out)


## 关闭列表（当前实现列表无特殊包裹，预留扩展）
static func _close_list(out: PackedStringArray, in_list: bool) -> void:
	pass


## 行内语法转换：bold/italic/strike/code/link/image
static func _inline(text: String) -> String:
	var s: String = text
	# 图片 ![alt](path)  —— 先处理避免被链接规则误吃
	s = _replace_pattern(s, "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)", "[img]$2[/img]")
	# 链接 [text](url)
	s = _replace_pattern(s, "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", "[url=$2]$1[/url]")
	# 粗体 **bold**
	s = _replace_pattern(s, "\\*\\*([^*]+)\\*\\*", "[b]$1[/b]")
	# 斜体 *italic*（在粗体之后处理，避免冲突）
	s = _replace_pattern(s, "\\*([^*]+)\\*", "[i]$1[/i]")
	# 删除线 ~~strike~~
	s = _replace_pattern(s, "~~([^~]+)~~", "[s]$1[/s]")
	# 行内代码 `code`
	s = _replace_pattern(s, "`([^`]+)`", "[code]$1[/code]")
	return s


## 用正则替换，保留捕获组
static func _replace_pattern(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return text
	return regex.sub(text, replacement, true)
