extends Node
## Unit tests for FileCopyOUT (rising-edge disk copy).

var _network: GNNetwork
var _engine: GNCookEngine
var _tmp_dir: String = ""


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)
	_tmp_dir = OS.get_cache_dir().path_join("gonodes_filecopy_test_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_tmp_dir)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()
	if not _tmp_dir.is_empty() and DirAccess.dir_exists_absolute(_tmp_dir):
		var d := DirAccess.open(_tmp_dir)
		if d != null:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if fn != "." and fn != "..":
					d.remove(fn)
				fn = d.get_next()
			d.list_dir_end()
		DirAccess.remove_absolute(_tmp_dir)


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _write_src(name: String, body: String) -> String:
	var path: String = _tmp_dir.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	GNTestAssert.assert_not_null(f, "write src")
	if f != null:
		f.store_string(body)
		f.close()
	return path


func test_file_copy_instantiate() -> void:
	var node := _make_node(FileCopyOUT.new(), "copy1")
	GNTestAssert.assert_eq(node.node_type, "file_copy", "node_type")


func test_file_copy_static_ok() -> void:
	var src := _write_src("a.txt", "hello-bitrots")
	var dst := _tmp_dir.path_join("b.txt")
	var err := FileCopyOUT.copy_file(src, dst, true, true)
	GNTestAssert.assert_eq(err, OK, "copy ok")
	GNTestAssert.assert_true(FileAccess.file_exists(dst), "dest exists")
	var got := FileAccess.get_file_as_string(dst)
	GNTestAssert.assert_eq(got, "hello-bitrots", "contents match")


func test_file_copy_no_overwrite() -> void:
	var src := _write_src("a.txt", "new")
	var dst := _write_src("b.txt", "old")
	var err := FileCopyOUT.copy_file(src, dst, false, true)
	GNTestAssert.assert_eq(err, ERR_ALREADY_EXISTS, "refuse overwrite")
	GNTestAssert.assert_eq(FileAccess.get_file_as_string(dst), "old", "dest unchanged")


func test_file_copy_rising_edge() -> void:
	var src := _write_src("src.bin", "pulse")
	var dst := _tmp_dir.path_join("dst.bin")
	var node := _make_node(FileCopyOUT.new(), "copy1") as FileCopyOUT
	node.set_param_value("source", src)
	node.set_param_value("dest", dst)
	node.set_param_value("overwrite", true)
	node.set_param_value("make_dirs", true)
	node.set_param_value("active", false)
	node.execute_cook([], _engine.frame_count)
	GNTestAssert.assert_true(not FileAccess.file_exists(dst), "no copy while inactive")
	node.set_param_value("active", true)
	node.execute_cook([], _engine.frame_count)
	GNTestAssert.assert_true(FileAccess.file_exists(dst), "copied on rising edge")
	# Hold active — should not re-copy / fail
	DirAccess.remove_absolute(dst)
	node.execute_cook([], _engine.frame_count)
	GNTestAssert.assert_true(not FileAccess.file_exists(dst), "no second copy while held")
