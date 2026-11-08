# Translation parity — yelp-rb

| | |
|---|---|
| Upstream | `origin/master` @ `ee532821` |
| Port | `ruby` @ `3aaa820c` (prior passes: `949a10d0`, `1b049d42`) |
| Domain | `yelp` (unconfirmed — no port build file names a domain) |
| Upstream messages | 83 distinct `(msgctxt, msgid)` keys (census via `.claude/skills/translation-parity/scripts/msgid-census.sh`, excluding `po/`, 0 unresolved) |
| Ported | 0 |
| Gaps | 83 |
| Extra (untranslated) | **4** (new this round, see below) |
| Upstream languages | 109 `.po` files |
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

(`libyelp/yelp-uri.c` — the file `lib/yelp_uri.rb` ports this round —
contributes 0 messages to this census; it has no user-visible strings
upstream, and the port's version correspondingly adds none here. This round's
new unmarked strings come from `lib/window.rb`, not `lib/yelp_uri.rb`; see
below.)

## Port census

`.claude/skills/translation-parity/scripts/msgid-census.sh .` run against the
`ruby` branch returns **0 rows**, same as every prior round. `grep -rn "_("
lib/` returns no gettext call sites. There is no `gettext` entry in the
gemspec or any Gemfile, and no `po/` directory exists anywhere in the port.

Every one of the 83 upstream messages is a gap, unchanged from the prior
round:

- **All 7 "present" component units** build their visible strings as bare
  Ruby literals (menu labels, tooltips, dialog fields, button labels). None
  marked.
- The 37 messages in `libyelp/yelp-view.c` and the error-page strings in
  `lib/error_page.rb` are gaps for two compounding reasons: unmarked, and —
  for the view's 37 — the component they belong to does not exist yet.

## New this round: `lib/window.rb`'s `status_title`

This round's `YelpUri` integration (`Window#load_uri`) added a new method,
`status_title`, mapping `YelpUri#document_type` to four bare string
literals that were not present in any prior round's census:

| Port string | `document_type` |
|---|---|
| `'Page Not Found'` | `:not_found` |
| `'Error Loading Page'` | `:error` |
| `'External Link'` | `:external` |
| `'No Page Loaded'` | (default) |

None of these four correspond to a located upstream `msgid` in this audit's
census of `libyelp/yelp-view.c` (where upstream's actual status-page
strings for these states would live, inside the component this port still
does not have) — they read as the port author's own invented wording for a
view-less window's placeholder status page, not a translation of an
upstream string. They are counted here as **4 extra, untranslated strings**
(port-authored text with no `_()` marking and no upstream `msgid` match),
distinct from the 83-gap count above, which stays at 83 because these four
do not correspond to any of upstream's 83 keys one for one. This is a new
"Extra" row this round; the three prior rounds had none.

No row can be marked `ported` by reading the code "more carefully" — the
census is definitive at 0/83.

## Languages

109 `.po` files ship upstream. The port ships 0.

- `languages_missing`: all 109.
- `domain_matches`: false — there is no domain, no `.mo`, nothing to match.

## Checks that did not run

- `msgfmt -c` validation of the carried-over `.po` set — not applicable; no
  `.po` set was carried over.
- `LANGUAGE=de LC_ALL=de_DE.UTF-8 <port binary>` on-screen verification — not
  run; there is no catalogue to display even if the binary launched under a
  German locale.

## Verdict

0/83 messages, 0/109 languages, no domain, no build step, and 4 new
untranslated strings added this round on top of the pre-existing gap.
`summary.parity` is unambiguously `false`. The port has not started
translation work, in this round or any prior one, and 109 languages' worth
of donated upstream translation work is currently inherited by nobody.
