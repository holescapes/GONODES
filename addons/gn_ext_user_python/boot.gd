## User Python extension boot script — registers code editor language and
## param row code param so the core editor handles "py_source" params.
extends RefCounted


static func boot() -> void:
	# Register "py_source" as a code-editor-eligible param
	GNParamRow.register_code_param("py_source")

	# Register Python code language with preset folder.
	# The preset folder "python" matches addons/gn_ext_user_python/presets/python/
	GNCodeEditor.register_code_language("py_source", {
		"preset_folder": "python",
		"file_ext": ".py",
	})
