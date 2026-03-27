"""[ARCHIVED] Fix all node_type values from smashed-together to snake_case.
Note: Per-family script operators referenced here were consolidated into
GDScriptSCRIPT/PythonSCRIPT/NativeSCRIPT in March 2026."""
import os

fixes = [
    # DAT
    ("addons/gonodes/operators/dat/file_in_dat.gd", "filein", "file_in"),
    ("addons/gonodes/operators/dat/osc_in_dat.gd", "oscin", "osc_in"),
    ("addons/gonodes/operators/dat/web_socket_dat.gd", "websocket", "web_socket"),
    ("addons/gonodes/operators/dat/web_server_dat.gd", "webserver", "web_server"),
    ("addons/gonodes/operators/dat/midi_in_dat.gd", "midiin", "midi_in"),
    ("addons/gonodes/operators/dat/multi_touch_in_dat.gd", "multitouchin", "multi_touch_in"),
    ("addons/gonodes/operators/dat/op_find_dat.gd", "opfind", "op_find"),
    ("addons/gonodes/operators/dat/panel_execute_dat.gd", "panelexecute", "panel_execute"),
    ("addons/gonodes/operators/dat/render_pick_dat.gd", "renderpick", "render_pick"),
    ("addons/gonodes/operators/dat/callback_dat.gd", "callbackdat", "callback"),
    ("addons/gonodes/operators/dat/script_dat.gd", "scriptdat", "script"),
    ("addons/gonodes/operators/dat/host_in_dat.gd", "hostindat", "host_in"),
    # TOP
    ("addons/gonodes/operators/top/movie_file_in_top.gd", "moviefilein", "movie_file_in"),
    ("addons/gonodes/operators/top/chop_to_top.gd", "choptotop", "chop_to_top"),
    ("addons/gonodes/operators/top/optical_flow_top.gd", "opticalflow", "optical_flow"),
    ("addons/gonodes/operators/top/compute_shader_top.gd", "compute", "compute_shader"),
    ("addons/gonodes/operators/top/custom_shader_top.gd", "glsl", "custom_shader"),
    ("addons/gonodes/operators/top/point_cloud_render_top.gd", "pointcloudrender", "point_cloud_render"),
    ("addons/gonodes/operators/top/reaction_diffusion_top.gd", "reactiondiffusion", "reaction_diffusion"),
    ("addons/gonodes/operators/top/fluid_2d_top.gd", "fluid2d", "fluid_2d"),
    ("addons/gonodes/operators/top/vector_path_top.gd", "vectorpath", "vector_path"),
    ("addons/gonodes/operators/top/host_in_top.gd", "hostin", "host_in"),
    # UI
    ("addons/gonodes/operators/ui/check_box_ui.gd", "checkbox", "check_box"),
    ("addons/gonodes/operators/ui/color_picker_ui.gd", "colorpicker", "color_picker"),
    ("addons/gonodes/operators/ui/color_rect_ui.gd", "colorrect", "color_rect"),
    ("addons/gonodes/operators/ui/item_list_ui.gd", "itemlist", "item_list"),
    ("addons/gonodes/operators/ui/line_edit_ui.gd", "lineedit", "line_edit"),
    ("addons/gonodes/operators/ui/link_button_ui.gd", "linkbutton", "link_button"),
    ("addons/gonodes/operators/ui/margin_container_ui.gd", "margincontainer", "margin_container"),
    ("addons/gonodes/operators/ui/menu_button_ui.gd", "menubutton", "menu_button"),
    ("addons/gonodes/operators/ui/nine_patch_rect_ui.gd", "ninepatchrect", "nine_patch_rect"),
    ("addons/gonodes/operators/ui/panel_container_ui.gd", "panelcontainer", "panel_container"),
    ("addons/gonodes/operators/ui/progress_bar_ui.gd", "progressbar", "progress_bar"),
    ("addons/gonodes/operators/ui/rich_text_label_ui.gd", "richtextlabel", "rich_text_label"),
    ("addons/gonodes/operators/ui/scroll_container_ui.gd", "scrollcontainer", "scroll_container"),
    ("addons/gonodes/operators/ui/spin_box_ui.gd", "spinbox", "spin_box"),
    ("addons/gonodes/operators/ui/split_container_ui.gd", "splitcontainer", "split_container"),
    ("addons/gonodes/operators/ui/tab_bar_ui.gd", "tabbar", "tab_bar"),
    ("addons/gonodes/operators/ui/tab_container_ui.gd", "tabcontainer", "tab_container"),
    ("addons/gonodes/operators/ui/text_edit_ui.gd", "textedit", "text_edit"),
    ("addons/gonodes/operators/ui/texture_button_ui.gd", "texturebutton", "texture_button"),
    ("addons/gonodes/operators/ui/texture_progress_bar_ui.gd", "textureprogressbar", "texture_progress_bar"),
    ("addons/gonodes/operators/ui/texture_rect_ui.gd", "texturerect", "texture_rect"),
    ("addons/gonodes/operators/ui/xy_pad_ui.gd", "xypad", "xy_pad"),
    # COMP
    ("addons/gonodes/operators/comp/merge_comp.gd", "merge_comp", "merge"),
    ("addons/gonodes/operators/comp/generic_script_node.gd", "genericscript", "script"),
    ("addons/gonodes/operators/comp/sub_network_node.gd", "subnet", "sub_network"),
    # SOP tested
    ("addons/gonodes/operators/sop/script_sop.gd", "scriptsop", "sop"),
    ("addons/gonodes/operators/sop/objectmerge_sop.gd", "objectmerge", "sop"),
    ("addons/gonodes/operators/sop/polybridge_sop.gd", "polybridge", "sop"),
    ("addons/gonodes/operators/sop/texture_sop.gd", "texture", "sop"),
    # SOP untested
    ("addons/gonodes/operators/sop/chop_to_sop.gd", "choptosop", "chop_to_sop"),
    ("addons/gonodes/operators/sop/dat_to_sop.gd", "dattosop", "dat_to_sop"),
    ("addons/gonodes/operators/sop/top_to_sop.gd", "toptosop", "top_to_sop"),
    ("addons/gonodes/operators/sop/file_in_sop.gd", "filein", "file_in"),
    ("addons/gonodes/operators/sop/file_out_sop.gd", "fileout", "file_out"),
    ("addons/gonodes/operators/sop/trail_ribbon_sop.gd", "trailribbon", "trail_ribbon"),
    ("addons/gonodes/operators/sop/voronoi_shatter_sop.gd", "voronoishatter", "voronoi_shatter"),
    ("addons/gonodes/operators/sop/uv_project_sop.gd", "uvproject", "uv_project"),
    ("addons/gonodes/operators/sop/polybevel_sop.gd", "polybevel", "poly_bevel"),
    ("addons/gonodes/operators/sop/polyloft_sop.gd", "polyloft", "poly_loft"),
    ("addons/gonodes/operators/sop/polypatch_sop.gd", "polypatch", "poly_patch"),
    ("addons/gonodes/operators/sop/polyreduce_sop.gd", "polyreduce", "poly_reduce"),
    ("addons/gonodes/operators/sop/polyspline_sop.gd", "polyspline", "poly_spline"),
    ("addons/gonodes/operators/sop/polystitch_sop.gd", "polystitch", "poly_stitch"),
    # IMG
    ("addons/gonodes/operators/img/pixel_sort_img.gd", "pixelsortimg", "pixel_sort"),
    ("addons/gonodes/operators/img/image_file_in_img.gd", "imagefileinimg", "image_file_in"),
    ("addons/gonodes/operators/img/image_sequence_img.gd", "imagesequenceimg", "image_sequence"),
    ("addons/gonodes/operators/img/top_to_img.gd", "toptoimg", "top_to_img"),
    ("addons/gonodes/operators/img/img_to_top.gd", "imgtotop", "img_to_top"),
    ("addons/gonodes/operators/img/webcam_img.gd", "webcamimg", "webcam"),
    ("addons/gonodes/operators/img/screen_grab_img.gd", "screengrab", "screen_grab"),
    ("addons/gonodes/operators/img/blur_img.gd", "blurimg", "blur"),
    ("addons/gonodes/operators/img/checkerboard_img.gd", "checkerboardimg", "checkerboard"),
    ("addons/gonodes/operators/img/edge_detect_img.gd", "edgedetectimg", "edge_detect"),
    ("addons/gonodes/operators/img/noise_img.gd", "noiseimg", "noise"),
    # OUTPUT
    ("addons/gonodes/operators/output/image_save_out.gd", "imagesave", "image_save"),
    ("addons/gonodes/operators/output/texture_save_out.gd", "texturesave", "texture_save"),
    ("addons/gonodes/operators/output/table_save_out.gd", "tablesave", "table_save"),
    ("addons/gonodes/operators/output/movie_out.gd", "movieout", "movie_out"),
    ("addons/gonodes/operators/output/record_out.gd", "recordout", "record"),
    ("addons/gonodes/operators/output/ffmpeg_out.gd", "ffmpegout", "ffmpeg"),
    ("addons/gonodes/operators/output/audio_device_out.gd", "audioout", "audio_device"),
    ("addons/gonodes/operators/output/osc_out.gd", "oscout", "osc_out"),
    ("addons/gonodes/operators/output/host_out_top.gd", "hostout", "host_out"),
    ("addons/gonodes/operators/output/host_out_dat.gd", "hostoutdat", "host_out_dat"),
    ("addons/gonodes/operators/output/host_out_chop.gd", "hostoutchop", "host_out_chop"),
    # MAT
    ("addons/gonodes/operators/mat/normal_map_mat.gd", "normalmap", "normal_map"),
    ("addons/gonodes/operators/mat/point_sprite_mat.gd", "pointsprite", "point_sprite"),
    # CHOP
    ("addons/gonodes/operators/chop/audio_band_chop.gd", "audioband", "audio_band"),
    ("addons/gonodes/operators/chop/audio_file_in_chop.gd", "audiofilein", "audio_file_in"),
    ("addons/gonodes/operators/chop/audio_in_chop.gd", "audioin", "audio_in"),
    ("addons/gonodes/operators/chop/audio_spectrum_chop.gd", "audiospectrum", "audio_spectrum"),
    ("addons/gonodes/operators/chop/cue_chop.gd", "cuesequencer", "cue_sequencer"),
    ("addons/gonodes/operators/chop/host_in_chop.gd", "hostinchop", "host_in"),
    ("addons/gonodes/operators/chop/keyboard_in_chop.gd", "keyboardin", "keyboard_in"),
    ("addons/gonodes/operators/chop/midi_in_chop.gd", "midiin", "midi_in"),
    ("addons/gonodes/operators/chop/mouse_in_chop.gd", "mousein", "mouse_in"),
    ("addons/gonodes/operators/chop/osc_in_chop.gd", "oscin", "osc_in"),
    ("addons/gonodes/operators/chop/script_chop.gd", "scriptchop", "script"),
    ("addons/gonodes/operators/chop/sop_to_chop.gd", "soptochop", "sop_to_chop"),
    ("addons/gonodes/operators/chop/top_to_chop.gd", "toptochop", "top_to_chop"),
    ("addons/gonodes/operators/chop/tabletin_chop.gd", "tabletin", "tablet_in"),
    # VOL
    ("addons/gonodes/operators/vol/sop_to_vol.gd", "soptovol", "sop_to_vol"),
    ("addons/gonodes/operators/vol/chop_to_vol.gd", "choptovol", "chop_to_vol"),
    ("addons/gonodes/operators/vol/marching_cubes_vol.gd", "marchingcubes", "marching_cubes"),
    ("addons/gonodes/operators/vol/gpu_marching_cubes_vol.gd", "gpumarchingcubes", "gpu_marching_cubes"),
]

ok = 0
fail = 0
skip = 0
for fp, old, new in fixes:
    if not os.path.exists(fp):
        print(f"SKIP (not found): {fp}")
        skip += 1
        continue
    t = open(fp, "r", encoding="utf-8").read()
    p = f'node_type = "{old}"'
    r = f'node_type = "{new}"'
    if p in t:
        open(fp, "w", encoding="utf-8", newline="").write(t.replace(p, r, 1))
        ok += 1
    else:
        print(f"MISS: {fp} — pattern '{old}' not found")
        fail += 1

print(f"\nDone: {ok} fixed, {fail} missed, {skip} skipped")
