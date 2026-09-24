class_name GNViewportPool
extends RefCounted
## Recycles SubViewports by resolution + format to reduce GPU memory churn.
##
## Pool key: viewport size, transparent_bg, disable_3d.
## Each bucket is capped at [constant MAX_PER_BUCKET]; extras are freed.

const MAX_PER_BUCKET := 16
const META_POOL_MANAGED := "_gn_pool_managed"

static var _buckets: Dictionary = {}


static func _make_key(size: Vector2i, transparent_bg: bool, disable_3d: bool) -> String:
	return "%d,%d,%d,%d" % [size.x, size.y, int(transparent_bg), int(disable_3d)]


static func _configure_viewport(vp: SubViewport, size: Vector2i,
		transparent_bg: bool, disable_3d: bool) -> void:
	vp.size = size
	vp.transparent_bg = transparent_bg
	vp.disable_3d = disable_3d
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.gui_disable_input = true


static func acquire(vp_name: String, size: Vector2i,
		transparent_bg: bool = true, disable_3d: bool = true) -> SubViewport:
	var key := _make_key(size, transparent_bg, disable_3d)
	var bucket: Array = _buckets.get(key, [])
	var vp: SubViewport = null
	while not bucket.is_empty():
		vp = bucket.pop_back()
		if is_instance_valid(vp) and not vp.is_queued_for_deletion():
			break
		vp = null
	if vp == null:
		vp = SubViewport.new()
	if not vp_name.is_empty():
		vp.name = vp_name
	_configure_viewport(vp, size, transparent_bg, disable_3d)
	vp.set_meta(META_POOL_MANAGED, true)
	_buckets[key] = bucket
	return vp


static func release(vp: SubViewport) -> void:
	if vp == null or not is_instance_valid(vp):
		return
	if vp.is_queued_for_deletion():
		return
	var parent := vp.get_parent()
	if parent != null:
		parent.remove_child(vp)
	while vp.get_child_count() > 0:
		var child := vp.get_child(0)
		vp.remove_child(child)
		child.free()
	_configure_viewport(vp, vp.size, vp.transparent_bg, vp.disable_3d)
	var key := _make_key(vp.size, vp.transparent_bg, vp.disable_3d)
	var bucket: Array = _buckets.get(key, [])
	if bucket.size() >= MAX_PER_BUCKET:
		vp.free()
		return
	bucket.append(vp)
	_buckets[key] = bucket


static func is_pool_managed(vp: SubViewport) -> bool:
	return vp != null and is_instance_valid(vp) and vp.has_meta(META_POOL_MANAGED)
