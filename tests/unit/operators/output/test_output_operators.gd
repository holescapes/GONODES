extends Node
## Correctness tests for OUT (Output) operators.
##
## Output operators are sinks — they write to files, devices, or windows.
## We test instantiation and parameter defaults; actual I/O is not tested
## in unit tests to avoid side effects.

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


# ═══════════════════════════════════════════════════════════════════════════════
# WindowOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_window_out_instantiate() -> void:
	var node := _make_node(WindowOUT.new(), "win1")
	GNTestAssert.assert_eq(node.node_type, "window", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ImageSaveOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_image_save_out_instantiate() -> void:
	var node := _make_node(ImageSaveOUT.new(), "imsave1")
	GNTestAssert.assert_eq(node.node_type, "image_save", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TextureSaveOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_texture_save_out_instantiate() -> void:
	var node := _make_node(TextureSaveOUT.new(), "texsave1")
	GNTestAssert.assert_eq(node.node_type, "texture_save", "node_type")


func test_texture_save_out_pulse_once_mode() -> void:
	var node := _make_node(TextureSaveOUT.new(), "texsave1") as TextureSaveOUT
	GNTestAssert.assert_eq(node.get_param_value("mode"), 0, "default Continuous")
	node.set_param_value("mode", 1)  # Pulse Once
	GNTestAssert.assert_eq(node.get_param_value("mode"), 1, "Pulse Once")
	# Build a CPU ImageTexture so cook path can run without a SubViewport
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var tex := ImageTexture.create_from_image(img)
	var td := GNTextureData.new()
	td.texture = tex
	td.resolution = Vector2i(8, 8)
	var inputs: Array[GNData] = [td]
	node.set_param_value("active", false)
	node.set_param_value("auto_number", false)
	node.set_param_value("file_path", OS.get_cache_dir().path_join("gonodes_pulse_test"))
	node.execute_cook(inputs, _engine.frame_count)
	node.set_param_value("active", true)
	node.execute_cook(inputs, _engine.frame_count)
	# Held active: pulse-once must not re-enqueue every cook
	var queued_after_rise: int = node._total_queued
	node.execute_cook(inputs, _engine.frame_count)
	node.execute_cook(inputs, _engine.frame_count)
	GNTestAssert.assert_eq(node._total_queued, queued_after_rise, "no extra pulse enqueues")
	node.set_param_value("active", false)
	node.execute_cook(inputs, _engine.frame_count)


# ═══════════════════════════════════════════════════════════════════════════════
# FileCopyOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_file_copy_out_instantiate_in_suite() -> void:
	var node := _make_node(FileCopyOUT.new(), "copy1")
	GNTestAssert.assert_eq(node.node_type, "file_copy", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TableSaveOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_table_save_out_instantiate() -> void:
	var node := _make_node(TableSaveOUT.new(), "tblsave1")
	GNTestAssert.assert_eq(node.node_type, "table_save", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MovieOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_movie_out_instantiate() -> void:
	var node := _make_node(MovieOUT.new(), "movie1")
	GNTestAssert.assert_eq(node.node_type, "movie_out", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RecordOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_record_out_instantiate() -> void:
	var node := _make_node(RecordOUT.new(), "rec1")
	GNTestAssert.assert_eq(node.node_type, "record", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# FFmpegOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_ffmpeg_out_instantiate() -> void:
	var node := _make_node(FFmpegOUT.new(), "ffmpeg1")
	GNTestAssert.assert_eq(node.node_type, "ffmpeg", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# AudioDeviceOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_device_out_instantiate() -> void:
	var node := _make_node(AudioDeviceOUT.new(), "audio1")
	GNTestAssert.assert_eq(node.node_type, "audio_device", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# OscOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_osc_out_instantiate() -> void:
	var node := _make_node(OscOUT.new(), "osc1")
	GNTestAssert.assert_eq(node.node_type, "osc_out", "node_type")
# ═══════════════════════════════════════════════════════════════════════════════
# HapOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_hap_out_instantiate() -> void:
	var node := _make_node(HapOUT.new(), "hap1")
	GNTestAssert.assert_eq(node.node_type, "hap_out", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SinkOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_sink_out_instantiate() -> void:
	var node := _make_node(SinkOUT.new(), "sink1")
	GNTestAssert.assert_eq(node.node_type, "sink", "node_type")


func test_sink_out_active_default() -> void:
	var node := _make_node(SinkOUT.new(), "sink2")
	GNTestAssert.assert_eq(node.get_param_value("active"), true, "active defaults to true")


# ═══════════════════════════════════════════════════════════════════════════════
# OutTunnel
# ═══════════════════════════════════════════════════════════════════════════════

func test_out_tunnel_instantiate() -> void:
	var node := _make_node(OutTunnel.new(), "tunnel1")
	GNTestAssert.assert_eq(node.node_type, "out_tunnel", "node_type")
