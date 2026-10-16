///|
let messages_dir : String = "../tests/rejection/messages"

///|
let reports_dir : String = "../_build/reports/rejection"

///|
/// The path the fixtures are rendered as, in the diagnostic header.
let fixture_path : String = "src/fixture.gleam"

///|
/// `tests/rejection/messages/<fixture without .gleam>.txt`.
fn snapshot_path(fixture : String) -> String {
  let stem = if fixture.has_suffix(".gleam") {
    fixture.view(end_offset=fixture.length() - 6).to_owned()
  } else {
    fixture
  }
  "\{messages_dir}/\{stem}.txt"
}

///|
/// One row of the side-by-side report.
priv struct ReportRow {
  fixture : String
  oracle_accepted : Bool
  oracle_error : String
  gleam_parser_accepted : Bool
  gleam_parser_error : String
  gleam_parser_message : String
}

///|
fn html_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
fn verdict_word(accepted : Bool) -> String {
  if accepted {
    "accepts"
  } else {
    "rejects"
  }
}

///|
/// `kind (lexical kind) start..end` for an error identity.
fn identity_text(identity : (String, String?, @gleam.SrcSpan)) -> String {
  let (kind, lexical, span) = identity
  let lexical_text = match lexical {
    Some(l) => " (\{l})"
    None => ""
  }
  "\{kind}\{lexical_text} \{span.start.to_int()}..\{span.end.to_int()}"
}

///|
/// The side-by-side HTML report: per fixture, the compiler's and
/// gleam-parser's verdicts, first errors and gleam-parser's message.
fn report_html(rows : Array[ReportRow]) -> String {
  let sb = StringBuilder()
  sb.write_string(
    (
      #|<!doctype html>
      #|<html lang="en"><head><meta charset="utf-8">
      #|<meta name="viewport" content="width=device-width, initial-scale=1">
      #|<title>Rejection parity</title>
      #|<style>
      #|body{font-family:system-ui,sans-serif;margin:16px;background:#fff;color:#111}
      #|table{border-collapse:collapse;width:100%}
      #|td,th{border:1px solid #ccc;padding:6px;vertical-align:top;text-align:left}
      #|pre{white-space:pre-wrap;margin:0;font-size:12px}
      #|.same{background:#e8f7e8}.diff{background:#fdecea}
      #|@media (prefers-color-scheme: dark){body{background:#111;color:#eee}td,th{border-color:#444}.same{background:#123312}.diff{background:#3a1616}}
      #|</style></head><body>
      #|<h1>Rejection parity: the Gleam compiler and gleam-parser</h1>
      #|<table><thead><tr><th>Fixture</th><th>Gleam compiler</th><th>gleam-parser</th></tr></thead><tbody>
      #|
    ),
  )
  for row in rows {
    let same = row.oracle_accepted == row.gleam_parser_accepted &&
      row.oracle_error == row.gleam_parser_error
    let class = if same { "same" } else { "diff" }
    sb.write_string(
      "<tr class=\"\{class}\"><td>\{html_escape(row.fixture)}</td>" +
      "<td><b>\{verdict_word(row.oracle_accepted)}</b> \{html_escape(row.oracle_error)}</td>" +
      "<td><b>\{verdict_word(row.gleam_parser_accepted)}</b> \{html_escape(row.gleam_parser_error)}<pre>\{html_escape(row.gleam_parser_message)}</pre></td></tr>\n",
    )
  }
  sb.write_string("</tbody></table></body></html>\n")
  sb.to_string()
}

///|
/// Create `path` and its parents (like `mkdir -p`).
fn ensure_dir(path : String) -> Unit raise {
  let mut prefix = ""
  for part in path.split("/") {
    prefix = if prefix == "" { part.to_owned() } else { "\{prefix}/\{part}" }
    if !@fs.path_exists(prefix) {
      @fs.create_dir(prefix)
    }
  }
}

///|
fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path.view(end_offset=i).to_owned()
    None => "."
  }
}

///|
/// Report rows and gleam-parser's rendered messages (by snapshot path) for
/// every fixture.
fn report_rows(
  verdicts : Json,
  key : String,
  read : (String) -> Bytes raise,
) -> (Array[ReportRow], Map[String, String]) raise {
  guard verdicts is Object(entries) else { return ([], Map([])) }
  let rows = []
  let messages : Map[String, String] = Map([])
  for fixture, entry in entries {
    guard entry is Object(e) && e.get(key) is Some(Object(v)) else { continue }
    let text = @utf8.decode(read(fixture))
    let error = first_error(text)
    let message = match error {
      Some(d) => {
        let rendered = @gleam.render_plain(
          d,
          @gleam.SourceText(text),
          fixture_path,
        )
        messages[snapshot_path(fixture)] = rendered
        rendered
      }
      None => ""
    }
    rows.push({
      fixture,
      oracle_accepted: v.get("accepted") is Some(True),
      oracle_error: oracle_error(v).map(identity_text).unwrap_or(""),
      gleam_parser_accepted: error is None,
      gleam_parser_error: error
      .map(d => identity_text(error_identity(d)))
      .unwrap_or(""),
      gleam_parser_message: message,
    })
  }
  (rows, messages)
}

///|
/// Snapshot files under `messages/`, as paths.
fn snapshot_files() -> Array[String] raise {
  if !@fs.path_exists(messages_dir) {
    return []
  }
  let found = []
  fn go(dir : String) raise {
    for entry in @fs.read_dir(dir) {
      let path = "\{dir}/\{entry}"
      if @fs.is_dir(path) {
        go(path)
      } else if path.has_suffix(".txt") {
        found.push(path)
      }
    }
  }

  go(messages_dir)
  found
}

///|
/// Compare gleam-parser's rendered messages with the snapshots. With
/// `approve`, write them (and remove stale snapshots) instead. Returns the
/// problems.
fn check_snapshots(
  messages : Map[String, String],
  approve : Bool,
) -> Array[String] raise {
  let problems = []
  for path in snapshot_files() {
    if !messages.contains(path) {
      if approve {
        @fs.remove_file(path)
      } else {
        problems.push("stale snapshot (fixture no longer rejected): \{path}")
      }
    }
  }
  for path, rendered in messages {
    let current = if @fs.path_exists(path) {
      Some(@fs.read_file_to_string(path))
    } else {
      None
    }
    if current == Some(rendered) {
      continue
    }
    if approve {
      ensure_dir(parent_dir(path))
      @fs.write_string_to_file(path, rendered)
    } else if current is None {
      problems.push("missing snapshot: \{path}")
    } else {
      problems.push("message changed: \{path}")
    }
  }
  if !problems.is_empty() {
    problems.push(
      "review the messages, then run GLEAM_REJECTION_MODE=approve mise run test:rejection",
    )
  }
  problems
}

///|
test "snapshots live next to the fixtures under messages/" {
  @expect.expect(snapshot_path("types/alias_without_type.gleam")).to_equal(
    "../tests/rejection/messages/types/alias_without_type.txt",
  )
}

///|
test "the side-by-side report escapes HTML" {
  @expect.expect_all(s => {
    let html = report_html([
      {
        fixture: "a/b.gleam",
        oracle_accepted: false,
        oracle_error: "UnexpectedToken 1..2",
        gleam_parser_accepted: false,
        gleam_parser_error: "UnexpectedToken 1..2",
        gleam_parser_message: "error: Syntax error <x> & y",
      },
    ])
    s.expect(html).to_contain("Syntax error &lt;x&gt; &amp; y")
    s.expect(html).to_contain("a/b.gleam")
    s.expect(html).to_contain("class=\"same\"")
  })
}
