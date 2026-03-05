class_name GNMarkdownRenderer
extends RefCounted
## Lightweight Markdown → BBCode converter for RichTextLabel display.
##
## Supports:
##   # H1, ## H2, ### H3          → [font_size] + [b]
##   **bold**, *italic*            → [b], [i]
##   `inline code`                 → [code][bgcolor]
##   ```code blocks```             → [code][bgcolor] block
##   | tables |                    → [table] BBCode
##   - unordered lists             → bullet indented
##   1. ordered lists              → numbered indented
##   --- horizontal rule           → [color]────────[/color]
##   [link text](url)              → [url] or plain text
##
## Usage:
##   var bbcode := GNMarkdownRenderer.render(markdown_text)

## Accent color for headers (can be overridden before calling render).
static var header_color: String = "#7eb8da"

## Background tint for code spans/blocks.
static var code_bg_color: String = "#1a1a2e"

## Muted color for horizontal rules.
static var rule_color: String = "#444444"


## Converts a Markdown string to BBCode.
static func render(md: String) -> String:
	var lines := md.split("\n")
	var bb := ""
	var in_code_block := false
	var code_block_lines: PackedStringArray = PackedStringArray()
	var in_table := false
	var table_cols := 0
	var table_row_idx := 0

	for i in range(lines.size()):
		var line: String = lines[i]

		# ── Code block toggle ──
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				# Close code block
				bb += "[/bgcolor][/code]\n\n"
				in_code_block = false
				code_block_lines.clear()
			else:
				# Open code block
				in_code_block = true
				bb += "[code][bgcolor=%s]" % code_bg_color
			continue

		if in_code_block:
			# Inside code block — preserve whitespace, escape BBCode
			bb += _escape_bbcode(line) + "\n"
			continue

		# ── Table detection ──
		var stripped := line.strip_edges()
		if stripped.begins_with("|") and stripped.ends_with("|"):
			var cells := _parse_table_row(stripped)
			# Separator row (|---|---|) — skip but don't break table
			if cells.size() > 0 and _is_separator_row(cells):
				continue
			if not in_table:
				in_table = true
				table_cols = cells.size()
				table_row_idx = 0
				bb += "[table=%d]" % table_cols
			# Emit table cells
			for ci in range(cells.size()):
				var cell_text := cells[ci].strip_edges()
				if table_row_idx == 0:
					bb += "[cell][b][color=#aaaaaa]%s[/color][/b][/cell]" % _inline(cell_text)
				else:
					bb += "[cell]%s[/cell]" % _inline(cell_text)
			# Pad if fewer cells than header
			for _pad in range(table_cols - cells.size()):
				bb += "[cell][/cell]"
			bb += "\n"
			table_row_idx += 1
			continue
		elif in_table:
			bb += "[/table]\n"
			in_table = false
			table_row_idx = 0

		# ── Horizontal rule ──
		if stripped == "---" or stripped == "***" or stripped == "___":
			bb += "[color=%s]────────────────────────────────────────[/color]\n\n" % rule_color
			continue

		# ── Headers ──
		if stripped.begins_with("### "):
			bb += "[font_size=15][b]%s[/b][/font_size]\n" % _inline(stripped.substr(4))
			continue
		if stripped.begins_with("## "):
			bb += "\n[font_size=17][b][color=%s]%s[/color][/b][/font_size]\n" % [header_color, _inline(stripped.substr(3))]
			continue
		if stripped.begins_with("# "):
			bb += "\n[font_size=22][b][color=%s]%s[/color][/b][/font_size]\n" % [header_color, _inline(stripped.substr(2))]
			continue

		# ── Unordered list ──
		if stripped.begins_with("- ") or stripped.begins_with("* "):
			bb += "  •  %s\n" % _inline(stripped.substr(2))
			continue

		# ── Ordered list ──
		var ol_match := _match_ordered_list(stripped)
		if not ol_match.is_empty():
			bb += "  %s  %s\n" % [ol_match, _inline(stripped.substr(ol_match.length() + 1).strip_edges())]
			continue

		# ── Blockquote ──
		if stripped.begins_with("> "):
			bb += "[indent][color=#999999][i]%s[/i][/color][/indent]\n" % _inline(stripped.substr(2))
			continue

		# ── Blank line ──
		if stripped.is_empty():
			bb += "\n"
			continue

		# ── Regular paragraph ──
		bb += _inline(line) + "\n"

	# Close any open table
	if in_table:
		bb += "[/table]\n"
	# Close any unclosed code block
	if in_code_block:
		bb += "[/bgcolor][/code]\n"

	return bb


## Processes inline Markdown formatting within a single line.
## Handles: **bold**, *italic*, `code`, [link](url)
static func _inline(text: String) -> String:
	var result := text

	# Inline code: `text` → [code][bgcolor]text[/bgcolor][/code]
	result = _replace_pattern(result, "`", "[code][bgcolor=%s]" % code_bg_color, "[/bgcolor][/code]")

	# Bold: **text** → [b]text[/b]
	result = _replace_pattern(result, "**", "[b]", "[/b]")

	# Italic: *text* → [i]text[/i]
	result = _replace_pattern(result, "*", "[i]", "[/i]")

	# Links: [text](url) — render as [url=url]text[/url]
	var link_regex := RegEx.new()
	link_regex.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	var link_match := link_regex.search(result)
	while link_match != null:
		var full := link_match.get_string()
		var link_text := link_match.get_string(1)
		var url := link_match.get_string(2)
		result = result.replace(full, "[color=#6699cc]%s[/color]" % link_text)
		link_match = link_regex.search(result)

	return result


## Replaces paired delimiters with BBCode open/close tags.
## e.g., _replace_pattern("hello **world**", "**", "[b]", "[/b]")
## Only replaces non-nested pairs from left to right.
static func _replace_pattern(text: String, delim: String, open_tag: String, close_tag: String) -> String:
	var result := ""
	var idx := 0
	var is_open := false
	while idx < text.length():
		if text.substr(idx, delim.length()) == delim:
			if is_open:
				result += close_tag
			else:
				result += open_tag
			is_open = not is_open
			idx += delim.length()
		else:
			result += text[idx]
			idx += 1
	# If we have an unclosed delimiter, it was a false start — just leave it
	return result


## Parses a Markdown table row: "| a | b | c |" → ["a", "b", "c"]
static func _parse_table_row(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	var parts := line.split("|")
	for p in parts:
		var trimmed := p.strip_edges()
		if not trimmed.is_empty():
			cells.append(trimmed)
	return cells


## Returns true if all cells in a row are separator patterns (---, :--:, etc.)
static func _is_separator_row(cells: PackedStringArray) -> bool:
	for cell in cells:
		var c := cell.strip_edges()
		if c.is_empty():
			continue
		# Must be only dashes, colons, and spaces
		var valid := true
		for ch_idx in range(c.length()):
			var ch := c[ch_idx]
			if ch != "-" and ch != ":" and ch != " ":
				valid = false
				break
		if not valid:
			return false
	return true


## Matches "1. ", "2. ", etc. and returns the number prefix or "".
static func _match_ordered_list(text: String) -> String:
	if text.length() < 3:
		return ""
	var dot_idx := text.find(". ")
	if dot_idx <= 0 or dot_idx > 4:
		return ""
	var num_part := text.substr(0, dot_idx)
	if num_part.is_valid_int():
		return num_part + "."
	return ""


## Escapes characters that have special meaning in BBCode.
static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")
