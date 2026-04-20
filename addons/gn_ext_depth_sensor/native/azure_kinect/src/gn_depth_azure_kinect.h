#ifndef GN_DEPTH_AZURE_KINECT_H
#define GN_DEPTH_AZURE_KINECT_H

#include "depth_sensor_backend.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <memory>
#include <vector>
#include <string>

using namespace godot;

class GNDepthAzureKinect : public RefCounted {
    GDCLASS(GNDepthAzureKinect, RefCounted);

protected:
    static void _bind_methods();

public:
    GNDepthAzureKinect();
    ~GNDepthAzureKinect();

#include "depth_sensor_members.h"
};

#endif // GN_DEPTH_AZURE_KINECT_H
