#!/usr/bin/env python3
"""Builds the XP Notepad icon files from packaging/icons/com.goshapps.Notepad.svg.

  windows/runner/resources/app_icon.ico   Windows: executable, window, taskbar and installer icon
  packaging/macos/AppIcon.icns            macOS: app icon, for when a macOS build exists

The Linux icon is the SVG itself. The Flatpak installs it as the scalable hicolor icon, which
GNOME and KDE both read. Needs ImageMagick built with librsvg (magick) and Pillow.
"""

import pathlib
import struct
import subprocess
import tempfile

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SVG = HERE / "com.goshapps.Notepad.svg"
ICO_OUT = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
ICNS_OUT = ROOT / "packaging" / "macos" / "AppIcon.icns"

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ICNS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def render(size, target):
    """Renders the SVG at size x size pixels with a transparent background; returns the PNG bytes."""
    subprocess.run(
        ["magick", "-background", "none", "-size", f"{size}x{size}", str(SVG), f"PNG32:{target}"],
        check=True,
    )
    return target.read_bytes()


def write_ico(path, sizes):
    """Writes an icon file with one PNG frame per size. Each frame is rendered from the SVG,
    so the small sizes are drawn for their pixel grid rather than scaled down."""
    with tempfile.TemporaryDirectory() as tmp:
        frames = [(size, render(size, pathlib.Path(tmp) / f"{size}.png")) for size in sizes]
    header = struct.pack("<HHH", 0, 1, len(frames))  # reserved, type 1 (icon), frame count
    offset = 6 + 16 * len(frames)
    entries = b""
    images = b""
    for size, data in frames:
        dim = 0 if size >= 256 else size  # the format stores 256 as 0
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
        images += data
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + entries + images)


def write_icns(path, sizes):
    """Writes a macOS icon set from a 1024-pixel render of the SVG."""
    with tempfile.TemporaryDirectory() as tmp:
        master = pathlib.Path(tmp) / "1024.png"
        render(1024, master)
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.open(master).save(path, format="ICNS", sizes=[(s, s) for s in sizes])


if __name__ == "__main__":
    write_ico(ICO_OUT, ICO_SIZES)
    write_icns(ICNS_OUT, ICNS_SIZES)
    print(f"wrote {ICO_OUT.relative_to(ROOT)} and {ICNS_OUT.relative_to(ROOT)}")
