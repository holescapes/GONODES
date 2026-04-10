class_name GNPattern
## Global pattern matching, expansion, and rename-capture utility.
##
## Provides a single, consistent pattern language used across all GONODES
## operators that filter, select, or rename channels, nodes, files, and
## indices.  Inspired by TouchDesigner + Houdini pattern syntax.
##
## ────────────────────────────────────────────────────────────────────────
## QUICK REFERENCE (see dev_docs/PATTERNS.md for full details)
##
## NAME MATCHING:
##   *            any string              (matches everything)
##   ?            any single char         (tx? → tx1, txA)
##   [abc]        character set           (t[xyz] → tx, ty, tz)
##   [a-z]        character range
##   [!abc]       negated set             (not a, b, or c)
##   *mid*        contains
##   prefix*      starts with
##   *suffix      ends with
##
## MULTI-PATTERN (comma-separated, exclusion with !):
##   tx, ty, tz           union of three exact names
##   *, !temp*            everything except temp-prefixed
##   chan*, !chan3         channels starting with "chan" but not "chan3"
##
## INDEX RANGES:
##   5                    exact index
##   0-10                 range 0 to 10 inclusive
##   0-10:2               stride — every 2nd  (0, 2, 4, 6, 8, 10)
##   0-20:3,7             take-skip — take 3, skip 4, repeat
##   *:3                  every 3rd of all
##   !5-10                exclude range
##
## EXPANSION (generate names from patterns):
##   ch[1-4]              → ch1 ch2 ch3 ch4
##   [rgb]_out            → r_out g_out b_out
##   ch[0-8:2]            → ch0 ch2 ch4 ch6 ch8
##   [tr][xyz]            → tx ty tz rx ry rz  (cartesian product)
##
## RENAME CAPTURE:
##   from: *_old   to: *(0)_new       foo_old → foo_new
##   from: *_*     to: *(1)_*(0)      aa_bb → bb_aa
##   from: ?x      to: ?(0)y          tx → ty
## ────────────────────────────────────────────────────────────────────────

# RegEx is a Godot built-in class
static var _regex_cache: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# NAME MATCHING
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true if [param text] matches [param pattern] (single glob pattern).
## Supports *, ?, [abc], [a-z], [!abc].  Case-sensitive.
static func matches(text: String, pattern: String) -> bool:
	if pattern == "*":
		return true
	if pattern == text:
		return true
	# Convert glob to regex
	var regex_str := _glob_to_regex(pattern)
	return _regex_test(regex_str, text)


## Returns true if [param text] matches any pattern in a comma-separated
## pattern string.  Patterns prefixed with ! are exclusions.
## Examples:  "tx, ty", "*, !temp*", "chan*, !chan3"
static func matches_any(text: String, csv_patterns: String) -> bool:
	var parsed := split_patterns(csv_patterns)
	# Must match at least one include pattern
	var included := false
	for pat in parsed["include"]:
		if matches(text, pat):
			included = true
			break
	if not included:
		return false
	# Must not match any exclude pattern
	for pat in parsed["exclude"]:
		if matches(text, pat):
			return false
	return true


## Filters [param names] by a comma-separated pattern string.
## Returns only the names that match (respecting ! exclusion).
static func filter(names: PackedStringArray, csv_patterns: String) -> PackedStringArray:
	var result := PackedStringArray()
	for name in names:
		if matches_any(name, csv_patterns):
			result.append(name)
	return result


## Splits a comma-separated pattern string into include and exclude lists.
## Returns {"include": PackedStringArray, "exclude": PackedStringArray}.
static func split_patterns(csv: String) -> Dictionary:
	var includes := PackedStringArray()
	var excludes := PackedStringArray()
	var parts := csv.split(",")
	for part in parts:
		var trimmed := part.strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed.begins_with("!"):
			excludes.append(trimmed.substr(1).strip_edges())
		else:
			includes.append(trimmed)
	# If no explicit includes, default to match-all
	if includes.is_empty() and not excludes.is_empty():
		includes.append("*")
	return {"include": includes, "exclude": excludes}


# ═══════════════════════════════════════════════════════════════════════════════
# INDEX RANGES
# ═══════════════════════════════════════════════════════════════════════════════

## Parses an index range string and returns matching indices up to [param count].
##
## Supported syntax:
##   "5"          → [5]
##   "0-10"       → [0,1,2,...,10]
##   "0-10:2"     → [0,2,4,6,8,10]            (stride)
##   "0-20:3,7"   → [0,1,2, 7,8,9, 14,15,16]  (take 3, period 7)
##   "*:3"        → [0,3,6,9,...] up to count   (every Nth of all)
##   "!5-10"      → all indices 0..count-1 EXCEPT 5..10
##
## Multiple ranges can be comma-separated: "0-5, 10-15, 20"
## [param count] is the total number of elements (defines upper bound).
static func parse_index_range(range_str: String, count: int) -> PackedInt32Array:
	var result_set: Dictionary = {}  # index → true, used as a set
	var parts := range_str.split(",")

	# Two-pass: first collect all includes, then apply excludes
	var includes: Array[String] = []
	var excludes: Array[String] = []

	for part in parts:
		var trimmed := part.strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed.begins_with("!"):
			excludes.append(trimmed.substr(1).strip_edges())
		else:
			includes.append(trimmed)

	# Parse include ranges
	for inc in includes:
		var indices := _parse_single_range(inc, count)
		for idx in indices:
			result_set[idx] = true

	# Parse exclude ranges and remove
	for exc in excludes:
		var indices := _parse_single_range(exc, count)
		for idx in indices:
			result_set.erase(idx)

	# Sort and return
	var keys: Array = result_set.keys()
	keys.sort()
	var result := PackedInt32Array()
	for k in keys:
		result.append(int(k))
	return result


## Parses a single range token (no comma, no ! prefix).
static func _parse_single_range(token: String, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	# "*:N" or "*:take,period" — every Nth of all
	if token.begins_with("*"):
		if token == "*":
			# All indices
			for i in range(count):
				result.append(i)
			return result
		# "*:stride" or "*:take,period"
		var after_star := token.substr(1)
		if after_star.begins_with(":"):
			after_star = after_star.substr(1)
			return _parse_stride_range(0, count - 1, after_star, count)
		return result

	# Check for range: "n-m" or "n-m:stride" or plain "n"
	var dash_pos := token.find("-")
	if dash_pos < 0:
		# Plain number
		var idx := token.to_int()
		if idx >= 0 and idx < count:
			result.append(idx)
		return result

	# Has dash: "n-m" with optional ":stride"
	var range_part := token
	var stride_part := ""
	var colon_pos := token.find(":")
	if colon_pos > 0:
		range_part = token.left(colon_pos)
		stride_part = token.substr(colon_pos + 1)

	var parts := range_part.split("-")
	if parts.size() < 2:
		return result
	var start := parts[0].strip_edges().to_int()
	var end := parts[1].strip_edges().to_int()

	if stride_part.is_empty():
		# Simple range
		for i in range(start, mini(end, count - 1) + 1):
			if i >= 0:
				result.append(i)
	else:
		result = _parse_stride_range(start, end, stride_part, count)

	return result


## Handles stride and take-skip patterns within a range [start, end].
## [param stride_str] is the part after ':', e.g. "2" or "3,7"
static func _parse_stride_range(start: int, end: int, stride_str: String,
		count: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	var stride_parts := stride_str.split(",")
	if stride_parts.size() == 1:
		# Simple stride: take every Nth
		var stride := maxi(stride_parts[0].strip_edges().to_int(), 1)
		var i := start
		while i <= end and i < count:
			if i >= 0:
				result.append(i)
			i += stride
	elif stride_parts.size() >= 2:
		# Take-skip: "take,period" — take first N, skip rest, repeat every period
		var take := maxi(stride_parts[0].strip_edges().to_int(), 1)
		var period := maxi(stride_parts[1].strip_edges().to_int(), take + 1)
		var i := start
		while i <= end and i < count:
			# Take phase
			for t in range(take):
				var idx := i + t
				if idx > end or idx >= count:
					break
				if idx >= 0:
					result.append(idx)
			i += period

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# EXPANSION (generate names from a pattern)
# ═══════════════════════════════════════════════════════════════════════════════

## Expands a pattern string into a list of names.
## Brackets in the pattern are expanded combinatorially (cartesian product).
##
## Examples:
##   "ch[1-3]"      → ["ch1", "ch2", "ch3"]
##   "[rgb]_out"     → ["r_out", "g_out", "b_out"]
##   "[tr][xyz]"     → ["tx", "ty", "tz", "rx", "ry", "rz"]
##   "ch[0-8:2]"    → ["ch0", "ch2", "ch4", "ch6", "ch8"]
##   "hello"         → ["hello"]
##
## Multiple space-separated tokens are each expanded independently:
##   "ch[1-2] pos[xyz]" → ["ch1", "ch2", "posx", "posy", "posz"]
static func expand(pattern: String) -> PackedStringArray:
	var tokens := pattern.strip_edges().split(" ", false)
	var all_results := PackedStringArray()
	for token in tokens:
		var expanded := _expand_token(token.strip_edges())
		for s in expanded:
			all_results.append(s)
	return all_results


## Expands a single token (no spaces) by processing all [...] groups left to right.
static func _expand_token(token: String) -> PackedStringArray:
	# Find all bracket groups and the text segments between them
	var segments: Array = []  # Array of PackedStringArray — each is a set of alternatives
	var pos := 0
	while pos < token.length():
		var open := token.find("[", pos)
		if open < 0:
			# Rest of string is literal
			segments.append(PackedStringArray([token.substr(pos)]))
			break

		# Literal text before the bracket
		if open > pos:
			segments.append(PackedStringArray([token.substr(pos, open - pos)]))

		# Find the closing bracket
		var close := token.find("]", open + 1)
		if close < 0:
			# Malformed — treat rest as literal
			segments.append(PackedStringArray([token.substr(pos)]))
			break

		# Parse bracket contents
		var inner := token.substr(open + 1, close - open - 1)
		segments.append(_expand_bracket(inner))
		pos = close + 1

	if segments.is_empty():
		return PackedStringArray([token])

	# Cartesian product of all segments
	var results := PackedStringArray([""])
	for seg in segments:
		var new_results := PackedStringArray()
		for prefix in results:
			for suffix in seg:
				new_results.append(prefix + suffix)
		results = new_results

	return results


## Expands the contents inside [...], e.g. "1-3", "rgb", "0-8:2", "1,3,5".
static func _expand_bracket(inner: String) -> PackedStringArray:
	var result := PackedStringArray()

	# Check if it looks numeric (contains digits and - or :)
	var has_digit := false
	var has_dash := false
	for ch in inner:
		if ch >= "0" and ch <= "9":
			has_digit = true
		if ch == "-":
			has_dash = true

	if has_digit and (has_dash or inner.contains(":") or inner.contains(",")):
		# Numeric range: "1-5", "0-10:2", "1,3,5", "1-3,7,9-11"
		var parts := inner.split(",")
		for part in parts:
			part = part.strip_edges()
			if part.contains("-"):
				var range_part := part
				var stride := 1
				if part.contains(":"):
					var colon := part.find(":")
					range_part = part.left(colon)
					stride = maxi(part.substr(colon + 1).to_int(), 1)
				var dash := range_part.find("-")
				var start := range_part.left(dash).to_int()
				var end := range_part.substr(dash + 1).to_int()
				var i := start
				while i <= end:
					result.append(str(i))
					i += stride
			else:
				# Single number
				result.append(part)
	else:
		# Alpha set: each character is an alternative
		for ch in inner:
			result.append(ch)

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# RENAME (match + capture + replace)
# ═══════════════════════════════════════════════════════════════════════════════

## Renames [param text] by matching against [param from_pat] and substituting
## captured wildcard segments into [param to_pat].
##
## Wildcard captures:
##   *(N) — text captured by the Nth * in from_pat (0-based)
##   ?(N) — text captured by the Nth ? in from_pat (0-based)
##
## Expansion in to_pat:
##   [1-3]  — expanded as a sequence (used with rename_batch for 1-to-many)
##
## Returns [param text] unchanged if it doesn't match [param from_pat].
static func rename(text: String, from_pat: String, to_pat: String) -> String:
	var captures := _capture_wildcards(text, from_pat)
	if captures.is_empty():
		return text  # No match — pass through unchanged
	return _apply_replacement(to_pat, captures)


## Renames a batch of names.  Returns {old_name: new_name} for all names
## that match [param from_pat].  Non-matching names are not included.
##
## If [param to_pat] contains [N-M] expansion syntax, the expanded names
## are assigned sequentially to matching inputs.
static func rename_batch(names: PackedStringArray, from_pat: String,
		to_pat: String) -> Dictionary:
	var result: Dictionary = {}

	# Check if to_pat uses expansion (produces multiple output names)
	var expanded_to := expand(to_pat)
	var use_expansion := expanded_to.size() > 1

	var match_idx := 0
	for name in names:
		var captures := _capture_wildcards(name, from_pat)
		if captures.is_empty():
			continue
		if use_expansion:
			# Assign expanded names sequentially
			if match_idx < expanded_to.size():
				result[name] = expanded_to[match_idx]
			else:
				# More matches than expanded names — apply capture to last expanded
				result[name] = _apply_replacement(expanded_to[expanded_to.size() - 1], captures)
		else:
			result[name] = _apply_replacement(to_pat, captures)
		match_idx += 1

	return result


## Captures wildcard segments from matching [param text] against [param pattern].
## Returns {"star": [...], "question": [...]} or an empty Dictionary if no match.
##
## For pattern "pre*_mid_*suf" matching "preHELLO_mid_WORLDsuf":
##   star[0] = "HELLO", star[1] = "WORLD"
static func _capture_wildcards(text: String, pattern: String) -> Dictionary:
	# Build a capturing regex from the glob pattern
	var regex_str := "^"
	var star_count := 0
	var q_count := 0
	var i := 0
	while i < pattern.length():
		var ch: String = pattern[i]
		match ch:
			"*":
				regex_str += "(.*?)"  # Non-greedy capture for *
				star_count += 1
			"?":
				regex_str += "(.)"    # Single char capture for ?
				q_count += 1
			"[":
				# Pass through character class as-is
				var close := pattern.find("]", i + 1)
				if close > i:
					var bracket := pattern.substr(i, close - i + 1)
					regex_str += _bracket_to_regex(bracket)
					i = close
				else:
					regex_str += "\\["
			".":
				regex_str += "\\."
			"(", ")", "+", "^", "$", "{", "}", "|", "\\":
				regex_str += "\\" + ch
			_:
				regex_str += ch
		i += 1

	# Make the last * greedy so it captures the rest
	# Find the last "(.*?)" and replace with "(.*)"
	var last_lazy := regex_str.rfind("(.*?)")
	if last_lazy >= 0:
		regex_str = regex_str.left(last_lazy) + "(.*)" + regex_str.substr(last_lazy + 5)

	regex_str += "$"

	var regex := RegEx.new()
	var err := regex.compile(regex_str)
	if err != OK:
		return {}

	var result := regex.search(text)
	if result == null:
		return {}

	# Distribute captured groups back to star and question lists
	var stars := PackedStringArray()
	var questions := PackedStringArray()
	var group_idx := 1  # RegEx groups are 1-based
	i = 0
	while i < pattern.length():
		var ch: String = pattern[i]
		match ch:
			"*":
				if group_idx <= result.get_group_count():
					stars.append(result.get_string(group_idx))
					group_idx += 1
			"?":
				if group_idx <= result.get_group_count():
					questions.append(result.get_string(group_idx))
					group_idx += 1
			"[":
				var close := pattern.find("]", i + 1)
				if close > i:
					i = close
		i += 1

	return {"star": stars, "question": questions}


## Substitutes captured wildcards into a replacement pattern.
## Replaces *(N) with star captures and ?(N) with question captures.
## Also handles bare * and ? (equivalent to *(0) and ?(0) for single-wildcard patterns).
static func _apply_replacement(to_pat: String, captures: Dictionary) -> String:
	var out := to_pat
	var stars: PackedStringArray = captures.get("star", PackedStringArray())
	var questions: PackedStringArray = captures.get("question", PackedStringArray())

	# Replace indexed captures: *(0), *(1), ..., ?(0), ?(1), ...
	for idx in range(stars.size()):
		out = out.replace("*(%d)" % idx, stars[idx])
	for idx in range(questions.size()):
		out = out.replace("?(%d)" % idx, questions[idx])

	# Handle bare * and ? as aliases for *(0) and ?(0)
	# Only if no indexed captures remain in the string
	if not out.contains("*(") and stars.size() > 0:
		# Replace first bare * only
		var star_pos := out.find("*")
		if star_pos >= 0:
			out = out.left(star_pos) + stars[0] + out.substr(star_pos + 1)
	if not out.contains("?(") and questions.size() > 0:
		var q_pos := out.find("?")
		if q_pos >= 0:
			out = out.left(q_pos) + questions[0] + out.substr(q_pos + 1)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Converts a glob pattern to a regex string (no anchors).
static func _glob_to_regex(pattern: String) -> String:
	var regex_str := "^"
	var i := 0
	while i < pattern.length():
		var ch: String = pattern[i]
		match ch:
			"*":
				regex_str += ".*"
			"?":
				regex_str += "."
			"[":
				var close := pattern.find("]", i + 1)
				if close > i:
					var bracket := pattern.substr(i, close - i + 1)
					regex_str += _bracket_to_regex(bracket)
					i = close
				else:
					regex_str += "\\["
			".":
				regex_str += "\\."
			"(", ")", "+", "^", "$", "{", "}", "|", "\\":
				regex_str += "\\" + ch
			_:
				regex_str += ch
		i += 1
	regex_str += "$"
	return regex_str


## Converts a bracket expression like [abc], [a-z], [!abc] to regex.
static func _bracket_to_regex(bracket: String) -> String:
	# bracket includes the [ and ] characters
	var inner := bracket.substr(1, bracket.length() - 2)
	if inner.begins_with("!"):
		return "[^" + _escape_bracket_inner(inner.substr(1)) + "]"
	return "[" + _escape_bracket_inner(inner) + "]"


## Escapes special regex characters inside a bracket expression,
## preserving the - for ranges.
static func _escape_bracket_inner(inner: String) -> String:
	var out := ""
	for ch in inner:
		match ch:
			"]":
				out += "\\]"
			"\\":
				out += "\\\\"
			_:
				out += ch
	return out


## Tests if text matches a pre-built regex string.  Uses a small cache.
static func _regex_test(regex_str: String, text: String) -> bool:
	var regex: RegEx
	if _regex_cache.has(regex_str):
		regex = _regex_cache[regex_str]
	else:
		regex = RegEx.new()
		regex.compile(regex_str)
		# Keep cache bounded
		if _regex_cache.size() > 256:
			_regex_cache.clear()
		_regex_cache[regex_str] = regex
	return regex.search(text) != null
