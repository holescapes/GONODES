extends SceneTree
## Headless script: pack one res://addons/gn_ext_<name>/ folder into
## templates/extensions/gn_ext_<name>.pck using Godot's PCKPacker.
##
## Usage:
##   godot --headless --path <project> -s scripts/pack_extension.gd -- gn_ext_foo


const FORBIDDEN_FOLDER := "gn_ext_native"
const OUTPUT_DIR := "res://templates/extensions"


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		push_error("Missing extension folder name. Example: -s scripts/pack_extension.gd -- gn_ext_mapper")
		quit(1)
		return

	var folder_name := str(user_args[0]).strip_edges()
	if not folder_name.begins_with("gn_ext_"):
		folder_name = "gn_ext_" + folder_name

	if folder_name == FORBIDDEN_FOLDER:
		push_error("Refusing to pack %s" % FORBIDDEN_FOLDER)
		quit(1)
		return

	var src_dir := "res://addons/%s" % folder_name
	if not DirAccess.dir_exists_absolute(src_dir):
		push_error("Extension folder not found: %s" % src_dir)
		quit(1)
		return

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		var mk_err := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		if mk_err != OK:
			push_error("Could not create output directory %s (error %d)" % [OUTPUT_DIR, mk_err])
			quit(1)
			return

	var out_path := "%s/%s.pck" % [OUTPUT_DIR, folder_name]
	var packer := PCKPacker.new()
	var err := packer.pck_start(out_path)
	if err != OK:
		push_error("pck_start failed for %s (error %d)" % [out_path, err])
		quit(1)
		return

	err = _pack_directory(packer, src_dir)
	if err != OK:
		push_error("Failed adding files from %s (error %d)" % [src_dir, err])
		quit(1)
		return

	err = packer.flush(true)
	if err != OK:
		push_error("flush failed for %s (error %d)" % [out_path, err])
		quit(1)
		return

	print("[pack_extension] Wrote %s from %s" % [out_path, src_dir])
	quit(0)


func _pack_directory(packer: PCKPacker, res_dir: String) -> Error:
	var dir := DirAccess.open(res_dir)
	if dir == null:
		return ERR_CANT_OPEN
	return _pack_directory_recursive(packer, dir, res_dir)


func _pack_directory_recursive(packer: PCKPacker, dir: DirAccess, res_dir: String) -> Error:
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		var res_path := res_dir.path_join(entry_name)
		if dir.current_is_dir():
			if entry_name != "." and entry_name != "..":
				var sub := DirAccess.open(res_path)
				if sub == null:
					return ERR_CANT_OPEN
				var sub_err := _pack_directory_recursive(packer, sub, res_path)
				if sub_err != OK:
					dir.list_dir_end()
					return sub_err
		else:
			var add_err := packer.add_file(res_path, res_path)
			if add_err != OK:
				dir.list_dir_end()
				return add_err
		entry_name = dir.get_next()
	dir.list_dir_end()
	return OK
