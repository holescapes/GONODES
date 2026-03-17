#include "gn_hap_decoder.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>
#include <algorithm>

// HAP section types (from hap.h spec)
#define HAP_SECTION_HEADER_SIZE 4
#define HAP_COMPRESSOR_NONE     0x00
#define HAP_COMPRESSOR_SNAPPY   0x01
#define HAP_FORMAT_RGB_DXT1     0x0B
#define HAP_FORMAT_RGBA_DXT5    0x0E
#define HAP_FORMAT_YCOCG_DXT5   0x0F

// Forward-declare Snappy decompress (from thirdparty/snappy)
extern "C" {
    // snappy-c.h interface
    typedef int snappy_status;
    snappy_status snappy_uncompressed_length(const char *compressed, size_t compressed_length, size_t *result);
    snappy_status snappy_uncompress(const char *compressed, size_t compressed_length, char *uncompressed, size_t *uncompressed_length);
}

namespace godot {

// ── Binding ───────────────────────────────────────────────────────────────────

void GNHapDecoder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open", "file_path"), &GNHapDecoder::open);
    ClassDB::bind_method(D_METHOD("close"), &GNHapDecoder::close);
    ClassDB::bind_method(D_METHOD("decode_next_frame"), &GNHapDecoder::decode_next_frame);
    ClassDB::bind_method(D_METHOD("seek_frame", "frame_index"), &GNHapDecoder::seek_frame);
    ClassDB::bind_method(D_METHOD("seek_time", "seconds"), &GNHapDecoder::seek_time);
    ClassDB::bind_method(D_METHOD("is_open"), &GNHapDecoder::is_open);
    ClassDB::bind_method(D_METHOD("get_width"), &GNHapDecoder::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GNHapDecoder::get_height);
    ClassDB::bind_method(D_METHOD("get_fps"), &GNHapDecoder::get_fps);
    ClassDB::bind_method(D_METHOD("get_frame_count"), &GNHapDecoder::get_frame_count);
    ClassDB::bind_method(D_METHOD("get_current_frame"), &GNHapDecoder::get_current_frame);
    ClassDB::bind_method(D_METHOD("get_duration"), &GNHapDecoder::get_duration);
    ClassDB::bind_method(D_METHOD("get_hap_variant"), &GNHapDecoder::get_hap_variant);
    ClassDB::bind_method(D_METHOD("get_image_format"), &GNHapDecoder::get_image_format);
    ClassDB::bind_method(D_METHOD("get_compressed_frame_size"), &GNHapDecoder::get_compressed_frame_size);
}

GNHapDecoder::GNHapDecoder() {}

GNHapDecoder::~GNHapDecoder() {
    close();
}

// ── Public API ────────────────────────────────────────────────────────────────

bool GNHapDecoder::open(const String &file_path) {
    close();

    // Convert Godot path to native OS path
    String native_path = file_path;
    if (native_path.begins_with("res://") || native_path.begins_with("user://")) {
        native_path = godot::UtilityFunctions::var_to_str(file_path);
    }

    CharString utf8 = native_path.utf8();

#ifdef _WIN32
    _file = _wfopen((const wchar_t *)native_path.utf16().get_data(), L"rb");
#else
    _file = fopen(utf8.get_data(), "rb");
#endif

    if (!_file) {
        UtilityFunctions::push_warning("GNHapDecoder: Failed to open file: " + file_path);
        return false;
    }

    if (!_parse_mov_header()) {
        UtilityFunctions::push_warning("GNHapDecoder: Invalid or unsupported HAP file: " + file_path);
        close();
        return false;
    }

    _current_frame = 0;
    return true;
}

void GNHapDecoder::close() {
    if (_file) {
        fclose(_file);
        _file = nullptr;
    }
    _frame_table.clear();
    _scratch.clear();
    _width = 0;
    _height = 0;
    _fps = 30.0;
    _hap_variant = 0;
    _current_frame = 0;
}

PackedByteArray GNHapDecoder::decode_next_frame() {
    PackedByteArray result;
    if (!_file || _current_frame >= (int)_frame_table.size()) {
        return result;
    }

    std::vector<uint8_t> dxt_data;
    if (!_read_hap_frame(_frame_table[_current_frame], dxt_data)) {
        return result;
    }

    _current_frame++;

    result.resize(dxt_data.size());
    memcpy(result.ptrw(), dxt_data.data(), dxt_data.size());
    return result;
}

void GNHapDecoder::seek_frame(int frame_index) {
    if (frame_index >= 0 && frame_index < (int)_frame_table.size()) {
        _current_frame = frame_index;
    }
}

void GNHapDecoder::seek_time(double seconds) {
    if (_fps > 0.0) {
        int frame = (int)(seconds * _fps);
        seek_frame(frame);
    }
}

bool GNHapDecoder::is_open() const { return _file != nullptr; }
int GNHapDecoder::get_width() const { return _width; }
int GNHapDecoder::get_height() const { return _height; }
double GNHapDecoder::get_fps() const { return _fps; }
int GNHapDecoder::get_frame_count() const { return (int)_frame_table.size(); }
int GNHapDecoder::get_current_frame() const { return _current_frame; }

double GNHapDecoder::get_duration() const {
    if (_fps > 0.0 && !_frame_table.empty()) {
        return (double)_frame_table.size() / _fps;
    }
    return 0.0;
}

int GNHapDecoder::get_hap_variant() const { return _hap_variant; }

int GNHapDecoder::get_image_format() const {
    // Godot Image format enums:
    //   FORMAT_DXT1 = 17
    //   FORMAT_DXT5 = 19
    switch (_hap_variant) {
        case 0: return 17; // DXT1 — HAP
        case 1: return 19; // DXT5 — HAP Alpha
        case 2: return 19; // DXT5 — HAP Q (YCoCg in shader)
        default: return 17;
    }
}

int GNHapDecoder::get_compressed_frame_size() const {
    // DXT1: 8 bytes per 4x4 block = w*h/2
    // DXT5: 16 bytes per 4x4 block = w*h
    int blocks_x = (_width + 3) / 4;
    int blocks_y = (_height + 3) / 4;
    int block_size = (_hap_variant == 0) ? 8 : 16;
    return blocks_x * blocks_y * block_size;
}

// ── MOV Container Parser (Minimal) ───────────────────────────────────────────
//
// Reads the QuickTime/MOV atom tree to find:
//   - 'trak' atom → 'mdia' → 'minf' → 'stbl' for sample table
//   - 'stsz' for frame sizes
//   - 'stco'/'co64' for chunk offsets
//   - 'stsd' for HAP codec identification
//   - 'mdhd' for timescale and duration → fps

static uint32_t read_u32_be(FILE *f) {
    uint8_t buf[4];
    if (fread(buf, 1, 4, f) != 4) return 0;
    return ((uint32_t)buf[0] << 24) | ((uint32_t)buf[1] << 16) |
           ((uint32_t)buf[2] << 8) | (uint32_t)buf[3];
}

static uint64_t read_u64_be(FILE *f) {
    uint8_t buf[8];
    if (fread(buf, 1, 8, f) != 8) return 0;
    return ((uint64_t)buf[0] << 56) | ((uint64_t)buf[1] << 48) |
           ((uint64_t)buf[2] << 40) | ((uint64_t)buf[3] << 32) |
           ((uint64_t)buf[4] << 24) | ((uint64_t)buf[5] << 16) |
           ((uint64_t)buf[6] << 8) | (uint64_t)buf[7];
}

static uint16_t read_u16_be(FILE *f) {
    uint8_t buf[2];
    if (fread(buf, 1, 2, f) != 2) return 0;
    return ((uint16_t)buf[0] << 8) | (uint16_t)buf[1];
}

// FourCC comparison helper
static bool fourcc_eq(uint32_t a, const char *b) {
    return a == ((uint32_t)b[0] << 24 | (uint32_t)b[1] << 16 |
                 (uint32_t)b[2] << 8 | (uint32_t)b[3]);
}

bool GNHapDecoder::_parse_mov_header() {
    // Seek to start
    fseek(_file, 0, SEEK_END);
    int64_t file_size = ftell(_file);
    fseek(_file, 0, SEEK_SET);

    // State collected during parsing
    std::vector<int32_t> sample_sizes;
    std::vector<int64_t> chunk_offsets;
    uint32_t timescale = 0;
    uint64_t duration = 0;
    bool found_hap = false;

    // Simple recursive atom scanner
    struct AtomRange {
        int64_t start;
        int64_t end;
    };

    // Container atoms that should be descended into
    auto is_container = [](uint32_t type) -> bool {
        return fourcc_eq(type, "moov") || fourcc_eq(type, "trak") ||
               fourcc_eq(type, "mdia") || fourcc_eq(type, "minf") ||
               fourcc_eq(type, "stbl");
    };

    // Iterative atom walk with stack
    std::vector<AtomRange> stack;
    stack.push_back({0, file_size});

    while (!stack.empty()) {
        AtomRange range = stack.back();
        stack.pop_back();

        int64_t pos = range.start;
        while (pos < range.end - 8) {
            fseek(_file, (long)pos, SEEK_SET);
            uint32_t atom_size = read_u32_be(_file);
            uint32_t atom_type = read_u32_be(_file);

            int64_t atom_end;
            if (atom_size == 1) {
                // 64-bit extended size
                uint64_t ext_size = read_u64_be(_file);
                atom_end = pos + (int64_t)ext_size;
            } else if (atom_size == 0) {
                atom_end = range.end; // atom extends to EOF
            } else {
                atom_end = pos + atom_size;
            }

            if (atom_end > range.end) atom_end = range.end;
            if (atom_end <= pos + 8) break; // invalid

            int64_t data_start = pos + 8;
            if (atom_size == 1) data_start = pos + 16;

            if (is_container(atom_type)) {
                // Push container children for processing
                stack.push_back({data_start, atom_end});
            }
            // stsd — Sample Description (contains codec FourCC and dimensions)
            else if (fourcc_eq(atom_type, "stsd")) {
                fseek(_file, (long)data_start, SEEK_SET);
                /* version + flags */ read_u32_be(_file);
                uint32_t entry_count = read_u32_be(_file);
                if (entry_count >= 1) {
                    uint32_t desc_size = read_u32_be(_file);
                    uint32_t codec_4cc = read_u32_be(_file);
                    (void)desc_size;

                    // HAP FourCC variants
                    if (fourcc_eq(codec_4cc, "Hap1")) {
                        _hap_variant = 0; found_hap = true;
                    } else if (fourcc_eq(codec_4cc, "Hap5")) {
                        _hap_variant = 1; found_hap = true;
                    } else if (fourcc_eq(codec_4cc, "HapY")) {
                        _hap_variant = 2; found_hap = true;
                    } else if (fourcc_eq(codec_4cc, "HapM")) {
                        _hap_variant = 2; found_hap = true;
                    }

                    if (found_hap) {
                        // Skip 6 reserved + 2 data_ref_index = 8 bytes
                        fseek(_file, 8, SEEK_CUR);
                        // Skip 2 (version) + 2 (revision) + 4 (vendor) = 8
                        fseek(_file, 8, SEEK_CUR);
                        // Skip temporal_quality(4) + spatial_quality(4) = 8
                        fseek(_file, 8, SEEK_CUR);
                        _width = read_u16_be(_file);
                        _height = read_u16_be(_file);
                    }
                }
            }
            // mdhd — Media Header (timescale and duration)
            else if (fourcc_eq(atom_type, "mdhd")) {
                fseek(_file, (long)data_start, SEEK_SET);
                uint32_t version_flags = read_u32_be(_file);
                uint8_t version = (version_flags >> 24) & 0xFF;
                if (version == 0) {
                    /* creation_time */ read_u32_be(_file);
                    /* modification_time */ read_u32_be(_file);
                    timescale = read_u32_be(_file);
                    duration = read_u32_be(_file);
                } else {
                    /* creation_time */ read_u64_be(_file);
                    /* modification_time */ read_u64_be(_file);
                    timescale = read_u32_be(_file);
                    duration = read_u64_be(_file);
                }
            }
            // stsz — Sample Size Box (per-frame sizes)
            else if (fourcc_eq(atom_type, "stsz")) {
                fseek(_file, (long)data_start, SEEK_SET);
                /* version + flags */ read_u32_be(_file);
                uint32_t default_size = read_u32_be(_file);
                uint32_t count = read_u32_be(_file);
                sample_sizes.resize(count);
                if (default_size != 0) {
                    for (uint32_t i = 0; i < count; i++)
                        sample_sizes[i] = (int32_t)default_size;
                } else {
                    for (uint32_t i = 0; i < count; i++)
                        sample_sizes[i] = (int32_t)read_u32_be(_file);
                }
            }
            // stco — Chunk Offset Box (32-bit offsets)
            else if (fourcc_eq(atom_type, "stco")) {
                fseek(_file, (long)data_start, SEEK_SET);
                /* version + flags */ read_u32_be(_file);
                uint32_t count = read_u32_be(_file);
                chunk_offsets.resize(count);
                for (uint32_t i = 0; i < count; i++)
                    chunk_offsets[i] = (int64_t)read_u32_be(_file);
            }
            // co64 — Chunk Offset Box (64-bit offsets)
            else if (fourcc_eq(atom_type, "co64")) {
                fseek(_file, (long)data_start, SEEK_SET);
                /* version + flags */ read_u32_be(_file);
                uint32_t count = read_u32_be(_file);
                chunk_offsets.resize(count);
                for (uint32_t i = 0; i < count; i++)
                    chunk_offsets[i] = (int64_t)read_u64_be(_file);
            }

            pos = atom_end;
        }
    }

    if (!found_hap || sample_sizes.empty() || chunk_offsets.empty()) {
        return false;
    }

    // Compute FPS
    if (timescale > 0 && duration > 0 && !sample_sizes.empty()) {
        _fps = (double)sample_sizes.size() * (double)timescale / (double)duration;
    }

    // Build frame table — assumes 1 sample per chunk (common for HAP)
    // If fewer chunks than samples, compute offsets sequentially
    _frame_table.resize(sample_sizes.size());
    if (chunk_offsets.size() >= sample_sizes.size()) {
        for (size_t i = 0; i < sample_sizes.size(); i++) {
            _frame_table[i].offset = chunk_offsets[i];
            _frame_table[i].size = sample_sizes[i];
        }
    } else {
        // Multiple samples per chunk — accumulate offsets
        size_t sample_idx = 0;
        for (size_t ci = 0; ci < chunk_offsets.size() && sample_idx < sample_sizes.size(); ci++) {
            int64_t running = chunk_offsets[ci];
            // Assume all remaining samples in this chunk until next chunk
            size_t next_chunk_start = (ci + 1 < chunk_offsets.size()) ?
                sample_sizes.size() : sample_sizes.size(); // simplified: 1 sample/chunk fallback
            // In practice, HAP MOV files use 1 sample per chunk
            _frame_table[sample_idx].offset = running;
            _frame_table[sample_idx].size = sample_sizes[sample_idx];
            sample_idx++;
        }
        // Fill remaining if any
        for (; sample_idx < sample_sizes.size(); sample_idx++) {
            if (sample_idx > 0) {
                _frame_table[sample_idx].offset =
                    _frame_table[sample_idx - 1].offset + _frame_table[sample_idx - 1].size;
            }
            _frame_table[sample_idx].size = sample_sizes[sample_idx];
        }
    }

    return true;
}

// ── HAP Frame Decode ──────────────────────────────────────────────────────────
//
// HAP frame layout:
//   [4 bytes] Section header: 3 bytes size (little-endian) + 1 byte type
//     - type low 4 bits = compressor (0x00=none, 0x01=snappy)
//     - type high 4 bits = texture format
//   [N bytes] Compressed or raw DXT data

bool GNHapDecoder::_read_hap_frame(const FrameEntry &entry, std::vector<uint8_t> &out_dxt) {
    if (!_file || entry.size < HAP_SECTION_HEADER_SIZE) return false;

    // Read raw chunk
    std::vector<uint8_t> chunk(entry.size);
    fseek(_file, (long)entry.offset, SEEK_SET);
    size_t read = fread(chunk.data(), 1, entry.size, _file);
    if ((int)read != entry.size) return false;

    // Parse HAP section header (little-endian 3-byte size + 1-byte type)
    uint32_t section_size = chunk[0] | ((uint32_t)chunk[1] << 8) | ((uint32_t)chunk[2] << 16);
    uint8_t section_type = chunk[3];

    // Handle extended size (if section_size == 0, next 4 bytes are the real size)
    const uint8_t *payload = chunk.data() + HAP_SECTION_HEADER_SIZE;
    size_t payload_size;
    if (section_size == 0 && entry.size >= 8) {
        section_size = payload[0] | ((uint32_t)payload[1] << 8) |
                       ((uint32_t)payload[2] << 16) | ((uint32_t)payload[3] << 24);
        payload += 4;
        payload_size = entry.size - 8;
    } else {
        payload_size = entry.size - HAP_SECTION_HEADER_SIZE;
    }

    uint8_t compressor = section_type & 0x0F;

    if (compressor == HAP_COMPRESSOR_NONE) {
        // Raw DXT data — no decompression needed
        out_dxt.assign(payload, payload + payload_size);
        return true;
    } else if (compressor == HAP_COMPRESSOR_SNAPPY) {
        // Snappy-compressed DXT data
        size_t uncompressed_length = 0;
        snappy_status status = snappy_uncompressed_length(
            (const char *)payload, payload_size, &uncompressed_length);
        if (status != 0) return false;

        out_dxt.resize(uncompressed_length);
        status = snappy_uncompress(
            (const char *)payload, payload_size,
            (char *)out_dxt.data(), &uncompressed_length);
        return status == 0;
    }

    // Unknown compressor
    return false;
}

} // namespace godot
