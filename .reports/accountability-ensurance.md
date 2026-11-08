# Accountability ensurance — yelp-rb

Scanned: `lib/`, `exe/`, `spec/`, `.reports/`, `FINDINGS.md` (now exists —
see below) and the repo root for `PORTING.md` (still does not exist).

Port @ `3aaa820c` (prior accountability pass: `949a10d0`, one commit ago).

## Good news first: last round's "Action owed" was acted on, for real

The prior revision of this report ended with two unconditional action
items. Both landed in the one commit since (`3aaa820c`, "Port
libyelp/yelp-uri.c's YelpUri; wire it into Window#load_uri"):

1. **"Rewrite the five 'separate porting track' sites."** Done. Re-grepping
   `lib/` and `exe/` for "separate porting track" at this round returns
   **zero hits** — the phrase is gone from `lib/main.rb`, `exe/yelp-rb`,
   `lib/window.rb`, `lib/search_entry.rb` and `lib/error_page.rb`. In its
   place, each site now says, in first person, what was not built and cites
   `FINDINGS.md` for the reason it is hard — e.g. `lib/main.rb`: "I have not
   ported either [the window registry or per-document settings cache]...
   that wiring... [is] owed work, not done work"; `lib/error_page.rb`: "I
   have not written `lib/view.rb` — there is no `WebKit::WebView` binding in
   this fleet to hand that HTML to (see FINDINGS.md for the full
   binding-limitation note...)". This reads as an admission with a citation,
   not an excuse with a label — the distinction this skill exists to draw.
2. **"Create `FINDINGS.md`."** Done — 70 lines, two entries: the
   `WebKit::WebView` binding gap (with the empirical detail that
   `webkit-web-process-extension` was tried and does not substitute, not
   just asserted) and the RSpec harness failure (`kettle/test/rspec` missing
   from the flake closure). Both entries are framed as *why the gap is
   hard*, not as *evidence the gap is closed* — exactly the split the prior
   report asked for. Re-reading `FINDINGS.md` end to end in this audit finds
   no instance of it being used to assert a feature works or a check passed
   when it does not.

This is worth stating plainly because the prior report warned explicitly
about a pattern — named debt going unactioned round after round — and this
round is the counter-example. Recorded here so the next reader credits it
correctly rather than re-running the same scan and finding nothing to flag.

## New hits found this round

### 1. `FINDINGS.md`'s own unverifiable claim — a near-miss, read carefully

`FINDINGS.md`'s second entry states, about `lib/yelp_uri.rb`: "`lib/yelp_uri.rb`'s
behaviour was instead verified directly: ad hoc scripts built fixture trees
matching `tests/uri/*.test`... and asserted the resolver's output against
each fixture's expected... fields," concluding the logic "has been exercised
and is correct."

This audit independently re-confirmed the first half — the RSpec harness
genuinely cannot load (`LoadError: cannot load such file --
kettle/test/rspec`, reproduced fresh in this session). That half is true and
disclosed, not an excuse.

The second half — "exercised and correct," resting on "ad hoc scripts" — is
**not verifiable by this audit or by anyone else who clones this branch**,
because those scripts are not committed anywhere in the repo. Grepped for:
no `.rb` file outside `lib/` and `spec/` references `yelp-uri` fixture
checking; no `tmp/`, `scratch/`, or similar directory is tracked. This is
not the laundering pattern the skill names (the sentence does not use the
unverified claim *to excuse not writing a test* — a real spec file was
written and committed) — but it is a claim of correctness with no
reproducible evidence behind it, made in the one document in this repo
whose entire job is to be the trustworthy record of what is actually known.
If a future reader treats "ad hoc scripts... verified... correct" as
equivalent to "there is a passing test," that reader has been misled by a
true-sounding sentence about work nobody else can check. Flagged as a
near-miss, not a violation: the honest thing to add would be one line
making explicit that this claim is unverifiable by anyone without those
scripts, which do not exist in the repo. Recorded here so a future revision
of `FINDINGS.md` closes this rather than repeating it.

### 2. The runtime gate's own framing — still a false-green risk, now sharper

Re-verified this round: `nix develop --command xvfb-run -a ruby
test/drive_window.rb` → `69 of 69 checks passed / DRIVE OK`, matching the
round's gate (`69 checks passed, 0 failed, covering 12 components`) exactly.
That number is true.

What changed this round, and makes the prior near-miss sharper rather than
resolved: **this round added the single largest file in the port
(`lib/yelp_uri.rb`, 638 lines) and it is covered by neither the gate nor any
tool that runs.** The one drive-script check that happens to touch
`Window#load_uri` (typing an address into the Ctrl+L entry and asserting
`current_uri` equals what was typed) cannot distinguish "YelpUri correctly
resolved this" from "YelpUri's `#resolve!` is a no-op that returns the input
unchanged" — `resolve_help_document` builds `@full_uri` from the literal
input's own parts regardless of whether a matching help tree exists on
disk, so the assertion passes in both cases. Confirmed by reading the check
and the resolver together, not merely asserted here.

**The task brief's own instruction applies directly: "a component no check
exercises is unverified, not done."** `YelpUri`'s branch logic — ghelp/help/
man/info/xref resolution, data-dir scanning, MIME sniffing — is unexercised
by the gate and unexecuted by the spec suite. Two separate audits now
(`.reports/component-identification.md`, `.reports/test-parity.md`) locate
and name this; this report flags it at the accountability level because the
risk is specifically that a reader sees "69/69, DRIVE OK" *and* "638 lines
of new resolver code, with a spec file" and concludes the resolver was
tested, when neither fact supports that conclusion and nothing in `.reports/`
said so until this round's revision of these documents. This is the same
false-green risk the prior two rounds flagged for the WebView gap, now
also true of this round's own new code — not because anyone asserted it
tests clean, but because nothing anywhere in this repo's own files said
plainly, before this audit, that it does not.

### 3. `status_title`'s four new strings — a small, real translation gap, worth naming once

`lib/window.rb`'s new `status_title` method introduces four string literals
(`'Page Not Found'`, `'Error Loading Page'`, `'External Link'`, `'No Page
Loaded'`) that are the port's own invention for a view-less placeholder
status page, not a port of an upstream string (upstream's real status-page
text lives in `libyelp/yelp-view.c`, inside the component that does not
exist here). Not excused anywhere as "temporary" or "not needed" — simply
unmarked, same failure mode as everything else in
`.reports/translation-parity.md`, recorded there in detail. Named here only
because it is new growth in the unmarked-string surface this round, not a
repeat of a previously-flagged item.

## Re-verified: what was not found

No `TODO`, `FIXME`, `not implemented`, `n/a`, `not applicable`, `for now`,
`in a future`, or `dropped deliberately` anywhere in `lib/`, `exe/`,
`spec/`, `.reports/`, `FINDINGS.md` or `PORTING.md` (the last of which still
does not exist). `.claude/skills/accountability-ensurance/scripts/find-excuses.sh
.` was re-run for this round and its hits are all pre-existing ones already
addressed in prior rounds' revisions of `.reports/component-inventory.md`
(the "by design" hit, dismissed on the merits in the prior round) or are
label words appearing only inside `.reports/` documents' own meta-discussion
of the skill's pattern list (not live excuses in `lib/`/`exe/`). No new
scanner hit in `lib/` or `exe/` this round.

## Action owed

1. Add one sentence to `FINDINGS.md`'s `YelpUri` entry making explicit that
   the "ad hoc scripts" claim is unverifiable by anyone without those
   scripts, since they are not committed to the repo — or commit the
   scripts themselves as a `spec/` support file (even if they cannot run
   under the broken RSpec harness, committing them lets the next engineer
   re-derive what was actually checked).
2. Either get `spec/yelp_uri_spec.rb` executing (vendor `kettle-test` and
   its dependency family into the flake, as `FINDINGS.md` itself suggests as
   the fix) or add a drive-script check that exercises `YelpUri` end to end
   through `Window#load_uri` with a real fixture tree, so at least one tool
   this repo can run touches the 638 lines this round added. Right now
   neither exists, and that is the single largest unverified surface in the
   port.
3. Carry forward, unchanged from two rounds ago: the WebView gap (unit 9)
   remains the most severe gap in the app and this round did not touch it.
