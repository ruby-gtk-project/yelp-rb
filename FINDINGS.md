# Findings

Binding and environment limitations discovered while porting yelp-rb, kept
here instead of as scattered excuse-comments in `lib/`. Each entry names the
upstream behaviour it blocks and the evidence for why it is blocked, not just
that it is.

## WebKit::WebView is not available to this process

Upstream's `libyelp/yelp-view.c` (`YelpView`, a `WebKitWebView` subclass) is
how every document actually gets painted: the five document backends
(docbook/mallard/man/info/simple) each transform their source into HTML or
XHTML, and `YelpView` hands the result to
`webkit_web_view_load_html`/`load_uri`. Printing, the in-page find bar's
highlight, the right-click context menu, zoom, and `win.yelp-view-go-back`/
`-go-forward` are all `WebKitWebView` behaviour reached through that same
widget.

The Ruby GTK bindings available to this fleet (confirmed by a prior porting
round, re-confirmed while writing this round's `lib/yelp_uri.rb`) provide
`webkit-web-process-extension`, the gem for WebKit's *web-process extension*
API (`WebKitWebProcessExtension`, `WebKitWebPage`) — the small library
WebKit dlopens inside its own separate, sandboxed web-process executable to
let an extension script talk to a page's DOM from *inside* that process.
There is no `webkit-gtk`/`WebKit::WebView` gem exposing the browsing-widget
API (`WebKitWebView`, `webkit_web_view_load_html`, `webkit_web_view_load_uri`)
that would actually let a GTK application embed a page and load content into
it.

This is not merely "a gem we haven't added yet": `webkit-web-process-extension`
cannot stand in for it. Its own README says so, and this round confirms it
empirically — `WebProcessExtension#signal_connect` attaches without raising,
but no `WebPage` is ever created in this process to fire it, because the
real extension is a shared library WebKit dlopens inside its own separate
web-process executable, and a Ruby gem loaded in the *application* process
cannot be that `.so`. There is no code path from this process into a
`WebKitWebView`.

**What this blocks:** `lib/view.rb` (the whole `YelpView` port), and
everything that depends on a loaded page existing — the document backends
(`lib/*_document.rb` for docbook/mallard/man/info/simple), `yelp-help-list.c`'s
All Help listing (built as rendered HTML), printing, and the go-back/-forward
actions, which `lib/window.rb` registers permanently disabled for exactly
this reason.

**What is not blocked by it, and is ported:** URI resolution
(`lib/yelp_uri.rb`, ported from `libyelp/yelp-uri.c`) needs no `WebView` at
all — it only touches `Gio::File`, `GLib` data-dir lookups, and a `man -w`
subprocess — which is why it is the first piece of the document pipeline
this port has working code and specs for (`spec/yelp_uri_spec.rb`).

## The RSpec harness cannot load in this sandbox

`spec/spec_helper.rb` (pre-existing, not written this round) requires
`kettle/test/rspec`. That gem is not present in this repository's Nix flake
gem closure, and `.rspec` forces `--require spec_helper` on every `rspec`
invocation, so **no spec file can currently be loaded**, regardless of what
it contains — this is true of `spec/yelp_uri_spec.rb` added this round as
much as it would be true of any other spec. `lib/yelp_uri.rb`'s behaviour
was instead verified directly: ad hoc scripts built fixture trees matching
`tests/uri/*.test` (ghelp docbook/mallard, with and without an `xref:`,
absolute paths with fragments, a `man:` file path, an `info:` name resolved
through `INFOPATH`) and asserted the resolver's output against each
fixture's expected `DOCUMENT TYPE`/`DOCUMENT URI`/`CANONICAL URI`/`SEARCH
PATH`/`PAGE ID`/`FRAG ID` fields.

Fixing the RSpec harness itself (vendoring `kettle-test` and its dependency
family into the flake) is outside this round's scope, but it is the reason
`spec/yelp_uri_spec.rb` cannot be demonstrated passing through `rake spec`
in this environment even though its logic has been exercised and is correct.
