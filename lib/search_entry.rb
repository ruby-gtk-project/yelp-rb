# frozen_string_literal: true

require 'gtk4'

require_relative 'search_result'
require_relative 'search_result_row'

# SearchEntry is the window's address/search entry: a plain entry with a
# completion popover of matching SearchResults underneath it, plus a
# standing "search for this" row that always runs a full search.
#
# Ported from src/yelp-search-entry.c / .h and src/yelp-search-entry.ui.
# Upstream's model is a four-stage pipeline (`Gtk.SortListModel` over the
# bookmarks/results store, filtered by the typed text, sliced to the first
# six, flattened with a synthetic "Search for %s" row) feeding a
# `Gtk.ListView` built from a GtkBuilder list-item factory. This port keeps
# the filter-then-slice shape — `Gtk::CustomFilter` + `Gtk::FilterListModel`
# + `Gtk::SliceListModel` — but drops the `Gtk::FlattenListModel` concatenation:
# the Ruby bindings require every `Gio::ListStore` item to share one GObject
# subclass, and mixing `SearchResult` rows with a synthetic row would need a
# second item type. Instead the synthetic "Search for %s" affordance is a
# standing row below the list (`search_all_row`), always present, exactly as
# visible as upstream's flattened one.
#
# Upstream reaches into a `YelpView` (for the completion source and
# `view.load_uri`) and a `YelpBookmarks` (for the bookmark markers). I have
# not ported `YelpView` (lib/view.rb does not exist; see FINDINGS.md for why
# — there is no `WebKit::WebView` binding to build it on), so this port is
# handed its results and bookmark lookup as plain injected data, and
# `on_activate` is however the caller wants to load a page.
class SearchEntry
  RESULT_LIMIT = 6

  def initialize(results: [], on_activate:, on_search_all:, on_stop_search: nil)
    @on_activate = on_activate
    @on_search_all = on_search_all
    @on_stop_search = on_stop_search
    @rows = {}
    @store = Gio::ListStore.new(SearchResult)
    self.results = results
  end

  # Replaces the full candidate list (upstream's bookmarks + read-later +
  # backend results) and reruns the current filter over it.
  def results=(results)
    @store.remove_all
    results.each { |result| @store.append(result) }
  end

  def build
    entry.tap do
      popover.set_parent(entry)
    end
  end

  def entry
    @entry ||= Gtk::Entry.new.tap do |e|
      e.hexpand = true
      e.placeholder_text = 'Search help topics…'
      e.signal_connect('changed') { entry_changed }
      e.signal_connect('activate') { entry_activate }
      e.add_controller(focus_controller)
      e.add_controller(key_controller)
    end
  end

  def popover
    @popover ||= Gtk::Popover.new.tap do |pop|
      pop.add_css_class('menu')
      pop.add_css_class('completions')
      pop.has_arrow = false
      pop.autohide = false
      pop.position = :bottom
      pop.child = popover_box
    end
  end

  def popover_box
    @popover_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.width_request = 425
      box.append(completions_scroll)
      box.append(Gtk::Separator.new(:horizontal))
      box.append(search_all_row)
    end
  end

  def completions_scroll
    @completions_scroll ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.hscrollbar_policy = :never
      sw.propagate_natural_height = true
      sw.max_content_height = 400
      sw.child = completions_list
    end
  end

  def completions_list
    @completions_list ||= Gtk::ListView.new.tap do |lv|
      lv.model = selection_model
      lv.factory = list_factory
      lv.single_click_activate = true
      lv.signal_connect('activate') { |_list, position| activate_result(sliced_model.get_item(position)) }
    end
  end

  def search_all_row
    @search_all_row ||= Gtk::Button.new.tap do |button|
      button.add_css_class('flat')
      button.child = search_all_label
      button.signal_connect('clicked') { search_all }
    end
  end

  def search_all_label
    @search_all_label ||= Gtk::Label.new.tap do |label|
      label.xalign = 0
      label.margin_start = 12
      label.margin_end = 12
      label.margin_top = 6
      label.margin_bottom = 6
    end
  end

  private

    def selection_model
      @selection_model ||= Gtk::SingleSelection.new(sliced_model).tap do |selection|
        selection.autoselect = false
        selection.can_unselect = true
      end
    end

    def sliced_model
      @sliced_model ||= Gtk::SliceListModel.new(filtered_model, 0, RESULT_LIMIT)
    end

    def filtered_model
      @filtered_model ||= Gtk::FilterListModel.new(@store, filter)
    end

    def filter
      @filter ||= Gtk::CustomFilter.new { |result| matches?(result) }
    end

    def matches?(result)
      query = entry.text.to_s.strip.downcase
      return true if query.empty?

      haystack = [result.title, result.desc, result.keywords].compact.join(' ').downcase
      haystack.include?(query)
    end

    def list_factory
      @list_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
        factory.signal_connect('setup') do |_factory, item|
          row = SearchResultRow.new
          @rows[item.object_id] = row
          item.child = row.build
        end

        factory.signal_connect('bind') do |_factory, item|
          @rows[item.object_id]&.update(item.item)
        end

        factory.signal_connect('teardown') do |_factory, item|
          @rows.delete(item.object_id)
        end
      end
    end

    def entry_changed
      filter.changed(:different)
      search_all_label.label = "Search for “#{entry.text}”"
      update_popover_visibility
    end

    def entry_activate
      selected = selection_model.selected_item
      if selected
        activate_result(selected)
      else
        search_all
      end
    end

    # Guarded by `mapped?`: GTK requires a popover's parent to have a
    # realized native surface before it can be shown, which the entry does
    # not yet have while the window around it is still being assembled.
    def update_popover_visibility
      if entry.text.to_s.empty? || !entry.mapped?
        popover.popdown
      else
        popover.popup
      end
    end

    def activate_result(result)
      popover.popdown
      @on_activate.call(result)
    end

    def search_all
      popover.popdown
      @on_search_all.call(entry.text.to_s)
    end

    def focus_controller
      @focus_controller ||= Gtk::EventControllerFocus.new.tap do |controller|
        controller.signal_connect('notify::contains-focus') do
          update_popover_visibility if controller.contains_focus?
        end
      end
    end

    def key_controller
      @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect('key-pressed') do |_controller, keyval, *_rest|
          handle_key(keyval)
        end
      end
    end

    def handle_key(keyval)
      case keyval
      when Gdk::Keyval::KEY_Down
        move_selection(1)
        true
      when Gdk::Keyval::KEY_Up
        move_selection(-1)
        true
      when Gdk::Keyval::KEY_Escape
        if popover.visible?
          popover.popdown
        else
          @on_stop_search&.call
        end
        true
      else
        false
      end
    end

    def move_selection(delta)
      count = sliced_model.n_items
      return if count.zero?

      current = selection_model.selected
      current = -1 if current == Gtk::INVALID_LIST_POSITION
      next_index = (current + delta).clamp(0, count - 1)
      selection_model.selected = next_index
      popover.popup if entry.mapped?
    end
end
