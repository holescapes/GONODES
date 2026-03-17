#include "gn_hap_encoder.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>
#include <algorithm>

// ── Snappy (thirdparty) ───────────────────────────────────────────────────────
extern "C" {
    typedef int snappy_status;
    size_t snappy_max_compressed_length(size_t source_length);
    snappy_status snappy_compress(const char *input, size_t input_length,
                                  char *compressed, size_t *compressed_length);
}

// ── Squish DXT compression (thirdparty) ───────────────────────────────────────
namespace squish {
    enum {
        kDxt1 = (1 << 0),
        kDxt5 = (1 << 2),
        kColourIterativeClusterFit = (1 << 8),
        kColourClusterFit = (1 << 3),
        kColourRangeFit = (1 << 4),
    };
    void CompressImage(const uint8_t *rgba, int width, int height,
                       void *blocks, int flags);
    int GetStorageRequirements(int width, int height, int flags);
}

// HAP section header constants
#define HAP_COMPRESSOR_SNAPPY   0x01
#define HAP_FORMAT_RGB_DXT1     0x0B
#define HAP_FORMAT_RGBA_DXT5    0x0E
#define HAP_FORMAT_YCOCG_DXT5   0x0F

namespace godot {

// ── Binding ───────────────────────────────────────────────────────────────────

void GNHapEncoder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start", "file_path", "width", "height", "fps", "variant"),
                         &GNHapEncoder::start);
    ClassDB::bind_method(D_METHOD("encode_frame", "rgba_data"), &GNHapEncoder::encode_frame);
    ClassDB::bind_method(D_METHOD("finish"), &GNHapEncoder::finish);
    ClassDB::bind_method(D_METHOD("is_encoding"), &GNHapEncoder::is_encoding);
    ClassDB::bind_method(D_METHOD("get_frame_count"), &GNHapEncoder::get_frame_count);
}

GNHapEncoder::GNHapEncoder() {}

GNHapEncoder::~GNHapEncoder() {
    if (_encoding) {
        finish();
    }
}

// ── Write Helpers ─────────────────────────────────────────────────────────────

void GNHapEncoder::_write_u32_be(uint32_t v) {
    uint8_t buf[4] = {
        (uint8_t)(v >> 24), (uint8_t)(v >> 16),
        (uint8_t)(v >> 8), (uint8_t)(v)
    };
    fwrite(buf, 1, 4, _file);
}

void GNHapEncoder::_write_u16_be(uint16_t v) {
    uint8_t buf[2] = { (uint8_t)(v >> 8), (uint8_t)(v) };
    fwrite(buf, 1, 2, _file);
}

void GNHapEncoder::_write_u64_be(uint64_t v) {
    uint8_t buf[8];
    for (int i = 7; i >= 0; i--) {
        buf[7 - i] = (uint8_t)(v >> (i * 8));
    }
    fwrite(buf, 1, 8, _file);
}

void GNHapEncoder::_write_fourcc(const char *cc) {
    fwrite(cc, 1, 4, _file);
}

// ── Public API ────────────────────────────────────────────────────────────────

bool GNHapEncoder::start(const String &file_path, int width, int height,
                          double fps, int variant) {
    if (_encoding) finish();

    CharString utf8 = file_path.utf8();

#ifdef _WIN32
    _file = _wfopen((const wchar_t *)file_path.utf16().get_data(), L"wb");
#else
    _file = fopen(utf8.get_data(), "wb");
#endif

    if (!_file) {
        UtilityFunctions::push_warning("GNHapEncoder: Failed to create file: " + file_path);
        return false;
    }

    _width = width;
    _height = height;
    _fps = fps;
    _variant = variant;
    _frame_count = 0;
    _frames.clear();
    _encoding = true;

    // Pre-allocate DXT buffer
    int squish_flags = (_variant == 0) ? squish::kDxt1 : squish::kDxt5;
    int dxt_size = squish::GetStorageRequirements(_width, _height, squish_flags);
    _dxt_buf.resize(dxt_size);

    // Pre-allocate Snappy output buffer
    _snap_buf.resize(snappy_max_compressed_length(dxt_size) + 8);

    // Write ftyp atom
    _write_u32_be(20); // atom size
    _write_fourcc("ftyp");
    _write_fourcc("qt  "); // brand
    _write_u32_be(0);      // minor version

    // Start mdat atom (size placeholder — will be patched in finish())
    _mdat_start = ftell(_file);
    _write_u32_be(0); // placeholder size
    _write_fourcc("mdat");

    return true;
}

bool GNHapEncoder::encode_frame(const PackedByteArray &rgba_data) {
    if (!_encoding || !_file) return false;

    int expected = _width * _height * 4;
    if (rgba_data.size() != expected) {
        UtilityFunctions::push_warning("GNHapEncoder: Frame size mismatch. Expected " +
            String::num_int64(expected) + " bytes, got " + String::num_int64(rgba_data.size()));
        return false;
    }

    // ── Step 1: DXT compress RGBA → DXT1 or DXT5 ─────────────────────────
    int squish_flags;
    uint8_t hap_format;
    switch (_variant) {
        case 0: // HAP — DXT1
            squish_flags = squish::kDxt1 | squish::kColourRangeFit;
            hap_format = HAP_FORMAT_RGB_DXT1;
            break;
        case 1: // HAP Alpha — DXT5
            squish_flags = squish::kDxt5 | squish::kColourRangeFit;
            hap_format = HAP_FORMAT_RGBA_DXT5;
            break;
        case 2: // HAP Q — YCoCg DXT5
        default:
            squish_flags = squish::kDxt5 | squish::kColourRangeFit;
            hap_format = HAP_FORMAT_YCOCG_DXT5;
            break;
    }

    int dxt_size = squish::GetStorageRequirements(_width, _height, squish_flags);
    squish::CompressImage(rgba_data.ptr(), _width, _height, _dxt_buf.data(), squish_flags);

    // ── Step 2: Snappy compress ───────────────────────────────────────────
    size_t snap_len = snappy_max_compressed_length(dxt_size);
    _snap_buf.resize(snap_len);
    snappy_status status = snappy_compress(
        (const char *)_dxt_buf.data(), dxt_size,
        (char *)_snap_buf.data(), &snap_len);

    bool use_snappy = (status == 0 && snap_len < (size_t)dxt_size);

    // ── Step 3: Write HAP section ─────────────────────────────────────────
    const uint8_t *payload;
    size_t payload_size;
    uint8_t section_type;

    if (use_snappy) {
        payload = _snap_buf.data();
        payload_size = snap_len;
        section_type = (hap_format << 4) | HAP_COMPRESSOR_SNAPPY;
    } else {
        payload = _dxt_buf.data();
        payload_size = dxt_size;
        section_type = (hap_format << 4) | 0x00; // no compression
    }

    // Record frame position
    FrameRecord rec;
    rec.offset = ftell(_file) - _mdat_start;
    int32_t hap_chunk_size = (int32_t)(4 + payload_size); // header + payload
    rec.size = hap_chunk_size;
    _frames.push_back(rec);

    // Write HAP section header (little-endian 3-byte size + type)
    uint8_t header[4];
    uint32_t section_size = (uint32_t)payload_size;
    header[0] = section_size & 0xFF;
    header[1] = (section_size >> 8) & 0xFF;
    header[2] = (section_size >> 16) & 0xFF;
    header[3] = section_type;
    fwrite(header, 1, 4, _file);

    // Write payload
    fwrite(payload, 1, payload_size, _file);

    _frame_count++;
    return true;
}

void GNHapEncoder::finish() {
    if (!_encoding || !_file) return;
    _encoding = false;

    // Patch mdat size
    int64_t mdat_end = ftell(_file);
    uint32_t mdat_size = (uint32_t)(mdat_end - _mdat_start);
    fseek(_file, (long)_mdat_start, SEEK_SET);
    _write_u32_be(mdat_size);
    fseek(_file, (long)mdat_end, SEEK_SET);

    // Write moov atom (index)
    _write_moov_atom();

    fclose(_file);
    _file = nullptr;

    UtilityFunctions::print("GNHapEncoder: Finished — " +
        String::num_int64(_frame_count) + " frames written.");
}

bool GNHapEncoder::is_encoding() const { return _encoding; }
int GNHapEncoder::get_frame_count() const { return _frame_count; }

// ── MOV moov Atom Writer ──────────────────────────────────────────────────────
//
// Writes the QuickTime moov atom tree containing:
//   moov → mvhd + trak → tkhd + mdia → mdhd + hdlr + minf → vmhd + dinf + stbl
//   stbl → stsd + stts + stsc + stsz + stco

void GNHapEncoder::_write_moov_atom() {
    // Pre-compute sizes for atoms that need them
    uint32_t timescale = (uint32_t)(_fps * 100.0);
    uint32_t frame_duration_ticks = (uint32_t)(timescale / _fps);
    uint64_t total_duration = (uint64_t)_frame_count * frame_duration_ticks;

    // HAP codec FourCC
    const char *codec_4cc;
    switch (_variant) {
        case 0:  codec_4cc = "Hap1"; break;
        case 1:  codec_4cc = "Hap5"; break;
        case 2:  codec_4cc = "HapY"; break;
        default: codec_4cc = "Hap1"; break;
    }

    // ── stsz (sample sizes) ──────────────────────────────────────────────
    // 12 header + 4*frame_count
    uint32_t stsz_size = 20 + 4 * (uint32_t)_frames.size();

    // ── stco (chunk offsets) — 32-bit, relative to file start ────────────
    // Offsets = mdat_start + 8 (mdat header) + frame.offset
    uint32_t stco_size = 16 + 4 * (uint32_t)_frames.size();

    // ── stsc (sample-to-chunk) — 1 sample per chunk ─────────────────────
    uint32_t stsc_size = 28; // 12 header + 1 entry (12 bytes) + 4 padding → 28

    // ── stts (time-to-sample) — all frames same duration ─────────────────
    uint32_t stts_size = 24; // 12 header + 1 entry (8 bytes) + 4 count

    // ── stsd (sample description) ────────────────────────────────────────
    //   8 (atom) + 4 (version+flags) + 4 (count) + sample_desc
    //   sample_desc: 4 (size) + 4 (codec) + 6 (reserved) + 2 (data_ref_index)
    //                + 2 (version) + 2 (revision) + 4 (vendor)
    //                + 4 (temporal_q) + 4 (spatial_q)
    //                + 2 (width) + 2 (height) + 4 (horiz_res) + 4 (vert_res)
    //                + 4 (data_size) + 2 (frame_count) + 32 (compressor_name)
    //                + 2 (depth) + 2 (color_table_id) = 86 bytes total
    uint32_t stsd_desc_size = 86;
    uint32_t stsd_size = 8 + 4 + 4 + stsd_desc_size; // = 102

    // ── stbl ─────────────────────────────────────────────────────────────
    uint32_t stbl_size = 8 + stsd_size + stts_size + stsc_size + stsz_size + stco_size;

    // ── dinf + dref ──────────────────────────────────────────────────────
    uint32_t dref_size = 28; // 8 + 4 + 4 + 12(url entry)
    uint32_t dinf_size = 8 + dref_size; // = 36

    // ── vmhd ─────────────────────────────────────────────────────────────
    uint32_t vmhd_size = 20;

    // ── minf ─────────────────────────────────────────────────────────────
    uint32_t minf_size = 8 + vmhd_size + dinf_size + stbl_size;

    // ── hdlr ─────────────────────────────────────────────────────────────
    uint32_t hdlr_size = 33; // 8 + 4 + 4 + 4 + 12(reserved) + 1(null name)

    // ── mdhd ─────────────────────────────────────────────────────────────
    uint32_t mdhd_size = 32; // version 0

    // ── mdia ─────────────────────────────────────────────────────────────
    uint32_t mdia_size = 8 + mdhd_size + hdlr_size + minf_size;

    // ── tkhd ─────────────────────────────────────────────────────────────
    uint32_t tkhd_size = 92; // version 0

    // ── trak ─────────────────────────────────────────────────────────────
    uint32_t trak_size = 8 + tkhd_size + mdia_size;

    // ── mvhd ─────────────────────────────────────────────────────────────
    uint32_t mvhd_size = 108; // version 0

    // ── moov ─────────────────────────────────────────────────────────────
    uint32_t moov_size = 8 + mvhd_size + trak_size;

    // ═══════════════════════════════════════════════════════════════════════
    // Write atoms
    // ═══════════════════════════════════════════════════════════════════════

    // moov
    _write_u32_be(moov_size);
    _write_fourcc("moov");

    // ── mvhd ─────────────────────────────────────────────────────────────
    _write_u32_be(mvhd_size);
    _write_fourcc("mvhd");
    _write_u32_be(0); // version 0 + flags
    _write_u32_be(0); // creation_time
    _write_u32_be(0); // modification_time
    _write_u32_be(timescale);
    _write_u32_be((uint32_t)total_duration);
    _write_u32_be(0x00010000); // preferred_rate (1.0 fixed-point)
    _write_u16_be(0x0100); // preferred_volume (1.0)
    // 10 bytes reserved
    uint8_t reserved10[10] = {0};
    fwrite(reserved10, 1, 10, _file);
    // 36 bytes matrix (identity)
    uint32_t matrix[9] = {0x00010000,0,0, 0,0x00010000,0, 0,0,0x40000000};
    for (int i = 0; i < 9; i++) _write_u32_be(matrix[i]);
    // 24 bytes pre-defined (zeros)
    uint8_t pre24[24] = {0};
    fwrite(pre24, 1, 24, _file);
    _write_u32_be(2); // next_track_id

    // ── trak ─────────────────────────────────────────────────────────────
    _write_u32_be(trak_size);
    _write_fourcc("trak");

    // ── tkhd ─────────────────────────────────────────────────────────────
    _write_u32_be(tkhd_size);
    _write_fourcc("tkhd");
    _write_u32_be(0x00000003); // version 0, flags=enabled+in_movie
    _write_u32_be(0); // creation_time
    _write_u32_be(0); // modification_time
    _write_u32_be(1); // track_id
    _write_u32_be(0); // reserved
    _write_u32_be((uint32_t)total_duration);
    // 8 bytes reserved
    uint8_t reserved8[8] = {0};
    fwrite(reserved8, 1, 8, _file);
    _write_u16_be(0); // layer
    _write_u16_be(0); // alternate_group
    _write_u16_be(0); // volume
    _write_u16_be(0); // reserved
    for (int i = 0; i < 9; i++) _write_u32_be(matrix[i]);
    _write_u32_be(_width << 16);  // width (fixed-point 16.16)
    _write_u32_be(_height << 16); // height (fixed-point 16.16)

    // ── mdia ─────────────────────────────────────────────────────────────
    _write_u32_be(mdia_size);
    _write_fourcc("mdia");

    // ── mdhd ─────────────────────────────────────────────────────────────
    _write_u32_be(mdhd_size);
    _write_fourcc("mdhd");
    _write_u32_be(0); // version 0 + flags
    _write_u32_be(0); // creation_time
    _write_u32_be(0); // modification_time
    _write_u32_be(timescale);
    _write_u32_be((uint32_t)total_duration);
    _write_u32_be(0); // language + quality

    // ── hdlr ─────────────────────────────────────────────────────────────
    _write_u32_be(hdlr_size);
    _write_fourcc("hdlr");
    _write_u32_be(0); // version + flags
    _write_fourcc("mhlr"); // handler_type (pre-defined)
    _write_fourcc("vide"); // subtype
    // 12 bytes reserved
    uint8_t reserved12[12] = {0};
    fwrite(reserved12, 1, 12, _file);
    uint8_t null_byte = 0;
    fwrite(&null_byte, 1, 1, _file); // component name (empty)

    // ── minf ─────────────────────────────────────────────────────────────
    _write_u32_be(minf_size);
    _write_fourcc("minf");

    // vmhd
    _write_u32_be(vmhd_size);
    _write_fourcc("vmhd");
    _write_u32_be(0x00000001); // version 0, flags=1
    _write_u16_be(0); // graphicsmode
    _write_u16_be(0); // opcolor[0]
    _write_u16_be(0); // opcolor[1]
    _write_u16_be(0); // opcolor[2]

    // dinf + dref
    _write_u32_be(dinf_size);
    _write_fourcc("dinf");
    _write_u32_be(dref_size);
    _write_fourcc("dref");
    _write_u32_be(0); // version + flags
    _write_u32_be(1); // entry_count
    _write_u32_be(12); // url entry size
    _write_fourcc("url ");
    _write_u32_be(0x00000001); // self-contained flag

    // ── stbl ─────────────────────────────────────────────────────────────
    _write_u32_be(stbl_size);
    _write_fourcc("stbl");

    // stsd
    _write_u32_be(stsd_size);
    _write_fourcc("stsd");
    _write_u32_be(0); // version + flags
    _write_u32_be(1); // entry_count
    // Video sample description
    _write_u32_be(stsd_desc_size); // description size
    _write_fourcc(codec_4cc);
    // 6 reserved bytes
    uint8_t reserved6[6] = {0};
    fwrite(reserved6, 1, 6, _file);
    _write_u16_be(1); // data_reference_index
    _write_u16_be(0); // version
    _write_u16_be(0); // revision
    _write_fourcc("appl"); // vendor
    _write_u32_be(0); // temporal_quality
    _write_u32_be(1024); // spatial_quality
    _write_u16_be(_width);
    _write_u16_be(_height);
    _write_u32_be(0x00480000); // horiz_resolution (72 dpi)
    _write_u32_be(0x00480000); // vert_resolution (72 dpi)
    _write_u32_be(0); // data_size
    _write_u16_be(1); // frame_count
    // 32-byte compressor name (Pascal string: length byte + name + padding)
    uint8_t comp_name[32] = {0};
    const char *name_str = "HAP";
    comp_name[0] = 3;
    memcpy(comp_name + 1, name_str, 3);
    fwrite(comp_name, 1, 32, _file);
    _write_u16_be(24); // depth
    _write_u16_be(0xFFFF); // color_table_id (-1 = default)

    // stts — Time-To-Sample
    _write_u32_be(stts_size);
    _write_fourcc("stts");
    _write_u32_be(0); // version + flags
    _write_u32_be(1); // entry_count
    _write_u32_be((uint32_t)_frame_count); // sample_count
    _write_u32_be(frame_duration_ticks);   // sample_delta

    // stsc — Sample-To-Chunk (1 sample per chunk)
    _write_u32_be(stsc_size);
    _write_fourcc("stsc");
    _write_u32_be(0); // version + flags
    _write_u32_be(1); // entry_count
    _write_u32_be(1); // first_chunk
    _write_u32_be(1); // samples_per_chunk
    _write_u32_be(1); // sample_description_index

    // stsz — Sample Sizes
    _write_u32_be(stsz_size);
    _write_fourcc("stsz");
    _write_u32_be(0); // version + flags
    _write_u32_be(0); // default_sample_size (0 = variable)
    _write_u32_be((uint32_t)_frames.size());
    for (const auto &fr : _frames) {
        _write_u32_be((uint32_t)fr.size);
    }

    // stco — Chunk Offsets (32-bit)
    _write_u32_be(stco_size);
    _write_fourcc("stco");
    _write_u32_be(0); // version + flags
    _write_u32_be((uint32_t)_frames.size());
    for (const auto &fr : _frames) {
        // Absolute file offset = mdat_start + 8 (mdat header) + relative offset
        _write_u32_be((uint32_t)(_mdat_start + 8 + fr.offset));
    }
}

} // namespace godot
