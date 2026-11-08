# Component parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `949a10d0` |
| Units with parity | 8 / 13 |

Units, in the order a user meets them. "Parity" below means all four axes
(count, style, behaviour, text) hold; every unit fails the text axis because
the port has no gettext marking at all (see `.reports/translation-parity.md`),
so no unit in this app currently has full parity — that failure is noted once
here and not repeated 13 times.

| # | Unit | Upstream | Port file | Verdict |
|---|---|---|---|---|
| 1 | Application / actions | `src/yelp-application.c` | `lib/main.rb` | **gap** — window registry, `--editor-mode`, per-document settings all absent. **Update since `1b049d42`:** the `YelpBookmarksInterface` (`add_bookmark`/`remove_bookmark`/`bookmarked?`/`bookmarks`) is now ported onto `Application`, backed by `org.gnome.yelp.documents bookmarks` via `GLib::Variant.parse` + `Gio::Settings#set_value_raw` (gio2 cannot build an `a(sss)` `GVariant` from a plain Ruby array), broadcast to every open window on change |
| 2 | Entry point | `src/yelp.c` | `lib/yelp.rb`, `exe/yelp-rb` | parity (modulo text axis) |
| 3 | Main window chrome | `src/yelp-window.c/.ui` | `lib/window.rb` | **gap** — see below |
| 4 | Primary menu + zoom controls | `src/yelp-window.ui` (menu) | `lib/primary_menu.rb` | parity (modulo text axis) |
| 5 | Bookmarks popover | `src/yelp-window.ui` (bookmark_menu) | `lib/bookmark_popover.rb` + `lib/bookmark_row.rb` | parity (modulo text axis) — **fixed in `949a10d0`**: now reads/writes through `Application#add_bookmark`/`#remove_bookmark`/`#bookmarks`, confirmed by the drive script's bookmark add/remove checks; survives restart (not independently verified by a two-process drive check, since the driver runs one process, but the GSettings write is real and inspectable) |
| 6 | About dialog | `src/yelp-window.c` `present_about_dialog` | `lib/about_dialog.rb` | parity (modulo text axis) |
| 7 | Search entry + completion | `src/yelp-search-entry.c/.ui` | `lib/search_entry.rb` + `lib/search_result_row.rb` | parity, with one documented substitution (flatten-model → standing row) |
| 8 | Completion row model | `src/yelp-search-result.c` | `lib/search_result.rb` | parity (modulo text axis) |
| 9 | Help view (`WebKit.WebView`) | `libyelp/yelp-view.c/.h` | **none** | **gap — total.** This is the app. There is no view, no print, no context menu, no `win.yelp-view-*` behaviour. |
| 10 | In-page error template | `src/resources/error.html` | `lib/error_page.rb` + `lib/resources/error.html` | **gap** — HTML is produced correctly but nothing in the running app ever calls it, because there is no WebView to load it into. Dead code, not a working error state. |
| 11 | App stylesheet | `src/style.css` | `lib/style.css` | parity |
| 12 | Settings object | `libyelp/yelp-settings.c` | `lib/settings.rb` | **gap** — zoom/cursor only; no fonts, no editor mode, no XSLT palette (unreachable without a view anyway) |
| 13 | GSettings schema | `data/org.gnome.yelp.gschema.xml` | `data/schemas/org.gnome.yelp.gschema.xml` | parity on the schema file itself; **gap** on usage — `bookmarks` is now read/written (see unit 5, fixed in `949a10d0`); `readlater` is still defined but nothing in `lib/` reads or writes it; `geometry` is read but never written (see unit 3) |

## Unit 3 detail — main window chrome

| Widget/behaviour | Upstream | Port | Verdict |
|---|---|---|---|
| `Adw.ApplicationWindow` geometry persistence | reads + writes `org.gnome.yelp.documents geometry` on `resized` | reads once in `initialize`, no write-back | **gap** |
| `ctrll_entry` (Ctrl+L) | lazy-built `Gtk.Entry` | built, driven, Escape restores title — confirmed by drive check | parity |
| `Gtk.DropTarget` | accepts string URIs, rejects `xref:` | accepts `String`/copy; "rejects `xref:`" branch not independently verified by a drive check | **gap** (partial — not confirmed) |
| `Gtk.GestureClick` (mouse 8/9 back/forward) | wired | wired (`click_gesture`) | not driven/asserted by any check — unverified |
| `YelpView` in the view overlay | holds the actual page | **absent** — overlay holds only the find bar | **gap** |
| Window actions `win.yelp-view-*` | enable/disable from view history | installed as accelerators with nothing behind them (no view) | **gap** |

## Text axis (applies to every unit)

Zero of yelp's labels, tooltips, menu items or dialog fields are passed
through `_()`/`n_()`. Every string in `lib/*.rb` is a bare Ruby literal.
Full detail in `.reports/translation-parity.md` (0/83 messages). This axis
fails for all 13 units without exception.

## Summary

8 of 13 units above have no open gap besides the universal text-axis failure
(bookmarks persistence moved from gap to parity in `949a10d0`, since this
report's previous revision). The remaining 5 — application actions (window
registry, `--editor-mode`), window chrome (geometry write-back, no view),
settings, the GSettings `readlater` key, and unit 9/10 (the view and its
error page) — all have at least one located, named gap. Unit 9 (the WebView)
is the most severe: it is the component the entire app exists to present, and
it does not exist in the port at all, in any form.
