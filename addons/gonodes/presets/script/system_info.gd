# @param string format %H:%M:%S Time format string

func cook():
	var dict := Time.get_datetime_dict_from_system()
	op.set_headers(PackedStringArray(["key", "value"]))
	op.append_row(PackedStringArray(["year", str(dict.year)]))
	op.append_row(PackedStringArray(["month", str(dict.month)]))
	op.append_row(PackedStringArray(["day", str(dict.day)]))
	op.append_row(PackedStringArray(["hour", str(dict.hour)]))
	op.append_row(PackedStringArray(["minute", str(dict.minute)]))
	op.append_row(PackedStringArray(["second", str(dict.second)]))
	op.append_row(PackedStringArray(["weekday", str(dict.weekday)]))
	op.append_row(PackedStringArray(["unix", str(Time.get_unix_time_from_system())]))
