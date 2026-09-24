extends Node
## Semantic palette tag derivation and search matching.


func test_palette_tags_audio_operator_gets_audio_tag() -> void:
	var reg := GNExtensionRegistry.instance()
	GNTestAssert.assert_true(reg.has_operator("AudioInCHOP"),
		"AudioInCHOP should be registered in the core manifest")
	var tags := reg.get_tags("AudioInCHOP")
	GNTestAssert.assert_true(tags.has("audio"),
		"AudioInCHOP should derive the audio tag, got: %s" % str(tags))


func test_palette_tags_matches_audio_query() -> void:
	var reg := GNExtensionRegistry.instance()
	GNTestAssert.assert_true(
		GNNodePalette.matches_operator_query("AudioInCHOP", "audio", reg),
		"Palette search for 'audio' should match AudioInCHOP via name or tag")
