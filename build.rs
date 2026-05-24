use std::fs;
use std::path::Path;

fn main() {
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let cfml_dir = Path::new("cfml");

    if !cfml_dir.exists() {
        fs::write(
            format!("{out_dir}/cfml_files.rs"),
            "pub static CFML_FILES: &[(&str, &[u8])] = &[];\n",
        )
        .unwrap();
        return;
    }

    let mut entries: Vec<(String, String)> = Vec::new();
    walk_dir(cfml_dir, cfml_dir, &mut entries);
    entries.sort_by(|a, b| a.0.cmp(&b.0));

    let mut code = String::from("pub static CFML_FILES: &[(&str, &[u8])] = &[\n");
    for (rel_path, abs_path) in &entries {
        code.push_str(&format!(
            "    ({rel_path:?}, include_bytes!({abs_path:?})),\n"
        ));
    }
    code.push_str("];\n");

    fs::write(format!("{out_dir}/cfml_files.rs"), &code).unwrap();

    // Re-run whenever any file under cfml/ changes
    println!("cargo:rerun-if-changed=cfml/");
}

fn walk_dir(base: &Path, dir: &Path, entries: &mut Vec<(String, String)>) {
    let Ok(iter) = fs::read_dir(dir) else { return };
    for entry in iter.flatten() {
        let path = entry.path();
        if path.is_dir() {
            walk_dir(base, &path, entries);
        } else if path.is_file() {
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
            if matches!(ext, "cfm" | "cfc" | "cfml") {
                let rel = path.strip_prefix(base).unwrap();
                let rel_str = rel.to_string_lossy().replace('\\', "/");
                let abs_str = path.canonicalize().unwrap().to_string_lossy().to_string();
                entries.push((rel_str, abs_str));
            }
        }
    }
}
