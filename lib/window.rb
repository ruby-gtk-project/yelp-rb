# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'bookmark_popover'
require_relative 'primary_menu'
require_relative 'search_entry'
require_relative 'search_result'
require_relative 'settings'
require_relative 'yelp/rb/version'

# Window is one help window: the header bar, the breakpoint that collapses it
# for narrow widths, the in-page find bar, the bottom action bar it moves
# controls to, the Ctrl+L address-bar override, drag-and-drop, and the extra
# mouse-button navigation gesture.
#
# Ported from src/yelp-window.c / .h and src/yelp-window.ui. Upstream builds
# this from a GtkBuilder template with a YelpView child that does the actual
# page loading and navigation (go-back/forward, printing, the search entry's
# completion view); YelpView is a separate porting track
# (lib/view.rb, not yet written), so this port tracks only what a view would
# tell it — the current address, as a plain string — and the actions that
# depend on the view's navigation stack (`yelp-view-go-back`/`-go-forward`)
# are registered disabled, exactly as they would be with no page history yet.
#
# Upstream's bookmarks are per-document, read from `org.gnome.yelp.documents`
# "bookmarks" keyed by document URI (see lib/settings.rb's note on why this
# port's GSettings for that schema is not relocatable). Without a view there
# is no document to key by, so this port's bookmarks are a single in-memory
# list for the window's current address — a window-session scope rather than
# upstream's "bookmarks survive restarts, per help document" one.
class Window < Adwaita::ApplicationWindow
  DEFAULT_URI = 'help:gnome-help'

  def initialize(application)
    super(application)
    @current_uri = DEFAULT_URI
    @bookmarks = []
    self.title = 'Help'
    width, height = doc_settings.get_value('geometry').to_a
    set_default_size(width, height)
    install_actions
    self.content = toolbar_view
    add_breakpoint(adaptive_breakpoint)
    add_controller(drop_target)
    add_controller(click_gesture)
  end

  def doc_settings = @doc_settings ||= Gio::Settings.new('org.gnome.yelp.documents')

  def current_uri = @current_uri

  # The address-bar override (Ctrl+L), drag-and-drop and the window's own
  # "New Window" action all funnel a new address through here. With no view
  # to hand it to yet, loading a URI means recording it as the window's
  # current address and reflecting it in the header's subtitle.
  def load_uri(uri)
    @current_uri = uri
    header_title.subtitle = uri
  end

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.top_bar_style = :raised
      view.bottom_bar_style = :raised
      view.add_top_bar(header_bar)
      view.content = content_overlay
      view.add_bottom_bar(bottom_toolbar)
    end
  end

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.title_widget = header_title

      bar.pack_start(go_back_button)
      bar.pack_start(go_forward_button)

      bar.pack_end(menu_button)
      bar.pack_end(bookmark_menu_button)
      bar.pack_end(search_button)
    end
  end

  def header_title
    @header_title ||= Adwaita::WindowTitle.new('Help', @current_uri)
  end

  def go_back_button
    @go_back_button ||= Gtk::Button.new(icon_name: 'go-previous-symbolic').tap do |button|
      button.tooltip_text = 'Back'
      button.action_name = 'win.yelp-view-go-back'
    end
  end

  def go_forward_button
    @go_forward_button ||= Gtk::Button.new(icon_name: 'go-next-symbolic').tap do |button|
      button.tooltip_text = 'Forward'
      button.action_name = 'win.yelp-view-go-forward'
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = 'Menu'
      button.primary = true
      button.popover = primary_menu
    end
  end

  def primary_menu = @primary_menu ||= PrimaryMenu.new

  def search_button
    @search_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'edit-find-symbolic'
      button.tooltip_text = 'Search (Ctrl+S)'
      button.signal_connect('toggled') { set_search_mode(button.active?) }
    end
  end

  # The real YelpSearchEntry: upstream swaps it into the header's title
  # widget slot while the search toggle is active (`search_bar` in
  # src/yelp-window.ui is bound bidirectionally to the toggle's state and
  # becomes the header's key-capture widget), inside an `Adw.Clamp` capped
  # at 425px.
  def search_entry
    @search_entry ||= SearchEntry.new(
      results:       bookmark_search_results,
      on_activate:   method(:search_result_activated),
      on_search_all: method(:search_all),
      on_stop_search: -> { search_button.active = false },
    )
  end

  def search_entry_clamp
    @search_entry_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 425
      clamp.child = search_entry.build
    end
  end

  def bookmark_menu_button
    @bookmark_menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'user-bookmarks-symbolic'
      button.tooltip_text = 'Bookmarks'
      button.popover = bookmark_popover.popover
    end
  end

  def bookmark_popover
    @bookmark_popover ||= BookmarkPopover.new(
      bookmarks:        @bookmarks,
      current_bookmark: current_bookmark,
      on_activate:      method(:bookmark_activated),
      on_add:           method(:bookmark_added),
      on_remove:        method(:bookmark_removed),
    )
  end

  # The find bar: a revealer holding a search entry and prev/next/close
  # buttons, shown over the content by the overlay below.
  #
  # Ported from the `find_bar` GtkRevealer in src/yelp-window.ui.
  def find_bar
    @find_bar ||= Gtk::Revealer.new.tap do |revealer|
      revealer.halign = :end
      revealer.valign = :start
      revealer.margin_start = 6
      revealer.margin_end = 6
      revealer.child = find_box
    end
  end

  def find_box
    @find_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.add_css_class('yelp-find-frame')
      box.append(find_entry)
      box.append(find_prev_button)
      box.append(find_next_button)
      box.append(find_close_button)
    end
  end

  def find_entry
    @find_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = 'Search in page…'
    end
  end

  def find_prev_button
    @find_prev_button ||= Gtk::Button.new(icon_name: 'go-up-symbolic').tap do |button|
      button.tooltip_text = 'Previous'
      button.valign = :center
      button.add_css_class('flat')
    end
  end

  def find_next_button
    @find_next_button ||= Gtk::Button.new(icon_name: 'go-down-symbolic').tap do |button|
      button.tooltip_text = 'Next'
      button.valign = :center
      button.add_css_class('flat')
    end
  end

  def find_close_button
    @find_close_button ||= Gtk::Button.new(icon_name: 'window-close-symbolic').tap do |button|
      button.tooltip_text = 'Close Search'
      button.valign = :center
      button.add_css_class('flat')
      button.signal_connect('clicked') { find_bar.reveal_child = false }
    end
  end

  # The overlay the find bar floats over. Upstream's overlaid child is the
  # YelpView; without one yet, this holds the one real thing the window
  # knows about its content: the address it would load.
  def content_overlay
    @content_overlay ||= Gtk::Overlay.new.tap do |overlay|
      overlay.child = content_status_page
      overlay.add_overlay(find_bar)
    end
  end

  def content_status_page
    @content_status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'help-about-symbolic'
      page.title = 'No Page Loaded'
      page.description = @current_uri
    end
  end

  # Moved to by `adaptive_breakpoint` on narrow windows; hidden otherwise.
  def bottom_toolbar
    @bottom_toolbar ||= Gtk::ActionBar.new.tap do |bar|
      bar.visible = false
      bar.pack_start(go_back_button_bottom)
      bar.pack_start(go_forward_button_bottom)
    end
  end

  def go_back_button_bottom
    @go_back_button_bottom ||= Gtk::Button.new(icon_name: 'go-previous-symbolic').tap do |button|
      button.tooltip_text = 'Back'
      button.action_name = 'win.yelp-view-go-back'
    end
  end

  def go_forward_button_bottom
    @go_forward_button_bottom ||= Gtk::Button.new(icon_name: 'go-next-symbolic').tap do |button|
      button.tooltip_text = 'Forward'
      button.action_name = 'win.yelp-view-go-forward'
    end
  end

  # Ported from `adaptive_mode_breakpoint` in src/yelp-window.ui: below
  # 400px the back/forward buttons leave the header, the bookmark button's
  # popover opens upward instead of down, and the bottom toolbar (holding
  # its own back/forward buttons) becomes visible.
  def adaptive_breakpoint
    @adaptive_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse('max-width: 400px'),
    ).tap do |breakpoint|
      breakpoint.add_setter(bottom_toolbar, 'visible', true)
      breakpoint.add_setter(go_back_button, 'visible', false)
      breakpoint.add_setter(go_forward_button, 'visible', false)
      breakpoint.add_setter(bookmark_menu_button, 'direction', GLib::Value.new(Gtk::ArrowType.gtype, :up))
    end
  end

  # Accepting a dropped string and loading it as an address — upstream's
  # `window_on_drop`, minus the `xref:` guard (that scheme only resolves
  # against a loaded document, which this port has none of yet).
  def drop_target
    @drop_target ||= Gtk::DropTarget.new(String, :copy).tap do |target|
      target.signal_connect('drop') do |_target, value, _x, _y|
        load_uri(value)
        true
      end
    end
  end

  # Mouse buttons 8 and 9 (the side buttons on many mice) drive back/forward,
  # exactly as upstream's `window_button_press` does, by activating the same
  # actions the header buttons use.
  def click_gesture
    @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
      gesture.button = 0
      gesture.signal_connect('pressed') do |_gesture, _n_press, _x, _y|
        case gesture.current_button
        when 8 then activate_action('yelp-view-go-back', nil)
        when 9 then activate_action('yelp-view-go-forward', nil)
        end
      end
    end
  end

  private

    def current_bookmark = @bookmarks.find { |bookmark| bookmark.page_id == @current_uri }

    def bookmark_activated(bookmark)
      bookmark_popover.popover.visible = false
      load_uri(bookmark.page_id)
    end

    def bookmark_added(*)
      @bookmarks << Bookmark.new(@current_uri, 'help-about-symbolic', @current_uri)
      bookmark_popover.bookmarks = @bookmarks
      bookmark_popover.current_bookmark = current_bookmark
      search_entry.results = bookmark_search_results
    end

    def bookmark_removed(bookmark)
      @bookmarks.delete(bookmark)
      bookmark_popover.bookmarks = @bookmarks
      bookmark_popover.current_bookmark = current_bookmark
      search_entry.results = bookmark_search_results
    end

    # The search entry's candidate list — upstream's completion model draws
    # from the backend's search index plus the YelpBookmarks interface
    # (bookmarks and read-later entries); without a backend yet (see
    # component-inventory.md) this port's candidates are the window's own
    # bookmarks, which is real data, not a placeholder list.
    def bookmark_search_results
      @bookmarks.map do |bookmark|
        SearchResult.new(
          title: bookmark.title,
          desc:  bookmark.page_id,
          icon:  bookmark.icon,
          page:  bookmark.page_id,
          flags: SearchResult::FLAG_BOOKMARKED,
        )
      end
    end

    def set_search_mode(active)
      if active
        header_bar.title_widget = search_entry_clamp
        search_entry.entry.grab_focus
      else
        header_bar.title_widget = header_title
      end
    end

    def search_result_activated(result)
      search_button.active = false
      load_uri(result.page)
    end

    # Upstream's "Search for <query>" row runs the full-text search backend
    # (yelp-storage's SQLite index) and shows its results as a page; without
    # that backend (a separate porting track) this loads the query itself as
    # the window's address, the same recovery `load_uri` every other address
    # source in this window uses.
    def search_all(query)
      search_button.active = false
      load_uri(query)
    end

    # The go-back/-forward actions are real actions with real enabled state —
    # just permanently disabled until lib/view.rb exists to give them a
    # navigation stack to act on.
    def navigation_action(name)
      Gio::SimpleAction.new(name, nil).tap { |action| action.enabled = false }
    end

    def install_actions
      add_action(navigation_action('yelp-view-go-back'))
      add_action(navigation_action('yelp-view-go-forward'))

      add_action(simple_action('yelp-window-new') { application.new_window })
      add_action(simple_action('yelp-window-close') { close })
      add_action(simple_action('yelp-window-find') { reveal_find_bar })
      add_action(simple_action('yelp-window-ctrll') { show_address_bar })
      add_action(simple_action('yelp-show-about-dialog') { about_dialog.present(self) })
    end

    def simple_action(name)
      Gio::SimpleAction.new(name, nil).tap { |action| action.signal_connect('activate') { yield } }
    end

    def reveal_find_bar
      find_bar.reveal_child = true
      find_entry.grab_focus
    end

    # Ported from `action_ctrll`: swap the header's title widget for an
    # editable entry pre-filled with the current address, selecting
    # everything after the URI scheme; Escape (on the entry's key
    # controller) restores `header_title`.
    def show_address_bar
      header_bar.title_widget = address_entry
      address_entry.text = @current_uri
      address_entry.grab_focus
      scheme_end = @current_uri.index(':')
      address_entry.select_region(scheme_end ? scheme_end + 1 : 0, -1)
    end

    def address_entry
      @address_entry ||= Gtk::Entry.new.tap do |entry|
        entry.signal_connect('activate') do
          load_uri(entry.text)
          header_bar.title_widget = header_title
        end
        entry.add_controller(address_entry_key_controller)
      end
    end

    def address_entry_key_controller
      @address_entry_key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect('key-pressed') do |_controller, keyval, *_rest|
          if keyval == Gdk::Keyval::KEY_Escape
            header_bar.title_widget = header_title
            true
          else
            false
          end
        end
      end
    end

    def about_dialog = @about_dialog ||= AboutDialog.new(Yelp::Rb::VERSION)
end
