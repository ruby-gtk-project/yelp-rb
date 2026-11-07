# yelp-rb component inventory

Surveyed against `origin/master` (upstream Yelp, C/GTK4/libadwaita) from the
`ruby` branch's current `lib/`. Order follows how a user meets each piece:
application, then window, then window chrome (menu, bookmarks, about), then
the search entry and its row, then shared settings, then the content view
and its error state.

Legend for **Exists?**: ✅ ported · ⚠️ ported but incomplete/behavior-limited
(see notes) · ❌ not ported.

## 1. Application — `src/yelp-application.c` / `.h`

The `Adw.Application` subclass: app-scoped actions, accelerators, per-window
registry, implements `YelpBookmarksInterface`.

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `Application` (Adw.Application) | `src/yelp-application.c/.h` | `lib/main.rb` | window/app class | ✅ |
| `app.yelp-application-show-cursor` (GPropertyAction) | `yelp-application.c` | `lib/main.rb` | action | ✅ |
| `app.yelp-application-larger-text` / `-smaller-text` / `-reset-text-size` | `yelp-application.c` | `lib/main.rb` | action | ✅ |
| Navigation/window accelerators (`<Primary>N`, `<Primary>W`, `<Primary>L`, `<Primary>S`, `<Primary>F`, `<Alt>Left/Right`, back/forward mouse buttons via gesture, `F10`-less menu) | `yelp-application.c` (`gtk_application_set_accels_for_action` calls) | `lib/main.rb` `ACCELS` | shortcuts | ✅ |
| `YelpBookmarksInterface` implementation (`yelp_application_iface_init`) | `libyelp/yelp-bookmarks.c/.h`, `yelp-application.c` | `lib/main.rb` | interface | ⚠️ — `add_bookmark`/`remove_bookmark`/`bookmarked?`/`bookmarks` are ported onto `Application`, backed by the real `bookmarks` GSettings key, and every window is notified on change; there is still no document pipeline, so `doc_uri` and `page_id` are both the window's current address rather than a document URI and a page within it |
| `windows_by_document` / per-document raise-existing-window | `yelp-application.c` | — | behavior | ❌ — not applicable without a document-loading pipeline; `Window`'s registry is `Gtk::Application#windows` only |
| Font sensitivity on gsettings `org.gnome.desktop.interface` | `yelp-application.c` (`application_set_font_sensitivity`) | `lib/main.rb` | behavior | ✅ |

## 2. Window — `src/yelp-window.c` / `.h` / `.ui`

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `Window` (Adw.ApplicationWindow, template `YelpWindow`) | `yelp-window.c/.h`, `yelp-window.ui` | `lib/window.rb` | window | ✅ |
| `AdwBreakpoint adaptive_mode_breakpoint` (max-width 400px) | `yelp-window.ui` | `lib/window.rb` | widget (behavior) | ✅ |
| `AdwToolbarView` / `AdwHeaderBar header` + `AdwWindowTitle header_title` | `yelp-window.ui` | `lib/window.rb` | widget | ✅ |
| `go_back_button` / `go_forward_button` (top, `win.yelp-view-go-back/-forward`) | `yelp-window.ui` | `lib/window.rb` | widget + action target | ⚠️ — widgets exist; the two actions exist but are registered **disabled** (no view/navigation stack yet) |
| `menu_button` → `primary_popover_menu` | `yelp-window.ui` | `lib/window.rb` + `lib/primary_menu.rb` | widget | ✅ |
| `search_button` (GtkToggleButton, `edit-find-symbolic`) + `search_bar` (GtkSearchBar) + `search_entry_clamp` | `yelp-window.ui` | `lib/window.rb` (uses `lib/search_entry.rb`'s `SearchEntry` inside the clamp) | widget | ✅ |
| `bookmark_menu_button` → `bookmark_menu` popover | `yelp-window.ui` | `lib/window.rb` + `lib/bookmark_popover.rb` | widget | ✅ |
| `find_bar` (GtkRevealer) + `find_entry` / `find_prev_button` / `find_next_button` / `find_close_button` (`.yelp-find-frame`, `flat`) | `yelp-window.ui` | `lib/window.rb` | widget | ✅ widgets + reveal/hide wired; ⚠️ find-in-page itself (`find_entry_changed`, `find_prev/next_clicked` driving the view's search) is a no-op since there is no view to search |
| `view_overlay` (GtkOverlay) + `YelpView view` | `yelp-window.ui` | — | widget | ❌ — `YelpView` itself is not ported (see §6) |
| `bottom_toolbar` (GtkActionBar, shown at narrow width) + bottom back/forward buttons | `yelp-window.ui` | `lib/window.rb` | widget | ✅ |
| `primary-menu` Gio.Menu + `primary_popover_menu` (GtkPopoverMenu) + zoom-controls custom slot | `yelp-window.ui` | `lib/primary_menu.rb` | menu | ✅ |
| `bookmark_menu` (GtkPopover, `.yelp-bookmark-menu`) + `bookmark_list`/`bookmark_sw`/`bookmark_add`/`bookmark_remove` | `yelp-window.ui` | `lib/bookmark_popover.rb`, `lib/bookmark_row.rb` | widget | ✅ widgets/behavior ported; ⚠️ backed by an in-memory per-window list, not the `org.gnome.yelp.documents` `bookmarks` GSettings key (needs a document identity to key by) |
| `win.yelp-window-new/-close/-find/-ctrll` actions | `yelp-window.c` | `lib/window.rb` | action | ✅ |
| `win.yelp-window-search` action (toggles `search_button`) | `yelp-window.c` | — | action | ❌ — not installed in `lib/window.rb`; only the button/bar widgets exist, not the action that `<Primary>S` or the menu's "Find in Page…" style entry would hit (note: upstream's `Ctrl+S`-labelled tooltip is on the button already) |
| `win.yelp-window-go-all` action ("All Help") | `yelp-window.c` | — | action | ❌ — see `HelpList` in §6 |
| `win.yelp-show-about-dialog` action (`gtk_widget_class_install_action`) | `yelp-window.c` | `lib/window.rb` → `lib/about_dialog.rb` | action | ✅ |
| Window resize → `geometry` GSettings (`window_resize_signal`, `notify::default-width/-height`) | `yelp-window.c`, `yelp-window.ui` | `lib/window.rb` (reads `geometry` on init) | behavior | ⚠️ — initial size is read from `org.gnome.yelp.documents` `geometry`; no signal handler writes it back on resize |
| `GtkDropTarget` (file/URI drag-and-drop onto the window) | `yelp-window.c` | `lib/window.rb` `drop_target` | controller | ✅ |
| Extra-mouse-button navigation gesture (back/forward buttons 8/9) | `yelp-window.c` | `lib/window.rb` `click_gesture` | controller | ✅ |
| Ctrl+L address-bar override (`action_ctrll`, swaps header title widget) | `yelp-window.c` | `lib/window.rb` `show_address_bar` | behavior | ✅ |
| `window_set_bookmark_buttons` (toggle add/remove visibility by current page) | `yelp-window.c` | `lib/bookmark_popover.rb` | behavior | ✅ |

## 3. PrimaryMenu — `primary-menu` / `primary_popover_menu` (in `src/yelp-window.ui`)

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `PrimaryMenu` (GtkPopoverMenu over `primary-menu` Gio.Menu) | `yelp-window.ui` | `lib/primary_menu.rb` | menu | ✅ |
| Menu items: New Window, Find in Page…, Print…, Previous Page, Next Page, All Help, About Help | `yelp-window.ui` | `lib/primary_menu.rb` | menu items | ⚠️ — "Print…" (`win.yelp-view-print`), "Previous/Next Page" (`win.yelp-view-go-previous/-next`) and "All Help" (`win.yelp-window-go-all`) target actions that don't exist yet (§2, §6); the menu items themselves render, the actions they fire don't |
| `zoom-controls` custom slot: shrink/reset/enlarge text (`app.yelp-application-smaller/-larger-text`, `app.yelp-application-reset-text-size`) + `font_adjustment_label` | `yelp-window.ui` | `lib/primary_menu.rb` | widget row | ✅ |

## 4. AboutDialog — `present_about_dialog` in `src/yelp-window.c`

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `AboutDialog` (Adw.AboutDialog) | `yelp-window.c` (`adw_show_about_dialog` call site) | `lib/about_dialog.rb` | dialog | ✅ |

## 5. SearchEntry / SearchResult — `src/yelp-search-entry.c/.h/.ui`, `src/yelp-search-result.c/.h`

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `SearchEntry` (template `YelpSearchEntry` parent `GtkEntry`) | `yelp-search-entry.c/.h/.ui` | `lib/search_entry.rb` | widget | ✅ |
| `completions_popover` (GtkPopover, `.menu .completions`) + `completions_scroll` + `completions_list` (GtkListView, single-click-activate) | `yelp-search-entry.ui` | `lib/search_entry.rb` | widget | ✅ |
| Completion pipeline: sort → filter(typed text) → slice(6) → synthetic "Search for %s" row | `yelp-search-entry.c` | `lib/search_entry.rb` | behavior | ⚠️ — filter+slice ported (`Gtk::CustomFilter`+`Gtk::FilterListModel`+`Gtk::SliceListModel`); the `Gtk.FlattenListModel` concatenation with the synthetic row is dropped (binding limitation — see file header), so the "search for this" row is handled separately rather than flattened into the same model |
| `SearchResult` (GObject, title/desc/icon/keywords/page/flags) | `yelp-search-result.c/.h` | `lib/search_result.rb` | type (GObject) | ✅ |
| `COMPLETION_FLAG_ACTIVATE_SEARCH` / `COMPLETION_FLAG_BOOKMARKED` | `yelp-search-result.h` | `lib/search_result.rb` | enum/flags | ✅ |
| Completion row template (GtkGrid: icon, title, bookmark-icon, desc w/ `dim-label caption`) | `yelp-search-entry.ui` (inline `GtkBuilderListItemFactory` bytes) | `lib/search_result_row.rb` | widget | ✅ |
| `get_bookmark_icon` closure (bookmark marker icon from `flags`) | `yelp-search-entry.ui` | `lib/search_result_row.rb` | behavior | ✅ |

## 6. Settings — `libyelp/yelp-settings.c/.h`, `data/org.gnome.yelp.gschema.xml`

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `Settings` singleton (zoom level, show-text-cursor) | `yelp-settings.c/.h` | `lib/settings.rb` | type (singleton) | ✅ |
| `org.gnome.yelp` schema: `show-cursor` (b), `zoom-level` (d, 0.5–4.0) | `data/org.gnome.yelp.gschema.xml` | `lib/settings.rb` | GSettings schema | ✅ |
| `org.gnome.yelp.documents` schema: `geometry` ((ii)) | `data/org.gnome.yelp.gschema.xml` | `lib/window.rb` | GSettings schema | ⚠️ — read on startup, not written back on resize (§2) |
| `org.gnome.yelp.documents` schema: `bookmarks` (a(sss)) | `data/org.gnome.yelp.gschema.xml` | `lib/main.rb` | GSettings schema | ✅ — read/written by `Application#add_bookmark`/`#remove_bookmark` via `GLib::Variant.parse` + `Gio::Settings#set_value_raw` (the Ruby binding cannot build an `a(sss)` GVariant from a plain array through `Gio::Settings#set_value`) |
| `org.gnome.yelp.documents` schema: `readlater` (a(ss)) | `data/org.gnome.yelp.gschema.xml` | — | GSettings schema | ❌ — not referenced anywhere in `lib/`; no upstream C caller was found outside the schema itself in this survey and may be legacy/unused upstream too, but is unaccounted for either way |
| Colour tokens from `Adw.StyleManager` (`YELP_SETTINGS_COLOR_BASE/TEXT`) | `yelp-settings.c` | — | behavior | ❌ — explicitly dropped per `lib/settings.rb`'s header; port styles via `lib/style.css` instead |
| Font settings from `org.gnome.desktop.interface` | `yelp-settings.c` | `lib/settings.rb` | behavior | ✅ |

## 7. View and error state — `libyelp/yelp-view.c/.h`, `src/resources/error.html`

This is the largest remaining gap: upstream's actual page-rendering widget.

| Component | Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| `YelpView` (WebKit-backed content view: load/navigate, page history, zoom, find-in-page, print, root-title, page-id, loading state) | `libyelp/yelp-view.c/.h` | `lib/view.rb` (planned, not written) | widget | ❌ — blocked: the fleet's released GTK/WebKit Ruby bindings cover `WebKitWebProcessExtension` only, not a drivable `WebKit.WebView` widget (see `lib/error_page.rb` header for the detailed rationale) |
| `view` signals used by the window (`new-view-requested`, `loaded`, `notify::is-loading`, `notify::yelp-uri`, `notify::page-id`, `notify::root-title`) | `yelp-window.ui` | — | signals | ❌ — no `view` object exists in `lib/window.rb` to connect these to |
| `win.yelp-view-go-back/-forward/-go-previous/-go-next` (page history / in-doc nav) | `yelp-window.c`, `yelp-application.c` | `lib/window.rb` (go-back/-forward only, disabled) | action | ⚠️ back/forward are present but disabled (§2); previous/next-page are entirely absent |
| `win.yelp-view-print` | `yelp-application.c`/`yelp-view.c` | — | action | ❌ |
| `ErrorPage` (in-page error HTML: icon, title, message, optional "Find Packages" recovery link) | `libyelp/yelp-view.c` (`view_show_error_page`) + `src/resources/error.html` | `lib/error_page.rb` | widget/template | ⚠️ — HTML template logic ported, but has nothing to hand its output to without a WebView (documented blocker in file header) |
| `HelpList` ("All Help" document: installed-help listing used by `win.yelp-window-go-all`) | `libyelp/yelp-help-list.c/.h` | — | type (YelpDocument) | ❌ — not a standalone widget upstream (it's a document rendered inside `YelpView`), so it is blocked on the same WebView gap |
| `YelpUri` (URI parsing: `help:`/`ghelp:`/`man:`/`info:`/plain paths) | `libyelp/yelp-uri.c/.h` | — | type (non-widget) | ❌ — infrastructure for the document pipeline, not itself a UI component; out of scope until a view exists to feed |
| Document backends (docbook, mallard, man, info, simple) | `libyelp/yelp-{docbook,mallard,man,info,simple}-document.c/.h` | — | type (non-widget) | ❌ — same as above |
| `yelp-bookmarks.c/.h` interface | `libyelp/yelp-bookmarks.c/.h` | — | interface | ❌ — see §1 |

## 8. Resources / data not yet exercised

| Item | Upstream file(s) | Kind | Exists? |
|---|---|---|---|
| `src/yelp.gresource.xml` (bundles `error.html`, `.ui` files, `style.css`) | `src/yelp.gresource.xml` | GResource manifest | ⚠️ — the port has no GResource bundle; `lib/resources/error.html` and `lib/style.css` are carried over as plain files loaded directly, which is consistent with the house style (no `.ui`/GResource in the Ruby port) but worth noting as a deliberate divergence, not a gap |
| `data/org.gnome.Yelp.metainfo.xml.in`, `.desktop.in` | app metadata | metadata | ❌ — not surveyed for a `lib/` equivalent; out of scope for widget parity |
| `po/*.po` catalogue (130 locales) | `po/*.po` | translation catalogue | ❌ — no i18n/gettext wiring found in `lib/`; all user-facing strings in `lib/` are hard-coded English literals (not marked for translation). This is a **translation-parity gap** for every string in every component above, not called out per-row |
| `data/org.gnome.yelp.gschema.xml` | — | GSettings schema file | ⚠️ — schema itself is not vendored under the port's own `data/`; `lib/settings.rb` and `lib/window.rb` assume `org.gnome.yelp`/`org.gnome.yelp.documents` are installed on the system (same as upstream requires) |

## Summary

- **Fully/mostly ported (widget + CSS + signals + actions line up):** Application
  shell and accelerators, Window chrome (header, breakpoint, find-bar
  widgets, drag-and-drop, mouse-gesture nav, Ctrl+L), PrimaryMenu, Bookmark
  popover/row, AboutDialog, SearchEntry + completion row + SearchResult,
  Settings (zoom/cursor/fonts).
- **Ported but behavior-limited** (widgets exist, the thing they'd drive
  doesn't): back/forward actions (disabled, no nav stack), find-in-page
  (no searchable view), bookmarks (in-memory only, no document-keyed
  GSettings persistence), window geometry (read-only, not saved).
- **Not ported, all blocked on the same root cause** — no drivable
  `WebKit.WebView` binding in this fleet: `YelpView` itself
  (`lib/view.rb`), `win.yelp-window-search`, `win.yelp-window-go-all` /
  `HelpList`, `win.yelp-view-print`, `win.yelp-view-go-previous/-next`,
  `YelpBookmarksInterface`'s document-keyed store, the `bookmarks`/
  `readlater` GSettings keys, and `YelpUri`/document backends (no document
  pipeline needed without a view to render into).
- **Not surveyed for parity in this pass:** i18n/gettext (no translation
  wiring found at all — flagged for a `translation-parity` pass), app
  metadata (`.desktop`, metainfo).
