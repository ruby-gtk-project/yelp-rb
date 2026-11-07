# yelp — upstream component inventory

Upstream ref: `origin/master` (the fork has no `origin/main`), at `ee532821`.
Port branch: `ruby`. Re-surveyed after the application shell and window chrome
landed; see "Port status" at the bottom for exactly what exists and what does
not.

Yelp is a WebKit-based help browser. Its UI surface is small — one window, one
embedded web view, a search entry with a completion popover, a bookmark
popover, a find bar and an about dialog — and almost all of upstream's bulk is
the non-UI document pipeline (`libyelp/yelp-*-document.c`, the XSLT
transformer, the URI parser, the decompressors, the SQLite cache). Those are
backend units, not components, and are listed separately at the bottom.

`lib/` on `ruby` today: `lib/yelp.rb` (one `require_relative "main"`),
`lib/main.rb` (the application class), `lib/window.rb`, `lib/settings.rb`,
`lib/about_dialog.rb`, `lib/primary_menu.rb`, `lib/bookmark_popover.rb`,
`lib/bookmark_row.rb`, `lib/search_result.rb`, `lib/yelp/rb/version.rb`. Each
section below says, in its "Status" line, which of these cover it and which
have nothing yet.

## src/yelp-application.c — the application object: actions, accelerators, settings, window registry

| Widget | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `Gtk.Application` (upstream `YelpApplication : AdwApplication`) | 1 | — | `startup`, `activate`, `open`, `command-line` | app name `_("Help")`, icon `org.gnome.Yelp`; flatpak-derived app id |
| — | — | — | `app.yelp-application-show-cursor` (`GPropertyAction`, `F7`) | bound to `YelpSettings:show-text-cursor` and gsettings `show-cursor` |
| — | — | — | `app.yelp-application-larger-text` (`<Control>plus`) | disabled at `YELP_ZOOM_LEVEL_MAX` |
| — | — | — | `app.yelp-application-smaller-text` (`<Control>minus`) | disabled at `YELP_ZOOM_LEVEL_MIN` |
| — | — | — | `app.yelp-application-reset-text-size` | resets gsettings `zoom-level` to 1.0 |

Accelerators the application installs for **window** actions (the actions
themselves live in `yelp-window.c` / `yelp-view.c`):
`win.yelp-window-find` `<Control>F`, `win.yelp-window-search` `<Control>S`,
`win.yelp-window-new` `<Control>N`, `win.yelp-window-close` `<Control>W`,
`win.yelp-window-ctrll` `<Control>L`, `win.yelp-view-print` `<Control>P`,
`win.yelp-view-go-back` `<Alt>Left`, `win.yelp-view-go-forward` `<Alt>Right`,
`win.yelp-view-go-previous` `<Control>Page_Up`,
`win.yelp-view-go-next` `<Control>Page_Down`.

Also: `--editor-mode` command-line option, per-document settings in a
`GKeyfileSettingsBackend` at `~/.config/yelp/yelp.cfg`, one window per
document (`windows_by_document`), and the `YelpBookmarks` interface
implementation (bookmarks / read-later, `bookmarks-changed` signal) backed by
the `org.gnome.yelp.documents` schema.

Repeaters: one window per opened document URI. Conditional: zoom actions
enable/disable on zoom level.

→ `lib/main.rb`

**Status: present.** `lib/main.rb` builds the `Gtk::Application`, installs the
four `app.yelp-application-*` actions with their accelerators, and
`lib/settings.rb` backs `zoom-level`/`show-cursor` with `Gio::Settings`.
**Missing:** the window registry (`windows_by_document`), the `--editor-mode`
option, the `GKeyfileSettingsBackend` for per-document settings, and the
`YelpBookmarks` interface (bookmarks/read-later, `bookmarks-changed`) — none
of this is in `lib/` yet.

## src/yelp.c — the process entry point

Four lines of substance: construct the application, `g_application_run`.

→ folds into `lib/main.rb` (the house style's one-expression launcher) and
`exe/yelp-rb`.

**Status: present.** `lib/yelp.rb` requires `lib/main.rb`; `exe/yelp-rb` exists.

## src/yelp-window.c + src/yelp-window.ui — the main window

| Widget | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (`YelpWindow`) | 1 | — | `notify::default-width`/`notify::default-height` → `window_resize_signal`, emits `resized` | geometry persisted to `org.gnome.yelp.documents geometry` |
| `Adw.Breakpoint` | 1 | — | condition `max-width: 400px` | shows `bottom_toolbar`, hides header back/forward, flips bookmark popover direction to `up` |
| `Adw.ToolbarView` | 1 | `top-bar-style: raised`, `bottom-bar-style: raised` | — | — |
| `Adw.HeaderBar` (`header`) | 1 | — | — | title widget swapped between `header_title` and `ctrll_entry` |
| `Adw.WindowTitle` (`header_title`) | 1 | — | — | title = page title or `_("Help")`; subtitle = root title when it differs |
| `Gtk.Button` (`go_back_button`, `go_forward_button`) | 2 | — | `win.yelp-view-go-back` / `win.yelp-view-go-forward` | tooltips `_("Back")`, `_("Forward")`; hidden under the breakpoint |
| `Gtk.MenuButton` (`menu_button`) | 1 | — | primary, popover `primary_popover_menu` | tooltip `_("Menu")`, icon `open-menu-symbolic` |
| `Gtk.ToggleButton` (`search_button`) | 1 | — | bound bidirectionally to `search_bar:search-mode-enabled` | tooltip `_("Search (Ctrl+S)")` |
| `Gtk.MenuButton` (`bookmark_menu_button`) | 1 | — | popover `bookmark_menu` | tooltip `_("Bookmarks")`; moved into the bottom bar in adaptive mode |
| `Gtk.SearchBar` (`search_bar`) | 1 | — | `notify::search-mode-enabled` → `window_search_mode` | key-capture widget is the window; entry connected in code |
| `Adw.Clamp` (`search_entry_clamp`) | 1 | — | — | maximum-size 425; hosts the `YelpSearchEntry` added in code |
| `Gtk.Overlay` (`view_overlay`) | 1 | — | — | holds the view plus the find bar overlay |
| `Gtk.Revealer` (`find_bar`) | 1 | — | — | halign end, valign start |
| `Gtk.Box` (find row) | 1 | `yelp-find-frame` | — | class defined in `src/style.css` |
| `Gtk.SearchEntry` (`find_entry`) | 1 | — | `changed` → `find_entry_changed`; `Gtk.EventControllerKey` → `find_entry_key_press` (Escape closes) | placeholder `_("Search in page…")` |
| `Gtk.Button` (`find_prev_button`, `find_next_button`, `find_close_button`) | 3 | `flat` | `clicked` → `find_prev_clicked` / `find_next_clicked` / `find_close_clicked` | tooltips `_("Previous")`, `_("Next")`, `_("Close Search")` |
| `YelpView` (`view`) | 1 | — | `new-view-requested` → `view_new_window`, `loaded` → `view_loaded`, `notify::is-loading` → `view_is_loading_changed`, `notify::yelp-uri` → `view_uri_selected`, `notify::page-id` → `window_set_bookmark_buttons`, `notify::root-title` → `view_root_title` | see its own section |
| `Gtk.ActionBar` (`bottom_toolbar`) | 1 | — | — | `visible` false until the breakpoint fires |
| `Gtk.Button` (`go_back_button_bottom`, `go_forward_button_bottom`) | 2 | — | `win.yelp-view-go-back` / `win.yelp-view-go-forward` | duplicate of the header pair for narrow windows |
| `Gtk.Entry` (`ctrll_entry`) | 1 | — | `activate` → `ctrll_entry_activate`; `Gtk.EventControllerKey` → `ctrll_entry_key_press` (Escape restores the title) | built lazily by `win.yelp-window-ctrll`; width = window width / 2; pre-selects the URI after the scheme colon |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → `window_on_drop` | accepts `G_TYPE_STRING` URIs, rejects `xref:` |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` → `window_button_press`, capture phase, any button | mouse buttons 8/9 → back/forward |

Window actions installed here: `win.yelp-window-new`, `win.yelp-window-close`,
`win.yelp-window-search`, `win.yelp-window-find`, `win.yelp-window-go-all`
(loads `help-list:`), `win.yelp-window-ctrll`, plus
`win.yelp-show-about-dialog` installed as a widget class action.

Repeaters: none in the template. Conditional: the whole bottom toolbar, and the
back/forward header buttons, are breakpoint-driven; `ctrll_entry` only exists
after `<Control>L`.

→ `lib/window.rb`

**Status: mostly present.** `lib/window.rb` (364 lines) builds the
`Adw.ApplicationWindow`, the breakpoint, the toolbar view, header bar, title,
back/forward buttons (header and bottom), the menu button + primary menu, the
search toggle button, the bookmark menu button, the find revealer/entry/
prev/next/close buttons, the bottom action bar, and the window actions
(`win.yelp-window-new`, `-close`, `-search`, `-find`, `-go-all`,
`win.yelp-show-about-dialog`). **Missing:** the real `YelpSearchEntry` (the
window's own code says this explicitly — "YelpSearchEntry (lib/search_entry.rb)
is a separate porting track"), the `YelpView`/`WebKit.WebView` itself (the
view overlay holds only the find bar, not a real view — window.rb's own
comment: "without one yet, this holds the one real thing the window [has]"),
`ctrll_entry` (`<Control>L`), the `Gtk.DropTarget` and `Gtk.GestureClick`
(mouse-button back/forward) controllers, and geometry persistence to
`org.gnome.yelp.documents geometry`. + `primary_popover_menu` — the primary menu

`Gtk.PopoverMenu` over a `Gio.Menu` of five sections, 7 items:
`_("New Window")` → `win.yelp-window-new`, `_("Find in Page…")` →
`win.yelp-window-find`, `_("Print…")` → `win.yelp-view-print`;
`_("Previous Page")` → `win.yelp-view-go-previous`, `_("Next Page")` →
`win.yelp-view-go-next`; a `custom="zoom-controls"` slot; `_("All Help")` →
`win.yelp-window-go-all`; `_("About Help")` → `win.yelp-show-about-dialog`.

The `zoom-controls` custom slot is its own component: a homogeneous horizontal
`Gtk.Box` holding `Gtk.Button` `zoom-out-symbolic` (`circular flat`, tooltip
`_("Shrink Text")`, `app.yelp-application-smaller-text`), a `Gtk.Button`
(`flat numeric`, tooltip `_("Reset Size")`,
`app.yelp-application-reset-text-size`) wrapping `Gtk.Label`
`font_adjustment_label` (`width-chars` 5, shows the zoom percentage), and
`Gtk.Button` `zoom-in-symbolic` (`circular flat`, tooltip `_("Enlarge Text")`,
`app.yelp-application-larger-text`).

→ `lib/primary_menu.rb` (menu model + the zoom-controls widget)

**Status: present.** `lib/primary_menu.rb` (135 lines) builds the menu model
and the zoom-controls box (shrink/reset/enlarge buttons bound to the
`app.yelp-application-*-text` actions, with a label kept in sync via
`refresh_zoom_labels`).

### src/yelp-window.ui `bookmark_menu` + `window_set_bookmarks` — the bookmarks popover

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` (`bookmark_menu`) | 1 | `yelp-bookmark-menu`, `menu` | — | `yelp-bookmark-menu row` padding from `src/style.css` |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12, width-request 280 |
| `Gtk.ScrolledWindow` (`bookmark_sw`) | 1 | — | — | hscroll never, height-request 200, max-content-width 280 |
| `Gtk.ListBox` (`bookmark_list`) | 1 | — | `row-activated` → `bookmark_activated` | selection-mode none |
| `Gtk.ListBoxRow` | N | — | — | **repeater** over the document's `a(sss)` bookmarks, sorted by title; carries `page-id` |
| `Gtk.Label` (per row) | N | — | — | title, xalign 0, ellipsize end, margins 9, tooltip = title |
| `Gtk.Button` (per row) | N | `flat` | `clicked` → `bookmark_removed` | `edit-delete-symbolic`, `focus-on-click` false |
| `Gtk.Button` (`bookmark_add`) | 1 | — | `clicked` → `bookmark_added` | `_("Add Bookmark")`; hidden when the page is already bookmarked or has no page id |
| `Gtk.Button` (`bookmark_remove`) | 1 | — | `clicked` → `bookmark_removed` | `_("Remove Bookmark")`; hidden when not bookmarked |

Empty state: the list box is simply empty — upstream has no placeholder.

→ `lib/bookmark_popover.rb` + `lib/bookmark_row.rb`

**Status: present.** `lib/bookmark_popover.rb` (127 lines) builds the popover,
box, scrolled window, list box and add/remove buttons; `lib/bookmark_row.rb`
(58 lines) is the per-row model/widget. Not re-verified in this pass against
the `org.gnome.yelp.documents` `bookmarks`/`readlater` schema wiring —
`component-parity` should confirm the row data actually comes from
`Gio::Settings` rather than a stub list.

### src/yelp-window.c `present_about_dialog` — the about dialog

`adw_show_about_dialog`: application-name `_("Help")`, application-icon
`org.gnome.Yelp`, website `https://apps.gnome.org/Yelp`, issue-url, licence
GPL-2.0, developer-name `_("The GNOME Project")`, a six-name developers list,
version, `_("translator-credits")`.

→ `lib/about_dialog.rb`

**Status: present.** `lib/about_dialog.rb` (34 lines) matches upstream field
for field: application name/icon, website, issue URL, GPL-2.0, developer
name, the six-name developers list, and a version passed in. Not yet marked
for translation (no `_()`/gettext call) and `_("translator-credits")` is not
wired — tracked under translation-parity, not here.

## src/yelp-search-entry.c + src/yelp-search-entry.ui — the search entry and its completion popover

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Entry` (`YelpSearchEntry`) | 1 | — | `activate` → `entry_activate_cb`, `changed` → `entry_changed_cb`; emits `search-activated`, `stop-search`, `preedit-changed` | properties `view`, `bookmarks`; hexpand set in code |
| `Gtk.Popover` (`completions_popover`) | 1 | `menu`, `completions` | — | `has-arrow` false, `autohide` false, width tracked to the entry |
| `Gtk.ScrolledWindow` (`completions_scroll`) | 1 | — | — | hscroll never, max-content-height 400, propagate-natural-height |
| `Gtk.ListView` (`completions_list`) | 1 | — | `activate` → `completion_activate_cb` | `single-click-activate`, `Gtk.NoSelection` |
| row `Gtk.Grid` (builder list-item factory) | N | — | — | **repeater** over the completion model; column-spacing 6, row-spacing 3 |
| row `Gtk.Image` (page icon) | N | — | — | pixel-size 16, bound to `YelpSearchResult:icon` |
| row `Gtk.Label` (title) | N | — | — | markup, ellipsize end, xalign 0, single-line, hexpand; bound to `:title` |
| row `Gtk.Image` (bookmark marker) | N | — | — | pixel-size 16, bound through the `get_bookmark_icon` closure over `:flags` |
| row `Gtk.Label` (description) | N | `dim-label`, `caption` | — | markup, ellipsize end, xalign 0; bound to `:desc` |
| `Gtk.EventControllerFocus` | 1 | — | `notify::contains-focus` | opens/closes the popover |
| `Gtk.EventControllerKey` (on the entry) | 2 | — | `key-pressed`, `key-released` | arrow/Return/Escape navigation; a second controller on the popover redirects typing back to the entry |

Model stack: `Gtk.SortListModel` (`entry_completion_sort`) →
`Gtk.FilterListModel` (`entry_match_func`) → `Gtk.SliceListModel` (first 6) →
concatenated with a one-row store holding the "search for this" result →
`Gtk.FlattenListModel`.

Conditional rows: the trailing `Gtk.ListStore` row is the synthetic
`YelpSearchResult` titled `_("Search for “%s”")` with description
`_("Browse all search results")`; the bookmark image is empty unless the
result's flags say bookmarked. The entry also surfaces bookmarks and
read-later entries via the `YelpBookmarks` interface, refreshing on
`bookmark-added` / `bookmark-removed`.

→ `lib/search_entry.rb` + `lib/search_result_row.rb`

**Status: missing entirely.** Neither `lib/search_entry.rb` nor
`lib/search_result_row.rb` exists. `lib/window.rb`'s own comment names this
as a separate porting track; the window's search button/search bar exist but
there is no real entry, completion popover, model stack or row factory
plugged into them yet.

## src/yelp-search-result.c — the completion row model object

A plain `GObject` with `icon`, `title`, `desc`, `uri`, `flags` properties and a
`YelpSearchResultFlags` enum (bookmarked / read-later). No widgets.

→ `lib/search_result.rb`

**Status: present.** `lib/search_result.rb` (55 lines) is the plain
icon/title/desc/uri/flags model with the bookmarked/read-later flags. Has no
consumer yet (see search-entry status above).

## libyelp/yelp-view.c + libyelp/yelp-view.h — the help view

| Widget | × | CSS | Signals / Actions | Notes |
|---|---:|---|---|---|
| `WebKit.WebView` (`YelpView`) | 1 | — | emits `new-view-requested`, `external-uri`, `loaded`; `context-menu` → `view_populate_context_menu`; `Gtk.GestureClick` for back/forward mouse buttons | custom `help:` URI scheme handler, `default-charset utf-8` |
| `Adw.AlertDialog` | 3 sites | — | one `close` response `_("_Close")` | `_("Package Install Link Error")`, `_("Failed to Save Image")`, `_("Failed to Save Code")` |
| `Gtk.FileDialog` | 2 | — | — | titles `_("Save Image")`, `_("Save Code")` |
| `WebKit.PrintOperation` | 1 | — | `run_dialog` | driven by `win.yelp-view-print` |

Actions registered onto the window by `yelp_view_register_actions`:
`win.yelp-view-print`, `win.yelp-view-go-back`, `win.yelp-view-go-forward`,
`win.yelp-view-go-previous`, `win.yelp-view-go-next` — each enabled/disabled
from the view's history and page links.

Context-menu action group (`WebKit.ContextMenu` items built from `GAction`s):
`OpenLink` `_("_Open Link")`, `OpenLinkNew` `_("Open Link in New _Window")`,
`CopyLink` `_("_Copy Link Location")`, `SendEmail`
`_("Send email to %s")`, `InstallPackages` `_("_Install Packages")`,
`CopyText` `_("_Copy Text")`, `CopyCode` `_("C_opy Code Block")`,
`SaveCode` `_("Save Code _Block As…")`, `SaveMedia`
`_("_Save Image As…")` / `_("_Save Video As…")`, `SendMedia`
`_("S_end Image To…")` / `_("S_end Video To…")`, plus separators. Items are
added conditionally on what was clicked (link / email link / install link /
image / video / code block / selected text).

Error states, rendered into the page from `src/resources/error.html`:
`_("Document Not Found")`, `_("Page Not Found")`, `_("Cannot Read")`,
`_("Unknown Error")`, `_("Could not load a document for ‘%s’")`,
`_("Could not load a document")`, `_("The URI ‘%s’ does not point to a valid
page.")`, `_("The URI does not point to a valid page.")`, `_("The URI ‘%s’
could not be parsed.")`, and the
`_("Find Packages Containing This Document")` recovery link.

→ `lib/view.rb` + `lib/view_context_menu.rb` + `lib/error_page.rb`

**Status: missing entirely.** None of `lib/view.rb`, `lib/view_context_menu.rb`
or `lib/error_page.rb` exists. This is the app's central component — the
actual `WebKit.WebView` — and the window currently has nothing in its view
overlay but the find bar (window.rb's own comment: "without one yet, this
holds the one real thing the window [has]"). The `win.yelp-view-*` actions
(print, go-back/-forward/-previous/-next) that `lib/window.rb` wires
accelerators for have no implementation to enable/disable against.

## src/resources/error.html — the in-page error template

Standalone HTML/CSS with Adwaita light and dark custom properties, a
`prefers-contrast: more` block and an `a.button` recovery link. Not a widget,
but it is the app's error state and has to ship with the port.

→ `lib/resources/error.html` (verbatim asset, loaded by `lib/error_page.rb`)

**Status: missing.** `lib/resources/` does not exist.

## src/style.css — the app stylesheet

Three rules: `.yelp-find-frame` (headerbar colours, 6px padding, bottom-rounded
12px), `.yelp-find-frame > * > *` (12px radius), `.yelp-bookmark-menu row`
(zero padding, 6px bottom margin). Every class here is applied in
`yelp-window.ui`; none is dead.

→ `lib/style.css` (loaded through a `Gtk::CssProvider` in `lib/main.rb`)

**Status: missing.** `lib/window.rb` already applies the `yelp-find-frame`
class to the find-bar box (plus `flat` on its three buttons), but there is no
`lib/style.css` and no `Gtk::CssProvider` registration in `lib/main.rb` to
define `.yelp-find-frame` or `.yelp-bookmark-menu row` — the class is applied
and does nothing yet.

## libyelp/yelp-settings.c — the appearance/behaviour settings object

Not a widget and upstream has no preferences dialog, but it drives user-visible
state the port needs: `show-text-cursor` (caret browsing, `F7`), `zoom-level`
(0.5–4.0, the zoom controls), font families and sizes derived from the GNOME
desktop settings, editor mode, and the colour/icon palette handed to the XSLT.

→ `lib/settings.rb`

**Status: present for zoom/cursor.** `lib/settings.rb` (79 lines) wraps
`Gio::Settings` for `zoom-level` (clamped 0.5–4.0) and `show-cursor`.
**Missing:** font families/sizes derived from GNOME desktop settings, editor
mode, and the colour/icon palette for the XSLT — none of these are reachable
yet since there is no XSLT pipeline or view to hand them to.

## data/org.gnome.yelp.gschema.xml — GSettings schemas

`org.gnome.yelp`: `show-cursor` (b, false), `zoom-level` (d, 0.5–4.0, 1.0).
`org.gnome.yelp.documents` (per-document, relocatable, keyfile-backed):
`geometry` ((ii), (960,630)), `bookmarks` (a(sss)), `readlater` (a(ss)).

→ `lib/settings.rb` (the port reads these through `Gio::Settings`)

**Status: present.** `data/schemas/org.gnome.yelp.gschema.xml` is already
carried over verbatim, and `lib/settings.rb` reads `show-cursor`/`zoom-level`
from it. The `org.gnome.yelp.documents` relocatable schema (`geometry`,
`bookmarks`, `readlater`) is in the same file but nothing in `lib/` reads it
yet — window geometry persistence and the bookmarks list are not wired to it.

## src/yelp.gresource.xml — the resource manifest

Bundles `yelp-window.ui`, `yelp-search-entry.ui`, `style.css`,
`resources/error.html`, seven scalable `yelp-page-*-symbolic.svg` status icons
and five 16×16 PNG status icons (including `bookmark.png`). The port has no
`.ui` files by design, so what carries over is the stylesheet, the error page
and the twelve icons.

→ `lib/resources/` (icons + `error.html`), no GResource equivalent

**Status: missing.** No icons and no `error.html` have been carried over into
`lib/resources/` (which does not exist).

## po/ — the translation catalogue

`po/LINGUAS` lists 109 languages with 109 matching `.po` files; the template is
regenerated from the `.ui` files and the `_()`-marked C strings.
`data/domains/yelp.pot` is a second, separate catalogue for the help-document
domains. Nothing in `lib/` is translated yet; the port needs a gettext path
before the strings above are worth marking.

→ `po/` (carried over wholesale once the components exist)

**Status: missing.** No `po/` directory exists on `ruby` yet, and nothing in
`lib/` marks its strings for translation (`lib/about_dialog.rb`'s six
developer names and dialog fields, `lib/primary_menu.rb`'s menu item labels,
`lib/window.rb`'s tooltips and placeholders, and `lib/bookmark_popover.rb`'s
button labels are all plain Ruby string literals). This is the
`translation-parity` skill's job, not re-litigated here.

## Backend units — not components, but the view has nothing to show without them

`libyelp/yelp-uri.c` (URI parsing: `help:`, `ghelp:`, `man:`, `info:`, paths),
`yelp-document.c` and the `yelp-docbook-document.c` / `yelp-mallard-document.c`
/ `yelp-man-document.c` / `yelp-info-document.c` / `yelp-simple-document.c`
backends, `yelp-help-list.c` (synthesises the `_("All Help Documents")` page
behind `win.yelp-window-go-all`), `yelp-transform.c` (libxslt),
`yelp-man-parser.c`, `yelp-info-parser.c`, `yelp-man-search.c`,
`yelp-storage.c` / `yelp-sqlite-storage.c` (the search index),
`yelp-bz2-decompressor.c` / `yelp-lzma-decompressor.c` /
`yelp-magic-decompressor.c`, `yelp-error.c`, `yelp-bookmarks.c` (interface),
`yelp-uri-builder.c`, `yelp-debug.c`,
`libyelp/web-process-extension/yelp-web-process-extension.c`, and the
`data/xslt/*.xsl.in` stylesheets.

These are a separate porting track from the component list above.

## Port status

No longer the untouched scaffold. What exists in `lib/` now, file by file:

| File | Lines | Covers | Status |
|---|---:|---|---|
| `lib/yelp.rb` | 3 | entry require | done |
| `lib/main.rb` | 131 | `Gtk::Application`, the four `app.yelp-application-*` actions + accelerators, `refresh_zoom_labels` | present; window registry, `--editor-mode`, per-document `GKeyfileSettingsBackend`, `YelpBookmarks` interface not started |
| `lib/settings.rb` | 79 | `zoom-level`, `show-cursor` via `Gio::Settings` | present for those two keys; fonts/editor-mode/XSLT palette not started |
| `lib/window.rb` | 364 | window chrome, breakpoint, header bar, title, back/forward (header + bottom), menu button, search toggle, bookmark menu button, find revealer/entry/buttons, bottom action bar, `win.yelp-window-*` actions | present for chrome; no real search entry, no view, no `ctrll_entry`, no drop target, no button-press controller, no geometry persistence |
| `lib/primary_menu.rb` | 135 | menu model, zoom-controls box | done |
| `lib/about_dialog.rb` | 34 | the about dialog, all fields | done (translation marking pending) |
| `lib/bookmark_popover.rb` | 127 | popover, list, add/remove buttons | present; not yet confirmed wired to the `org.gnome.yelp.documents` schema rather than a stub |
| `lib/bookmark_row.rb` | 58 | per-row bookmark model/widget | done |
| `lib/search_result.rb` | 55 | completion-row model (icon/title/desc/uri/flags) | done; has no consumer |
| `lib/yelp/rb/version.rb` | — | gem version | done |

**Missing entirely** — no file exists for any of these:
- `lib/search_entry.rb` + `lib/search_result_row.rb` (the real `YelpSearchEntry`, completion popover, model stack, row factory)
- `lib/view.rb` + `lib/view_context_menu.rb` + `lib/error_page.rb` (the `WebKit.WebView`, print, context menu, error states) — this is the app's central component and the window currently has nothing real in its view area
- `lib/resources/` (icons, `error.html`)
- `lib/style.css` + its `Gtk::CssProvider` registration (the `yelp-find-frame` class is already applied in `lib/window.rb` with nothing to define it)
- `po/` and any translation marking on the strings already written
- The entire backend porting track: URI parsing, the document backends, the XSLT transformer, the man/info parsers, the SQLite search index, the decompressors, the bookmarks interface, the web-process extension

## Blockers worth naming before the remaining widget code is written

- **WebKitGTK 6 Ruby bindings.** `YelpView` *is* a `WebKitWebView`, and the
  whole app is a frame around it. Whether the fork's dev shell exposes usable
  `webkit2gtk-6.0` bindings to Ruby decides the shape of `lib/view.rb`. The
  `webkit-web-process-extension` gem (see `libyelp/web-process-extension/`
  above) is the released binding for the companion process extension; it and
  `libxmlb` are now declared in `yelp-rb.gemspec` and `nix/Gemfile`
  (confirmed by reading both files directly), so the remaining risk is
  proving at runtime that `WebKitWebProcessExtension` actually exposes a
  usable `WebKit.WebView` for `lib/view.rb` to subclass, not whether the gem
  is wired in.
- **libxml2/libxslt from Ruby** for the DocBook/Mallard/man/info → HTML
  pipeline, plus the `help:` custom URI scheme handler. `libxmlb`'s `Xmlb`
  gem is a binary-XML cache reader, not a general XSLT engine, so it does not
  cover this pipeline by itself — confirm what it does and does not reach
  before assuming it closes this gap.
- `Adwaita::ApplicationWindow` is usable in the bindings but
  `Adwaita::Application` is not, so the application object is
  `Gtk::Application` — `lib/main.rb` already does this.
- `Gtk::BuilderListItemFactory` drives the completion rows upstream; the port
  has no `.ui`, so those rows must be rebuilt as a
  `Gtk::SignalListItemFactory` once `lib/search_entry.rb` is written.
- `Adw.Breakpoint` setters are declarative upstream; `lib/window.rb` already
  has to build the breakpoint and its setters in Ruby — confirm against the
  `ruby-gtk` skill that the setter calls it uses are the supported shape.
- The upstream ref is `origin/master`; the task text named `origin/main`, which
  does not exist in this fork (only `origin/main` as a stale local-only ref
  resolving to the same commit — the remote has no `main` branch).
