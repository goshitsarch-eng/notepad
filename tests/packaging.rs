use std::path::PathBuf;

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn read(rel: &str) -> String {
    std::fs::read_to_string(root().join(rel)).unwrap()
}

#[test]
fn full_gpl_and_correct_attribution_are_present() {
    let license_text = read("LICENSE");
    let copyright_text = read("COPYRIGHT");
    assert!(license_text.lines().count() > 600);
    assert!(license_text.contains("GNU GENERAL PUBLIC LICENSE"));
    assert!(license_text.contains("END OF TERMS AND CONDITIONS"));
    assert!(copyright_text.contains("Notepad"));
    assert!(copyright_text.contains("Copyright © 2026 Gosh and Notepad contributors."));
    assert!(!copyright_text.contains("Vaughan"));
    assert!(!copyright_text.contains("WordPad"));
}

#[test]
fn license_material_is_installed_with_the_application() {
    let justfile = read("justfile");
    assert!(justfile.contains("LICENSE"));
    assert!(justfile.contains("COPYRIGHT"));
    assert!(justfile.contains("share") && justfile.contains("licenses"));
}

#[test]
fn release_version_is_consistent() {
    let cargo = read("Cargo.toml");
    let metainfo = read("data/com.goshapps.Notepad.metainfo.xml");
    let readme = read("README.md");
    assert!(cargo.contains("version = \"3.0.0\""));
    assert!(metainfo.contains("<release version=\"3.0.0\""));
    assert!(metainfo.contains("<release version=\"3.0.0\" date=\"2026-09-06\""));
    assert!(metainfo.contains("<release version=\"2.0.4\""));
    assert!(metainfo.contains("<release version=\"2.0.3\""));
    assert!(metainfo.contains("<release version=\"2.0.2\""));
    assert!(metainfo.contains("<release version=\"2.0.1\""));
    assert!(readme.contains("Current release: **3.0.0**"));
    let readme_flat = readme.split_whitespace().collect::<Vec<_>>().join(" ");
    let metainfo_flat = metainfo.split_whitespace().collect::<Vec<_>>().join(" ");
    assert!(readme_flat.contains("leading check column"));
    assert!(metainfo_flat.contains("leading check column"));
}

#[test]
fn flatpak_uses_cosmic_baseapp() {
    let manifest = read("com.goshapps.Notepad.json");
    let value: serde_json::Value = serde_json::from_str(&manifest).unwrap();
    assert_eq!(value["runtime"], "org.freedesktop.Platform");
    assert_eq!(value["runtime-version"], "25.08");
    assert_eq!(value["sdk"], "org.freedesktop.Sdk");
    assert_eq!(value["base"], "com.system76.Cosmic.BaseApp");
    assert_eq!(value["base-version"], "stable");
    assert_eq!(value["command"], "notepad");
    let finish = value["finish-args"]
        .as_array()
        .expect("finish-args")
        .iter()
        .filter_map(|v| v.as_str())
        .collect::<Vec<_>>();
    assert!(
        finish.contains(&"--filesystem=xdg-config/cosmic:rw"),
        "config must be writable in the Flatpak sandbox: {finish:?}"
    );
    assert!(!finish.contains(&"--filesystem=xdg-config/cosmic:ro"));
}

#[test]
fn user_facing_identity_is_gosh_without_real_name() {
    let paths = [
        "README.md",
        "COPYRIGHT",
        "src/app.rs",
        "data/com.goshapps.Notepad.metainfo.xml",
        "data/com.goshapps.Notepad.desktop",
    ];
    let text: String = paths.iter().map(|p| read(p)).collect::<Vec<_>>().join("\n");
    assert!(!text.contains("Vaughan"));
    assert!(text.contains("© 2026 Gosh") || text.contains("Copyright © 2026 Gosh"));
}

#[test]
fn metainfo_declares_cosmic_application() {
    let metainfo = read("data/com.goshapps.Notepad.metainfo.xml");
    assert!(metainfo.contains("<id>com.system76.CosmicApplication</id>"));
    assert!(metainfo.contains("<id>com.goshapps.Notepad</id>"));
}
