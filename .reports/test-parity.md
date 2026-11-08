# Test parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `3aaa820c` (prior passes: `949a10d0`, `1b049d42`) |
| Upstream tests | 7 (6 standalone C test programs + 1 table-driven URI test with 10 fixtures, counted as its 10 cases below) |
| Ported (written) | 1 of 7 (`tests/test-uri.c`'s shape, as `spec/yelp_uri_spec.rb`, 16 examples) |
| Ported (passing / confirmed running) | **0** |
| Gaps | 7 (16 cases, counting the URI fixtures individually), unchanged, because a suite that cannot execute does not count as parity |
| Test command (port) | `nix develop --command xvfb-run -a ruby test/drive_window.rb` (gate) — `spec/yelp_uri_spec.rb` has no working command in this environment |

Upstream ships no GLib `g_test_add_func` suite and no meson/automake test
registration file. Each `tests/test-*.c` is a tiny standalone `main()` smoke
program (57–179 lines):

| Upstream file | Shape | Behaviour it pins |
|---|---|---|
| `tests/test-bz2.c` | standalone `main`, 57 lines | bz2 decompressor round-trips a compressed help page |
| `tests/test-lzma.c` | standalone `main`, 57 lines | lzma decompressor round-trips a compressed help page |
| `tests/test-magic.c` | standalone `main`, 57 lines | MIME/magic detection picks the right document backend |
| `tests/test-transform.c` | standalone `main`, 179 lines | XSLT transform produces the expected HTML for a fixture document |
| `tests/test-view.c` | standalone `main`, 108 lines | `YelpView` loads a document end-to-end |
| `tests/test-uri.c` + `tests/uri/*.test` (10 fixtures) | one `main` driven by 10 fixture files | `YelpUri` parses each URI scheme/form into the right document type and locator |

## Census

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `tests/test-bz2.c` | bz2-compressed help pages decompress correctly | — | **gap** — no decompressor exists in the port |
| 2 | `tests/test-lzma.c` | lzma-compressed help pages decompress correctly | — | **gap** — no decompressor exists in the port |
| 3 | `tests/test-magic.c` | MIME detection selects the right document backend | — | **gap** — no document backend exists in the port |
| 4 | `tests/test-transform.c` | XSLT transform produces correct HTML from a DocBook/Mallard fixture | — | **gap** — no transform pipeline exists in the port |
| 5 | `tests/test-view.c` | `YelpView` loads a document end-to-end and renders it | — | **gap** — no `YelpView`/`WebKit.WebView` exists in the port at all |
| 6 | `tests/uri/ghelp-docbook-{1,2}.test` + `path-docbook-{1,2}.test` (4 cases) | `help:`/`ghelp:`/path URIs resolve to the DocBook backend with the right locator | `spec/yelp_uri_spec.rb` — "resolves a docbook document, matching ghelp-docbook-1.test", "resolves a docbook xref, matching ghelp-docbook-2.test", "resolves an absolute docbook path, matching path-docbook-1.test", "keeps the fragment on the canonical uri, matching path-docbook-2.test" | **written, not confirmed running** — see verdict below |
| 7 | `tests/uri/ghelp-mallard-{1,2}.test` + `path-mallard-{1,2}.test` (4 cases) | same, for Mallard | `spec/yelp_uri_spec.rb` — 4 matching examples, named the same way | **written, not confirmed running** |
| 8 | `tests/uri/man-{1,2}.test` (2 cases) | `man:` URIs resolve to the man backend | `spec/yelp_uri_spec.rb` has 2 man examples, but neither names itself against `man-1.test`/`man-2.test` specifically (one is "a man page given as a bare file path", the other "falls back to not_found") — fixture-for-fixture correspondence not confirmed, only scheme coverage | **written, not confirmed running, and only approximately mapped** |

**Behaviour still owed, per row:** a user who opens a bz2- or lzma-compressed
help page, a DocBook/Mallard/man document by any of its four addressing
forms, or any page at all, gets a result. Rows 1–5 are untouched this round.
Rows 6–8 have a spec file written against them for the first time, but see
below for why that does not move them out of "gap."

## Why rows 6–8 are still gaps, not "ported"

This round added `lib/yelp_uri.rb` (638 lines, ported from
`libyelp/yelp-uri.c`) and `spec/yelp_uri_spec.rb` (170 lines, 16 examples
rebuilding fixture directory trees analogous to upstream's `tests/uri/*.test`
files). That is real progress on rows 6–8's *production code* and a real
attempt at test coverage for it. It is independently re-verified in this
audit that:

1. **The spec file cannot be executed in this environment.** Running
   `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit
   RSpec::Core::Runner.run(["--format","progress","--require","spec_helper",
   "spec"])'` (the dev shell's own printed spec command) produces:
   ```
   Failure/Error: require "kettle/test/rspec"
   LoadError: cannot load such file -- kettle/test/rspec
   0 examples, 0 failures, 2 errors occurred outside of examples
   ```
   `spec/spec_helper.rb` requires `kettle/test/rspec`, a gem absent from this
   repo's Nix flake closure, and `.rspec` forces `--require spec_helper` on
   every invocation, so no spec in this repo — `spec/yelp_uri_spec.rb`
   included — can load, regardless of its own content.
2. **The port's own `FINDINGS.md` (new this round) discloses this itself**,
   in the right place, rather than hiding it: "no spec file can currently be
   loaded... `lib/yelp_uri.rb`'s behaviour was instead verified directly: ad
   hoc scripts... asserted the resolver's output against each fixture's
   expected... fields." That is an honest statement that the committed,
   repo-tracked test suite has never once passed, in this environment or any
   CI built from it.
3. **The "ad hoc scripts" claimed as the real verification are not in the
   repo.** They are not committed, not named, not reproducible by this audit
   or by anyone who clones `ruby` fresh. The claim that `yelp_uri.rb`'s
   "logic has been exercised and is correct" rests entirely on work this
   audit cannot see and the next engineer cannot re-run. That is not a
   criticism of the honesty of the disclosure — `FINDINGS.md` says exactly
   this, correctly flagged as unresolved — but it means rows 6–8 do not get
   to move to "ported": **per this audit's brief, a suite that has never
   been executed is a gap, and that is true whether the suite never existed
   or exists and has never once run.** Both are the same gap from a
   reader's standpoint: zero committed, reproducible evidence that
   `YelpUri` does what the fixtures require.

Reading the spec file itself (done for this audit): it covers 8 of the 10
upstream fixtures by the ported test's own naming (`ghelp-docbook-{1,2}`,
`ghelp-mallard-{1,2}`, `path-docbook-{1,2}`, `path-mallard-{1,2}`), omits
explicit 1:1 naming for `man-{1,2}.test`, and adds extra cases upstream's
`test-uri.c` fixture set does not have (`help:`, `help-list:`, `info:` via
`INFOPATH`, external-scheme, and a `resolved?` state check) — a reasonable
superset in intent, written with real care for upstream's resolution rules
(e.g. the comment block explaining why fixtures are rebuilt in a tmpdir
rather than assuming `/usr/share/gnome/help/user-guide` exists on the host).
None of that care changes the verdict: intent and coverage-by-reading are
not the same thing as a green CI run, and this audit found zero.

## Why rows 1–5 remain 0/5, not "N/A"

Unchanged from the prior round: every one of these tests exercises parts of
the document pipeline that still do not exist in the port (decompressors,
MIME backend selection, XSLT transform, `WebKit.WebView`). There is no Ruby
code these tests could even be translated against yet.

## The port's own suite is not test parity, and is read here as `## Extra`

`test/drive_window.rb` (69 `check` assertions, run under
`test/gtk_driver.rb`) is a real, currently-passing suite — re-run for this
audit: `69 of 69 checks passed / DRIVE OK`. None of its 69 checks exercises
`YelpUri`'s resolution logic in any way that would fail if that logic were
wrong (see `.reports/component-identification.md`'s runtime-gate section for
why the one check that touches `load_uri` cannot distinguish correct
resolution from a no-op passthrough). None of the 69 checks maps to any of
the 8 rows above.

## Extra

- `test/drive_window.rb` — 69 checks, real and passing, covering window
  chrome/zoom/show-cursor/Ctrl+L/drop-target/bookmarks/find-bar/search/about
  dialog/second-window/breakpoint. Excludes the document pipeline entirely.
- `spec/yelp_uri_spec.rb` — 16 examples, written, **never executed by any
  tool in this repo**, per above.

## The runtime gate, read against this ledger

The round's gate (69 checks, 0 failed, `drive_ok: true`, 12 components per
this round's harness, vs. 10 and 12 in the two prior rounds for the same
drive script — the "components" count itself is not something
`test/drive_window.rb` prints, is sourced from outside this repo, and has
drifted across three audits of the identical 69-check script, which is
itself worth flagging: a number that changes without the thing it is
counting changing is not a number to trust) is exactly
`test/drive_window.rb`'s own count. It is not evidence of test parity with
upstream, and — new finding this round — it is not evidence that this
round's own new code (`lib/yelp_uri.rb`) works either. **0/7 (16 individual
cases), suite-for-suite.** The one row this round made a real, careful
attempt at (rows 6–8) still counts as a gap, because "wrote a spec" and
"the spec has ever run and passed" are different claims, and only the first
one is true here.
