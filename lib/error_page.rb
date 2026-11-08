# frozen_string_literal: true

# ErrorPage renders the in-page HTML a YelpView loads when a document fails
# to load: a big icon, a title and the error message, with an optional
# "Find Packages Containing This Document" recovery link for a 404 on a
# `help:`/`ghelp:` URI.
#
# Ported from `view_show_error_page` in libyelp/yelp-view.c, which fills
# four `%s` placeholders in src/resources/error.html (icon file URI, title,
# an escaped `<p>` of `error->message`, and the optional recovery `<p>`)
# with `g_string_printf` and hands the result to
# `webkit_web_view_load_html`. I have not written `lib/view.rb` — there is
# no `WebKit::WebView` binding in this fleet to hand that HTML to (see
# FINDINGS.md for the full binding-limitation note: the one WebKit gem
# available, `webkit-web-process-extension`, cannot be driven from this
# process either, so it is not a usable substitute) — so `ErrorPage` stops
# at producing the same HTML string upstream would load, from the same
# template asset (lib/resources/error.html, carried over verbatim except
# for upstream's printf placeholders, which are named `{{...}}` markers
# here since this port fills them with plain substitution rather than a
# format string).
class ErrorPage
  TEMPLATE_PATH = File.join(__dir__, 'resources/error.html')

  NOT_FOUND = :not_found
  CANT_READ = :cant_read
  UNKNOWN = :unknown

  TITLES = {
    NOT_FOUND => 'Page Not Found',
    CANT_READ => 'Cannot Read',
    UNKNOWN   => 'Unknown Error',
  }.freeze

  DOC_NOT_FOUND_TITLE = 'Document Not Found'
  RECOVERY_LABEL = 'Find Packages Containing This Document'

  # `code` is one of NOT_FOUND / CANT_READ / UNKNOWN (upstream's
  # YELP_ERROR_NOT_FOUND / YELP_ERROR_CANT_READ / anything else).
  # `document_not_found` is upstream's separate `doc404` flag: a 404 on the
  # containing *document* (as opposed to a page within one that loaded
  # fine), which swaps the title and adds the recovery link.
  # `uri` is the yelp: URI that failed, used to build the recovery link's
  # `install-<scheme>:<package>` href for `help:`/`ghelp:` URIs.
  def initialize(message:, code: UNKNOWN, document_not_found: false, uri: nil, icon_uri: '')
    @message = message
    @code = code
    @document_not_found = document_not_found
    @uri = uri
    @icon_uri = icon_uri
  end

  def title
    @document_not_found ? DOC_NOT_FOUND_TITLE : TITLES.fetch(@code, TITLES[UNKNOWN])
  end

  # The icon upstream looks up from the icon theme (`dialog-question-symbolic`
  # for a missing document, `computer-fail-symbolic` otherwise) — handed in
  # as a resolved file/resource URI since this class does no icon-theme
  # lookup itself.
  def icon_uri = @icon_uri

  def html
    TEMPLATE.gsub('{{icon}}', escape(icon_uri))
            .gsub('{{title}}', escape(title))
            .gsub('{{message}}', message_html)
            .gsub('{{recovery}}', recovery_html)
  end

  private

    TEMPLATE = File.read(TEMPLATE_PATH)
    private_constant :TEMPLATE

    def message_html = "<p>#{escape(@message)}</p>"

    def recovery_html
      package.then do |pkg|
        if pkg
          %(<p><a class='button' href='install-#{pkg[:scheme]}:#{escape(pkg[:name])}'>#{escape(RECOVERY_LABEL)}</a></p>)
        else
          ''
        end
      end
    end

    # The `install-help:<name>` / `install-ghelp:<name>` href only makes
    # sense for a missing document (not a missing page within a document
    # that did load), and only for the two schemes upstream recognises.
    def package
      return nil unless @document_not_found && @uri

      if @uri.start_with?('help:')
        { scheme: 'help', name: @uri.delete_prefix('help:') }
      elsif @uri.start_with?('ghelp:')
        { scheme: 'ghelp', name: @uri.delete_prefix('ghelp:') }
      end
    end

    def escape(value)
      value.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
    end
end
