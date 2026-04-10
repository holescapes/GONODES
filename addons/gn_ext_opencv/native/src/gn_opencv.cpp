#include "gn_opencv.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

// ══════════════════════════════════════════════════════════════════════════════
// Bind methods
// ══════════════════════════════════════════════════════════════════════════════

void GNOpenCV::_bind_methods() {
    ClassDB::bind_method(D_METHOD("threshold", "rgba", "w", "h", "thresh_val", "max_val", "method", "block_size", "c_offset"), &GNOpenCV::threshold);
    ClassDB::bind_method(D_METHOD("morphology", "rgba", "w", "h", "operation", "kernel_shape", "kernel_size", "iterations"), &GNOpenCV::morphology);
    ClassDB::bind_method(D_METHOD("set_blob_tracker_params", "max_track_dist", "max_lost_frames"), &GNOpenCV::set_blob_tracker_params);
    ClassDB::bind_method(D_METHOD("detect_blobs", "rgba", "w", "h", "min_area", "max_area", "circ_min", "circ_max", "conv_min", "conv_max", "iner_min", "iner_max", "draw_ids", "draw_bbox"), &GNOpenCV::detect_blobs);
    ClassDB::bind_method(D_METHOD("get_blob_data"), &GNOpenCV::get_blob_data);
    ClassDB::bind_method(D_METHOD("bg_subtract_init", "method", "history", "threshold"), &GNOpenCV::bg_subtract_init);
    ClassDB::bind_method(D_METHOD("bg_subtract_apply", "rgba", "w", "h", "learning_rate", "detect_shadows"), &GNOpenCV::bg_subtract_apply);
    ClassDB::bind_method(D_METHOD("bg_subtract_reset"), &GNOpenCV::bg_subtract_reset);
    ClassDB::bind_method(D_METHOD("draw_contours", "rgba", "w", "h", "mode", "method", "draw_idx", "color_r", "color_g", "color_b", "thickness", "min_area"), &GNOpenCV::draw_contours);
    ClassDB::bind_method(D_METHOD("get_contour_data"), &GNOpenCV::get_contour_data);
    ClassDB::bind_method(D_METHOD("optical_flow_farneback", "prev_rgba", "curr_rgba", "w", "h", "pyr_scale", "levels", "winsize", "iterations", "poly_n", "poly_sigma", "magnitude_scale"), &GNOpenCV::optical_flow_farneback);
    ClassDB::bind_method(D_METHOD("color_range_mask", "rgba", "w", "h", "low_h", "low_s", "low_v", "high_h", "high_s", "high_v"), &GNOpenCV::color_range_mask);
    ClassDB::bind_method(D_METHOD("get_color_track_data"), &GNOpenCV::get_color_track_data);
    ClassDB::bind_method(D_METHOD("tracker_init", "rgba", "w", "h", "method", "roi_x", "roi_y", "roi_w", "roi_h"), &GNOpenCV::tracker_init);
    ClassDB::bind_method(D_METHOD("tracker_update", "rgba", "w", "h", "draw_color_r", "draw_color_g", "draw_color_b", "draw_thickness"), &GNOpenCV::tracker_update);
    ClassDB::bind_method(D_METHOD("tracker_get_roi"), &GNOpenCV::tracker_get_roi);
    ClassDB::bind_method(D_METHOD("hough_lines", "rgba", "w", "h", "rho", "theta", "threshold", "min_length", "max_gap", "color_r", "color_g", "color_b", "thickness"), &GNOpenCV::hough_lines);
    ClassDB::bind_method(D_METHOD("get_line_data"), &GNOpenCV::get_line_data);
    ClassDB::bind_method(D_METHOD("hough_circles", "rgba", "w", "h", "dp", "min_dist", "high_threshold", "center_threshold", "min_radius", "max_radius", "color_r", "color_g", "color_b", "thickness"), &GNOpenCV::hough_circles);
    ClassDB::bind_method(D_METHOD("get_circle_data"), &GNOpenCV::get_circle_data);
    ClassDB::bind_method(D_METHOD("convolve", "rgba", "w", "h", "kernel", "kernel_w", "kernel_h", "normalize"), &GNOpenCV::convolve);
    ClassDB::bind_method(D_METHOD("find_chessboard", "rgba", "w", "h", "cols", "rows"), &GNOpenCV::find_chessboard);
    ClassDB::bind_method(D_METHOD("calibrate_camera", "all_corners", "cols", "rows", "image_w", "image_h"), &GNOpenCV::calibrate_camera);
    ClassDB::bind_method(D_METHOD("undistort", "rgba", "w", "h", "camera_matrix", "dist_coeffs"), &GNOpenCV::undistort);
    ClassDB::bind_method(D_METHOD("perspective_warp", "rgba", "w", "h", "src_points", "dst_points", "out_w", "out_h", "interpolation"), &GNOpenCV::perspective_warp);
    ClassDB::bind_method(D_METHOD("detect_aruco", "rgba", "w", "h", "dictionary", "draw_color_r", "draw_color_g", "draw_color_b", "draw_thickness", "draw_ids"), &GNOpenCV::detect_aruco);
    ClassDB::bind_method(D_METHOD("get_aruco_data"), &GNOpenCV::get_aruco_data);
    ClassDB::bind_method(D_METHOD("estimate_aruco_pose", "camera_matrix", "dist_coeffs", "marker_size"), &GNOpenCV::estimate_aruco_pose);
    ClassDB::bind_method(D_METHOD("detect_qrcodes", "rgba", "w", "h"), &GNOpenCV::detect_qrcodes);
    ClassDB::bind_method(D_METHOD("match_features", "rgba_a", "w_a", "h_a", "rgba_b", "w_b", "h_b", "method", "max_features", "max_dist", "color_r", "color_g", "color_b", "thickness"), &GNOpenCV::match_features);
    ClassDB::bind_method(D_METHOD("stereo_depth", "rgba_left", "rgba_right", "w", "h", "num_disparities", "block_size", "min_disparity", "uniqueness_ratio", "speckle_window", "speckle_range"), &GNOpenCV::stereo_depth);
    ClassDB::bind_method(D_METHOD("draw_overlay", "rgba", "w", "h", "commands", "label_text"), &GNOpenCV::draw_overlay);
}

GNOpenCV::GNOpenCV() {}
GNOpenCV::~GNOpenCV() {}

// ══════════════════════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════════════════════

cv::Mat GNOpenCV::_rgba_to_mat(const PackedByteArray &rgba, int w, int h) {
    cv::Mat mat(h, w, CV_8UC4);
    if ((int)rgba.size() >= w * h * 4) {
        memcpy(mat.data, rgba.ptr(), w * h * 4);
    }
    return mat;
}

PackedByteArray GNOpenCV::_mat_to_rgba(const cv::Mat &mat) {
    PackedByteArray out;
    cv::Mat rgba;
    if (mat.channels() == 4) {
        rgba = mat;
    } else if (mat.channels() == 3) {
        cv::cvtColor(mat, rgba, cv::COLOR_BGR2RGBA);
    } else if (mat.channels() == 1) {
        cv::cvtColor(mat, rgba, cv::COLOR_GRAY2RGBA);
    } else {
        return out;
    }
    out.resize(rgba.rows * rgba.cols * 4);
    memcpy(out.ptrw(), rgba.data, out.size());
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Threshold
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::threshold(const PackedByteArray &rgba, int w, int h,
        float thresh_val, float max_val, int method, int block_size, float c_offset) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    cv::Mat result;
    switch (method) {
        case 0: cv::threshold(gray, result, thresh_val, max_val, cv::THRESH_BINARY); break;
        case 1: cv::threshold(gray, result, thresh_val, max_val, cv::THRESH_BINARY_INV); break;
        case 2: cv::threshold(gray, result, 0, max_val, cv::THRESH_BINARY | cv::THRESH_OTSU); break;
        case 3: {
            int bs = block_size | 1;
            if (bs < 3) bs = 3;
            cv::adaptiveThreshold(gray, result, max_val, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                cv::THRESH_BINARY, bs, c_offset);
            break;
        }
        case 4: {
            int bs = block_size | 1;
            if (bs < 3) bs = 3;
            cv::adaptiveThreshold(gray, result, max_val, cv::ADAPTIVE_THRESH_MEAN_C,
                cv::THRESH_BINARY, bs, c_offset);
            break;
        }
        default: cv::threshold(gray, result, thresh_val, max_val, cv::THRESH_BINARY); break;
    }
    return _mat_to_rgba(result);
}

// ══════════════════════════════════════════════════════════════════════════════
// Morphology
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::morphology(const PackedByteArray &rgba, int w, int h,
        int operation, int kernel_shape, int kernel_size, int iterations) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    int ks = std::max(1, kernel_size) | 1;
    int shape = cv::MORPH_RECT;
    switch (kernel_shape) {
        case 1: shape = cv::MORPH_CROSS; break;
        case 2: shape = cv::MORPH_ELLIPSE; break;
    }
    cv::Mat kernel = cv::getStructuringElement(shape, cv::Size(ks, ks));

    int op = cv::MORPH_ERODE;
    switch (operation) {
        case 1: op = cv::MORPH_DILATE; break;
        case 2: op = cv::MORPH_OPEN; break;
        case 3: op = cv::MORPH_CLOSE; break;
        case 4: op = cv::MORPH_GRADIENT; break;
        case 5: op = cv::MORPH_TOPHAT; break;
        case 6: op = cv::MORPH_BLACKHAT; break;
    }

    cv::Mat result;
    cv::morphologyEx(src, result, op, kernel, cv::Point(-1, -1), std::max(1, iterations));
    return _mat_to_rgba(result);
}

// ══════════════════════════════════════════════════════════════════════════════
// Blob tracking
// ══════════════════════════════════════════════════════════════════════════════

void GNOpenCV::set_blob_tracker_params(float max_track_dist, int max_lost_frames) {
    _blob_max_track_dist = max_track_dist;
    _blob_max_lost_frames = max_lost_frames;
}

PackedByteArray GNOpenCV::detect_blobs(const PackedByteArray &rgba, int w, int h,
        float min_area, float max_area, float circ_min, float circ_max,
        float conv_min, float conv_max, float iner_min, float iner_max,
        bool draw_ids, bool draw_bbox) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    cv::SimpleBlobDetector::Params params;
    params.filterByArea = true;
    params.minArea = min_area;
    params.maxArea = max_area;
    params.filterByCircularity = (circ_min > 0 || circ_max < 1);
    params.minCircularity = circ_min;
    params.maxCircularity = circ_max;
    params.filterByConvexity = (conv_min > 0 || conv_max < 1);
    params.minConvexity = conv_min;
    params.maxConvexity = conv_max;
    params.filterByInertia = (iner_min > 0 || iner_max < 1);
    params.minInertiaRatio = iner_min;
    params.maxInertiaRatio = iner_max;

    auto detector = cv::SimpleBlobDetector::create(params);
    std::vector<cv::KeyPoint> kps;
    detector->detect(gray, kps);

    // Simple tracking by nearest-neighbour
    std::vector<BlobInfo> new_blobs;
    std::vector<bool> used(_blobs.size(), false);
    for (auto &kp : kps) {
        float best_dist = _blob_max_track_dist;
        int best_idx = -1;
        for (int i = 0; i < (int)_blobs.size(); i++) {
            if (used[i]) continue;
            float dx = kp.pt.x - _blobs[i].cx;
            float dy = kp.pt.y - _blobs[i].cy;
            float d = std::sqrt(dx * dx + dy * dy);
            if (d < best_dist) { best_dist = d; best_idx = i; }
        }
        BlobInfo b;
        b.cx = kp.pt.x;
        b.cy = kp.pt.y;
        b.radius = kp.size * 0.5f;
        b.w = kp.size;
        b.h = kp.size;
        if (best_idx >= 0) {
            b.id = _blobs[best_idx].id;
            used[best_idx] = true;
        } else {
            b.id = _next_blob_id++;
        }
        new_blobs.push_back(b);
    }
    _blobs = new_blobs;

    // Draw overlay
    cv::Mat out = src.clone();
    for (auto &b : _blobs) {
        cv::Scalar color(255, 0, 0, 255);
        if (draw_bbox) {
            cv::rectangle(out,
                cv::Point((int)(b.cx - b.w * 0.5f), (int)(b.cy - b.h * 0.5f)),
                cv::Point((int)(b.cx + b.w * 0.5f), (int)(b.cy + b.h * 0.5f)),
                color, 2);
        }
        if (draw_ids) {
            cv::putText(out, std::to_string(b.id),
                cv::Point((int)b.cx + 5, (int)b.cy - 5),
                cv::FONT_HERSHEY_SIMPLEX, 0.5, color, 1);
        }
    }
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::get_blob_data() {
    PackedFloat32Array out;
    out.push_back((float)_blobs.size());
    for (auto &b : _blobs) {
        out.push_back((float)b.id);
        out.push_back(b.cx);
        out.push_back(b.cy);
        out.push_back(b.radius);
        out.push_back(b.w);
        out.push_back(b.h);
    }
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Background subtraction
// ══════════════════════════════════════════════════════════════════════════════

void GNOpenCV::bg_subtract_init(int method, int history, float p_threshold) {
    if (method == 1) {
        _bg_sub = cv::createBackgroundSubtractorKNN(history, p_threshold, false);
    } else {
        _bg_sub = cv::createBackgroundSubtractorMOG2(history, p_threshold, false);
    }
}

PackedByteArray GNOpenCV::bg_subtract_apply(const PackedByteArray &rgba, int w, int h,
        float learning_rate, bool detect_shadows) {
    if (_bg_sub.empty()) {
        bg_subtract_init(0, 500, 16.0);
    }
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);
    cv::Mat mask;
    _bg_sub->apply(bgr, mask, learning_rate);
    if (!detect_shadows) {
        cv::threshold(mask, mask, 200, 255, cv::THRESH_BINARY);
    }
    return _mat_to_rgba(mask);
}

void GNOpenCV::bg_subtract_reset() {
    _bg_sub.release();
}

// ══════════════════════════════════════════════════════════════════════════════
// Contours
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::draw_contours(const PackedByteArray &rgba, int w, int h,
        int mode, int method, int draw_idx, float color_r, float color_g,
        float color_b, int thickness, float min_area) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    int cv_mode = (mode == 1) ? cv::RETR_TREE : cv::RETR_EXTERNAL;
    int cv_method = (method == 1) ? cv::CHAIN_APPROX_NONE : cv::CHAIN_APPROX_SIMPLE;

    _contours.clear();
    std::vector<cv::Vec4i> hierarchy;
    cv::findContours(gray, _contours, hierarchy, cv_mode, cv_method);

    // Filter by min area
    if (min_area > 0) {
        _contours.erase(std::remove_if(_contours.begin(), _contours.end(),
            [min_area](const std::vector<cv::Point> &c) { return cv::contourArea(c) < min_area; }),
            _contours.end());
    }

    cv::Mat out = src.clone();
    cv::Scalar color((int)(color_b * 255), (int)(color_g * 255),
                     (int)(color_r * 255), 255);
    cv::drawContours(out, _contours, draw_idx, color, thickness);
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::get_contour_data() {
    PackedFloat32Array out;
    out.push_back((float)_contours.size());
    for (int i = 0; i < (int)_contours.size(); i++) {
        auto &c = _contours[i];
        float area = (float)cv::contourArea(c);
        auto m = cv::moments(c);
        float cx = m.m00 > 0 ? (float)(m.m10 / m.m00) : 0;
        float cy = m.m00 > 0 ? (float)(m.m01 / m.m00) : 0;
        float peri = (float)cv::arcLength(c, true);
        out.push_back((float)i);
        out.push_back(area);
        out.push_back(cx);
        out.push_back(cy);
        out.push_back(peri);
        out.push_back((float)c.size());
    }
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Optical flow
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::optical_flow_farneback(const PackedByteArray &prev_rgba,
        const PackedByteArray &curr_rgba, int w, int h,
        float pyr_scale, int levels, int winsize, int iterations,
        int poly_n, float poly_sigma, float magnitude_scale) {
    cv::Mat prev = _rgba_to_mat(prev_rgba, w, h);
    cv::Mat curr = _rgba_to_mat(curr_rgba, w, h);
    cv::Mat prev_gray, curr_gray;
    cv::cvtColor(prev, prev_gray, cv::COLOR_RGBA2GRAY);
    cv::cvtColor(curr, curr_gray, cv::COLOR_RGBA2GRAY);

    cv::Mat flow;
    cv::calcOpticalFlowFarneback(prev_gray, curr_gray, flow,
        pyr_scale, levels, winsize, iterations, poly_n, poly_sigma, 0);

    // Encode flow as RG image (R=horizontal, G=vertical)
    cv::Mat rgba_out(h, w, CV_8UC4);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            cv::Vec2f f = flow.at<cv::Vec2f>(y, x);
            int r = std::clamp((int)(128.0f + f[0] * magnitude_scale), 0, 255);
            int g = std::clamp((int)(128.0f + f[1] * magnitude_scale), 0, 255);
            rgba_out.at<cv::Vec4b>(y, x) = cv::Vec4b((uint8_t)r, (uint8_t)g, 128, 255);
        }
    }
    return _mat_to_rgba(rgba_out);
}

// ══════════════════════════════════════════════════════════════════════════════
// Color tracking
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::color_range_mask(const PackedByteArray &rgba, int w, int h,
        float low_h, float low_s, float low_v,
        float high_h, float high_s, float high_v) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat bgr, hsv;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);

    cv::Scalar lo((int)(low_h * 0.5f), (int)(low_s * 255), (int)(low_v * 255));
    cv::Scalar hi((int)(high_h * 0.5f), (int)(high_s * 255), (int)(high_v * 255));
    cv::Mat mask;
    cv::inRange(hsv, lo, hi, mask);

    // Compute centroid
    auto m = cv::moments(mask, true);
    _color_pixel_count = (int)m.m00;
    _color_area = (float)(m.m00 / 255.0);
    _color_cx = m.m00 > 0 ? (float)(m.m10 / m.m00) : 0;
    _color_cy = m.m00 > 0 ? (float)(m.m01 / m.m00) : 0;

    return _mat_to_rgba(mask);
}

PackedFloat32Array GNOpenCV::get_color_track_data() {
    PackedFloat32Array out;
    out.push_back(_color_cx);
    out.push_back(_color_cy);
    out.push_back(_color_area);
    out.push_back((float)_color_pixel_count);
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Object tracking
// ══════════════════════════════════════════════════════════════════════════════

void GNOpenCV::tracker_init(const PackedByteArray &rgba, int w, int h,
        int method, int roi_x, int roi_y, int roi_w, int roi_h) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);

    _tracker_roi = cv::Rect(roi_x, roi_y, roi_w, roi_h);
    // TrackerMIL is in core OpenCV; KCF/CSRT require opencv_contrib.
    _tracker = cv::TrackerMIL::create();
    _tracker->init(bgr, _tracker_roi);
    _tracker_ok = true;
}

PackedByteArray GNOpenCV::tracker_update(const PackedByteArray &rgba, int w, int h,
        float draw_color_r, float draw_color_g, float draw_color_b, int draw_thickness) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    if (_tracker.empty()) return _mat_to_rgba(src);

    cv::Mat bgr;
    cv::cvtColor(src, bgr, cv::COLOR_RGBA2BGR);
    _tracker_ok = _tracker->update(bgr, _tracker_roi);

    cv::Mat out = src.clone();
    if (_tracker_ok) {
        cv::Scalar color((int)(draw_color_b * 255), (int)(draw_color_g * 255),
                         (int)(draw_color_r * 255), 255);
        cv::rectangle(out, _tracker_roi, color, draw_thickness);
    }
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::tracker_get_roi() {
    PackedFloat32Array out;
    out.push_back((float)_tracker_roi.x);
    out.push_back((float)_tracker_roi.y);
    out.push_back((float)_tracker_roi.width);
    out.push_back((float)_tracker_roi.height);
    out.push_back(_tracker_ok ? 1.0f : 0.0f);
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Hough lines
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::hough_lines(const PackedByteArray &rgba, int w, int h,
        float rho, float theta, int threshold_val, float min_length, float max_gap,
        float color_r, float color_g, float color_b, int thickness) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray, edges;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);
    cv::Canny(gray, edges, 50, 150);

    _lines.clear();
    cv::HoughLinesP(edges, _lines, rho, theta, threshold_val, min_length, max_gap);

    cv::Mat out = src.clone();
    cv::Scalar color((int)(color_b * 255), (int)(color_g * 255),
                     (int)(color_r * 255), 255);
    for (auto &l : _lines) {
        cv::line(out, cv::Point(l[0], l[1]), cv::Point(l[2], l[3]), color, thickness);
    }
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::get_line_data() {
    PackedFloat32Array out;
    out.push_back((float)_lines.size());
    for (auto &l : _lines) {
        out.push_back((float)l[0]);
        out.push_back((float)l[1]);
        out.push_back((float)l[2]);
        out.push_back((float)l[3]);
    }
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Hough circles
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::hough_circles(const PackedByteArray &rgba, int w, int h,
        float dp, float min_dist, float high_threshold, float center_threshold,
        int min_radius, int max_radius,
        float color_r, float color_g, float color_b, int thickness) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(9, 9), 2, 2);

    _circles.clear();
    cv::HoughCircles(gray, _circles, cv::HOUGH_GRADIENT, dp, min_dist,
        high_threshold, center_threshold, min_radius, max_radius);

    cv::Mat out = src.clone();
    cv::Scalar color((int)(color_b * 255), (int)(color_g * 255),
                     (int)(color_r * 255), 255);
    for (auto &c : _circles) {
        cv::circle(out, cv::Point((int)c[0], (int)c[1]), (int)c[2], color, thickness);
        cv::circle(out, cv::Point((int)c[0], (int)c[1]), 3, color, -1);
    }
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::get_circle_data() {
    PackedFloat32Array out;
    out.push_back((float)_circles.size());
    for (auto &c : _circles) {
        out.push_back(c[0]);
        out.push_back(c[1]);
        out.push_back(c[2]);
    }
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// Convolution
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::convolve(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &kernel, int kernel_w, int kernel_h, bool normalize) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat kern(kernel_h, kernel_w, CV_32F);
    for (int i = 0; i < kernel_w * kernel_h && i < (int)kernel.size(); i++) {
        kern.at<float>(i) = kernel[i];
    }
    if (normalize) {
        double s = cv::sum(kern)[0];
        if (std::abs(s) > 1e-6) kern /= s;
    }
    cv::Mat result;
    cv::filter2D(src, result, -1, kern);
    return _mat_to_rgba(result);
}

// ══════════════════════════════════════════════════════════════════════════════
// Camera calibration
// ══════════════════════════════════════════════════════════════════════════════

PackedFloat32Array GNOpenCV::find_chessboard(const PackedByteArray &rgba, int w, int h,
        int cols, int rows) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    std::vector<cv::Point2f> corners;
    bool found = cv::findChessboardCorners(gray, cv::Size(cols, rows), corners);

    PackedFloat32Array out;
    if (found) {
        cv::cornerSubPix(gray, corners, cv::Size(11, 11), cv::Size(-1, -1),
            cv::TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::COUNT, 30, 0.001));
        for (auto &pt : corners) {
            out.push_back(pt.x);
            out.push_back(pt.y);
        }
    }
    return out;
}

Dictionary GNOpenCV::calibrate_camera(const Array &all_corners, int cols, int rows,
        int image_w, int image_h) {
    std::vector<std::vector<cv::Point3f>> obj_points;
    std::vector<std::vector<cv::Point2f>> img_points;

    std::vector<cv::Point3f> objp;
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            objp.push_back(cv::Point3f((float)c, (float)r, 0));

    for (int i = 0; i < (int)all_corners.size(); i++) {
        PackedFloat32Array corners_pf = all_corners[i];
        std::vector<cv::Point2f> pts;
        for (int j = 0; j + 1 < (int)corners_pf.size(); j += 2) {
            pts.push_back(cv::Point2f(corners_pf[j], corners_pf[j + 1]));
        }
        if ((int)pts.size() == cols * rows) {
            obj_points.push_back(objp);
            img_points.push_back(pts);
        }
    }

    Dictionary result;
    if (img_points.empty()) {
        result["reprojection_error"] = -1.0;
        return result;
    }

    cv::Mat cam_matrix, dist_coeffs;
    std::vector<cv::Mat> rvecs, tvecs;
    double rpe = cv::calibrateCamera(obj_points, img_points,
        cv::Size(image_w, image_h), cam_matrix, dist_coeffs, rvecs, tvecs);

    PackedFloat32Array mat_arr;
    mat_arr.resize(9);
    for (int i = 0; i < 9; i++)
        mat_arr[i] = (float)cam_matrix.at<double>(i);

    PackedFloat32Array dist_arr;
    dist_arr.resize(5);
    for (int i = 0; i < std::min(5, (int)dist_coeffs.total()); i++)
        dist_arr[i] = (float)dist_coeffs.at<double>(i);

    result["matrix"] = mat_arr;
    result["distortion"] = dist_arr;
    result["reprojection_error"] = rpe;
    return result;
}

PackedByteArray GNOpenCV::undistort(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &camera_matrix, const PackedFloat32Array &dist_coeffs) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat cam(3, 3, CV_64F);
    for (int i = 0; i < 9 && i < (int)camera_matrix.size(); i++)
        cam.at<double>(i) = camera_matrix[i];

    cv::Mat dist(1, 5, CV_64F, cv::Scalar(0));
    for (int i = 0; i < 5 && i < (int)dist_coeffs.size(); i++)
        dist.at<double>(i) = dist_coeffs[i];

    cv::Mat result;
    cv::undistort(src, result, cam, dist);
    return _mat_to_rgba(result);
}

// ══════════════════════════════════════════════════════════════════════════════
// Perspective warp
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::perspective_warp(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &src_points, const PackedFloat32Array &dst_points,
        int out_w, int out_h, int interpolation) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);

    cv::Point2f src_pts[4], dst_pts[4];
    for (int i = 0; i < 4; i++) {
        src_pts[i] = cv::Point2f(src_points[i * 2], src_points[i * 2 + 1]);
        dst_pts[i] = cv::Point2f(dst_points[i * 2], dst_points[i * 2 + 1]);
    }

    cv::Mat M = cv::getPerspectiveTransform(src_pts, dst_pts);
    int flags = cv::INTER_LINEAR;
    switch (interpolation) {
        case 1: flags = cv::INTER_NEAREST; break;
        case 2: flags = cv::INTER_CUBIC; break;
        case 3: flags = cv::INTER_LANCZOS4; break;
    }
    cv::Mat result;
    cv::warpPerspective(src, result, M, cv::Size(out_w > 0 ? out_w : w, out_h > 0 ? out_h : h), flags);
    return _mat_to_rgba(result);
}

// ══════════════════════════════════════════════════════════════════════════════
// ArUco markers
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::detect_aruco(const PackedByteArray &rgba, int w, int h,
        int dictionary, float draw_color_r, float draw_color_g, float draw_color_b,
        int draw_thickness, bool draw_ids) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    // Map dictionary index to OpenCV predefined dictionaries
    int dict_id = cv::aruco::DICT_4X4_50;
    if (dictionary >= 0 && dictionary <= 15) {
        dict_id = dictionary;  // Direct mapping to cv::aruco::DICT_*
    } else if (dictionary >= 16 && dictionary <= 19) {
        dict_id = cv::aruco::DICT_APRILTAG_16h5 + (dictionary - 16);
    }

    cv::aruco::Dictionary dict = cv::aruco::getPredefinedDictionary(dict_id);
    cv::aruco::ArucoDetector detector(dict);

    _aruco_ids.clear();
    _aruco_corners.clear();
    std::vector<std::vector<cv::Point2f>> rejected;
    detector.detectMarkers(gray, _aruco_corners, _aruco_ids, rejected);

    cv::Mat out = src.clone();
    if (!_aruco_ids.empty()) {
        // Draw detected markers
        for (int i = 0; i < (int)_aruco_ids.size(); i++) {
            auto &corners = _aruco_corners[i];
            cv::Scalar color((int)(draw_color_b * 255), (int)(draw_color_g * 255),
                             (int)(draw_color_r * 255), 255);
            for (int j = 0; j < 4; j++) {
                cv::line(out, corners[j], corners[(j + 1) % 4], color, draw_thickness);
            }
            if (draw_ids) {
                cv::Point2f center(0, 0);
                for (auto &pt : corners) { center.x += pt.x; center.y += pt.y; }
                center.x /= 4; center.y /= 4;
                cv::putText(out, std::to_string(_aruco_ids[i]),
                    cv::Point((int)center.x, (int)center.y),
                    cv::FONT_HERSHEY_SIMPLEX, 0.6, color, 2);
            }
        }
    }
    return _mat_to_rgba(out);
}

PackedFloat32Array GNOpenCV::get_aruco_data() {
    PackedFloat32Array out;
    out.push_back((float)_aruco_ids.size());
    for (int i = 0; i < (int)_aruco_ids.size(); i++) {
        out.push_back((float)_aruco_ids[i]);
        // Center
        float cx = 0, cy = 0;
        for (auto &pt : _aruco_corners[i]) { cx += pt.x; cy += pt.y; }
        cx /= 4; cy /= 4;
        out.push_back(cx);
        out.push_back(cy);
        // 4 corner points
        for (auto &pt : _aruco_corners[i]) {
            out.push_back(pt.x);
            out.push_back(pt.y);
        }
    }
    return out;
}

PackedFloat32Array GNOpenCV::estimate_aruco_pose(const PackedFloat32Array &camera_matrix,
        const PackedFloat32Array &dist_coeffs, float marker_size) {
    PackedFloat32Array out;
    if (_aruco_ids.empty() || camera_matrix.size() < 9 || dist_coeffs.size() < 5) {
        out.push_back(0);
        return out;
    }

    cv::Mat cam(3, 3, CV_64F);
    for (int i = 0; i < 9; i++) cam.at<double>(i) = camera_matrix[i];
    cv::Mat dist(1, 5, CV_64F);
    for (int i = 0; i < 5; i++) dist.at<double>(i) = dist_coeffs[i];

    // Object points for a single marker
    float half = marker_size * 0.5f;
    std::vector<cv::Point3f> obj_pts = {
        {-half, half, 0}, {half, half, 0}, {half, -half, 0}, {-half, -half, 0}
    };

    out.push_back((float)_aruco_ids.size());
    for (int i = 0; i < (int)_aruco_ids.size(); i++) {
        cv::Mat rvec, tvec;
        cv::solvePnP(obj_pts, _aruco_corners[i], cam, dist, rvec, tvec);

        out.push_back((float)_aruco_ids[i]);
        out.push_back((float)rvec.at<double>(0));
        out.push_back((float)rvec.at<double>(1));
        out.push_back((float)rvec.at<double>(2));
        out.push_back((float)tvec.at<double>(0));
        out.push_back((float)tvec.at<double>(1));
        out.push_back((float)tvec.at<double>(2));
    }
    return out;
}

// ══════════════════════════════════════════════════════════════════════════════
// QR code detection
// ══════════════════════════════════════════════════════════════════════════════

Array GNOpenCV::detect_qrcodes(const PackedByteArray &rgba, int w, int h) {
    cv::Mat src = _rgba_to_mat(rgba, w, h);
    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    cv::QRCodeDetector detector;
    std::vector<cv::Point> points;
    std::vector<std::string> decoded_info;
    std::vector<cv::Mat> straight_qrcodes;

    detector.detectAndDecodeMulti(gray, decoded_info, points);

    Array results;
    int pts_per_qr = 4;
    for (int i = 0; i < (int)decoded_info.size(); i++) {
        Dictionary d;
        d["text"] = String(decoded_info[i].c_str());
        d["type"] = String("QR");

        PackedFloat32Array corners;
        int base = i * pts_per_qr;
        for (int j = 0; j < pts_per_qr && base + j < (int)points.size(); j++) {
            corners.push_back((float)points[base + j].x);
            corners.push_back((float)points[base + j].y);
        }
        d["points"] = corners;
        results.push_back(d);
    }
    return results;
}

// ══════════════════════════════════════════════════════════════════════════════
// Feature matching
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::match_features(const PackedByteArray &rgba_a, int w_a, int h_a,
        const PackedByteArray &rgba_b, int w_b, int h_b,
        int method, int max_features, float max_dist,
        float color_r, float color_g, float color_b, int thickness) {
    cv::Mat src_a = _rgba_to_mat(rgba_a, w_a, h_a);
    cv::Mat src_b = _rgba_to_mat(rgba_b, w_b, h_b);
    cv::Mat gray_a, gray_b;
    cv::cvtColor(src_a, gray_a, cv::COLOR_RGBA2GRAY);
    cv::cvtColor(src_b, gray_b, cv::COLOR_RGBA2GRAY);

    cv::Ptr<cv::Feature2D> detector;
    switch (method) {
        case 1: detector = cv::SIFT::create(max_features); break;
        case 2: detector = cv::AKAZE::create(); break;
        default: detector = cv::ORB::create(max_features); break;
    }

    std::vector<cv::KeyPoint> kp_a, kp_b;
    cv::Mat desc_a, desc_b;
    detector->detectAndCompute(gray_a, cv::noArray(), kp_a, desc_a);
    detector->detectAndCompute(gray_b, cv::noArray(), kp_b, desc_b);

    std::vector<cv::DMatch> matches;
    if (!desc_a.empty() && !desc_b.empty()) {
        cv::Ptr<cv::DescriptorMatcher> matcher;
        if (method == 1) {
            matcher = cv::BFMatcher::create(cv::NORM_L2);
        } else {
            matcher = cv::BFMatcher::create(cv::NORM_HAMMING);
        }
        std::vector<cv::DMatch> all_matches;
        matcher->match(desc_a, desc_b, all_matches);

        // Filter by distance
        for (auto &m : all_matches) {
            if (m.distance <= max_dist) matches.push_back(m);
        }
        // Limit count
        if ((int)matches.size() > max_features) matches.resize(max_features);
    }

    // Draw matches side by side
    cv::Scalar color((int)(color_b * 255), (int)(color_g * 255),
                     (int)(color_r * 255), 255);
    cv::Mat out;
    cv::drawMatches(gray_a, kp_a, gray_b, kp_b, matches, out, color,
        cv::Scalar::all(-1), std::vector<char>(), cv::DrawMatchesFlags::DEFAULT);

    // Convert to RGBA
    cv::Mat rgba_result;
    cv::cvtColor(out, rgba_result, cv::COLOR_BGR2RGBA);
    return _mat_to_rgba(rgba_result);
}

// ══════════════════════════════════════════════════════════════════════════════
// Stereo depth
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::stereo_depth(const PackedByteArray &rgba_left,
        const PackedByteArray &rgba_right, int w, int h,
        int num_disparities, int block_size, int min_disparity,
        int uniqueness_ratio, int speckle_window, int speckle_range) {
    cv::Mat left = _rgba_to_mat(rgba_left, w, h);
    cv::Mat right = _rgba_to_mat(rgba_right, w, h);
    cv::Mat gray_l, gray_r;
    cv::cvtColor(left, gray_l, cv::COLOR_RGBA2GRAY);
    cv::cvtColor(right, gray_r, cv::COLOR_RGBA2GRAY);

    int nd = std::max(16, (num_disparities / 16) * 16);
    int bs = block_size | 1;
    if (bs < 5) bs = 5;

    auto stereo = cv::StereoBM::create(nd, bs);
    stereo->setMinDisparity(min_disparity);
    stereo->setUniquenessRatio(uniqueness_ratio);
    stereo->setSpeckleWindowSize(speckle_window);
    stereo->setSpeckleRange(speckle_range);

    cv::Mat disp;
    stereo->compute(gray_l, gray_r, disp);

    // Normalize to 0-255
    cv::Mat disp_norm;
    cv::normalize(disp, disp_norm, 0, 255, cv::NORM_MINMAX, CV_8U);
    return _mat_to_rgba(disp_norm);
}

// ══════════════════════════════════════════════════════════════════════════════
// Draw overlay
// ══════════════════════════════════════════════════════════════════════════════

PackedByteArray GNOpenCV::draw_overlay(const PackedByteArray &rgba, int w, int h,
        const PackedFloat32Array &commands, const String &label_text) {
    cv::Mat out = _rgba_to_mat(rgba, w, h);

    int i = 0;
    int n = (int)commands.size();
    while (i < n) {
        int cmd = (int)commands[i++];
        switch (cmd) {
            case 1: // Rectangle: x, y, w, h, r, g, b, thickness
                if (i + 7 < n) {
                    int rx = (int)commands[i], ry = (int)commands[i+1];
                    int rw = (int)commands[i+2], rh = (int)commands[i+3];
                    cv::Scalar c((int)(commands[i+6]*255), (int)(commands[i+5]*255), (int)(commands[i+4]*255), 255);
                    cv::rectangle(out, cv::Rect(rx, ry, rw, rh), c, (int)commands[i+7]);
                    i += 8;
                }
                break;
            case 2: // Circle: cx, cy, radius, r, g, b, thickness
                if (i + 6 < n) {
                    cv::Scalar c((int)(commands[i+5]*255), (int)(commands[i+4]*255), (int)(commands[i+3]*255), 255);
                    cv::circle(out, cv::Point((int)commands[i], (int)commands[i+1]),
                        (int)commands[i+2], c, (int)commands[i+6]);
                    i += 7;
                }
                break;
            case 3: // Line: x1, y1, x2, y2, r, g, b, thickness
                if (i + 7 < n) {
                    cv::Scalar c((int)(commands[i+6]*255), (int)(commands[i+5]*255), (int)(commands[i+4]*255), 255);
                    cv::line(out, cv::Point((int)commands[i], (int)commands[i+1]),
                        cv::Point((int)commands[i+2], (int)commands[i+3]), c, (int)commands[i+7]);
                    i += 8;
                }
                break;
            case 4: // Crosshair: cx, cy, size, r, g, b, thickness
                if (i + 6 < n) {
                    int cx = (int)commands[i], cy = (int)commands[i+1];
                    int sz = (int)commands[i+2];
                    cv::Scalar c((int)(commands[i+5]*255), (int)(commands[i+4]*255), (int)(commands[i+3]*255), 255);
                    int th = (int)commands[i+6];
                    cv::line(out, cv::Point(cx - sz, cy), cv::Point(cx + sz, cy), c, th);
                    cv::line(out, cv::Point(cx, cy - sz), cv::Point(cx, cy + sz), c, th);
                    i += 7;
                }
                break;
            default:
                i = n; // Unknown command — stop
                break;
        }
    }

    // Label text
    if (label_text.length() > 0) {
        std::string text = std::string(label_text.utf8().get_data());
        cv::putText(out, text, cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX,
            0.7, cv::Scalar(255, 255, 255, 255), 2);
    }

    return _mat_to_rgba(out);
}
