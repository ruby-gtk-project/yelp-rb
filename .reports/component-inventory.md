# yelp-rb — upstream component inventory

Upstream read at `origin/master` (this repo has no `main` ref; GNOME Yelp's
default branch is `master`). Port branch: `ruby`.

Scanned: `git ls-tree -r --name-only origin/master` (608 paths), then every
file under `src/`, `libyelp/`, `data/org.gnome.yelp.gschema.xml`,
`src/yelp.gresource.xml` and `po/`. `data/mathjax`, `data/dtd` and
`data/xslt` are vendored rendering machinery (MathML/DocBook/Mallard→HTML
transforms), not UI — they back the content `YelpView` displays, not a widget,
and are called out as blockers below rather than given a `lib/*.rb` row.

## Current `ruby` branch state

`lib/` is the unwritten scaffold: `lib/yelp.rb`, `lib/yelp/application.rb`
(one window, one `Adwaita::StatusPage` placeholder, no real content),
`lib/yelp/rb/version.rb`. No other component has been started.

## Component list

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/yelp.c` | `lib/yelp/application.rb` (entry point folded into Application#build) | app entry point | partial — stub only, no real startup |
| `src/yelp-application.c` / `.h` | `lib/yelp/application.rb` | application class (`Adw.Application`): actions (`app.yelp-application-show-cursor`, `-larger-text`, `-smaller-text`, `-reset-text-size`), accelerators, per-document `GSettings`, window registry | stub — only builds one window + status page, no actions/accelerators/settings |
| `src/yelp-window.c` / `.h` / `src/yelp-window.ui` | `lib/yelp/window.rb` | window (`Adw.ApplicationWindow` template `YelpWindow`): header bar, back/forward buttons, menu button, search toggle, bookmark menu button, `Adw.Breakpoint` for narrow width, bottom `GtkActionBar`, find bar (`GtkRevealer` + `GtkSearchEntry` + prev/next/close buttons), `GtkSearchBar` wrapping the search entry, embeds `YelpView` in a `GtkOverlay`, address-bar override (Ctrl+L → `GtkEntry` swapped into the header title), `win.*` actions (`yelp-window-new`, `-close`, `-find`, `-search`, `-ctrll`, `-go-all`, `-show-about-dialog`), drag-and-drop target, click gesture | missing entirely |
| `src/yelp-window.ui` (embedded `GtkPopoverMenu` `primary_popover_menu`) | `lib/yelp/window.rb` (or split out) | primary hamburger menu: New Window, Find in Page…, Print…, Previous/Next Page, zoom controls (shrink/reset/enlarge text, a custom slot), All Help, About Help | missing |
| `src/yelp-window.ui` (embedded `GtkPopover` `bookmark_menu`) + `window_set_bookmarks`/`window_set_bookmark_buttons` in `yelp-window.c` | `lib/yelp/window.rb` (bookmark popover) | bookmarks popover: scrollable `GtkListBox` of bookmark rows (label + delete button built in code, one row per bookmark — a repeater), Add/Remove Bookmark buttons | missing |
| `yelp-window.c: present_about_dialog` | `lib/yelp/window.rb` (or `lib/yelp/about_dialog.rb`) | dialog — `Adw.AboutDialog` (via `adw_show_about_dialog`): app name, icon, website, issue URL, GPL-2.0 license, developer credits, translator credits | missing |
| `src/yelp-search-entry.c` / `.h` / `src/yelp-search-entry.ui` | `lib/yelp/search_entry.rb` | widget — `YelpSearchEntry` (subclasses `Gtk.Entry`): completion `GtkPopover` containing a `GtkScrolledWindow` → `GtkListView` bound to a `GtkNoSelection` model of `YelpSearchResult`, row template built from an inline `GtkBuilderListItemFactory` (icon, title, bookmark-flag icon, description), `activate`/`changed` signals | missing |
| `src/yelp-search-result.c` / `.h` | `lib/yelp/search_result.rb` | model (not a widget) — `GObject` with `title`/`desc`/`icon`/`page`/`flags`/`keywords` properties, backs the search-entry completion list | missing |
| `libyelp/yelp-view.c` / `.h` | `lib/yelp/view.rb` | widget — `YelpView` subclasses `WebKit.WebView`: context menu (open link, open in new window, copy link, save/send image, copy/save code, copy to clipboard), custom `help:`/`man:`/`info:` URI scheme handler, print action, back/forward/prev/next `GSimpleAction`s, policy-decision and script-dialog handling, `new-view-requested`/`loaded`/`external-uri` signals | missing — this is the core content view; needs a GTK WebKit binding (`webkit2gtk`/`webkit6` gem) the port has not wired in yet |
| `libyelp/web-process-extension/yelp-web-process-extension.c` | — (process-extension, not a widget) | behaviour — WebKit web-process-extension that mediates DOM access for `YelpView` (link/image/code handling in the popup actions above) | missing — needs the `webkit-web-process-extension` gem; no equivalent exists in the port yet |
| `src/resources/error.html` + `libyelp/yelp-error.c`/`.h` | no widget file; content asset | error state — static HTML shell `YelpView` loads on a load failure, backed by the `YELP_ERROR` domain | missing (the HTML asset itself has no Ruby translation — it would ship as a resource, not code) |
| `libyelp/yelp-help-list.c` / `.h` | no widget file; content generator | empty/fallback state — generates the "All Help" listing page (XSLT `links2html.xsl` over installed doc registrations) shown by `win.yelp-window-go-all` and as the startup fallback when no doc URI resolves | missing — blocker: needs an XSLT engine (e.g. `libxslt`/`nokogiri`) wired in; no Ruby equivalent exists yet |
| `libyelp/yelp-docbook-document.c`/.h, `yelp-mallard-document.c`/.h, `yelp-man-document.c`/.h, `yelp-man-parser.c`/.h, `yelp-info-document.c`/.h, `yelp-info-parser.c`/.h, `yelp-simple-document.c`/.h, `yelp-document.c`/.h | no widget file; document/content backends | content pipeline feeding `YelpView` (DocBook, Mallard, man, info, plain-text pages) | missing — blocker: these are the biggest piece of "full parity"; each is a distinct XML/text-to-HTML transform (`data/xslt/*.xsl.in`), none ported |
| `libyelp/yelp-transform.c`/.h | — | behaviour — generic libxslt transform runner used by every document backend above | missing — same libxslt blocker |
| `libyelp/yelp-bookmarks.c`/.h | — (interface, implemented by `Yelp::Application`) | behaviour — `add_bookmark`/`remove_bookmark`/`is_bookmarked`, `bookmark-added`/`bookmark-removed`/`bookmarks-changed` signals, backing the bookmark popover | missing |
| `libyelp/yelp-settings.c`/.h | `lib/yelp/settings.rb` (or folded into Application) | behaviour — singleton holding zoom level, text cursor, editor mode, font/color scheme derived from `Gtk.Settings`, icon ordering (`yelp_settings_cmp_icons` used to sort bookmark/menu entries) | missing |
| `libyelp/yelp-uri.c`/.h, `yelp-uri-builder.c`/.h | — | behaviour — URI parsing/resolution (`help:`, `man:`, `info:`, file paths) that `Application`/`Window` depend on to open a document | missing |
| `libyelp/yelp-storage.c`/.h, `yelp-sqlite-storage.c`/.h | — | behaviour — on-disk cache (SQLite) for transformed pages | missing — blocker if a `sqlite3` gem isn't already a dependency |
| `libyelp/yelp-bz2-decompressor.c`/.h, `yelp-lzma-decompressor.c`/.h, `yelp-magic-decompressor.c`/.h | — | behaviour — stream decompressors for compressed man/info pages | missing |
| `data/org.gnome.yelp.gschema.xml` | no `lib/*.rb` (a GSettings schema, installed alongside the app) | preferences/state — `org.gnome.yelp`: `show-cursor` (bool), `zoom-level` (double, 0.5–4.0); `org.gnome.yelp.documents`: `geometry`, `bookmarks` (`a(sss)`), `readlater` (`a(ss)`) | missing — no `.gschema.xml` in the port tree yet, needed before `Gio::Settings` can bind anything |
| `src/yelp.gresource.xml` | no `lib/*.rb` (a GResource manifest) | packaging — bundles `yelp-window.ui`, `yelp-search-entry.ui`, `style.css`, status-page SVG/PNG icons, `error.html` into `/org/gnome/yelp/` | missing — the Ruby house style builds widgets in code with no `.ui`, so this manifest's UI files have no 1:1 port target, but `style.css`, the icon set and `error.html` still need to ship as data |
| `src/style.css` | no `lib/*.rb` (stylesheet asset) | styling — custom classes `yelp-find-frame`, `yelp-bookmark-menu` referenced by `yelp-window.ui` | missing |
| `src/icons/scalable/status/yelp-page-*-symbolic.svg` + `icons/16x16/status/*.png` | no `lib/*.rb` (icon assets) | iconography — per-content-type status icons (video, search, task, problem, ui, tip, generic page) shown in search results / bookmarks | missing |
| `data/domains/*`, `data/xslt/*.xsl.in` | — | i18n plumbing for the doc backends above (not app UI) | n/a to widget port, feeds the document-backend blocker |
| `po/*.po` (115 locale files) + `po/ChangeLog` | — | translation catalogue for every string above (menu items, tooltips, about-dialog strings, error text) | missing — no `po/` catalogue exists in the port; see `translation-parity` skill |

## Keyboard shortcuts / accelerators (from `yelp-application.c: yelp_application_init`)

All are set with `gtk_application_set_accels_for_action` and belong to
`Yelp::Application`/`Yelp::Window` once ported:

| Accelerator | Action |
|---|---|
| `F7` | `app.yelp-application-show-cursor` |
| `Ctrl+Plus` | `app.yelp-application-larger-text` |
| `Ctrl+Minus` | `app.yelp-application-smaller-text` |
| `Ctrl+F` | `win.yelp-window-find` |
| `Ctrl+S` | `win.yelp-window-search` |
| `Ctrl+N` | `win.yelp-window-new` |
| `Ctrl+W` | `win.yelp-window-close` |
| `Ctrl+L` | `win.yelp-window-ctrll` (address-bar override) |
| `Ctrl+P` | `win.yelp-view-print` |
| `Alt+Left` | `win.yelp-view-go-back` |
| `Alt+Right` | `win.yelp-view-go-forward` |
| `Ctrl+Page_Up` | `win.yelp-view-go-previous` |
| `Ctrl+Page_Down` | `win.yelp-view-go-next` |

No standalone `.blp`/shortcuts-window `.ui` exists upstream for a
`Gtk.ShortcutsWindow` — these are plain accelerator-to-action bindings, not a
separate dialog.

## Summary

- Upstream has **no files at all yet ported** beyond the empty scaffold:
  every row above is missing from `lib/`.
- Widget-bearing units to build, in the order a user meets them: `Yelp::Application`
  → `Yelp::Window` → `Yelp::View` (WebKit) → `Yelp::SearchEntry`/`Yelp::SearchResult`
  → the bookmark popover and about dialog living inside `Window`.
- Three cross-cutting blockers surfaced while reading, worth raising before
  porting widgets starts in earnest:
  1. **WebKit.** `YelpView` subclasses `WebKit.WebView`; the port needs a
     working `webkit2gtk`/webkit6 GTK4 binding, plus the
     `webkit-web-process-extension` gem for the companion process extension
     (`libyelp/web-process-extension/yelp-web-process-extension.c`).
  2. **Document backends.** DocBook/Mallard/man/info rendering and the
     "All Help" list are all libxslt-driven; nothing in `lib/` touches this
     yet and it is the largest remaining body of upstream logic.
  3. **GSettings schema.** `data/org.gnome.yelp.gschema.xml` has not been
     copied into the port tree, so `show-cursor`/`zoom-level`/per-document
     `bookmarks`/`geometry` cannot be bound yet.
