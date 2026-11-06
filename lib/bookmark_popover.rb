# frozen_string_literal: true

require 'adwaita'

require_relative 'bookmark_row'

# BookmarkPopover is the popover opened from the header bar's bookmark
# button: the current page's bookmarks, plus add/remove buttons for the page
# that is open right now.
#
# Ported from the `bookmark_menu` GtkPopover in src/yelp-window.ui and the
# bookmark_activated / bookmark_added / bookmark_removed handlers in
# src/yelp-window.c. Upstream rebuilds `bookmark_list` from a GVariant array
# every time the document's bookmarks change (window_set_bookmarks); this
# port is handed that same array as a plain Ruby array of Bookmark structs
# and does the same rebuild in `bookmarks=`.
#
# Upstream shows the add/remove buttons unconditionally and only toggles
# which of the two is visible, based on whether the current page is already
# bookmarked (window_set_bookmark_buttons) — this port keeps that: the
# visibility is reread, not the row contents, which are never hidden.
#
class BookmarkPopover < Adwaita::Bin
  # `current_bookmark` is the Bookmark for the page that is open right now,
  # or nil when that page has not been bookmarked — it is what the "Remove
  # Bookmark" button removes, and its presence is what picks add vs remove.
  def initialize(bookmarks: [], current_bookmark: nil, on_activate:, on_add:, on_remove:)
    super()
    @bookmarks = bookmarks
    @current_bookmark = current_bookmark
    @on_activate = on_activate
    @on_add = on_add
    @on_remove = on_remove
    self.child = content
    refresh
  end

  def popover = @popover ||= Gtk::Popover.new.tap do |pop|
    pop.add_css_class('menu')
    pop.child = self
  end

  def bookmarks=(bookmarks)
    @bookmarks = bookmarks
    refresh
  end

  def current_bookmark=(bookmark)
    @current_bookmark = bookmark
    refresh
  end

  def content
    @content ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.width_request = 280

      box.append(scrolled_window)
      box.append(empty_label)
      box.append(add_button)
      box.append(remove_button)
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.hscrollbar_policy = :never
      sw.vscrollbar_policy = :automatic
      sw.height_request = 200
      sw.max_content_width = 280
      sw.child = list_box
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |box|
      box.hexpand = true
      box.selection_mode = :none
      box.signal_connect('row-activated') { |_box, row| @on_activate.call(row.bookmark) }
    end
  end

  def empty_label
    @empty_label ||= Gtk::Label.new('No bookmarks for this page').tap do |label|
      label.add_css_class('dim-label')
      label.margin_top = 12
      label.margin_bottom = 12
    end
  end

  def add_button
    @add_button ||= Gtk::Button.new(label: 'Add Bookmark').tap do |button|
      button.margin_start = 6
      button.margin_end = 6
      button.margin_top = 6
      button.margin_bottom = 6
      button.signal_connect('clicked') { @on_add.call }
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new(label: 'Remove Bookmark').tap do |button|
      button.margin_start = 6
      button.margin_end = 6
      button.margin_top = 6
      button.margin_bottom = 6
      button.signal_connect('clicked') { @on_remove.call(@current_bookmark) }
    end
  end

  # Rebuilds the list from the current bookmarks array (window_set_bookmarks)
  # and the add/remove visibility from the current page's state
  # (window_set_bookmark_buttons).
  def refresh
    list_box.tap do |box|
      box.observe_children.to_a.each { |row| box.remove(row) }
      sorted_bookmarks.each { |bookmark| box.append(BookmarkRow.new(bookmark, on_remove: @on_remove)) }
    end
    scrolled_window.visible = @bookmarks.any?
    empty_label.visible = @bookmarks.empty?
    add_button.visible = @current_bookmark.nil?
    remove_button.visible = !@current_bookmark.nil?
  end

  private

    def sorted_bookmarks = @bookmarks.sort_by { |bookmark| bookmark.title.to_s }
end
