#!/usr/bin/env python3
"""Player template names, version stamps, and editor bundles.

The Build dialog downloads GONODESPlayer-<tag>-<platform>.zip from the GitHub
release recorded in addons/gonodes/template_source.cfg. This script writes
that file, writes TEMPLATE_VERSION.txt beside a player, and packs the
release zips. Godot and godot-cpp versions stay in versions.env.
"""

from __future__ import annotations

import argparse
import os
import stat
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_CFG = os.path.join(ROOT, "addons", "gonodes", "template_source.cfg")
STAMP_NAME = "TEMPLATE_VERSION.txt"

# Platforms the editor may download. Android and iOS are built by hand.
DOWNLOADABLE = (
    "windows_x86_64",
    "windows_arm64",
    "linux_x86_64",
    "linux_arm64",
    "macos",
    "web",
)


def load_versions_env() -> dict:
    vals = {}
    path = os.path.join(ROOT, "versions.env")
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            vals[key.strip()] = value.strip()
    return vals


def app_version() -> str:
    project = os.path.join(ROOT, "project.godot")
    with open(project, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("config/version="):
                return line.split("=", 1)[1].strip().strip('"')
    raise ValueError("project.godot is missing config/version")


def player_asset_name(tag: str, platform: str) -> str:
    return "GONODESPlayer-%s-%s.zip" % (tag, platform)


def editor_asset_name(tag: str, platform: str) -> str:
    return "GONODESEditor-%s-%s.zip" % (tag, platform)


def download_url(repository: str, tag: str, platform: str) -> str:
    if not repository or not tag or "/" not in repository or ".." in repository:
        return ""
    return "https://github.com/%s/releases/download/%s/%s" % (
        repository,
        tag,
        player_asset_name(tag, platform),
    )


def stamp_text(godot_version: str, gonodes_version: str) -> str:
    return "godot=%s\ngonodes=%s\n" % (godot_version, gonodes_version)


def write_stamp(directory: str, godot_version: str, gonodes_version: str) -> str:
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, STAMP_NAME)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(stamp_text(godot_version, gonodes_version))
    return path


def read_source_cfg(path: str = SOURCE_CFG) -> dict:
    found = {"service": "", "repository": "", "tag": "", "godot_version": ""}
    if not os.path.isfile(path):
        return found
    section = ""
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#") or line.startswith(";"):
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if section != "source" or "=" not in line:
                continue
            key, value = line.split("=", 1)
            found[key.strip()] = value.strip().strip('"')
    return found


def write_source(repository: str, tag: str) -> None:
    versions = load_versions_env()
    godot_version = versions.get("GODOT_VERSION", "")
    if not godot_version:
        raise ValueError("versions.env is missing GODOT_VERSION")
    os.makedirs(os.path.dirname(SOURCE_CFG), exist_ok=True)
    text = (
        "[source]\n"
        "\n"
        'service="github"\n'
        'repository="%s"\n'
        'tag="%s"\n'
        'godot_version="%s"\n'
    ) % (repository, tag, godot_version)
    with open(SOURCE_CFG, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def _zip_dir(source_dir: str, zip_path: str) -> None:
    os.makedirs(os.path.dirname(zip_path), exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for dirpath, _dirnames, filenames in os.walk(source_dir):
            for name in filenames:
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, source_dir).replace(os.sep, "/")
                info = zipfile.ZipInfo(rel)
                mode = os.stat(full).st_mode
                info.external_attr = (mode & 0xFFFF) << 16
                if stat.S_ISDIR(mode):
                    continue
                with open(full, "rb") as handle:
                    archive.writestr(info, handle.read())


def stage(tag: str, templates: str, editors: str, out_dir: str) -> list:
    """Zip each player folder and, when an editor exists, an editor bundle.

    The editor bundle has the editor at the archive root and the matching
    player under templates/<platform>/.
    """
    written = []
    os.makedirs(out_dir, exist_ok=True)
    if not os.path.isdir(templates):
        return written
    for platform in sorted(os.listdir(templates)):
        player_dir = os.path.join(templates, platform)
        if not os.path.isdir(player_dir):
            continue
        player_zip = os.path.join(out_dir, player_asset_name(tag, platform))
        _zip_dir(player_dir, player_zip)
        written.append(player_zip)
        editor_dir = os.path.join(editors, platform)
        if not os.path.isdir(editor_dir):
            continue
        bundle = os.path.join(out_dir, "_bundle_" + platform)
        if os.path.isdir(bundle):
            import shutil
            shutil.rmtree(bundle)
        import shutil
        shutil.copytree(editor_dir, bundle)
        dest_player = os.path.join(bundle, "templates", platform)
        shutil.copytree(player_dir, dest_player)
        editor_zip = os.path.join(out_dir, editor_asset_name(tag, platform))
        _zip_dir(bundle, editor_zip)
        shutil.rmtree(bundle)
        written.append(editor_zip)
    return written


def _self_check() -> None:
    import shutil
    import tempfile

    assert player_asset_name("v0.1.0-beta", "linux_arm64") == (
        "GONODESPlayer-v0.1.0-beta-linux_arm64.zip"
    )
    assert download_url("", "v1", "web") == ""
    assert download_url("kino/gonodes", "v1", "web").endswith(
        "/releases/download/v1/GONODESPlayer-v1-web.zip"
    )
    assert download_url("../x", "v1", "web") == ""
    tmp = tempfile.mkdtemp()
    try:
        player = os.path.join(tmp, "templates", "linux_x86_64")
        os.makedirs(player)
        with open(os.path.join(player, "GONODESPlayer"), "w", encoding="utf-8") as handle:
            handle.write("player")
        write_stamp(player, "4.7.2", "0.1.0-beta")
        editor = os.path.join(tmp, "editor_dist", "linux_x86_64")
        os.makedirs(editor)
        with open(os.path.join(editor, "GONODES"), "w", encoding="utf-8") as handle:
            handle.write("editor")
        out = os.path.join(tmp, "release")
        written = stage("v0.1.0-beta", os.path.join(tmp, "templates"), os.path.join(tmp, "editor_dist"), out)
        names = sorted(os.path.basename(path) for path in written)
        assert names == [
            "GONODESEditor-v0.1.0-beta-linux_x86_64.zip",
            "GONODESPlayer-v0.1.0-beta-linux_x86_64.zip",
        ]
        with zipfile.ZipFile(os.path.join(out, names[0])) as archive:
            assert "GONODES" in archive.namelist()
            assert "templates/linux_x86_64/GONODESPlayer" in archive.namelist()
            assert "templates/linux_x86_64/TEMPLATE_VERSION.txt" in archive.namelist()
    finally:
        shutil.rmtree(tmp)
    print("template_release self-check passed")


def main() -> int:
    parser = argparse.ArgumentParser(description="GONODES player template release helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    stamp = sub.add_parser("write-stamp")
    stamp.add_argument("--dir", required=True)

    source = sub.add_parser("write-source")
    source.add_argument("--repository", required=True)
    source.add_argument("--tag", required=True)

    pack = sub.add_parser("stage")
    pack.add_argument("--tag", required=True)
    pack.add_argument("--templates", default=os.path.join(ROOT, "templates"))
    pack.add_argument("--editors", default=os.path.join(ROOT, "editor_dist"))
    pack.add_argument("--out", default=os.path.join(ROOT, "dist", "release"))

    sub.add_parser("self-check")
    args = parser.parse_args()

    if args.cmd == "self-check":
        _self_check()
        return 0
    if args.cmd == "write-stamp":
        versions = load_versions_env()
        path = write_stamp(args.dir, versions.get("GODOT_VERSION", ""), app_version())
        print(path)
        return 0
    if args.cmd == "write-source":
        write_source(args.repository, args.tag)
        print(SOURCE_CFG)
        return 0
    written = stage(args.tag, args.templates, args.editors, args.out)
    for path in written:
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
