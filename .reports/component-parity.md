# Component parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `1b049d42` |
| Units with parity | 7 / 13 |

Units, in the order a user meets them. "Parity" below means all four axes
(count, style, behaviour, text) hold; every unit fails the text axis because
the port has no gettext marking at all (see `.reports/translation-parity.md`),
so no unit in this app currently has full parity — that failure is noted once
here and not repeated 13 times.

| # | Unit | Upstream | Port file | Verdict |
|---|---|---|---|---|
| 1 | Application / actions | `src/yelp-application.c` | `lib/main.rb` | **gap** — window registry, `--editor-mode`, per-document settings, `YelpBookmarks` interface all absent |
| 2 | Entry point | `src/yelp.c` | `lib/yelp.rb`, `exe/yelp-rb` | parity (modulo text axis) |
| 3 | Main window chrome | `src/yelp-window.c/.ui` | `lib/window.rb` | **gap** — see below |
| 4 | Primary menu + zoom controls | `src/yelp-window.ui` (menu) | `lib/primary_menu.rb` | parity (modulo text axis) |
| 5 | Bookmarks popover | `src/yelp-window.ui` (bookmark_menu) | `lib/bookmark_popover.rb` + `lib/bookmark_row.rb` | **gap** — not backed by `org.gnome.yelp.documents`; data lost on restart |
| 6 | About dialog | `src/yelp-window.c` `present_about_dialog` | `lib/about_dialog.rb` | parity (modulo text axis) |
| 7 | Search entry + completion | `src/yelp-search-entry.c/.ui` | `lib/search_entry.rb` + `lib/search_result_row.rb` | parity, with one documented substitution (flatten-model → standing row) |
| 8 | Completion row model | `src/yelp-search-result.c` | `lib/search_result.rb` | parity (modulo text axis) |
| 9 | Help view (`WebKit.WebView`) | `libyelp/yelp-view.c/.h` | **none** | **gap — total.** This is the app. There is no view, no print, no context menu, no `win.yelp-view-*` behaviour. |
| 10 | In-page error template | `src/resources/error.html` | `lib/error_page.rb` + `lib/resources/error.html` | **gap** — HTML is produced correctly but nothing in the running app ever calls it, because there is no WebView to load it into. Dead code, not a working error state. |
| 11 | App stylesheet | `src/style.css` | `lib/style.css` | parity |
| 12 | Settings object | `libyelp/yelp-settings.c` | `lib/settings.rb` | **gap** — zoom/cursor only; no fonts, no editor mode, no XSLT palette (unreachable without a view anyway) |
| 13 | GSettings schema | `data/org.gnome.yelp.gschema.xml` | `data/schemas/org.gnome.yelp.gschema.xml` | parity on the schema file itself; **gap** on usage — `org.gnome.yelp.documents` keys `bookmarks`/`readlater` are defined but nothing in `lib/` reads or writes them (see unit 5), and `geometry` is read but never written (see unit 3) |

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

7 of 13 units above have no open gap besides the universal text-axis failure.
The remaining 6 — application actions, window chrome, bookmarks persistence,
settings, the GSettings-backed units, and unit 9/10 (the view and its error
page) — all have at least one located, named gap. Unit 9 (the WebView) is
the most severe: it is the component the entire app exists to present, and it
does not exist in the port at all, in any form.
