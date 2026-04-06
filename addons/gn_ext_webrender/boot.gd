## WebRender extension boot script — registers code editor languages and param row
## code params so the core editor knows how to handle "html" and "javascript" params.
extends RefCounted


static func boot() -> void:
	if DisplayServer.get_name() == "headless":
		return

	# Register both params as code-editor-eligible
	GNParamRow.register_code_param("html")
	GNParamRow.register_code_param("javascript")

	# Register HTML language
	GNCodeEditor.register_code_language("html", {
		"preset_folder": "html",
		"highlighter": _apply_html_highlighter,
		"ref_text": "HTML5 / CSS3 — <style>, <script>, <canvas>, <div>, <img>, <video>",
		"file_ext": ".html",
	})

	# Register JavaScript language
	GNCodeEditor.register_code_language("javascript", {
		"preset_folder": "js",
		"highlighter": _apply_js_highlighter,
		"ref_text": "JS: document, window, requestAnimationFrame, canvas, ctx, fetch, JSON, Promise",
		"file_ext": ".js",
	})


# ═══════════════════════════════════════════════════════════════════════════════
# HTML Syntax Highlighting
# ═══════════════════════════════════════════════════════════════════════════════

static func _apply_html_highlighter(code_edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings (attributes)
	h.add_color_region('"', '"', Color(0.87, 0.72, 0.45))
	h.add_color_region("'", "'", Color(0.87, 0.72, 0.45))

	# HTML comments
	h.add_color_region("<!--", "-->", Color(0.45, 0.45, 0.45))

	# Script blocks (yellow-green to indicate embedded JS)
	h.add_color_region("<script", "</script>", Color(0.78, 0.82, 0.45))

	# Style blocks (purple-ish to indicate embedded CSS)
	h.add_color_region("<style", "</style>", Color(0.72, 0.55, 0.85))

	# HTML tags
	for tag in ["html", "head", "body", "div", "span", "p", "a", "img",
			"h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li",
			"table", "tr", "td", "th", "form", "input", "button",
			"canvas", "video", "audio", "source", "iframe",
			"section", "header", "footer", "nav", "main", "article",
			"meta", "link", "title", "br", "hr"]:
		h.add_keyword_color(tag, Color(0.5, 0.75, 0.95))

	# HTML attributes
	for attr in ["id", "class", "style", "src", "href", "width", "height",
			"type", "name", "value", "placeholder", "alt", "title",
			"onclick", "onload", "onerror", "data", "charset",
			"content", "rel", "media", "autoplay", "controls", "loop"]:
		h.add_keyword_color(attr, Color(0.9, 0.7, 0.45))

	# CSS properties (commonly used in style attributes)
	for prop in ["color", "background", "margin", "padding", "border",
			"display", "position", "flex", "grid", "font",
			"transform", "transition", "animation", "opacity",
			"overflow", "visibility", "cursor"]:
		h.add_keyword_color(prop, Color(0.55, 0.82, 0.72))

	# Doctype / meta
	h.add_keyword_color("DOCTYPE", Color(0.65, 0.65, 0.65))

	code_edit.syntax_highlighter = h


# ═══════════════════════════════════════════════════════════════════════════════
# JavaScript Syntax Highlighting
# ═══════════════════════════════════════════════════════════════════════════════

static func _apply_js_highlighter(code_edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region('"', '"', Color(0.87, 0.72, 0.45))
	h.add_color_region("'", "'", Color(0.87, 0.72, 0.45))
	h.add_color_region("`", "`", Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)
	h.add_color_region("/*", "*/", Color(0.45, 0.45, 0.45))

	# JS keywords
	for kw in ["var", "let", "const", "function", "return", "if", "else",
			"for", "while", "do", "switch", "case", "break", "continue",
			"new", "this", "class", "extends", "super", "import", "export",
			"default", "try", "catch", "finally", "throw", "typeof",
			"instanceof", "in", "of", "async", "await", "yield",
			"true", "false", "null", "undefined", "void", "delete"]:
		h.add_keyword_color(kw, Color(0.9, 0.45, 0.55))

	# Built-in objects / DOM
	for obj in ["document", "window", "console", "Math", "Date", "Array",
			"Object", "String", "Number", "Boolean", "RegExp", "JSON",
			"Promise", "Map", "Set", "Symbol", "Proxy", "Reflect",
			"Error", "TypeError", "Intl", "globalThis",
			"HTMLElement", "Element", "Node", "Event",
			"navigator", "location", "history", "screen",
			"localStorage", "sessionStorage", "fetch"]:
		h.add_keyword_color(obj, Color(0.5, 0.85, 0.95))

	# Common methods / functions
	for fn in ["getElementById", "querySelector", "querySelectorAll",
			"createElement", "appendChild", "removeChild", "addEventListener",
			"setTimeout", "setInterval", "clearTimeout", "clearInterval",
			"requestAnimationFrame", "cancelAnimationFrame",
			"getContext", "fillRect", "clearRect", "strokeRect",
			"beginPath", "moveTo", "lineTo", "arc", "fill", "stroke",
			"drawImage", "getImageData", "putImageData",
			"log", "warn", "error", "info",
			"parse", "stringify", "then", "catch", "finally",
			"push", "pop", "map", "filter", "reduce", "forEach",
			"toString", "valueOf", "hasOwnProperty"]:
		h.add_keyword_color(fn, Color(0.55, 0.82, 0.72))

	code_edit.syntax_highlighter = h
