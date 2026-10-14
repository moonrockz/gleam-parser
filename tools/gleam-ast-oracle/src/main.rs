mod encode;

use camino::Utf8PathBuf;
use gleam_core::parse::parse_module;
use gleam_core::warning::WarningEmitter;
use std::io::Write;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
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
