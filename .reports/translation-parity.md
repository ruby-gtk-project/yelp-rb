# Translation parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `949a10d0` (prior pass: `1b049d42`) |
| Domain | `yelp` (unconfirmed — no port build file names a domain; taken from upstream's `.mo`/`gettext` package name) |
| Upstream messages | 83 distinct `(msgctxt, msgid)` keys (census via `.claude/skills/translation-parity/scripts/msgid-census.sh`, excluding `po/`, 0 unresolved) |
| Ported | 0 |
| Gaps | 83 |
| Extra (untranslated) | 0 |
| Upstream languages | 109 `.po` files (`po/LINGUAS` lists 111 lines; 2 are not blank/comment-free — not re-verified line by line, noted as an open item) |
| Languages shipped by the port | 0 |
| Build command | none — no gettext dependency, no `po/` directory, no `.mo` build step anywhere in the port |

## Messages by upstream source

| Source | Messages |
|---|---:|
| `libyelp/yelp-view.c` | 37 |
| `src/yelp-window.ui` | 23 |
| `libyelp/yelp-docbook-document.c` | 7 |
| `data/org.gnome.Yelp.metainfo.xml.in` | 7 |
| `libyelp/yelp-info-document.c` | 5 |
| `src/yelp-window.c` | 4 |
| `libyelp/yelp-transform.c` | 4 |
| `libyelp/yelp-man-document.c` | 4 |
| `org.gnome.Yelp.desktop.in` | 3 |
| `libyelp/yelp-mallard-document.c` | 3 |
| `src/yelp-search-entry.c` | 2 |
| `src/yelp-application.c` | 2 |
| `libyelp/yelp-lzma-decompressor.c` | 2 |
| `libyelp/yelp-document.c` | 2 |
| `libyelp/yelp-bz2-decompressor.c` | 2 |
| `libyelp/yelp-help-list.c` | 1 |
| `libyelp/yelp-error.c` | 1 |
| `data/domains/yelp.pot` | 1 |

## Port census

`.claude/skills/translation-parity/scripts/msgid-census.sh .` run against the
`ruby` branch returns **0 rows**. `grep -rn "_(" lib/` returns no gettext
call sites (the only `_(` hits are Ruby method-definition syntax, not a
marker). There is no `gettext` entry in the gemspec or any Gemfile, and no
`po/` directory exists anywhere in the port.

This is not a case of rewording or partial marking — it is a complete absence
of the mechanism. Every one of the 83 upstream messages is a gap:

- **All 7 "present" component units** in `.reports/component-parity.md`
  (application, entry point, primary menu, bookmark popover, about dialog,
  search entry, search result row) build their visible strings as bare Ruby
  literals: menu item labels (`_("New Window")`, `_("Find in Page…")`, …),
  tooltips (`_("Back")`, `_("Menu")`, `_("Bookmarks")`, …), dialog fields
  (the six developer names, `_("translator-credits")`), button labels
  (`_("Add Bookmark")`, `_("Remove Bookmark")`), and the zoom-control
  tooltips. None of them are marked.
- The 37 messages in `libyelp/yelp-view.c` (context-menu items, error
  dialogs, file-dialog titles) and the error-page strings in
  `lib/error_page.rb` (`Page Not Found`, `Cannot Read`, `Unknown Error`,
  `Document Not Found`, `Find Packages Containing This Document`, and the
  constructed messages) are gaps for two compounding reasons: unmarked, *and*
  — for the view's 37 — the component they belong to does not exist yet
  (named in `.reports/component-parity.md`, unit 9).

No row can be marked `ported` by reading the code "more carefully" — the
census is definitive at 0.

## Languages

109 `.po` files ship upstream, carrying however many translated strings
`msgfmt`/`rmsgfmt` would compile (not separately re-counted here, since the
port ships none of them regardless of per-language completeness). The port
ships 0.

- `languages_missing`: all 109.
- `domain_matches`: false — there is no domain, no `.mo`, nothing to match.

## Checks that did not run

- `msgfmt -c` validation of the carried-over `.po` set — not applicable; no
  `.po` set was carried over.
- `LANGUAGE=de LC_ALL=de_DE.UTF-8 <port binary>` on-screen verification — not
  run; there is no catalogue to display even if the binary launched under a
  German locale.

## Verdict

0/83 messages, 0/109 languages, no domain, no build step. `summary.parity`
is unambiguously `false`. This is not a case needing nuance: the port has not
started translation work, and 109 languages' worth of donated upstream
translation work is currently inherited by nobody.
