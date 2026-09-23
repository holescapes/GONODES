extends Node
## Phase 4b audit tests — copy-on-write ownership.
##
## Contract (dev_docs/DATA_TYPES.md §4–§6, GONODES_CONTEXT.md §21):
##   - Each node owns cached_output. Downstream must not mutate it when anyone
##     else can still read it (another wire, or a viewer).
##   - _mutable_input() duplicates only when GNData._shared is set.
##   - The cook engine sets _shared when consumer count > 1.
##   - A viewer on the producer counts as a consumer of that producer.


var _engine: GNCookEngine
var _network: GNNetwork


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 0
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


func _make(script_class, id: String) -> GNNode:
	var node: GNNode = script_class.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _cook() -> void:
	_engine.cook_frame(_engine.current_delta)


func test_cow_mutable_input_sole_consumer_returns_original() -> void:
	var node := GNNode.new()
	var src := GNChannelData.new()
	src.set_channel("out", PackedFloat32Array([1.0, 2.0]))
	src._shared = false
	var got := node._mutable_input(src)
	GNTestAssert.assert_eq(got, src, "sole consumer is zero-copy")
	GNTestAssert.assert_null(node._mutable_input(null), "null stays null")
	node.free()


func test_cow_mutable_input_shared_duplicates_and_isolates() -> void:
	var node := GNNode.new()
	var src := GNChannelData.new()
	src.set_channel("out", PackedFloat32Array([1.0, 2.0]))
	src._shared = true
	var copy := node._mutable_input(src) as GNChannelData
	GNTestAssert.assert_ne(copy, src, "shared input is duplicated")
	GNTestAssert.assert_false(copy._shared, "duplicate is a private copy")
	copy.set_channel("out", PackedFloat32Array([9.0, 9.0]))
	GNTestAssert.assert_approx(src.get_value("out", 0), 1.0, 0.001, "upstream channel unchanged")
	node.free()


func test_cow_image_duplicate_does_not_alias_pixels() -> void:
	var src := GNImageData.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	src.set_image(img)
	src._shared = true
	var copy := src.duplicate_data() as GNImageData
	GNTestAssert.assert_false(copy._shared, "duplicate clears _shared")
	copy.image.set_pixel(0, 0, Color.BLUE)
	GNTestAssert.assert_eq(src.image.get_pixel(0, 0), Color.RED, "upstream pixel unchanged")


func test_cow_table_duplicate_does_not_alias_rows() -> void:
	var src := GNTableData.new()
	src.has_header = false
	src.append_row(PackedStringArray(["keep"]))
	var copy := src.duplicate_data() as GNTableData
	copy.set_cell(0, 0, "changed")
	GNTestAssert.assert_eq(src.cell(0, 0), "keep", "upstream cell unchanged")


func test_cow_wire_fanout_marks_shared() -> void:
	var a := _make(ConstantCHOP, "a")
	a.set_param_value("name0", "ch")
	a.set_param_value("value0", 3.0)
	_make(NullCHOP, "b")
	_make(NullCHOP, "c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("a", 0, "c", 0)
	var sinks: Array[String] = ["b", "c"]
	_engine.set_active_sinks(sinks)
	_cook()
	GNTestAssert.assert_not_null(a.cached_output, "producer cooked")
	GNTestAssert.assert_gt(_engine._consumer_counts.get("a", 0), 1, "two wires count as fan-out")
	# NullCHOP returns the upstream GNData object. The engine then stamps
	# _shared from the null's own consumer count (0) onto that same object.
	GNTestAssert.assert_true(a.cached_output._shared, "fan-out _shared must survive passthrough")


func test_cow_sole_wire_consumer_stays_unshared() -> void:
	## Intentional zero-copy: one downstream wire and no viewer.
	var a := _make(ConstantCHOP, "a")
	a.set_param_value("name0", "ch")
	a.set_param_value("value0", 3.0)
	var b := _make(NullCHOP, "b")
	b.is_sink = true
	_network.connect_nodes("a", 0, "b", 0)
	_engine.set_active_sinks([] as Array[String])
	_cook()
	GNTestAssert.assert_not_null(a.cached_output, "producer cooked via sink")
	GNTestAssert.assert_false(a.cached_output._shared, "single wire is not shared")


func test_cow_viewer_on_producer_counts_as_consumer() -> void:
	## DATA_TYPES.md §5: the viewer reads cached_output outside the wire graph.
	## A producer with one mutating downstream AND a viewer must be _shared,
	## or the viewer shows the mutated buffer.
	var a := _make(ConstantCHOP, "a")
	a.set_param_value("name0", "ch")
	a.set_param_value("value0", 3.0)
	var b := _make(NullCHOP, "b")
	b.is_sink = true
	_network.connect_nodes("a", 0, "b", 0)
	var sinks: Array[String] = ["a"]
	_engine.set_active_sinks(sinks)
	_cook()
	GNTestAssert.assert_true(a.cached_output._shared,
		"viewer on the producer is an extra consumer")


func test_cow_fanout_pixel_sort_does_not_alias_upstream_image() -> void:
	var noise := _make(NoiseIMG, "noise")
	noise.set_param_value("resolution", Vector2i(8, 8))
	noise.set_param_value("type", 1)
	_make(PixelSortIMG, "sort")
	_make(NullIMG, "other")
	_network.connect_nodes("noise", 0, "sort", 0)
	_network.connect_nodes("noise", 0, "other", 0)
	var sinks: Array[String] = ["sort", "other"]
	_engine.set_active_sinks(sinks)
	_cook()
	var n_out := noise.cached_output as GNImageData
	var s_out := _network.nodes["sort"].cached_output as GNImageData
	GNTestAssert.assert_not_null(n_out, "noise cooked")
	GNTestAssert.assert_not_null(s_out, "sort cooked")
	GNTestAssert.assert_not_null(n_out.image, "noise has an image")
	GNTestAssert.assert_not_null(s_out.image, "sort has an image")
	GNTestAssert.assert_false(n_out.image == s_out.image,
		"fan-out PixelSort must not alias the producer's Image")


func test_cow_null_cooked_before_sort_does_not_alias() -> void:
	## Passthrough stamps _shared from its own consumer count onto the
	## producer's object. If that null cooks before an in-place filter,
	## the filter sees _shared == false and mutates the shared Image.
	var noise := _make(NoiseIMG, "noise")
	noise.set_param_value("resolution", Vector2i(8, 8))
	noise.set_param_value("type", 1)
	_make(NullIMG, "other")
	_make(PixelSortIMG, "sort")
	_network.connect_nodes("noise", 0, "other", 0)
	_network.connect_nodes("noise", 0, "sort", 0)
	var sinks: Array[String] = ["other", "sort"]
	_engine.set_active_sinks(sinks)
	_cook()
	var n_out := noise.cached_output as GNImageData
	var s_out := _network.nodes["sort"].cached_output as GNImageData
	GNTestAssert.assert_not_null(n_out.image, "noise image")
	GNTestAssert.assert_not_null(s_out.image, "sort image")
	GNTestAssert.assert_false(n_out.image == s_out.image,
		"NullIMG cooking first must not clear _shared before PixelSort")


func test_cow_viewer_on_noise_pixel_sort_does_not_alias() -> void:
	## Behavioral form of test_viewer_on_producer_counts_as_consumer.
	## PixelSortIMG writes pixels in place, then publishes that same Image.
	var noise := _make(NoiseIMG, "noise")
	noise.set_param_value("resolution", Vector2i(8, 8))
	noise.set_param_value("type", 1)
	var sort := _make(PixelSortIMG, "sort")
	sort.is_sink = true
	_network.connect_nodes("noise", 0, "sort", 0)
	var sinks: Array[String] = ["noise"]
	_engine.set_active_sinks(sinks)
	_cook()
	var n_out := noise.cached_output as GNImageData
	var s_out := sort.cached_output as GNImageData
	GNTestAssert.assert_not_null(n_out.image, "noise image")
	GNTestAssert.assert_not_null(s_out.image, "sort image")
	GNTestAssert.assert_false(n_out.image == s_out.image,
		"viewer + in-place sort must not share the producer's Image")
