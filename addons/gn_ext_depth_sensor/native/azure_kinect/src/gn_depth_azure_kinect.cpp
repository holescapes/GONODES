#include "gn_depth_azure_kinect.h"
#include <godot_cpp/variant/utility_functions.hpp>

extern std::unique_ptr<DepthSensorBackend> create_azure_kinect_backend();

#define GN_DEPTH_CLASS GNDepthAzureKinect
#define GN_DEPTH_BACKEND_NAME "azure_kinect"
#define GN_DEPTH_BACKEND_FACTORY create_azure_kinect_backend

#include "depth_sensor_impl.h"
