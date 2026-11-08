# yelp-rb — component identification (refresh)

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` (the fork has no `main`; `origin/master` is the parent's default branch) |
| Port | `ruby` @ `3aaa820c` (prior pass: `949a10d0`) |
| Supersedes | `.reports/component-inventory.md` and the prior revision of this file (`949a10d0`), now stale — this round ports `lib/yelp_uri.rb`, wires it into `Window#load_uri`, adds `FINDINGS.md`, and rewrites the five "separate porting track" sites the prior accountability pass flagged |

This is a third refresh: the per-file widget/CSS/signal tables from earlier
rounds are still accurate for the files they already covered. What changed
since `949a10d0` is one new file and one changed call site:

| File | Lines | Status |
|---|---:|---|
| `lib/yelp.rb` | 3 | done — entry require |
| `lib/main.rb` | 216 | present: `Gtk::Application`, 4 `app.yelp-application-*` actions + accelerators, `YelpBookmarksInterface`. Missing: window registry (`windows_by_document`), `--editor-mode`, per-document `GKeyfileSettingsBackend`. Its "separate porting track" comment is now rewritten to cite `FINDINGS.md` (which now exists — see below) instead of asserting a schedule. |
| `lib/settings.rb` | 79 | present for `zoom-level`/`show-cursor`. Missing: font families/sizes, editor mode, XSLT colour/icon palette |
| `lib/window.rb` | ~400 | present: chrome, breakpoint, header bar, title, back/forward, menu button, search toggle, bookmark menu button, find revealer/buttons, bottom action bar, `ctrll_entry`, `Gtk::DropTarget`, `Gtk::GestureClick`, `win.yelp-window-*` actions. **New this round:** `load_uri` now constructs a `YelpUri`, calls `#resolve!`, and uses `canonical_uri`/`document_type` to set the header subtitle and a new `status_title` status-page mapping (`Page Not Found`/`Error Loading Page`/`External Link`/`No Page Loaded`) — four more unmarked user-visible strings, folded into the existing 0/83 translation gap. Still reads `geometry` once and never writes it back. **Still no `YelpView`/`WebKit.WebView` in the view overlay** — the central component of the app is still simply absent; only the address/status plumbing around where a view would sit has grown. |
| `lib/primary_menu.rb` | 135 | done — menu model + zoom-controls box |
| `lib/about_dialog.rb` | 34 | done, fields match upstream; no `_()` marking |
| `lib/bookmark_popover.rb` | 127 | present; persists through `Application#add_bookmark`/`#remove_bookmark`/`#bookmarks` |
| `lib/bookmark_row.rb` | 58 | done |
| `lib/search_result.rb` | 55 | done — plain model |
| `lib/search_entry.rb` | 262 | present, substitution noted in prior rounds (flatten-model → standing row). Its "separate porting track" comment is now rewritten to cite `FINDINGS.md`. |
| `lib/search_result_row.rb` | 79 | done — completion row widget |
| `lib/error_page.rb` | 112 | produces the right HTML string; still dead code (nothing calls it, no WebView to load it into). Its binding-limitation paragraph is now moved to `FINDINGS.md` and the in-file comment shortened to a citation, which is the correct split — this round actually did what the prior accountability report's "Action owed" #2 asked for. |
| `lib/resources/error.html` | — | unchanged; 12 status icons still not carried over |
| `lib/style.css` | 14 | unchanged, parity |
| `lib/yelp/rb/version.rb` | — | done — gem version |
| **`lib/yelp_uri.rb`** | **638** | **new this round.** Ported from `libyelp/yelp-uri.c`/`.h`: resolves `ghelp:`/`help:`/`help-list:`/`file:`/`man:`/`info:`/`xref:`/bare-path addresses into a document type, canonical URI, `Gio::File`, search path and page/fragment id, synchronously (`#resolve!`) rather than upstream's async worker-thread + "resolved" signal — a documented, reasoned substitution, not silently dropped behaviour. `--editor-mode`'s `index.page.stub` fallback and the `/proc` guard in `resolve_ghelp_uri` are explicitly not carried over (no flag exists yet to drive them). This is the single largest file in the port and the first piece of the document-loading pipeline (previously 0% ported — see `.reports/test-parity.md` and `.reports/component-parity.md` unit 9) to exist in any form. |
| **`spec/yelp_uri_spec.rb`** | **170** | **new this round.** 16 examples rebuilding upstream's fixture shapes (`tests/uri/*.test`) under throwaway tmpdirs, covering 8 of the 10 upstream URI-test fixtures by name plus man/info/help-list/external/unresolved cases. **Confirmed in this audit: cannot run.** `spec_helper.rb` requires `kettle/test/rspec`, which is not in this environment's gem closure (`nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--require","spec_helper","spec"])'` → `LoadError: cannot load such file -- kettle/test/rspec`, 0 examples, 2 errors). This is disclosed in `FINDINGS.md` (new this round) rather than hidden, which is the right place for it — but it means the spec file is unexecuted code whose assertions have never been checked by any tool, in this repo or any CI it would run in. |
| **`FINDINGS.md`** | **70** | **new this round.** Records two binding/environment limitations: no `WebKit::WebView` gem exists in this fleet (only `webkit-web-process-extension`, confirmed empirically not a substitute), and the RSpec harness cannot load (`kettle/test/rspec` missing) so `spec/yelp_uri_spec.rb` has never executed — the port's own author states this "cannot be demonstrated passing through `rake spec` in this environment even though its logic has been exercised and is correct," a claim this audit can confirm the "cannot run" half of and cannot independently confirm the "exercised and correct" half of (see `.reports/test-parity.md`). |

**Still missing entirely, no file exists for any of these:**
- `lib/view.rb` + `lib/view_context_menu.rb` — the `WebKit.WebView` itself, print, the context menu, the `win.yelp-view-*` action implementations
- `po/` and all gettext marking (zero `_()`/`n_()` calls anywhere in `lib/`, and the count of unmarked strings grew this round — see `lib/window.rb` row above)
- The rest of the backend: the five document backends (docbook/mallard/man/info/simple), `yelp-transform.c` (XSLT), the man/info parsers, `yelp-storage.c`/sqlite search index, the two decompressors, `yelp-help-list.c`, the web-process extension

**Never carried over at all:**
- Window registry (one window per document URI, raising the existing one) — note `lib/main.rb`'s comment now says `lib/yelp_uri.rb` "can now resolve" the key this would need, but nothing calls it from `Application` yet
- `--editor-mode`
- `GKeyfileSettingsBackend` for per-document settings
- Geometry *persistence* (read-only, one-way)
- Status icons (12 assets)

## Runtime-gate scope check

The gate's 69 checks (`test/drive_window.rb`) exercise: window chrome, zoom
actions, show-cursor toggle, `Ctrl+L` address bar, drop target wiring,
bookmarks add/remove, find bar, search entry/completion popover/keyboard nav,
about dialog, second window + `win.yelp-window-close`, and the adaptive
breakpoint. Re-run for this audit: `nix develop --command xvfb-run -a ruby
test/drive_window.rb` → `69 of 69 checks passed / DRIVE OK`, matching the
round's gate exactly.

**It still covers zero of `lib/yelp_uri.rb`'s own resolution logic.** One
step ("open the address bar again and load a new address") types
`help:gnome-help/accessibility` into the Ctrl+L entry and asserts
`window.current_uri == 'help:gnome-help/accessibility'`. That assertion
passes whether or not `YelpUri` actually finds a matching help tree on disk:
`resolve_help_document` builds `@full_uri` from the input's own document/page
parts unconditionally, so the literal string round-trips through
`canonical_uri` regardless of `document_type` (`:mallard` if a matching
`gnome-help` tree happens to exist in this sandbox's XDG data dirs, `:error`/
`:not_found` if not — never checked either way by the drive script). No
check in the suite reads `window.content_status_page.title`,
`.description`, or any `YelpUri` instance's `document_type`, `file`,
`search_path`, `page_id` or `frag_id`. The 638 lines of branch logic in
`lib/yelp_uri.rb` — ghelp/help/man/info/xref resolution, data-dir scanning,
MIME sniffing, the man-path shell-out — are exercised by **nothing** this
repo can currently run: not the gate (wrong surface), not the spec suite
(cannot load). "10 components, 0 failed" (this round; two prior rounds
reported 12 and 10) still describes the fraction of the app the gate was
built to drive, not the app, and now not even all of what was *written*
this round. Per the accountability-ensurance finding below, the port's own
`FINDINGS.md` is honest about the spec suite not running; nothing in
`.reports/` said so until this revision.
