/*  dat_row_filter.h — Example UserNativeDAT
 *  Filters rows from an input DAT table by matching a column against a pattern.
 *  Demonstrates get_input_table() for DAT input reading.
 *  Load this via: UserNativeDAT → Templates → Examples → Row Filter
 */
#ifndef DAT_ROW_FILTER_H
#define DAT_ROW_FILTER_H

#include <gn_user_node.h>
#include <gn_user_dat.h>

using namespace godot;

class DATRowFilter : public gn::GNUserNode {
	GDCLASS(DATRowFilter, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "dat_row_filter"; }
	String get_node_description() const override {
		return "Filters rows from input table: keep or discard rows matching a text pattern.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in";  in0["family"] = "DAT"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input table";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "DAT"; out0["direction"] = "output";
		out0["label"] = "Filtered table";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::pars("pattern", "",
			"Pattern", "Text to match against column values (case-insensitive)."));
		params.push_back(gn::pari("column", 0, 0, 100,
			"Column", "Column index to match against (0-based)."));
		params.push_back(gn::parb("invert", false,
			"Invert", "Discard matching rows instead of keeping them."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		String pattern = pars(params, "pattern", "");
		int    col     = pari(params, "column", 0);
		bool   invert  = parb(params, "invert", false);

		PackedStringArray headers;
		Array rows;
		if (!gn::get_input_table(inputs, 0, headers, rows))
			return Dictionary();

		Array filtered;
		String pat_lower = pattern.to_lower();

		for (int r = 0; r < rows.size(); r++) {
			PackedStringArray row = rows[r];
			bool match = false;
			if (col < row.size()) {
				String cell = row[col].to_lower();
				match = cell.contains(pat_lower);
			}
			bool keep = invert ? !match : match;
			if (pattern.is_empty())
				keep = true;  // empty pattern = pass all
			if (keep)
				filtered.push_back(row);
		}

		return gn::make_dat_table(headers, filtered);
	}
};

#endif // DAT_ROW_FILTER_H
