#include "gn_native_audio_dynamics_chop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>


namespace godot {

void GNNativeAudioDynamicsChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "in_channels", "mode",
                                  "threshold_db", "ratio",
                                  "attack_ms", "release_ms",
                                  "makeup_db", "sample_rate", "reset"),
                         &GNNativeAudioDynamicsChop::process);
    ClassDB::bind_method(D_METHOD("clear_state"),
                         &GNNativeAudioDynamicsChop::clear_state);
}

double GNNativeAudioDynamicsChop::_db_to_lin(double db) {
    return pow(10.0, db / 20.0);
}

double GNNativeAudioDynamicsChop::_lin_to_db(double lin) {
    if (lin <= 0.0) return -120.0;
    return 20.0 * log10(lin);
}

void GNNativeAudioDynamicsChop::clear_state() {
    _env.clear();
}

Dictionary GNNativeAudioDynamicsChop::process(const Dictionary &in_channels,
                                               int mode,
                                               double threshold_db, double ratio,
                                               double attack_ms, double release_ms,
                                               double makeup_db, double sample_rate,
                                               bool reset) {
    if (reset) _env.clear();

    Dictionary result;
    double thresh_lin = _db_to_lin(threshold_db);
    double makeup_lin = _db_to_lin(makeup_db);
    double sr = sample_rate > 0.0 ? sample_rate : 44100.0;
    double att_coeff = attack_ms > 0.0 ? exp(-1.0 / (attack_ms * 0.001 * sr)) : 0.0;
    double rel_coeff = release_ms > 0.0 ? exp(-1.0 / (release_ms * 0.001 * sr)) : 0.0;

    Array keys = in_channels.keys();
    for (int ci = 0; ci < keys.size(); ++ci) {
        String name = keys[ci];
        Variant cv = in_channels[name];
        if (cv.get_type() != Variant::PACKED_FLOAT32_ARRAY) continue;
        PackedFloat32Array data = cv;
        int len = data.size();
        if (len == 0) continue;

        const float *dp = data.ptr();
        PackedFloat32Array out;
        out.resize(len);
        float *op = out.ptrw();

        double env = 0.0;
        if (_env.has(name)) {
            env = _env[name];
        }

        for (int i = 0; i < len; ++i) {
            double input = (double)dp[i];
            double abs_in = fabs(input);

            // Envelope follower (RC)
            if (abs_in > env) {
                env = att_coeff * env + (1.0 - att_coeff) * abs_in;
            } else {
                env = rel_coeff * env + (1.0 - rel_coeff) * abs_in;
            }

            // Gain computation
            double gain = 1.0;
            if (env > thresh_lin && thresh_lin > 0.0) {
                double env_db = _lin_to_db(env);
                double thresh_db_val = threshold_db;
                double over = env_db - thresh_db_val;

                switch (mode) {
                    case 0: // Compressor
                        gain = _db_to_lin(thresh_db_val + over / ratio - env_db);
                        break;
                    case 1: // Limiter
                        gain = _db_to_lin(thresh_db_val - env_db);
                        break;
                    case 2: // Expander
                        if (env < thresh_lin) {
                            double under = thresh_db_val - env_db;
                            gain = _db_to_lin(-under * (ratio - 1.0));
                        }
                        break;
                    case 3: // Gate
                        if (env < thresh_lin) gain = 0.0;
                        break;
                }
            } else if (mode >= 2 && env <= thresh_lin) {
                // Below threshold for expander/gate
                if (mode == 3) {
                    gain = 0.0;
                } else if (mode == 2 && thresh_lin > 0.0) {
                    double env_db = _lin_to_db(MAX(env, 1e-10));
                    double under = threshold_db - env_db;
                    gain = _db_to_lin(-under * (ratio - 1.0));
                }
            }

            op[i] = (float)(input * gain * makeup_lin);
        }

        _env[name] = env;
        result[name] = out;
    }

    return result;
}

} // namespace godot
