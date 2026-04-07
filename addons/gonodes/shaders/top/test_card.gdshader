shader_type canvas_item;
// TestCardTOP — broadcast / projection-mapping calibration test card.
// Resolution-aware: grid spacing, labels, and features scale to the output size.
// Inspired by SMPTE RP 219 / EBU colour bars, MadMapper, and Resolume test cards.

uniform vec2 resolution = vec2(1920.0, 1080.0);
uniform int card_type = 0;  // 0=Full, 1=Grid Only, 2=Color Bars Only, 3=Grayscale, 4=RGBW
uniform float grid_cells = 16.0;    // Number of grid divisions on the long axis
uniform float line_width = 1.5;     // Grid line width in pixels
uniform vec4 grid_color : source_color = vec4(0.35, 0.35, 0.35, 1.0);
uniform vec4 bg_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);
uniform vec4 center_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool show_grid = true;
uniform bool show_center = true;
uniform bool show_color_bars = true;
uniform bool show_grayscale = true;
uniform bool show_corners = true;
uniform bool show_safe_area = true;
uniform bool show_circle = true;
uniform float safe_margin = 0.05;   // 5% safe-area margin (broadcast standard)

// ── Helpers ──────────────────────────────────────────────────────────────────

// Signed distance to a box centered at `center` with half-size `half_ext`.
float sd_box(vec2 p, vec2 center, vec2 half_ext) {
    vec2 d = abs(p - center) - half_ext;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Anti-aliased step: returns 1.0 inside, 0.0 outside, smooth edge.
float aa_fill(float dist, float px) {
    return 1.0 - smoothstep(-px, px, dist);
}

// ── Digit rendering (3×5 bitmap font) ───────────────────────────────────────
// Each digit encoded as 15 bits in a single int (row-major, top to bottom).

const int DIGITS[10] = int[10](
    0x7B6F,  // 0: 11110 11011 01101 11110
    0x2C97,  // 1
    0x73E7,  // 2
    0x72A7,  // 3
    0x5BC9,  // 4
    0x79A7,  // 5
    0x79AF,  // 6
    0x7249,  // 7
    0x7BAF,  // 8
    0x7BA7   // 9
);

// Returns 1.0 if pixel (px_coord) is inside digit `d` rendered at `origin`
// with cell size `cell`.  Digit occupies a 3×5 grid of cells.
float draw_digit(vec2 px_coord, vec2 origin, float cell, int d) {
    vec2 local = (px_coord - origin) / cell;
    if (local.x < 0.0 || local.x >= 3.0 || local.y < 0.0 || local.y >= 5.0)
        return 0.0;
    int col = int(floor(local.x));
    int row = int(floor(local.y));
    int bit_index = row * 3 + col;
    int pattern = DIGITS[clamp(d, 0, 9)];
    return float((pattern >> (14 - bit_index)) & 1);
}

// Render a positive integer (up to 5 digits) at `origin`, returning 1.0 on lit pixels.
float draw_number(vec2 px_coord, vec2 origin, float cell, int number) {
    // Determine digit count
    int num = max(number, 0);
    int digit_count = 1;
    int tmp = num;
    while (tmp >= 10) { tmp /= 10; digit_count++; }
    if (digit_count > 5) digit_count = 5;

    float result = 0.0;
    int divisor = 1;
    for (int i = 1; i < digit_count; i++) divisor *= 10;

    for (int i = 0; i < digit_count; i++) {
        int d = (num / divisor) % 10;
        float x_off = float(i) * cell * 4.0;  // 3 wide + 1 gap
        result = max(result, draw_digit(px_coord, origin + vec2(x_off, 0.0), cell, d));
        divisor /= 10;
        if (divisor < 1) divisor = 1;
    }
    return result;
}

// Render "x" character (simple cross) at origin with cell size.
float draw_x(vec2 px_coord, vec2 origin, float cell) {
    vec2 local = (px_coord - origin) / cell;
    if (local.x < 0.0 || local.x >= 3.0 || local.y < 0.0 || local.y >= 5.0)
        return 0.0;
    int col = int(floor(local.x));
    int row = int(floor(local.y));
    // X pattern: diagonal hits
    if ((row == 0 || row == 4) && (col == 0 || col == 2)) return 1.0;
    if ((row == 1 || row == 3) && (col == 0 || col == 2)) return 1.0;
    if (row == 2 && col == 1) return 1.0;
    return 0.0;
}

// Render "WxH" resolution label centered at `center`.
float draw_resolution_label(vec2 px_coord, vec2 center, float cell, int w, int h) {
    // Estimate total width: w_digits * 4 + 4 (x char) + h_digits * 4 cells
    int wd = 1; int t = w; while (t >= 10) { t /= 10; wd++; }
    int hd = 1; t = h; while (t >= 10) { t /= 10; hd++; }
    float total_w = float(wd * 4 + 4 + hd * 4 - 1) * cell;
    float origin_x = center.x - total_w * 0.5;
    float origin_y = center.y - cell * 2.5;

    float result = 0.0;
    vec2 pos = vec2(origin_x, origin_y);
    result = max(result, draw_number(px_coord, pos, cell, w));
    pos.x += float(wd) * cell * 4.0;
    result = max(result, draw_x(px_coord, pos, cell));
    pos.x += cell * 4.0;
    result = max(result, draw_number(px_coord, pos, cell, h));
    return result;
}


// ── SMPTE-style colour bars ─────────────────────────────────────────────────

vec3 color_bar(int index) {
    // Top row: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
    if (index == 0) return vec3(0.75);           // 75% White
    if (index == 1) return vec3(0.75, 0.75, 0.0); // Yellow
    if (index == 2) return vec3(0.0, 0.75, 0.75); // Cyan
    if (index == 3) return vec3(0.0, 0.75, 0.0);  // Green
    if (index == 4) return vec3(0.75, 0.0, 0.75); // Magenta
    if (index == 5) return vec3(0.75, 0.0, 0.0);  // Red
    if (index == 6) return vec3(0.0, 0.0, 0.75);  // Blue
    return vec3(0.0);                              // Black
}


// ── Main ─────────────────────────────────────────────────────────────────────

void fragment() {
    vec2 px = UV * resolution;       // Pixel coordinate
    vec2 uv = UV;                    // Normalised [0,1]
    float aspect = resolution.x / resolution.y;
    float px_size = 1.0 / max(resolution.x, resolution.y);  // For AA

    vec3 col = bg_color.rgb;

    // ── Card type presets ────────────────────────────────────────────────
    bool do_grid = show_grid;
    bool do_center = show_center;
    bool do_bars = show_color_bars;
    bool do_gray = show_grayscale;
    bool do_corners = show_corners;
    bool do_safe = show_safe_area;
    bool do_circle = show_circle;

    if (card_type == 1) {
        // Grid Only
        do_bars = false; do_gray = false; do_corners = false;
        do_safe = false; do_circle = false;
    } else if (card_type == 2) {
        // Color Bars Only
        do_grid = false; do_center = false; do_corners = false;
        do_safe = false; do_circle = false;
    } else if (card_type == 3) {
        // Grayscale
        do_bars = false; do_grid = false; do_center = false;
        do_corners = false; do_safe = false; do_circle = false;
        do_gray = true;
    } else if (card_type == 4) {
        // RGBW
        do_bars = false; do_gray = false; do_grid = false;
        do_safe = false; do_circle = false;
        // Quadrant RGBW
        if (uv.x < 0.5 && uv.y < 0.5) col = vec3(1.0, 0.0, 0.0);
        else if (uv.x >= 0.5 && uv.y < 0.5) col = vec3(0.0, 1.0, 0.0);
        else if (uv.x < 0.5 && uv.y >= 0.5) col = vec3(0.0, 0.0, 1.0);
        else col = vec3(1.0);
    }

    // ── Color bars (top 67%) ─────────────────────────────────────────────
    if (do_bars && card_type == 0) {
        if (uv.y < 0.67) {
            int bar_idx = int(floor(uv.x * 8.0));
            bar_idx = clamp(bar_idx, 0, 7);
            col = color_bar(bar_idx);
        } else if (uv.y < 0.75) {
            // Reverse mini bars
            int bar_idx = 7 - int(floor(uv.x * 8.0));
            bar_idx = clamp(bar_idx, 0, 7);
            col = color_bar(bar_idx);
        } else {
            // Bottom: grayscale ramp
            col = vec3(uv.x);
        }
    }
    if (do_bars && card_type == 2) {
        int bar_idx = int(floor(uv.x * 8.0));
        bar_idx = clamp(bar_idx, 0, 7);
        col = color_bar(bar_idx);
    }

    // ── Grayscale ramp (full screen when card_type==3) ───────────────────
    if (do_gray && card_type == 3) {
        // 16-step discrete grayscale
        float step_val = floor(uv.x * 16.0) / 15.0;
        col = vec3(step_val);
    }

    // ── Center circle (inscribed in frame) ───────────────────────────────
    if (do_circle) {
        vec2 center = resolution * 0.5;
        float radius = min(resolution.x, resolution.y) * 0.45;
        float dist_circle = length(px - center) - radius;
        float circle_line = aa_fill(abs(dist_circle) - line_width, 1.0);
        col = mix(col, center_color.rgb * 0.6, circle_line * 0.7);
    }

    // ── Grid ─────────────────────────────────────────────────────────────
    if (do_grid) {
        float cell_px = max(resolution.x, resolution.y) / grid_cells;
        vec2 grid_frac = mod(px, cell_px);
        float dist_h = min(grid_frac.x, cell_px - grid_frac.x);
        float dist_v = min(grid_frac.y, cell_px - grid_frac.y);
        float grid_dist = min(dist_h, dist_v);
        float grid_alpha = aa_fill(grid_dist - line_width * 0.5, 1.0);
        col = mix(col, grid_color.rgb, grid_alpha * grid_color.a);

        // Heavier centre lines
        float cx_dist = abs(px.x - resolution.x * 0.5);
        float cy_dist = abs(px.y - resolution.y * 0.5);
        float center_line = aa_fill(min(cx_dist, cy_dist) - line_width * 1.5, 1.0);
        col = mix(col, center_color.rgb, center_line * 0.5);
    }

    // ── Safe-area rectangle ──────────────────────────────────────────────
    if (do_safe) {
        float mx = resolution.x * safe_margin;
        float my = resolution.y * safe_margin;
        vec2 safe_min = vec2(mx, my);
        vec2 safe_max = vec2(resolution.x - mx, resolution.y - my);
        vec2 safe_center = (safe_min + safe_max) * 0.5;
        vec2 safe_half = (safe_max - safe_min) * 0.5;
        float safe_dist = abs(sd_box(px, safe_center, safe_half)) - line_width * 0.5;
        float safe_alpha = aa_fill(safe_dist, 1.0);
        col = mix(col, vec3(0.0, 0.8, 0.0), safe_alpha * 0.7);
    }

    // ── Corner markers ───────────────────────────────────────────────────
    if (do_corners) {
        float marker_len = min(resolution.x, resolution.y) * 0.04;
        float mw = line_width * 2.0;
        // Check each corner
        for (int c = 0; c < 4; c++) {
            vec2 corner;
            if (c == 0) corner = vec2(0.0, 0.0);
            else if (c == 1) corner = vec2(resolution.x, 0.0);
            else if (c == 2) corner = vec2(0.0, resolution.y);
            else corner = resolution;

            vec2 dp = px - corner;
            float adx = abs(dp.x);
            float ady = abs(dp.y);
            // L-shaped corner: horizontal arm + vertical arm
            bool in_h = (adx < marker_len && ady < mw);
            bool in_v = (ady < marker_len && adx < mw);
            if (in_h || in_v) {
                col = center_color.rgb;
            }
        }
    }

    // ── Center crosshair ─────────────────────────────────────────────────
    if (do_center) {
        vec2 center = resolution * 0.5;
        float cross_len = min(resolution.x, resolution.y) * 0.06;
        float cx = abs(px.x - center.x);
        float cy = abs(px.y - center.y);
        bool in_cross = (cx < line_width * 1.5 && cy < cross_len) ||
                        (cy < line_width * 1.5 && cx < cross_len);
        if (in_cross) {
            col = center_color.rgb;
        }

        // Small center dot
        float dot_dist = length(px - center);
        float dot_alpha = aa_fill(dot_dist - line_width * 3.0, 1.0);
        col = mix(col, center_color.rgb, dot_alpha);
    }

    // ── Resolution label at centre ───────────────────────────────────────
    if (do_center) {
        float label_cell = max(2.0, min(resolution.x, resolution.y) / 120.0);
        vec2 label_center = resolution * 0.5 + vec2(0.0, min(resolution.x, resolution.y) * 0.10);
        float label_val = draw_resolution_label(px, label_center, label_cell,
                int(resolution.x), int(resolution.y));
        col = mix(col, center_color.rgb, label_val);
    }

    COLOR = vec4(col, 1.0);
}
