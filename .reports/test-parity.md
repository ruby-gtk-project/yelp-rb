# Test parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `1b049d42` |
| Upstream tests | 7 (6 standalone C test programs + 1 table-driven URI test with 10 fixtures, counted as its 10 cases below) |
| Ported | 0 |
| Gaps | 7 (16 cases, counting the URI fixtures individually) |
| Test command (port) | `nix develop --command xvfb-run -a ruby test/drive_window.rb` |

Upstream ships no GLib `g_test_add_func` suite and no meson/automake test
registration file — `tests/Makefile.am`/`meson.build` is absent from
`origin/master`. Each `tests/test-*.c` is a tiny standalone `main()` smoke
program (57–179 lines), not a framework-driven suite:

| Upstream file | Shape | Behaviour it pins |
|---|---|---|
| `tests/test-bz2.c` | standalone `main`, 57 lines | the bz2 decompressor round-trips a compressed help page |
| `tests/test-lzma.c` | standalone `main`, 57 lines | the lzma decompressor round-trips a compressed help page |
| `tests/test-magic.c` | standalone `main`, 57 lines | MIME/magic detection picks the right document backend |
| `tests/test-transform.c` | standalone `main`, 179 lines | the XSLT transform pipeline produces the expected HTML for a fixture document |
| `tests/test-view.c` | standalone `main`, 108 lines | `YelpView` loads a document end-to-end |
| `tests/test-uri.c` + `tests/uri/*.test` (10 fixtures) | one `main` driven by 10 fixture files, one case each (`ghelp-docbook-{1,2}`, `ghelp-mallard-{1,2}`, `man-{1,2}`, `path-docbook-{1,2}`, `path-mallard-{1,2}`) | `YelpUri` parses each URI scheme/form into the right document type and locator |

## Census

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `tests/test-bz2.c` | bz2-compressed help pages decompress correctly | — | **gap** — no decompressor exists in the port |
| 2 | `tests/test-lzma.c` | lzma-compressed help pages decompress correctly | — | **gap** — no decompressor exists in the port |
| 3 | `tests/test-magic.c` | MIME detection selects the right document backend | — | **gap** — no document backend exists in the port |
| 4 | `tests/test-transform.c` | XSLT transform produces correct HTML from a DocBook/Mallard fixture | — | **gap** — no transform pipeline exists in the port |
| 5 | `tests/test-view.c` | `YelpView` loads a document end-to-end and renders it | — | **gap** — no `YelpView`/`WebKit.WebView` exists in the port at all |
| 6 | `tests/uri/ghelp-docbook-{1,2}.test` + `path-docbook-{1,2}.test` (4 cases) | `help:`/`ghelp:`/path URIs resolve to the DocBook backend with the right locator | — | **gap** — no URI parser exists in the port |
| 7 | `tests/uri/ghelp-mallard-{1,2}.test` + `path-mallard-{1,2}.test` (4 cases) | same, for Mallard | — | **gap** — no URI parser exists in the port |
| 8 | `tests/uri/man-{1,2}.test` (2 cases) | `man:` URIs resolve to the man backend | — | **gap** — no URI parser exists in the port |

**Behaviour still owed, per row:** a user who opens a bz2- or lzma-compressed
help page, a DocBook/Mallard/man document by any of its four addressing
forms, or any page at all, gets a result — because right now none of that
pipeline exists for a Ruby test to even target.

## Why the count is 0/7, not "N/A"

Every one of these tests exercises the document pipeline (`libyelp/`) — URI
parsing, decompression, backend selection, XSLT transform, and the
`WebKit.WebView` wrapper. None of that pipeline has been ported (confirmed in
`.reports/component-identification.md` and `.reports/component-parity.md`).
There is no Ruby code these tests could even be translated against yet. That
makes every row a gap, not an exemption — per the test-parity skill, "the
bindings don't carry this feature" and "this is C-specific plumbing" are not
states a row may hold. The row exists; it is open.

## The port's own suite is not test parity, and is read here as `## Extra`

`test/drive_window.rb` (69 `check` assertions across 54 `step`s, run under
`test/gtk_driver.rb`) is a real, currently-passing suite — re-run for this
audit: `69 of 69 checks passed / DRIVE OK`. It was written for the port, from
scratch, and does not correspond to any upstream test — upstream has no GUI
widget tests at all; its suite is backend-only. None of the 69 checks maps to
any of the 7 rows above.

## Extra

- `test/drive_window.rb` — 69 checks driving window chrome, zoom actions,
  show-cursor, Ctrl+L address bar, drop-target wiring, bookmarks add/remove,
  find bar, search entry/completion/keyboard navigation, the about dialog, a
  second window, and the adaptive breakpoint. Real and passing, and useful —
  but it tests only what the port chose to build, which excludes the entire
  document pipeline this ledger is about.

## The runtime gate, read against this ledger

The round's gate (69 checks, 0 failed, 12 components, `drive_ok: true`) is
exactly `test/drive_window.rb`'s own count. It is not evidence of test parity
with upstream — it is evidence that the port's own, self-selected surface
works. Per this skill: **the port has inherited no safety net from upstream's
suite at all.** 0/7 (16 individual cases), suite-for-suite, and the backend
code the upstream suite exists to protect has not been started.
