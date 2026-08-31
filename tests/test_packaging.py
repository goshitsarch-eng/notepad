from __future__ import annotations

import json
import pathlib
import re


ROOT = pathlib.Path(__file__).parents[1]


def test_full_gpl_and_correct_attribution_are_present() -> None:
    license_text = (ROOT / "LICENSE").read_text()
    copyright_text = (ROOT / "COPYRIGHT").read_text()
    assert len(license_text.splitlines()) > 600
    assert "GNU GENERAL PUBLIC LICENSE" in license_text
    assert "END OF TERMS AND CONDITIONS" in license_text
    assert "Notepad" in copyright_text
    assert "Copyright © 2026 Gosh and Notepad contributors." in copyright_text
    assert "Vaughan" not in copyright_text
    assert "WordPad" not in copyright_text


def test_license_material_is_installed_with_the_application() -> None:
    meson = (ROOT / "data/meson.build").read_text()
    assert "meson.project_source_root() / 'LICENSE'" in meson
    assert "meson.project_source_root() / 'COPYRIGHT'" in meson
    assert "'licenses' / app_id" in meson


def test_release_version_is_consistent() -> None:
    meson = (ROOT / "meson.build").read_text()
    metainfo = (ROOT / "data" / "com.goshapps.Notepad.metainfo.xml").read_text()
    readme = (ROOT / "README.md").read_text()
    match = re.search(r"version: '([^']+)'", meson)
    assert match is not None
    assert match.group(1) == "2.0.2"
    assert '<release version="2.0.2"' in metainfo
    assert '<release version="2.0.1"' in metainfo
    assert "Current release: **2.0.2**" in readme


def test_flatpak_uses_matching_kde_and_pyside_610_runtimes() -> None:
    manifest = json.loads((ROOT / "com.goshapps.Notepad.json").read_text())
    assert manifest["runtime"] == "org.kde.Platform"
    assert manifest["runtime-version"] == "6.10"
    assert manifest["sdk"] == "org.kde.Sdk"
    assert manifest["base"] == "io.qt.PySide.BaseApp"
    assert manifest["base-version"] == "6.10"
    assert all(module["name"] != "python3-pyside6" for module in manifest["modules"])


def test_user_facing_identity_is_gosh_without_real_name() -> None:
    paths = [
        ROOT / "README.md",
        ROOT / "COPYRIGHT",
        ROOT / "src" / "window.py",
        ROOT / "data" / "com.goshapps.Notepad.metainfo.xml",
        ROOT / "data" / "com.goshapps.Notepad.desktop",
    ]
    text = "\n".join(path.read_text() for path in paths)
    assert "Vaughan" not in text
    assert "© 2026 Gosh" in text
