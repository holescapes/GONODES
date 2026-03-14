#ifndef GN_NATIVE_AUDIO_DYNAMICS_CHOP_H
#define GN_NATIVE_AUDIO_DYNAMICS_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/templates/hash_map.hpp>

namespace godot {

/// Dynamics processor (compressor/limiter/expander/gate) with per-channel
/// envelope follower state.
class GNNativeAudioDynamicsChop : public RefCounted {
    GDCLASS(GNNativeAudioDynamicsChop, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary process(const Dictionary &in_channels, int mode,
                       double threshold_db, double ratio,
                       double attack_ms, double release_ms,
                       double makeup_db, double sample_rate, bool reset);
    void clear_state();

private:
    HashMap<String, double> _env;

    static double _db_to_lin(double db);
    static double _lin_to_db(double lin);
};

} // namespace godot

#endif
