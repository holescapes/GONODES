#!/usr/bin/env python3
"""Show SDKs GONODES does not download for you.

Permissive libraries are fetched by setup_deps.py and by GitHub Actions.
The entries below are either proprietary, or an official installer we do
not unpack. Each check is the file the build probe looks for.
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Paths are relative to the repository root and match native/build.cfg probes.
MANUAL = [
    {
        "name": "NDI",
        "why": "Proprietary. Vizrt does not allow this SDK in the GONODES download.",
        "url": "https://ndi.video/for-developers/ndi-sdk/",
        "files": [
            "addons/gn_ext_ndi/native/ndi_sdk/Include/Processing.NDI.Lib.h",
            "addons/gn_ext_ndi/native/ndi_sdk/Lib/x64/Processing.NDI.Lib.x64.lib",
        ],
        "note": "Linux: ndi_sdk/lib/x86_64-linux/libndi.so. macOS: ndi_sdk/lib/libndi.dylib. At runtime install the NDI Runtime as well.",
    },
    {
        "name": "Blackmagic DeckLink",
        "why": "Proprietary. The DeckLink SDK is not redistributable.",
        "url": "https://www.blackmagicdesign.com/support/ (Developer SDK)",
        "files": [
            "addons/gn_ext_blackmagic/native/decklink_sdk/include/DeckLinkAPI.h",
        ],
        "note": "Also install Blackmagic Desktop Video on the machine that captures or plays out.",
    },
    {
        "name": "Azure Kinect",
        "why": "Proprietary device SDK.",
        "url": "https://learn.microsoft.com/en-us/azure/kinect-dk/sensor-sdk-download",
        "files": [
            "addons/gn_ext_depth_sensor/native/azure_kinect_sdk/include/k4a/k4a.h",
        ],
        "note": "Body tracking needs the Body Tracking SDK beside it. Linux can use the Microsoft apt packages instead of this folder.",
    },
    {
        "name": "Ultraleap",
        "why": "Proprietary tracking SDK.",
        "url": "https://developer.leapmotion.com/tracking-software-download",
        "files": [
            "addons/gn_ext_depth_sensor/native/ultraleap_sdk/include/LeapC.h",
        ],
        "note": "Windows import library: ultraleap_sdk/lib/x64/LeapC.lib. Linux uses /usr/include/ultraleap from the tracking install.",
    },
    {
        "name": "Intel RealSense",
        "why": "Apache 2.0, but the Windows SDK is an installer we do not unpack into the repo.",
        "url": "https://github.com/IntelRealSense/librealsense/releases/latest",
        "files": [
            "addons/gn_ext_depth_sensor/native/realsense_sdk/include/librealsense2/rs.hpp",
        ],
        "note": "Copy include/ and the import library into realsense_sdk/. Linux: sudo apt install librealsense2-dev after adding Intel's apt repo.",
    },
]


def main() -> int:
    print("SDKs GONODES does not download")
    print("Permissive libraries (Python, NumPy, ONNX Runtime, OpenCV, Syphon,")
    print("Spout2, CEF) are fetched by:  python setup_deps.py")
    print("The same commands run in GitHub Actions.")
    print("YOLOv8 weights are AGPL and are not part of that download.")
    print()
    missing = 0
    for item in MANUAL:
        present = [
            rel for rel in item["files"]
            if os.path.isfile(os.path.join(ROOT, rel))
        ]
        state = "present" if len(present) == len(item["files"]) else "missing"
        if state == "missing":
            missing += 1
        print(f"[{state}] {item['name']}")
        print(f"  {item['why']}")
        print(f"  {item['url']}")
        for rel in item["files"]:
            mark = "ok" if os.path.isfile(os.path.join(ROOT, rel)) else "needed"
            print(f"  {mark}: {rel}")
        print(f"  {item['note']}")
        print()
    if missing:
        print(f"{missing} manual SDK(s) not in the tree. The rest of GONODES still builds.")
    else:
        print("Every manual SDK check file is present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
