extends Node
## Tests for GNAssetBrowser filtering helpers.

const _AssetBrowser := preload("res://addons/gonodes/ui/gn_asset_browser.gd")


func test_asset_browser_filter_description_query() -> void:
	var assets: Array = [{
		"name": "DemoAsset",
		"description": "Bezier warp with built-in interactive panel",
		"family": "TOP",
	}]
	var filtered: Array = _AssetBrowser.filter_custom_assets(assets, "interactive", "")
	GNTestAssert.assert_eq(filtered.size(), 1,
		"Should keep asset whose description contains the query")
	GNTestAssert.assert_eq(filtered[0].get("name", ""), "DemoAsset",
		"Filtered asset name should match")


func test_asset_browser_filter_family() -> void:
	var assets: Array = [
		{"name": "TopAsset", "description": "A TOP asset", "family": "TOP"},
		{"name": "ChopAsset", "description": "A CHOP asset", "family": "CHOP"},
	]
	var filtered: Array = _AssetBrowser.filter_custom_assets(assets, "", "CHOP")
	GNTestAssert.assert_eq(filtered.size(), 1, "Should keep only CHOP family")
	GNTestAssert.assert_eq(filtered[0].get("name", ""), "ChopAsset",
		"CHOP asset should remain")
