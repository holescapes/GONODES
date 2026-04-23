/*  csv_parse_dat.h — Example UserNativeDAT
 *  High-performance CSV parser using C++ string operations.
 *  Load this via: UserNativeDAT → Templates → Examples → CSV Parser
 */
#ifndef CSV_PARSE_DAT_H
#define CSV_PARSE_DAT_H

#include <gn_user_node.h>
#include <gn_user_dat.h>

using namespace godot;

class CSVParseDAT : public gn::GNUserNode {
	GDCLASS(CSVParseDAT, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "csv_parse_dat"; }
	String get_node_description() const override {
		return "Fast CSV parser — reads text input and produces a structured table.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "text_in"; in0["family"] = "DAT"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Raw CSV text";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "table_out"; out0["family"] = "DAT"; out0["direction"] = "output";
		out0["label"] = "Parsed table";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::pars("delimiter", ",",
			"Delimiter", "Column separator character."));
		params.push_back(gn::parb("first_row_headers", true,
			"First Row Headers", "Treat the first row as column headers."));
		params.push_back(gn::parb("trim_whitespace", true,
			"Trim Whitespace", "Strip leading/trailing whitespace from cells."));
		params.push_back(gn::pari("max_rows", 0, 0, 1000000,
			"Max Rows", "Maximum rows to parse (0 = unlimited)."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		String delim     = pars(params, "delimiter", ",");
		bool   headers   = parb(params, "first_row_headers", true);
		bool   do_trim   = parb(params, "trim_whitespace", true);
		int    max_rows  = pari(params, "max_rows", 0);

		// Get input text
		String text = gn::get_input_text(inputs, 0);
		if (text.is_empty())
			return Dictionary();

		char32_t sep = delim.is_empty() ? ',' : delim[0];

		// Split into lines
		PackedStringArray lines = text.split("\n", false);
		if (lines.is_empty())
			return Dictionary();

		int start_row = 0;
		PackedStringArray out_headers;

		// Parse header row
		if (headers && lines.size() > 0) {
			PackedStringArray cells = lines[0].split(String::chr(sep));
			for (int i = 0; i < cells.size(); i++) {
				String cell = cells[i];
				if (do_trim) cell = cell.strip_edges();
				out_headers.push_back(cell);
			}
			start_row = 1;
		}

		// Parse data rows
		Array rows;
		int row_count = 0;

		for (int r = start_row; r < lines.size(); r++) {
			if (max_rows > 0 && row_count >= max_rows)
				break;

			String line = lines[r];
			if (line.strip_edges().is_empty())
				continue;

			PackedStringArray cells = line.split(String::chr(sep));
			PackedStringArray out_row;

			for (int c = 0; c < cells.size(); c++) {
				String cell = cells[c];
				if (do_trim) cell = cell.strip_edges();
				// Handle quoted fields (strip surrounding quotes)
				if (cell.length() >= 2 && cell[0] == '"' && cell[cell.length()-1] == '"') {
					cell = cell.substr(1, cell.length() - 2);
				}
				out_row.push_back(cell);
			}

			rows.push_back(out_row);
			row_count++;
		}

		// Generate default headers if none
		if (out_headers.is_empty() && rows.size() > 0) {
			PackedStringArray first_row = rows[0];
			for (int i = 0; i < first_row.size(); i++) {
				out_headers.push_back(String("col") + String::num_int64(i));
			}
		}

		return gn::make_dat_table(out_headers, rows);
	}
};

#endif // CSV_PARSE_DAT_H
