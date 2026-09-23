extends Node
## Phase 4l — OSC 1.0 encode/decode. Does not open a UDP socket.
## A pass here is wire format only. Live peer delivery stays UNVERIFIED.


func test_osc_roundtrip_int_float_string() -> void:
	var raw := GNOscParser.encode("/gonodes/tx", [7, 0.5, "hi"])
	var msg := GNOscParser.decode(raw)
	GNTestAssert.assert_not_null(msg, "decoded message")
	GNTestAssert.assert_eq(msg.address, "/gonodes/tx", "address")
	GNTestAssert.assert_eq(msg.type_tags, "ifs", "type tags")
	GNTestAssert.assert_eq(msg.args.size(), 3, "arg count")
	GNTestAssert.assert_eq(msg.args[0], 7, "int")
	GNTestAssert.assert_approx(float(msg.args[1]), 0.5, 0.0001, "float")
	GNTestAssert.assert_eq(str(msg.args[2]), "hi", "string")


func test_osc_roundtrip_bundle() -> void:
	var a := GNOscParser.encode("/a", [1])
	var b := GNOscParser.encode("/b", [2])
	var bundle := GNOscParser.encode_bundle([a, b])
	var msgs := GNOscParser.decode_all(bundle)
	GNTestAssert.assert_eq(msgs.size(), 2, "bundle size")
	if msgs.size() >= 2:
		GNTestAssert.assert_eq(msgs[0].address, "/a", "first address")
		GNTestAssert.assert_eq(msgs[1].address, "/b", "second address")
		GNTestAssert.assert_eq(msgs[0].args[0], 1, "first arg")
		GNTestAssert.assert_eq(msgs[1].args[0], 2, "second arg")
