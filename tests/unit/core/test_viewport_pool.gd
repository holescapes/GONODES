extends Node
## Unit tests for GNViewportPool acquire/release recycling.


func test_acquire_release_reuses_same_viewport() -> void:
	var vp1 := GNViewportPool.acquire("TestVP", Vector2i(128, 64), true, true)
	GNTestAssert.assert_not_null(vp1, "acquire should return a SubViewport")
	GNTestAssert.assert_eq(vp1.size, Vector2i(128, 64), "acquire should set requested size")

	GNViewportPool.release(vp1)

	var vp2 := GNViewportPool.acquire("TestVP2", Vector2i(128, 64), true, true)
	GNTestAssert.assert_eq(vp2, vp1, "same pool key should reuse the released viewport")

	var vp3 := GNViewportPool.acquire("TestVP3", Vector2i(256, 64), true, true)
	GNTestAssert.assert_ne(vp3, vp1, "different size should not reuse the viewport")

	GNViewportPool.release(vp2)
	GNViewportPool.release(vp3)
