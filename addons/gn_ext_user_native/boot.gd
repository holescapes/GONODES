## User Native C++ extension boot script — registers code editor language and
## param row code param so the core editor handles "cpp_source" params.
extends RefCounted


static func boot() -> void:
	# Register "cpp_source" as a code-editor-eligible param
	GNParamRow.register_code_param("cpp_source")

	# Register Native C++ code language with preset folder.
	# The preset folder "cpp" matches addons/gn_ext_user_native/presets/cpp/
	GNCodeEditor.register_code_language("cpp_source", {
		"preset_folder": "cpp",
		"file_ext": ".h",
	})
