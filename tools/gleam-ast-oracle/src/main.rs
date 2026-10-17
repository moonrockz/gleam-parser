mod encode;

use camino::Utf8PathBuf;
use gleam_core::parse::parse_module;
use gleam_core::warning::WarningEmitter;
use std::io::Write;
use unicode_width::UnicodeWidthChar;

fn unicode_widths() -> serde_json::Value {
    let mut ranges = Vec::new();
    let mut start = 0u32;
    let mut width = 0usize;
    for code in 0..=0x110000u32 {
        // MoonBit can represent lone UTF-16 surrogates; keep them one column.
        let next = char::from_u32(code).map_or(1, |ch| ch.width().unwrap_or(0));
        if next != width || code == 0x110000 {
            if width != 1 {
                ranges.push(serde_json::json!([start, code, width]));
            }
            start = code;
            width = next;
        }
    }
    serde_json::json!({
        "crate_version": "0.2.2",
        "unicode_version": unicode_width::UNICODE_VERSION,
        "ranges": ranges,
    })
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.as_slice() == ["--unicode-widths"] {
        println!("{}", unicode_widths());
        return;
    }
    if args.is_empty() {
        eprintln!("usage: gleam-ast-oracle FILE...");
        std::process::exit(2);
    }
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    for arg in args {
        let src = match std::fs::read_to_string(&arg) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("{arg}: {e}");
                std::process::exit(1);
            }
        };
        let (emitter, warnings) = WarningEmitter::vector();
        let value = match parse_module(Utf8PathBuf::from(&arg), &src, &emitter) {
            Ok(parsed) => encode::parsed(&parsed, &warnings.take()),
            Err(error) => encode::parse_error(&error),
        };
        // serde_json's Map is a BTreeMap: keys come out sorted. No whitespace.
        writeln!(out, "{}", serde_json::to_string(&value).expect("json")).expect("stdout");
    }
}
