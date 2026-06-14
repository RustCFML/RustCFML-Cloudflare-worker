//! Walks `cfml/` and emits a Rust source file with a single
//! `pub static CFML_FILES: &[(&str, &[u8])]` table the lib uses to
//! seed `cfml_worker::embedded_vfs::EmbeddedVfs`.
//!
//! Also synthesises an `includes/version.cfm` into that table carrying the
//! resolved RustCFML (`cfml-worker`) version from `Cargo.lock`, so the UI
//! can show the engine version it was built against. (The CFML `server`
//! scope can't be used for this — building it touches OS/env APIs that
//! panic in the Workers wasm runtime.)

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    println!("cargo:rerun-if-changed=cfml");
    println!("cargo:rerun-if-changed=Cargo.lock");

    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR");
    let out_dir = env::var("OUT_DIR").expect("OUT_DIR");

    let root: PathBuf = env::current_dir().expect("cwd").join("cfml");
    let mut entries: Vec<(String, PathBuf)> = Vec::new();
    if root.exists() {
        walk(&root, &root, &mut entries);
    }
    entries.sort_by(|a, b| a.0.cmp(&b.0));

    // Synthesise includes/version.cfm from the locked cfml-worker version.
    let version = locked_version(&Path::new(&manifest_dir).join("Cargo.lock"), "cfml-worker")
        .unwrap_or_else(|| "unknown".to_string());
    let version_cfm = Path::new(&out_dir).join("version.cfm");
    fs::write(
        &version_cfm,
        format!("<cfset request.rustCfmlVersion = {:?}>\n", version),
    )
    .expect("write version.cfm");
    entries.push((
        "includes/version.cfm".to_string(),
        version_cfm,
    ));

    let dest = Path::new(&out_dir).join("embedded_files.rs");

    let mut src = String::new();
    src.push_str("pub static CFML_FILES: &[(&str, &[u8])] = &[\n");
    for (rel, abs) in &entries {
        // Embedded paths are virtual-root–relative; cfml-worker prefixes
        // them with `WorkerConfig.virtual_root` at lookup time.
        let abs_str = abs.to_string_lossy().replace('\\', "/");
        src.push_str(&format!(
            "    ({:?}, include_bytes!({:?})),\n",
            rel, abs_str
        ));
    }
    src.push_str("];\n");

    fs::write(dest, src).expect("write embedded_files.rs");
}

/// Extract a package's resolved `version` from Cargo.lock by scanning for the
/// `[[package]]` block whose `name = "<pkg>"`, then the `version` line that
/// follows it. Returns `None` if the package isn't present.
fn locked_version(lock_path: &Path, pkg: &str) -> Option<String> {
    let lock = fs::read_to_string(lock_path).ok()?;
    let name_line = format!("name = {:?}", pkg);
    let mut lines = lock.lines();
    while let Some(line) = lines.next() {
        if line.trim() == name_line {
            for next in lines.by_ref() {
                let next = next.trim();
                if let Some(rest) = next.strip_prefix("version = ") {
                    return Some(rest.trim_matches('"').to_string());
                }
                // version sits immediately under name within a block; bail at
                // the next block boundary to avoid bleeding into another pkg.
                if next == "[[package]]" {
                    break;
                }
            }
        }
    }
    None
}

fn walk(base: &Path, dir: &Path, out: &mut Vec<(String, PathBuf)>) {
    let Ok(rd) = fs::read_dir(dir) else { return };
    for entry in rd.flatten() {
        let path = entry.path();
        if path.is_dir() {
            walk(base, &path, out);
        } else if path.is_file() {
            let rel = path
                .strip_prefix(base)
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('\\', "/");
            out.push((rel, path));
        }
    }
}
