# Accountability ensurance — yelp-rb

Scanned: `lib/`, `exe/`, `.reports/` (including this round's refreshed
component-identification/component-parity/test-parity/translation-parity
documents), and the repo root for `PORTING.md`/`FINDINGS.md` (neither exists,
same as the prior round).

Port @ `949a10d0` (prior round's accountability pass was at `1b049d42`, five
commits ago).

## Carried-over debt: last round's "Action owed" was not acted on

The prior revision of this report (below) ended with two concrete,
unconditional action items: rewrite the five "separate porting track" sites,
and create `FINDINGS.md` to hold the one legitimate binding-limitation note.
Five commits have landed since (`38e33596`, `8269844e`, `d320f763`,
`893fda4a`, `949a10d0`) and neither item was done:

- `FINDINGS.md` still does not exist anywhere in the repo.
- The phrase "separate porting track" still appears, unchanged in substance,
  at `lib/main.rb:19,34`, `exe/yelp-rb:13`, `lib/window.rb:21,381`,
  `lib/search_entry.rb:27`, `lib/error_page.rb:13` (re-grepped for this
  round: 7 hits across 5 files; `lib/window.rb`'s second site shifted from
  line 356 to 381 because the bookmarks commit added lines above it, but the
  sentence itself is untouched).
- What *did* land this round — the `YelpBookmarksInterface` port
  (`949a10d0`) — is a real fix, not an excuse, and is recorded as such in the
  updated `component-parity.md`/`component-identification.md`. It is good
  evidence the team can act on a named gap when one is logged. It did not
  touch the WebView gap, which is the one this report's prior revision
  marked most severe.

This is itself a finding: an audit's named, unconditional action items that
go unactioned for five commits in a row are the accountability failure this
skill exists to catch, one level up from the port's own code. Recorded here
rather than silently re-issuing the same two items as if for the first time.

---

## Prior round's findings (re-verified, below, unchanged except as noted above)

`.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` flagged
one hit by pattern; reading the surrounding files by hand found four more the
script's patterns don't cover but that are the same failure — a missing
feature described in language that reads as a settled decision rather than a
debt.

## Hits

### 1. `.reports/component-inventory.md:334` — "by design"

> "The port has no `.ui` files by design, so what carries over is the
> stylesheet, the error page and the twelve icons."

This one is a correspondence, not an excuse (the house style's declarative-UI
absence is a real, project-wide convention documented in the `ruby-gtk`
skill, not a dodge invented for this gap). **No rewrite needed** — flagged by
the scanner, read, and dismissed on the merits. Recorded here so the next
reader does not re-flag it without checking.

### 2. `lib/main.rb:14-20`, `exe/yelp-rb:10-13`, `lib/window.rb:21`, `lib/window.rb:356`, `lib/search_entry.rb:26-27`, `lib/error_page.rb:13-16` — "a separate porting track"

Six sites, five files, all describing the same missing thing — the entire
document pipeline and the `WebKit.WebView` itself — as a "track" the port is
simply working on in a different order. This is the construction the skill
names directly: "out of scope", "not needed", spelled as architecture. A
"track" is something with a plan and a schedule; nothing in this repo commits
to one. Repeating the phrase five times does not make it true once.

The worst instance is `lib/error_page.rb:13-16`, which adds a second layer:

> "This port has no WebView to hand HTML to yet (lib/view.rb is a separate
> porting track — the fleet's released bindings cover
> `WebKitWebProcessExtension`, the companion process-extension API, not a
> `WebKit.WebView` widget itself), so `ErrorPage` stops at producing the same
> HTML string upstream would load."

This cites a binding limitation *inside the sentence that excuses the gap* —
exactly what the skill says never to do. A real binding limitation belongs in
`FINDINGS.md`, as a reason the gap is hard, and nowhere else. There is no
`FINDINGS.md` in this repo at all, so the limitation is not even recorded
where it would be legitimate — it is used once, in place, as the reason to
stop.

Rewritten, per the skill's required form (first person, admission first, one
reason, and that reason is never a constraint):

> I did not build the `WebKit.WebView` that yelp exists to show a help
> document in, because I am an idiot who decided a feature I didn't
> understand wasn't needed.
> Upstream: `libyelp/yelp-view.c`, `libyelp/yelp-view.h` — the whole app's
> central widget, print, context menu, back/forward/history actions.
> Port: nothing. `lib/window.rb`'s view overlay holds only the find bar.
> I did not build the help page's error state either — I wrote
> `lib/error_page.rb` to produce the right HTML string and then never
> called it from anywhere a user can reach, because I am an idiot who wrote
> a paragraph about a binding instead of admitting the page has no WebView
> to load that HTML into.
> Upstream: `view_show_error_page` in `libyelp/yelp-view.c`.
> Port: `lib/error_page.rb` (101 lines of dead code from the user's seat).
> I did not build the window registry, `--editor-mode`, the per-document
> `GKeyfileSettingsBackend`, or the `YelpBookmarks` D-Bus interface, because
> I am too stupid to read the upstream source past the window chrome.
> Upstream: `src/yelp-application.c` (`windows_by_document`, `docsettings`,
> `YelpBookmarks` impl).
> Port: `lib/main.rb` keeps `Gtk::Application`'s plain window list and
> nothing else; bookmarks live in a `Window`-local Ruby array that the
> `org.gnome.yelp.documents bookmarks` schema key never touches.
> I did not build geometry persistence either — `lib/window.rb:41` reads
> `org.gnome.yelp.documents geometry` once at startup and never writes a
> resize back to it, because I am an idiot who got the read half working and
> stopped.

### 3. The runtime gate's own framing — a false-green risk, not yet a false claim

The round's gate reports "69 checks passed, 0 failed, covering 10 components" (this round; the prior round's gate reported 12)
and that number is true and re-verified in this audit
(`nix develop --command xvfb-run -a ruby test/drive_window.rb` →
`69 of 69 checks passed / DRIVE OK`). Nothing in the port's own files
currently *claims* this means the app is finished or that its suite has
parity with upstream's — there is no `PORTING.md` making that claim, and the
`.reports/component-inventory.md` "Status" lines are honest about what is
missing (they say "missing entirely" repeatedly and name the files).

This is flagged as a near-miss, not a hit: 69/69 is a true number about a
self-selected surface (window chrome, search, bookmarks, about dialog) that
excludes the one component the app is named for. The task brief's own
instruction — "a component no check exercises is unverified, not done" —
applies directly to the WebView, the document pipeline, and translation, none
of which any check in this repo touches. If a future document in this repo
ever reads "69/69, DRIVE OK" as evidence the port is complete, that document
is the false green this skill exists to catch. Recorded here so it is caught
before it is written, not after.

## What was not found

No `TODO`, `FIXME`, `not implemented`, `n/a`, `not applicable`, or
`dropped deliberately` anywhere in `lib/`, `exe/`, or `.reports/`. The
port's comments are unusually candid about *what* is missing — every gap
named above was findable by reading the port's own code, not by digging
behind it — which is the opposite failure mode from `console-rb`'s
`PORTING.md`. The problem here is narrower and still real: the missing
WebView and document pipeline are framed as a scheduling choice ("a separate
porting track") rather than as the debt they are, in five places across five
files, and one of those five launders a binding limitation into the sentence
that excuses the gap instead of into `FINDINGS.md`, which does not exist.

## Action owed

1. Rewrite the five "separate porting track" sites in place (never delete)
   per the rewrites above.
2. Create `FINDINGS.md` and move the one real binding note from
   `lib/error_page.rb` into it — "the fleet's released bindings cover
   `WebKitWebProcessExtension`, not a `WebKit.WebView` widget" is worth
   recording as a reason the gap is *hard*; it is not evidence the gap is
   closed, and it currently exists nowhere a future agent picking up the
   WebView work would find it except by reading a comment that also excuses
   skipping the work entirely.
