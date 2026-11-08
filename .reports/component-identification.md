# yelp-rb — component identification (refresh)

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` (the fork has no `main`; `origin/master` is the parent's default branch) |
| Port | `ruby` @ `949a10d0` |
| Supersedes | `.reports/component-inventory.md`, which predates the four most recent commits (search entry/completion popover, stylesheet, error page, the window drive-script extension, and the `YelpBookmarksInterface` port) and is now stale in its "Status" lines |

This is a second refresh: the per-file widget/CSS/signal tables in
`.reports/component-inventory.md` are still accurate (nothing upstream was
re-scanned differently). What changed since the prior refresh (`1b049d42`) is
that `lib/main.rb`'s bookmark gap closed — `add_bookmark`/`remove_bookmark`/
`bookmarked?`/`bookmarks` now persist to `org.gnome.yelp.documents bookmarks`
instead of a `Window`-local in-memory array. The corrected file-by-file
status, current as of `949a10d0`:

| File | Lines | Status |
|---|---:|---|
| `lib/yelp.rb` | 3 | done — entry require |
| `lib/main.rb` | 195 | present: `Gtk::Application`, 4 `app.yelp-application-*` actions + accelerators, and (new in `949a10d0`) `YelpBookmarksInterface` (`add_bookmark`/`remove_bookmark`/`bookmarked?`/`bookmarks`) backed by `org.gnome.yelp.documents bookmarks`, broadcasting to every open window. Missing: window registry (`windows_by_document`), `--editor-mode`, per-document `GKeyfileSettingsBackend` |
| `lib/settings.rb` | 79 | present for `zoom-level`/`show-cursor`. Missing: font families/sizes from GNOME desktop settings, editor mode, XSLT colour/icon palette |
| `lib/window.rb` | 364+ | present: chrome, breakpoint, header bar, title, back/forward (header+bottom), menu button, search toggle, bookmark menu button, find revealer/buttons, bottom action bar, `ctrll_entry` (Ctrl+L), `Gtk::DropTarget`, `Gtk::GestureClick` (mouse back/forward), `win.yelp-window-*` actions. Reads `org.gnome.yelp.documents geometry` on open but **never writes it back** (no resize/close handler persisting new geometry). **No `YelpView`/`WebKit.WebView` in the view overlay at all** — the central component of the app is simply absent; the overlay holds only the find bar. |
| `lib/primary_menu.rb` | 135 | done — menu model + zoom-controls box |
| `lib/about_dialog.rb` | 34 | done, fields match upstream; no `_()` marking |
| `lib/bookmark_popover.rb` | 127 | present; list/add/remove now wired (since `949a10d0`) to `Application#add_bookmark`/`#remove_bookmark`/`#bookmarks`, which persist to the `org.gnome.yelp.documents bookmarks` GSettings key — bookmarks survive a restart |
| `lib/bookmark_row.rb` | 58 | done |
| `lib/search_result.rb` | 55 | done — plain model |
| `lib/search_entry.rb` | 252 | **new since the stale report.** Entry + completion popover + filter/slice model stack + standing "search for" row. Drops upstream's `Gtk::FlattenListModel` concatenation (acknowledged in the file's own header comment) in favour of a separate standing row — a real design substitution, not a gap, and it is the one place in this port where the comment correctly states a reason that survives scrutiny (a real Ruby-bindings constraint on mixed-type `Gio::ListStore`s) rather than waving off a feature. Reaches into no `YelpView`/`YelpBookmarks`, by construction, since neither exists. |
| `lib/search_result_row.rb` | 79 | **new.** Completion row widget (icon/title/bookmark-marker/description) |
| `lib/error_page.rb` | 101 | **new.** Produces the same HTML string upstream's `view_show_error_page` would load — but there is no `WebKit::WebView` anywhere in the port to hand that HTML to. It is dead code from the user's perspective: nothing calls it from a running window, because `lib/view.rb` does not exist. |
| `lib/resources/error.html` | — | **new.** Carried over verbatim except upstream's printf placeholders, now `{{...}}` markers. The 12 status icons (7 scalable SVG, 5 PNG) from `src/yelp.gresource.xml` are still **not** carried over — `lib/resources/` holds only `error.html`. |
| `lib/style.css` | 14 | **new.** All three upstream rules present (`yelp-find-frame`, `yelp-bookmark-menu row`) |
| `lib/yelp/rb/version.rb` | — | done — gem version |

**Still missing entirely, no file exists for any of these:**
- `lib/view.rb` + `lib/view_context_menu.rb` — the `WebKit.WebView` itself, print, the context menu, the `win.yelp-view-*` action implementations (window.rb wires accelerators for actions that have nothing behind them to enable/disable)
- `po/` and all gettext marking (zero `_()`/`n_()` calls anywhere in `lib/`)
- The entire backend: `yelp-uri.c` (URI parsing), the five document backends, `yelp-transform.c` (XSLT), the man/info parsers, `yelp-storage.c`/sqlite search index, the two decompressors, `yelp-help-list.c`, the web-process extension

**Never carried over at all:**
- Window registry (one window per document URI, raising the existing one)
- `--editor-mode`
- `GKeyfileSettingsBackend` for per-document settings
- Geometry *persistence* (read-only, one-way)
- Status icons (12 assets)

## Runtime-gate scope check

The gate's 69 checks (`test/drive_window.rb`) exercise: window chrome, zoom
actions, show-cursor toggle, `Ctrl+L` address bar, drop target wiring,
bookmarks add/remove, find bar, search entry/completion popover/keyboard nav,
about dialog, second window + `win.yelp-window-close`, and the adaptive
breakpoint. That is a real, passing 69/69 — confirmed by re-running it
(`nix develop --command xvfb-run -a ruby test/drive_window.rb` → `69 of 69
checks passed / DRIVE OK`).

It covers **zero** of: the document pipeline, URI parsing, the WebView, the
context menu, printing, translation, window-registry/editor-mode/per-document
settings, geometry write-back, or the status icons — because none of those
exist to drive. "10 components, 0 failed" (this round; the prior round reported 12) describes the fraction of the app
that was built, not the app. Per the accountability-ensurance finding below,
this is not stated anywhere in the port's own files.
