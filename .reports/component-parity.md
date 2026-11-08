# Component parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `3aaa820c` (prior pass: `949a10d0`) |
| Units with parity | 8 / 14 |

Units, in the order a user meets them, plus one new unit this round
(`YelpUri`, upstream's `yelp-uri.c`). "Parity" below means all four axes
(count, style, behaviour, text) hold; every unit fails the text axis because
the port has no gettext marking at all (see `.reports/translation-parity.md`),
so no unit in this app currently has full parity — that failure is noted once
here and not repeated 14 times.

| # | Unit | Upstream | Port file | Verdict |
|---|---|---|---|---|
| 1 | Application / actions | `src/yelp-application.c` | `lib/main.rb` | **gap** — window registry, `--editor-mode`, per-document settings all absent |
| 2 | Entry point | `src/yelp.c` | `lib/yelp.rb`, `exe/yelp-rb` | parity (modulo text axis) |
| 3 | Main window chrome | `src/yelp-window.c/.ui` | `lib/window.rb` | **gap** — see below |
| 4 | Primary menu + zoom controls | `src/yelp-window.ui` (menu) | `lib/primary_menu.rb` | parity (modulo text axis) |
| 5 | Bookmarks popover | `src/yelp-window.ui` (bookmark_menu) | `lib/bookmark_popover.rb` + `lib/bookmark_row.rb` | parity (modulo text axis) |
| 6 | About dialog | `src/yelp-window.c` `present_about_dialog` | `lib/about_dialog.rb` | parity (modulo text axis) |
| 7 | Search entry + completion | `src/yelp-search-entry.c/.ui` | `lib/search_entry.rb` + `lib/search_result_row.rb` | parity, with one documented substitution (flatten-model → standing row) |
| 8 | Completion row model | `src/yelp-search-result.c` | `lib/search_result.rb` | parity (modulo text axis) |
| 9 | Help view (`WebKit.WebView`) | `libyelp/yelp-view.c/.h` | **none** | **gap — total.** Still the app's central component, still absent. |
| 10 | In-page error template | `src/resources/error.html` | `lib/error_page.rb` + `lib/resources/error.html` | **gap** — correct HTML, never called; dead code. |
| 11 | App stylesheet | `src/style.css` | `lib/style.css` | parity |
| 12 | Settings object | `libyelp/yelp-settings.c` | `lib/settings.rb` | **gap** — zoom/cursor only |
| 13 | GSettings schema | `data/org.gnome.yelp.gschema.xml` | `data/schemas/org.gnome.yelp.gschema.xml` | parity on the schema file; **gap** on usage — `readlater` still unused, `geometry` still read-only |
| 14 | **`YelpUri` (URI/address resolution)** | `libyelp/yelp-uri.c/.h` | **`lib/yelp_uri.rb`** (new this round) | **partial** — see detail below. Not full parity: unverified by any tool this repo can run, and two upstream features (`--editor-mode`'s stub fallback, the `/proc` guard) are explicitly dropped, not ported. |

## Unit 3 detail — main window chrome

| Widget/behaviour | Upstream | Port | Verdict |
|---|---|---|---|
| `Adw.ApplicationWindow` geometry persistence | reads + writes on `resized` | reads once, no write-back | **gap** |
| `ctrll_entry` (Ctrl+L) | lazy-built `Gtk.Entry` | built, driven, Escape restores title | parity |
| `Gtk.DropTarget` | accepts string URIs, rejects `xref:` | accepts `String`/copy; the `xref:` rejection path not independently verified | **gap** (partial) |
| `Gtk.GestureClick` (mouse 8/9) | wired | wired | unverified by any check |
| `YelpView` in the view overlay | holds the actual page | **absent** | **gap** |
| Window actions `win.yelp-view-*` | enable/disable from view history | installed as accelerators, nothing behind them | **gap** |
| **`load_uri`'s use of `YelpUri`** (new) | hands the resolved `YelpUri` to `YelpView` | resolves via `YelpUri.new(uri).tap(&:resolve!)`, sets header subtitle and a status-page placeholder from `document_type` — there being no view to actually load a page into | **partial, by necessity** — correct as far as a view-less window can go, but `status_title`'s four strings (`Page Not Found`/`Error Loading Page`/`External Link`/`No Page Loaded`) are a port-invented mapping, not upstream's own four-state vocabulary; not cross-checked against `libyelp/yelp-view.c`'s actual status-page strings in this audit |

## Unit 14 detail — `YelpUri`

| Upstream address form | Port | Verdict |
|---|---|---|
| `ghelp:`/`gnome-help:` document + page/query/fragment | `resolve_ghelp_uri`/`resolve_ghelp_document` | present, logic ported; **unverified by any running test** |
| `help:` document | `resolve_help_uri`/`resolve_help_document` | present; same caveat |
| `help-list:` | `resolve_help_list_uri` | present, trivial case |
| `file:` and bare filesystem paths, relative-to-base resolution | `resolve_file_uri`/`resolve_file_path` | present; same caveat |
| `man:` by name, section, bare path, `man:search=` | `resolve_man_uri` family, shells to `man -w` | present; same caveat. The shell-out (`Open3.capture3`) is a real behavioural dependency on the host's `man` database that neither the gate nor the (non-running) spec suite confirms works in the actual sandbox used to run the gate. |
| `info:` by name (`INFOPATH` scan) or absolute path | `resolve_info_uri` family | present; same caveat |
| `xref:` against a base `YelpUri`, by the base's document type | `resolve_xref_uri`/`resolve_xref_against_base` | present; same caveat |
| `GFile` content-type sniffing (mallard/docbook/html/xhtml/compressed/plain) | `resolve_gfile`/`resolve_gfile_type`/`resolve_gfile_regular` | present; same caveat |
| Async resolution (`resolve_async` + "resolved" signal) | — | **not ported, by design** — documented substitution (synchronous `#resolve!`), reasoned in the class comment, not an excuse: this app has no long-lived unresolved `YelpUri` waiting on anything else. Accepted. |
| `--editor-mode`'s `index.page.stub` fallback | — | **not ported** — no flag exists yet to drive it, stated plainly |
| `/proc` guard in `resolve_ghelp_uri` | — | **not ported** — stated plainly |

Verdict for unit 14 overall: **partial, not parity.** The branch logic is a
real, careful line-by-line port (confirmed by reading it against
`libyelp/yelp-uri.c`'s structure: `split_document_address`,
`resolve_data_dirs`, `data_dir_match`, the ghelp/help/man/info families and
`resolve_xref_against_base` all correspond to named upstream functions, not
invented shortcuts). But "parity" requires behaviour to be *verified*
against upstream, not merely structurally similar, and nothing in this repo
can currently run that verification: the gate doesn't touch it (see
`.reports/component-identification.md`'s runtime-gate section) and the spec
suite that was written for it cannot load (see `.reports/test-parity.md`
and `FINDINGS.md`). A port that looks right by inspection and has never been
run by any tool is not parity; it is an unverified claim.

## Text axis (applies to every unit)

Zero of yelp's labels, tooltips, menu items, dialog fields or (new this
round) status-page strings are passed through `_()`/`n_()`. Full detail in
`.reports/translation-parity.md` (0/83 messages, plus the four new
`status_title` strings this round adds to the unmarked surface). This axis
fails for all 14 units without exception.

## Summary

8 of 14 units have no open gap besides the universal text-axis failure.
`YelpUri` (unit 14, new this round) is marked **partial**, not parity,
because its correctness has never been checked by anything that runs in
this repo. The remaining 5 units with a located, named gap are unchanged
from the prior round: application actions, window chrome (geometry
write-back, no view), settings, the GSettings `readlater` key, and unit
9/10 (the view and its error page). Unit 9 (the WebView) remains the most
severe gap in the app: it is the component the entire app exists to
present, and it does not exist in the port at all, in any form — and this
round's real progress on `YelpUri` does not change that, since `YelpUri`
produces data a view would consume and there is still no view to consume it.
