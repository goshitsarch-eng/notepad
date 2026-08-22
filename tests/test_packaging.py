from __future__ import annotations

import pathlib


ROOT = pathlib.Path(__file__).parents[1]


def test_full_gpl_and_correct_attribution_are_present() -> None:
    license_text = (ROOT / "LICENSE").read_text()
    copyright_text = (ROOT / "COPYRIGHT").read_text()
    assert len(license_text.splitlines()) > 600
    assert "GNU GENERAL PUBLIC LICENSE" in license_text
    assert "END OF TERMS AND CONDITIONS" in license_text
    assert "Notepad" in copyright_text
    assert "Vaughan Jones" in copyright_text
    assert "WordPad" not in copyright_text


def test_license_material_is_installed_with_the_application() -> None:
    meson = (ROOT / "data/meson.build").read_text()
    assert "meson.project_source_root() / 'LICENSE'" in meson
    assert "meson.project_source_root() / 'COPYRIGHT'" in meson
    assert "'licenses' / app_id" in meson
