#ifndef GN_OPENCV_H
#define GN_OPENCV_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>
#include <opencv2/video.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/objdetect.hpp>
#include <opencv2/objdetect/aruco_detector.hpp>
#include <opencv2/photo.hpp>

#include <vector>
#include <memory>

using namespace godot;

class GNOpenCV : public RefCounted {
    GDCLASS(GNOpenCV, RefCounted);

protected:
    static void _bind_methods();

public:
    GNOpenCV();
    ~GNOpenCV();

    // ── Thresholding ─────────────────────────────────────────────
    PackedByteArray threshold(const PackedByteArray &rgba, int w, int h,
        float thresh_val, float max_val, int method, int block_size, float c_offset);

    // ── Morphology ───────────────────────────────────────────────
    PackedByteArray morphology(const PackedByteArray &rgba, int w, int h,
        int operation, int kernel_shape, int kernel_size, int iterations);

    // ── Blob tracking ────────────────────────────────────────────
    void set_blob_tracker_params(float max_track_dist, int max_lost_frames);
    PackedByteArray detect_blobs(const PackedByteArray &rgba, int w, int h,
        float min_area, float max_area, float circ_min, float circ_max,
        float conv_min, float conv_max, float iner_min, float iner_max,
        bool draw_ids, bool draw_bbox);
    PackedFloat32Array get_blob_data();

    // ── Background subtraction ───────────────────────────────────
    void bg_subtract_init(int method, int history, float threshold);
    PackedByteArray bg_subtract_apply(const PackedByteArray &rgba, int w, int h,
        float learning_rate, bool detect_shadows);
    void bg_subtract_reset();

    // ── Contours ─────────────────────────────────────────────────
    PackedByteArray draw_contours(const PackedByteArray &rgba, int w, int h,
        int mode, int method, int draw_idx, float color_r, float color_g,
        float color_b, int thickness, float min_area);
    PackedFloat32Array get_contour_data();

    // ── Optical flow ─────────────────────────────────────────────
    PackedByteArray optical_flow_farneback(const PackedByteArray &prev_rgba,
        const PackedByteArray &curr_rgba, int w, int h,
        float pyr_scale, int levels, int winsize, int iterations,
        int poly_n, float poly_sigma, float magnitude_scale);

    // ── Color tracking ───────────────────────────────────────────
    PackedByteArray color_range_mask(const PackedByteArray &rgba, int w, int h,
        float low_h, float low_s, float low_v,
        float high_h, float high_s, float high_v);
    PackedFloat32Array get_color_track_data();

    // ── Object tracking ──────────────────────────────────────────
    void tracker_init(const PackedByteArray &rgba, int w, int h,
        int method, int roi_x, int roi_y, int roi_w, int roi_h);
    PackedByteArray tracker_update(const PackedByteArray &rgba, int w, int h,
        float draw_color_r, float draw_color_g, float draw_color_b, int draw_thickness);
    PackedFloat32Array tracker_get_roi();

    // ── Hough lines ──────────────────────────────────────────────
    PackedByteArray hough_lines(const PackedByteArray &rgba, int w, int h,
        float rho, float theta, int threshold_val, float min_length, float max_gap,
        float color_r, float color_g, float color_b, int thickness);
    PackedFloat32Array get_line_data();

    // ── Hough circles ────────────────────────────────────────────
    PackedByteArray hough_circles(const PackedByteArray &rgba, int w, int h,
        float dp, float min_dist, float high_threshold, float center_threshold,
        int min_radius, int max_radius,
        float color_r, float color_g, float color_b, int thickness);
    PackedFloat32Array get_circle_data();

    // ── Convolution ──────────────────────────────────────────────
    PackedByteArray convolve(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &kernel, int kernel_w, int kernel_h, bool normalize);

    // ── Camera calibration ───────────────────────────────────────
    PackedFloat32Array find_chessboard(const PackedByteArray &rgba, int w, int h,
        int cols, int rows);
    Dictionary calibrate_camera(const Array &all_corners, int cols, int rows,
        int image_w, int image_h);
    PackedByteArray undistort(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &camera_matrix, const PackedFloat32Array &dist_coeffs);

    // ── Perspective warp ─────────────────────────────────────────
    PackedByteArray perspective_warp(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &src_points, const PackedFloat32Array &dst_points,
        int out_w, int out_h, int interpolation);

    // ── ArUco markers ────────────────────────────────────────────
    PackedByteArray detect_aruco(const PackedByteArray &rgba, int w, int h,
        int dictionary, float draw_color_r, float draw_color_g, float draw_color_b,
        int draw_thickness, bool draw_ids);
    PackedFloat32Array get_aruco_data();
    PackedFloat32Array estimate_aruco_pose(const PackedFloat32Array &camera_matrix,
        const PackedFloat32Array &dist_coeffs, float marker_size);

    // ── QR code ──────────────────────────────────────────────────
    Array detect_qrcodes(const PackedByteArray &rgba, int w, int h);

    // ── Feature matching ─────────────────────────────────────────
    PackedByteArray match_features(const PackedByteArray &rgba_a, int w_a, int h_a,
        const PackedByteArray &rgba_b, int w_b, int h_b,
        int method, int max_features, float max_dist,
        float color_r, float color_g, float color_b, int thickness);

    // ── Stereo depth ─────────────────────────────────────────────
    PackedByteArray stereo_depth(const PackedByteArray &rgba_left,
        const PackedByteArray &rgba_right, int w, int h,
        int num_disparities, int block_size, int min_disparity,
        int uniqueness_ratio, int speckle_window, int speckle_range);

    // ── Draw overlay ─────────────────────────────────────────────
    PackedByteArray draw_overlay(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &commands, const String &label_text);

private:
    // Helper: RGBA PackedByteArray -> cv::Mat (no copy)
    cv::Mat _rgba_to_mat(const PackedByteArray &rgba, int w, int h);
    // Helper: cv::Mat -> RGBA PackedByteArray
    PackedByteArray _mat_to_rgba(const cv::Mat &mat);

    // Blob tracker state
    struct BlobInfo { int id; float cx, cy, radius, w, h; };
    std::vector<BlobInfo> _blobs;
    int _next_blob_id = 0;
    float _blob_max_track_dist = 80.0f;
    int _blob_max_lost_frames = 5;

    // Background subtractor
    cv::Ptr<cv::BackgroundSubtractor> _bg_sub;

    // Contour data
    std::vector<std::vector<cv::Point>> _contours;

    // Color tracking centroid
    float _color_cx = 0, _color_cy = 0, _color_area = 0;
    int _color_pixel_count = 0;

    // Object tracker
    cv::Ptr<cv::Tracker> _tracker;
    cv::Rect _tracker_roi;
    bool _tracker_ok = false;

    // Hough results
    std::vector<cv::Vec4i> _lines;
    std::vector<cv::Vec3f> _circles;

    // ArUco results
    std::vector<int> _aruco_ids;
    std::vector<std::vector<cv::Point2f>> _aruco_corners;
};

#endif // GN_OPENCV_H
