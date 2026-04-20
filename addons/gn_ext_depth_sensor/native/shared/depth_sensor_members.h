// depth_sensor_members.h — Shared member declarations for depth sensor classes.
// Include this INSIDE the class body, after the constructor/destructor declarations.

    PackedStringArray get_available_backends();
    TypedArray<Dictionary> enumerate_devices();
    bool open_device(const String &serial, const String &backend_name);
    void close_device();
    bool is_device_open() const;
    int get_capabilities() const;
    bool has_capability(int cap) const;
    String get_active_backend() const;

    bool capture(int timeout_ms = 33);

    PackedByteArray get_depth_rgba(int max_mm = 5000);
    int get_depth_width() const;
    int get_depth_height() const;
    PackedByteArray get_depth_raw();

    PackedByteArray get_color_rgba();
    int get_color_width() const;
    int get_color_height() const;

    PackedByteArray get_ir_rgba();
    int get_ir_width() const;
    int get_ir_height() const;

    PackedByteArray get_player_index_rgba();

    TypedArray<Dictionary> get_skeleton_data();
    int get_joint_count() const;

    PackedFloat32Array get_point_cloud_positions();
    PackedByteArray get_point_cloud_colors();
    int get_point_count() const;

    Dictionary get_floor_plane();

    TypedArray<Dictionary> get_hand_data();
    int get_hand_count() const;

private:
    std::unique_ptr<DepthSensorBackend> m_backend;
    std::string m_active_backend_name;

    // Cached frame data (filled by capture())
    std::vector<uint8_t> m_depth_buf;
    std::vector<uint8_t> m_color_buf;
    std::vector<uint8_t> m_ir_buf;
    std::vector<uint8_t> m_player_idx_buf;
    std::vector<DepthSensorBody> m_bodies;
    std::vector<float> m_pc_positions;
    std::vector<uint8_t> m_pc_colors;

    int m_depth_w = 0, m_depth_h = 0;
    int m_color_w = 0, m_color_h = 0;
    int m_ir_w = 0, m_ir_h = 0;
    int m_player_w = 0, m_player_h = 0;
    int m_point_count = 0;

    float m_floor_nx = 0, m_floor_ny = 1, m_floor_nz = 0, m_floor_d = 0;
    bool m_floor_valid = false;

    std::vector<DepthSensorHand> m_hands;
