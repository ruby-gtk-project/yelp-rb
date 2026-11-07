# frozen_string_literal: true

require 'gtk4'

# SearchResultRow is one row of the search entry's completion list: an icon,
# a title, a bookmark marker and a description, laid out in a grid exactly
# like the row template upstream builds from a GtkBuilder list-item factory.
#
# Ported from the row template in src/yelp-search-entry.ui (the
# `completions_list` factory's `Gtk.Grid`). Upstream wires each cell with
# `Gtk.Expression` bindings straight to a `YelpSearchResult`'s properties;
# this port has no `.ui` and no expression bindings, so `update` does the
# same job by hand each time `Gtk::SignalListItemFactory`'s `bind` signal
# fires — the row is a plain object, built once per visible list slot and
# rebound whenever the item behind that slot changes.
class SearchResultRow
  def build
    grid.tap do |g|
      g.attach(icon, 0, 0, 1, 2)
      g.attach(title_label, 1, 0, 1, 1)
      g.attach(bookmark_icon, 2, 0, 1, 1)
      g.attach(desc_label, 1, 1, 2, 1)
    end
  end

  # Populates the row from a SearchResult, called on every `bind`.
  def update(result)
    icon.icon_name = result.icon
    title_label.label = result.title.to_s
    desc_label.label = result.desc.to_s
    bookmark_icon.icon_name = result.bookmarked? ? 'user-bookmarks-symbolic' : nil
    bookmark_icon.opacity = result.bookmarked? ? 1.0 : 0.0
  end

  def grid
    @grid ||= Gtk::Grid.new.tap do |g|
      g.column_spacing = 6
      g.row_spacing = 3
      g.margin_start = 6
      g.margin_end = 6
      g.margin_top = 3
      g.margin_bottom = 3
    end
  end

  def icon
    @icon ||= Gtk::Image.new.tap do |i|
      i.pixel_size = 16
      i.valign = :center
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |l|
      l.use_markup = true
      l.ellipsize = :end
      l.xalign = 0
      l.single_line_mode = true
      l.hexpand = true
    end
  end

  def bookmark_icon
    @bookmark_icon ||= Gtk::Image.new.tap do |i|
      i.pixel_size = 16
      i.valign = :center
    end
  end

  def desc_label
    @desc_label ||= Gtk::Label.new.tap do |l|
      l.use_markup = true
      l.ellipsize = :end
      l.xalign = 0
      l.add_css_class('dim-label')
      l.add_css_class('caption')
    end
  end
end
