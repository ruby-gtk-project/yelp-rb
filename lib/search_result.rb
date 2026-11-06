# frozen_string_literal: true

# SearchResult is one row of the search completion list: a page the user can
# jump to, with the text the completion view shows for it.
#
# Ported from upstream's src/yelp-search-result.c / .h, a plain GObject with
# six string/uint properties and no behaviour of its own — title, desc, icon
# and keywords are markup-escaped by upstream's property setters before
# storage, since the completion view renders them straight into Pango markup.
#
# COMPLETION_FLAG_ACTIVATE_SEARCH and COMPLETION_FLAG_BOOKMARKED from
# upstream's header are the two bits `flags` can carry: activating a row with
# the first bit set runs a full search instead of opening `page` directly, and
# the second bit marks a result that is already bookmarked.
#
class SearchResult
  FLAG_ACTIVATE_SEARCH = 1 << 0
  FLAG_BOOKMARKED = 1 << 1

  attr_accessor :icon, :page, :flags, :keywords
  attr_reader :title, :desc

  def initialize(title: nil, desc: nil, icon: nil, page: nil, flags: 0, keywords: nil)
    self.title = title
    self.desc = desc
    @icon = icon
    @page = page
    @flags = flags
    @keywords = keywords
  end

  def title=(value)
    @title = escape(value)
  end

  def desc=(value)
    @desc = escape(value)
  end

  def activate_search? = flags.anybits?(FLAG_ACTIVATE_SEARCH)

  def bookmarked? = flags.anybits?(FLAG_BOOKMARKED)

  MARKUP_ESCAPES = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    "'" => '&apos;',
    '"' => '&quot;',
  }.freeze

  private

    def escape(value) = value&.gsub(/[&<>'"]/, MARKUP_ESCAPES)
end
