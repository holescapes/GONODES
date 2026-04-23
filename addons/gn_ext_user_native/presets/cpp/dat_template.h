/*  DAT Template — Minimal starting point for a UserNativeDAT.
 *  Generates a simple table with timestamps.
 */
#ifndef USER_DAT_TEMPLATE_H
#define USER_DAT_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_dat.h>

using namespace godot;

class MyUserDAT : public gn::GNUserNode {
	GDCLASS(MyUserDAT, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_dat"; }
	String get_node_description() const override { return "My custom DAT."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "DAT"; out0["direction"] = "output";
		out0["label"] = "Output table";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::pari("rows", 5, 1, 1000,
			"Rows", "Number of output rows."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		int num_rows = pari(params, "rows", 5);
		float elapsed = parf(context, "elapsed", 0.0);

		PackedStringArray headers;
		headers.push_back("index");
		headers.push_back("value");

		Array rows;
		for (int i = 0; i < num_rows; i++) {
			PackedStringArray row;
			row.push_back(String::num_int64(i));
			row.push_back(String::num(elapsed + float(i), 3));
			rows.push_back(row);
		}
		return gn::make_dat_table(headers, rows);
	}
};

#endif
