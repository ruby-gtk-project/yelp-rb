# frozen_string_literal: true

require 'gtk4'

# Bookmark is one remembered page: a page id to jump back to, the icon and
# title window_set_bookmarks in upstream reads off the page itself, kept so
# the row can be redrawn without re-visiting the page.
#
# Ported from the `(sss)` tuples upstream's `org.gnome.yelp.documents`
# "bookmarks" key stores per document-URI (see window_set_bookmarks in
# src/yelp-window.c) — page id, icon name, title.
Bookmark = Struct.new(:page_id, :icon, :title)

# BookmarkRow is one row of the bookmarks popover: the bookmark's title and a
# delete button.
#
# Ported from the per-entry GtkListBoxRow window_set_bookmarks builds by hand
# in src/yelp-window.c — a GtkBox with an ellipsized, left-aligned label and
# a flat "edit-delete-symbolic" button. Upstream disables focus-on-click on
# the delete button so clicking it does not steal focus from the list box;
# this port does the same.
#
class BookmarkRow < Gtk::ListBoxRow
  def initialize(bookmark, on_remove:)
    super()
    @bookmark = bookmark
    @on_remove = on_remove
    self.child = row_box
  end

  attr_reader :bookmark

  def row_box
    @row_box ||= Gtk::Box.new(:horizontal, 4).tap do |box|
      box.append(title_label)
      box.append(remove_button)
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new(@bookmark.title).tap do |label|
      label.tooltip_text = @bookmark.title
      label.hexpand = true
      label.xalign = 0.0
      label.ellipsize = :end
      label.margin_start = 9
      label.margin_end = 9
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new(icon_name: 'edit-delete-symbolic').tap do |button|
      button.add_css_class('flat')
      button.focus_on_click = false
      button.signal_connect('clicked') { @on_remove.call(@bookmark) }
    end
  end
end
