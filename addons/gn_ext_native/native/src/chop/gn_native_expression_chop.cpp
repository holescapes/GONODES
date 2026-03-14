#include "gn_native_expression_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/expression.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

void GNNativeExpressionChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "expr_str", "in_channels",
                                  "ch_names", "base_length",
                                  "time_val", "delta"),
                         &GNNativeExpressionChop::process);
}

Dictionary GNNativeExpressionChop::process(const String &expr_str,
                                            const Dictionary &in_channels,
                                            const PackedStringArray &ch_names,
                                            int base_length,
                                            double time_val, double delta) {
    Dictionary result;

    PackedStringArray var_names;
    var_names.push_back("v");  // current sample value
    var_names.push_back("i");  // sample index
    var_names.push_back("n");  // total samples
    var_names.push_back("ci"); // channel index
    var_names.push_back("t");  // time
    var_names.push_back("dt"); // delta

    Ref<Expression> expr;
    expr.instantiate();
    if (expr->parse(expr_str, var_names) != OK) {
        result["error"] = true;
        return result;
    }

    Array vals;
    vals.resize(6);
    vals[4] = time_val;
    vals[5] = delta;

    int ch_count = ch_names.size();
    for (int ci = 0; ci < ch_count; ++ci) {
        String name = ch_names[ci];
        Variant cv = in_channels.get(name, Variant());
        PackedFloat32Array in_data;
        if (cv.get_type() == Variant::PACKED_FLOAT32_ARRAY) {
            in_data = cv;
        }

        int length = MAX((int)in_data.size(), base_length);
        if (length <= 0) length = 1;

        PackedFloat32Array out_data;
        out_data.resize(length);
        float *op = out_data.ptrw();
        const float *ip = in_data.size() > 0 ? in_data.ptr() : nullptr;

        vals[2] = (double)length;
        vals[3] = (double)ci;

        for (int i = 0; i < length; ++i) {
            float cur = (ip && i < (int)in_data.size()) ? ip[i] : 0.0f;
            vals[0] = (double)cur;
            vals[1] = (double)i;

            Variant r = expr->execute(vals, nullptr, false);
            if (r.get_type() == Variant::FLOAT) op[i] = (float)(double)r;
            else if (r.get_type() == Variant::INT) op[i] = (float)(int64_t)r;
            else op[i] = cur;
        }

        result[name] = out_data;
    }

    return result;
}

} // namespace godot
